#!/bin/bash

kubectl delete -f cadvisor.daemonset.yaml
kubectl delete -f postgres.secret.yaml
kubectl delete -f postgres.configmap.yaml
kubectl delete -f postgres.volume.yaml
kubectl delete -f postgres.deployment.yaml
kubectl delete -f postgres.service.yaml
kubectl delete -f redis.configmap.yaml
kubectl delete -f redis.deployment.yaml
kubectl delete -f redis.service.yaml
kubectl delete -f poll.deployment.yaml
kubectl delete -f poll.service.yaml
kubectl delete -f poll.ingress.yaml
kubectl delete -f result.deployment.yaml
kubectl delete -f result.service.yaml
kubectl delete -f result.ingress.yaml
kubectl delete -f worker.deployment.yaml
kubectl delete -f traefik.deployment.yaml
kubectl delete -f traefik.service.yaml
kubectl delete -f traefik.rbac.yaml

echo "✅ Tous les objets Kubernetes ont été supprimés"