#!/bin/bash

echo "🗑️ Suppression de toutes les ressources Kubernetes du projet..."

# kubectl peut prendre tous les fichiers en une seule commande
kubectl delete -f result.ingress.yaml -f result.service.yaml -f result.deployment.yaml \
               -f poll.ingress.yaml -f poll.service.yaml -f poll.deployment.yaml \
               -f worker.deployment.yaml \
               -f redis.service.yaml -f redis.deployment.yaml -f redis.configmap.yaml \
               -f postgres.service.yaml -f postgres.deployment.yaml -f postgres.volume.yaml -f postgres.configmap.yaml -f postgres.secret.yaml \
               -f traefik.service.yaml -f traefik.deployment.yaml -f traefik.rbac.yaml -f traefik.ingressclass.yaml \
               -f cadvisor.daemonset.yaml --ignore-not-found=true

echo "✅ Suppression terminée."