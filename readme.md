# Bernstein - Orchestration de Conteneurs avec Kubernetes

Ce projet déploie une application de sondage web multi-composants sur un cluster Kubernetes, en utilisant Traefik comme reverse proxy et load balancer. L'application est inspirée du projet "Example Voting App".

## Composants de l'application

L'application est constituée des éléments suivants :

*   **Poll** : Une application web Python (Flask) qui collecte les votes et les pousse dans une file d'attente Redis.
*   **Redis** : Une file d'attente en mémoire qui stocke temporairement les votes.
*   **Worker** : Une application Java qui consomme les votes depuis Redis et les stocke dans une base de données PostgreSQL.
*   **PostgreSQL** : Une base de données relationnelle qui stocke de manière persistante les votes.
*   **Result** : Une application web Node.js qui récupère les votes depuis PostgreSQL et affiche les résultats.

## Outils d'infrastructure

*   **Traefik (v2.7)** : Agit comme reverse proxy et load balancer (namespace: `kube-public`), exposant les applications `poll` et `result` via des règles d'Ingress. Il fournit également un tableau de bord d'administration.
*   **cAdvisor** : Un outil de monitoring (namespace: `kube-system`) qui fournit des informations sur l'utilisation des ressources des conteneurs.

## Prérequis

*   Un cluster Kubernetes fonctionnel (par exemple, Minikube, k3s, Kind, ou un cluster managé dans le cloud).
*   `kubectl` configuré pour interagir avec votre cluster.
*   (Optionnel, pour le test local) Accès `sudo` pour modifier le fichier `/etc/hosts`.

## Note sur les Namespaces
La plupart des composants de l'application (Poll, Worker, Result, PostgreSQL, Redis) sont déployés dans le namespace `default`. Traefik est dans `kube-public` et cAdvisor dans `kube-system`.

## Déploiement

1.  Clonez ce dépôt (ou assurez-vous d'être dans le répertoire du projet).
2.  Rendez le script de déploiement exécutable :
    ```bash
    chmod +x deploy.sh
    ```
3.  Exécutez le script de déploiement :
    ```bash
    ./deploy.sh
    ```
    Le script va :
    *   Déployer tous les composants Kubernetes (Déploiements, Services, ConfigMaps, Secrets, Ingress, etc.).
    *   Attendre que PostgreSQL soit prêt.
    *   Créer la table `votes` dans PostgreSQL.
    *   Redémarrer l'application `result` pour s'assurer qu'elle prend en compte la table.
    *   Tenter d'ajouter les entrées `poll.dop.io` et `result.dop.io` à votre fichier `/etc/hosts` local (peut nécessiter un mot de passe `sudo`).

## Accès aux applications

Une fois le déploiement terminé et fonctionnel, vous devriez pouvoir accéder aux applications via les URLs standards (le reverse proxy Traefik s'occupe de la redirection vers les bons services). Assurez-vous que votre fichier `/etc/hosts` est correctement configuré.

*   **Application Poll** : `http://poll.dop.io`
*   **Application Result** : `http://result.dop.io`
*   **Tableau de bord Traefik** :
    *   Depuis la VM où Kubernetes s'exécute : `http://localhost:30042`
    *   Depuis une machine hôte (en remplaçant `<NODE_IP>` par l'IP de votre nœud Kubernetes) : `http://<NODE_IP>:30042`

*(Note : Le port 30021 est le NodePort du service Traefik. Bien que vous puissiez l'utiliser, l'accès direct via le nom de domaine est la méthode prévue.)*

## Suppression des ressources

Pour supprimer toutes les ressources Kubernetes créées par ce projet, le script `undeploy.sh` est fourni.

1.  N'oubliez pas de le rendre exécutable si ce n'est pas déjà fait :
    ```bash
    chmod +x undeploy.sh
    ```
2.  Exécutez le script de suppression :
    ```bash
    ./undeploy.sh
    ```
Le script supprimera toutes les ressources listées dans les fichiers YAML du projet.

## Fichiers de configuration

Tous les manifestes Kubernetes se trouvent à la racine du projet (par exemple, `poll.deployment.yaml`, `postgres.service.yaml`, etc.).