#!/usr/bin/env bash

# ${NAMESPACE} : Nom du namespace à supprimer
NAMESPACE="scloud-observability"

echo "Nettoyage complet de la stack Grafana..."

# Arrêter les port-forwards :
# pkill : Tue des processus par Nom / Pattern.
# -f : Cherche dans la ligne de commande complète (Pas juste le nom du processus).
# "kubectl -n ${NAMESPACE} port-forward" : Pattern à chercher.
# 2>/dev/null : Redirige les erreurs (stderr) vers /dev/null.
# || true : Retourne toujours succès, afin d'éviter les plantages si rien à tuer.
echo "Arrêt des port-forwards..."
pkill -f "kubectl -n ${NAMESPACE} port-forward" 2>/dev/null || true

# sleep 2 : Attend 2 secondes pour laisser le temps aux processus port-forward de se terminer proprement.
sleep 2

# Supprimer les releases Helm :
# helm uninstall : Désinstalle une ou plusieurs releases Helm.
# -n ${NAMESPACE} : Namespace ciblé.
# grafana loki tempo mimir alloy : Liste des releases à désinstaller (en une seule commande).
# 2>/dev/null : Redirige les erreurs (stderr) vers /dev/null.
# || true : Évite l'échec du script si une ou plusieurs releases n'existent pas.
echo "Suppression des releases Helm..."
sudo helm uninstall -n ${NAMESPACE} grafana loki tempo mimir alloy 2>/dev/null || true

# Supprimer le namespace :
# kubectl delete namespace : Supprime le namespace et toutes ses ressources.
# --timeout=60s : Timeout de 60 secondes pour éviter que le script reste bloqué si le namespace ne se supprime pas.
# 2>/dev/null : Redirige les erreurs (stderr) vers /dev/null.
# || true : Retourne toujours succès, afin d'éviter les plantages si le namespace n'existe pas.
echo "Suppression du namespace ${NAMESPACE}..."
sudo kubectl delete namespace ${NAMESPACE} --timeout=60s 2>/dev/null || true

# Nettoyer les logs :
# rm -f : Supprime les fichiers (force, pas d'erreur si le fichier n'existe pas).
# /tmp/pf-*.log : Pattern qui capture tous les fichiers de logs créés par les port-forwards 
# (pf-grafana.log, pf-loki.log, pf-tempo.log, pf-mimir.log, pf-alloy.log).
echo "Nettoyage des logs..."
rm -f /tmp/pf-*.log

# Vérification :
echo ""
echo "Nettoyage terminé !"
echo ""
echo "Vérifications :"

# Vérification du namespace :
# echo -n : Affiche sans retour à la ligne (pour afficher le résultat sur la même ligne).
# kubectl get namespace : Récupère les informations du namespace.
# 2>&1 : Redirige stderr vers stdout pour pouvoir le traiter avec grep.
# grep -q "NotFound" : Cherche "NotFound" en mode silencieux (-q ne retourne qu'un code succès/échec).
# && ... || ... : Affiche "Supprimé" si grep trouve "NotFound", sinon "Existe encore".
echo -n "  • Namespace: "
sudo kubectl get namespace ${NAMESPACE} 2>&1 | grep -q "NotFound" && echo "Supprimé" || echo "Existe encore"

# Vérification des releases Helm :
# helm list -n ${NAMESPACE} : Liste toutes les releases dans le namespace.
# wc -l : Compte le nombre de lignes.
# RELEASES : Stocke le résultat (1 = header uniquement = aucune release, >1 = des releases existent).
# [ "$RELEASES" -eq 1 ] : Compare à 1 (et non 0) car helm list retourne toujours une ligne de header.
# $((RELEASES-1)) : Calcule le nombre réel de releases (total - header).
echo -n "  • Helm releases: "
RELEASES=$(helm list -n ${NAMESPACE} 2>/dev/null | wc -l)
[ "$RELEASES" -eq 1 ] && echo "Aucun" || echo "$((RELEASES-1)) restant(s)"

# Vérification des port-forwards :
# ps aux : Liste tous les processus actifs sur la machine.
# grep -c "[p]ort-forward.*${NAMESPACE}" : Compte les lignes contenant le pattern.
# [p] : Astuce pour exclure la commande grep elle-même des résultats (grep ne matche pas "[p]ort-forward").
# -c : Compte le nombre de lignes trouvées.
# PF_COUNT : Stocke le nombre de processus port-forward actifs.
echo -n "  • Port-forwards: "
PF_COUNT=$(ps aux | grep -c "[p]ort-forward.*${NAMESPACE}")
[ "$PF_COUNT" -eq 0 ] && echo "Aucun" || echo "${PF_COUNT} actif(s)"

echo ""
echo "Vous pouvez maintenant lancer ./deploy-scloud-observability.sh"