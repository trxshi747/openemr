#!/bin/bash
echo "==============================="
echo "MÉTRIQUES KUBERNETES - $(date)"
echo "==============================="

echo ""
echo "--- Nombre de pods actifs ---"
kubectl get pods -n openemr | grep Running | wc -l

echo ""
echo "--- CPU / RAM par pod ---"
kubectl top pods -n openemr

echo ""
echo "--- Statut HPA ---"
kubectl get hpa -n openemr

echo ""
echo "--- Événements HPA ---"
kubectl describe hpa openemr-hpa -n openemr | grep -A10 "Events"
