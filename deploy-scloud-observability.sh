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

# Arrêter les anciens port-forwards
# pkill : Tue des processus par Nom / Pattern.
# -f : Cherche dans la ligne de commande complète (Pas juste le nom du processus).
# "kubectl -n ${NAMESPACE} port-forward" : Pattern à chercher.
# 2>/dev/null : Redirige les erreurs (stderr) vers /dev/null.
# || true : Retourne toujours succès, afin d'éviter les plantage si rien à tuer.
echo "Nettoyage des anciens port-forwards..."
pkill -f "kubectl -n ${NAMESPACE} port-forward" 2>/dev/null || true
sleep 2

# Démarrer les port-forwards en arrière-plan
# kubectl port-forward : Crée un tunnel entre la machine et le cluster.
# svc/grafana... : Cible le service nommé.
# 3000:80... : Port local (Machine) : Port du service dans le cluster.
# > /tmp/pf-grafana.log : Redirige la sortie standard (stdout) vers un fichier log.
# 2>&1 : Redirige aussi les erreurs (stderr) vers le même fichier.
# & : Lance le processus en arrière-plan.
echo "Démarrage des port-forwards..."

sudo kubectl -n ${NAMESPACE} port-forward svc/grafana 3000:80 > /tmp/pf-grafana.log 2>&1 &
echo "Grafana: http://localhost:3000"

sudo kubectl -n ${NAMESPACE} port-forward svc/loki 3100:3100 > /tmp/pf-loki.log 2>&1 &
echo "Loki: http://localhost:3100"

sudo kubectl -n ${NAMESPACE} port-forward svc/tempo 4318:4318 > /tmp/pf-tempo.log 2>&1 &
echo "Tempo: http://localhost:4318"

sudo kubectl -n ${NAMESPACE} port-forward svc/mimir-k3s-gateway 8080:80 > /tmp/pf-mimir.log 2>&1 &
echo "Mimir: http://localhost:8080"

sudo kubectl -n ${NAMESPACE} port-forward svc/alloy 14318:4318 > /tmp/pf-alloy.log 2>&1 &
echo "Alloy: http://localhost:12345"

#Health checks
echo ""
echo "Vérification de la santé des services..."
sleep 5

# curl : Fait une requête HTTP.
# -sf : Mode silencieux, fail silencieusement en cas d'erreur HTTP.
# http://... : URL (Endpoints spécifiques à chaque service) à tester.
# 2>/dev/null : Redirige les erreurs (stderr) vers /dev/null.
# && .. : Affiche OK / KO si le curl réussit, ou non.
curl -sf http://localhost:3000/api/health > /dev/null && echo "Grafana OK" || echo "Grafana KO"
curl -sf http://localhost:8080/prometheus/api/v1/status/buildinfo > /dev/null && echo "Mimir OK" || echo "Mimir KO"
curl -sf http://localhost:3100/ready > /dev/null && echo "Loki OK" || echo "Loki KO"

echo ""
echo "Stack déployée avec succès !"
echo ""
echo "Points d'Accès:"
echo "  • Grafana: http://localhost:3000 (admin/admin)"
echo "  • Mimir:   http://localhost:8080"
echo "  • Loki:    http://localhost:3100"
echo "  • Tempo:   http://localhost:4318"
echo "  • Alloy:   http://localhost:12345"
echo ""
echo "Pour arrêter les port-forwards:"
echo "  pkill -f 'kubectl -n ${NAMESPACE} port-forward'"