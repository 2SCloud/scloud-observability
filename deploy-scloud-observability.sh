#!/usr/bin/env bash


# Mode strict :
# Si une commande échoue, le script s'arrête.
set -e


# Variables :
# ${NAMESPACE} : Définit le nom du namespace.
# ${VALUES_DIR} : Définit le path (Dossier relatif au script) des fichiers de configuration de la stack Grafana.
NAMESPACE="scloud-observability"
VALUES_DIR="./grafana"

echo "Déploiement de la stack Scloud-Observability sur k3s"

# Créer le namespace :
# kubectl create namespace ${NAMESPACE} : Crée le namespace avec le nom adéquat.
# 2>/dev/null : Redirige les erreurs (stderr) vers /dev/null.
# echo "..." : Affiche un avertissement si la commande précedente échoue.
echo "Création du namespace ${NAMESPACE}..."
sudo kubectl create namespace ${NAMESPACE} 2>/dev/null || echo "⚠️  Namespace déjà existant"

# Ajouter les repos Helm :
# helm repo add grafana "..." : Ajoute un dépôt de charts Helm, ici le dépôt officiel de Grafana.
# helm repo update : Met à jour la liste des charts disponibles.
echo "Ajout des repos Helm..."
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Déployer tous les composants :
# helm update --install : Commande permettant de savoir si le chart existe ou non.
# Si le chart existe, il le met à jour, sinon il l'installe.
# mimir, loki... : Nom du release.
# grafana/mimir-distributed, grafana/loki... : Chart à utiliser (format repot/chart).
# -n ${NAMESPACE} : Namespace définit.
# -f ${VALUES_DIR}/mimir-values.yaml... : Fichier de configuration.
echo "Déploiement de Mimir..."
helm upgrade --install mimir grafana/mimir-distributed \
  -n ${NAMESPACE} -f ${VALUES_DIR}/mimir-values.yaml

echo "Déploiement de Loki..."
helm upgrade --install loki grafana/loki \
  -n ${NAMESPACE} -f ${VALUES_DIR}/loki-values.yaml

echo "Déploiement de Tempo..."
helm upgrade --install tempo grafana/tempo \
  -n ${NAMESPACE} -f ${VALUES_DIR}/tempo-values.yaml

echo "Déploiement d'Alloy..."
helm upgrade --install alloy grafana/alloy \
  -n ${NAMESPACE} -f ${VALUES_DIR}/alloy-values.yaml

echo "Déploiement de Grafana..."
helm upgrade --install grafana grafana/grafana \
  -n ${NAMESPACE} -f ${VALUES_DIR}/grafana-values.yaml

# Attendre que les pods soient prêts :
# kubectl wait : Attend qu'une condition soit remplie avant de continuer
# -n ${NAMESPACE} : Namespace définit.
# --for=condition=ready : Attend que le la ressource soit "Ready".
# pod : Type de ressource à surveiller.
# -l app.kubernetes.io/name=grafana... : Selectionne les pods ayant ce label.
# --timeout=300s : Timeout de 5 minutes.
echo "Attente du démarrage des services..."
sudo kubectl -n ${NAMESPACE} wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --timeout=300s
sudo kubectl -n ${NAMESPACE} wait --for=condition=ready pod -l app.kubernetes.io/name=loki --timeout=300s
sudo kubectl -n ${NAMESPACE} wait --for=condition=ready pod -l app.kubernetes.io/name=tempo --timeout=300s

echo ""
echo "Stack scloud-observability déployée avec succès !"