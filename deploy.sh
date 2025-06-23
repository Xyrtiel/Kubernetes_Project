#!/bin/bash

set -e

echo "🚀 Déploiement du projet Kubernetes..."

# 1. Monitoring - cAdvisor
echo "✅ Déploiement de cAdvisor..."
kubectl apply -f cadvisor.daemonset.yaml

# 2. PostgreSQL (Secret, ConfigMap, Volume, Déploiement, Service)
echo "✅ Déploiement de PostgreSQL..."
kubectl apply -f postgres.secret.yaml
kubectl apply -f postgres.configmap.yaml
kubectl apply -f postgres.volume.yaml
kubectl apply -f postgres.deployment.yaml
kubectl apply -f postgres.service.yaml

# 3. Redis
echo "✅ Déploiement de Redis..."
kubectl apply -f redis.configmap.yaml
kubectl apply -f redis.deployment.yaml
kubectl apply -f redis.service.yaml

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
echo "💤 Pause pour s'assurer que le service PostgreSQL est prêt à accepter les connexions..."
sleep 10 # Short delay to allow DB service to fully initialize after pod is ready

echo "✅ Création de la table 'votes' dans PostgreSQL..."
kubectl exec deployment/postgres -n default -- psql -h localhost -U postgres -d votes -c "CREATE TABLE IF NOT EXISTS votes (id text PRIMARY KEY, vote text NOT NULL);"

echo "🔄 Redémarrage du déploiement 'result' pour s'assurer qu'il voit la table..."
kubectl rollout restart deployment/result -n default
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
echo "🌐 Accès :"
echo "  - Poll App : http://poll.dop.io:30021"
echo "  - Result App : http://result.dop.io:30021"
echo "  - Traefik Dashboard (depuis la VM) : http://localhost:30042 (ou http://$NODE_IP:30042 depuis l'hôte)"