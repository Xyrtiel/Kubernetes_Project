#!/bin/bash

set -e

echo "🚀 Déploiement du projet Kubernetes..."

# 1. Monitoring - cAdvisor
echo "✅ Déploiement de cAdvisor..."
kubectl apply -f cadvisor.daemonset.yaml

# 2. PostgreSQL (Secret, ConfigMap, Volume, Déploiement, Service)
echo "✅ Déploiement de PostgreSQL..."
kubectl apply -f postgres.secret.yaml -f postgres.configmap.yaml -f postgres.volume.yaml -f postgres.deployment.yaml -f postgres.service.yaml

# 3. Redis
echo "✅ Déploiement de Redis..."
kubectl apply -f redis.configmap.yaml -f redis.deployment.yaml -f redis.service.yaml

# 4. Applications poll, worker, result + ingress
echo "✅ Déploiement de l'application (poll, worker, result)..."
kubectl apply -f poll.deployment.yaml -f poll.service.yaml -f poll.ingress.yaml -f worker.deployment.yaml -f result.deployment.yaml -f result.service.yaml -f result.ingress.yaml

# 5. Traefik
echo "✅ Déploiement de Traefik..."
# On déploie le ServiceAccount, le RBAC, l'IngressClass et le Service AVANT le Déploiement
# pour éviter une race condition où le pod Traefik démarre avant que son service n'existe.
kubectl apply -f traefik.rbac.yaml
kubectl apply -f traefik.ingressclass.yaml
kubectl apply -f traefik.service.yaml
kubectl apply -f traefik.deployment.yaml

# 6. Initialiser la base PostgreSQL avec la table "votes"
echo "⏳ Attente du démarrage de PostgreSQL..."
kubectl wait deployment/postgres --for=condition=available --timeout=180s -n default

echo "⏳ Attente que PostgreSQL accepte les connexions..."
retries=15
until kubectl exec deployment/postgres -n default -- pg_isready -U postgres -d votes -h localhost -q; do
  retries=$((retries - 1))
  if [ $retries -eq 0 ]; then
    echo "❌ Erreur: PostgreSQL n'est pas devenu prêt à temps."
    exit 1
  fi
  echo "PostgreSQL n'est pas encore prêt, nouvelle tentative dans 5 secondes..."
  sleep 5
done

echo "✅ Initialisation de la base de données et nettoyage des anciens votes..."
POD_NAME=$(kubectl get pod -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl cp schema.sql default/${POD_NAME}:/tmp/schema.sql
kubectl exec deployment/postgres -n default -- psql -h localhost -U postgres -d votes -f /tmp/schema.sql
kubectl exec deployment/postgres -n default -- psql -h localhost -U postgres -d votes -c "TRUNCATE TABLE votes;"

echo "🔄 Redémarrage des déploiements 'worker' et 'result' pour garantir un état propre..."
kubectl rollout restart deployment/worker -n default
kubectl rollout restart deployment/result -n default
kubectl rollout status deployment/worker -n default --timeout=120s
kubectl rollout status deployment/result -n default --timeout=120s # Attend que le redémarrage soit terminé

# 7. Ajout des entrées hosts locales
echo "✅ Ajout de poll.dop.io et result.dop.io à /etc/hosts..."
# Essaye de récupérer l'ExternalIP du premier nœud.
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')

if [ -z "$NODE_IP" ]; then
  echo "ℹ️ Aucune ExternalIP trouvée pour le premier nœud. Tentative avec InternalIP..."
  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

if [ -z "$NODE_IP" ]; then
  echo "❌ Erreur: Impossible de déterminer l'adresse IP du nœud pour /etc/hosts."
  exit 1
fi
echo "ℹ️ Utilisation de l'IP $NODE_IP pour poll.dop.io et result.dop.io dans /etc/hosts (sur cette machine)."
echo "$NODE_IP poll.dop.io result.dop.io" | sudo tee -a /etc/hosts

echo "🎉 Déploiement terminé avec succès !"
echo "🌐 Accès aux applications :"
echo "  - Application Poll : http://poll.dop.io"
echo "  - Application Result : http://result.dop.io"
echo "  - Tableau de bord Traefik : http://$NODE_IP:30042"

# IF NOT WORKING WRITE : MINIKUBE STATUS, MINIKUBE START