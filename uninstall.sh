#!/bin/bash
set -e

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "\n${YELLOW}[FORTRESS UNINSTALL]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# ============================================================
# UNINSTALL SCRIPT
# ============================================================
echo -e "${RED}WARNING: This will completely remove Fortress from your Kubernetes cluster.${NC}"
read -p "Are you sure you want to proceed? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

print_step "Uninstalling ArgoCD..."
helm uninstall argocd -n argocd || true
kubectl delete namespace argocd --ignore-not-found

print_step "Uninstalling Falco..."
helm uninstall falco -n falco || true
kubectl delete namespace falco --ignore-not-found

print_step "Uninstalling Monitoring Stack (Grafana/Loki)..."
helm uninstall grafana -n monitoring || true
helm uninstall loki -n monitoring || true
kubectl delete configmap fortress-dashboard -n monitoring --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found

print_step "Uninstalling Kyverno and Policies..."
kubectl delete -f k8s/policies/ --ignore-not-found || true
helm uninstall kyverno -n kyverno || true
kubectl delete namespace kyverno --ignore-not-found

print_step "Removing dangling ClusterRoleBindings / Webhooks..."
kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io kyverno-resource-validating-webhook-cfg --ignore-not-found || true
kubectl delete mutatingwebhookconfigurations.admissionregistration.k8s.io kyverno-resource-mutating-webhook-cfg --ignore-not-found || true
kubectl delete clusterrole kyverno:webhook --ignore-not-found || true
kubectl delete clusterrolebinding kyverno:webhook --ignore-not-found || true

print_success "Uninstall complete! Your cluster is now effectively a clean slate for Fortress."
