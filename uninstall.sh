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

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

# Paths relative to this script - works from any folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# PREFLIGHT CHECKS
# ============================================================
command -v kubectl >/dev/null 2>&1 || print_error "kubectl not found."
command -v helm >/dev/null 2>&1 || print_error "helm not found."
kubectl cluster-info >/dev/null 2>&1 || print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."

CONTEXT=$(kubectl config current-context)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# ============================================================
# CONFIRMATION
# ============================================================
echo -e "${RED}WARNING: This will completely remove Fortress from this cluster:${NC}"
echo -e "  Context: ${BLUE}$CONTEXT${NC}"
echo -e "  Server:  ${BLUE}$SERVER${NC}"
echo -e "Your own applications will NOT be deleted, but they will no longer be protected."
read -r -p "Type the context name to confirm: " CONFIRM
[[ "$CONFIRM" == "$CONTEXT" ]] || print_error "Context name does not match. Nothing was removed."

# ============================================================
# UNINSTALL
# ============================================================
print_step "Removing ArgoCD applications (your apps keep running)..."
# Remove finalizers first - deleting an Application must never delete your apps
for app in fortress-in-a-box user-workloads; do
    kubectl patch application "$app" -n argocd --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
done
kubectl delete application fortress-in-a-box user-workloads -n argocd --ignore-not-found 2>/dev/null || true
kubectl delete appproject fortress-user-workloads -n argocd --ignore-not-found 2>/dev/null || true

print_step "Uninstalling ArgoCD..."
helm uninstall argocd -n argocd || true
kubectl delete namespace argocd --ignore-not-found --timeout=5m

print_step "Uninstalling Falco..."
helm uninstall falco -n falco || true
kubectl delete namespace falco --ignore-not-found --timeout=5m

print_step "Uninstalling Monitoring Stack (Grafana/Loki)..."
helm uninstall grafana -n monitoring || true
helm uninstall loki -n monitoring || true
kubectl delete namespace monitoring --ignore-not-found --timeout=5m

print_step "Uninstalling Kyverno and Policies..."
kubectl delete -f "$SCRIPT_DIR/k8s/policies/" --ignore-not-found || true
helm uninstall kyverno -n kyverno || true
# Leftover Kyverno webhooks would block every new pod in the cluster
kubectl delete validatingwebhookconfigurations,mutatingwebhookconfigurations \
    -l webhook.kyverno.io/managed-by=kyverno --ignore-not-found
kubectl delete namespace kyverno --ignore-not-found --timeout=5m

print_step "Removing dangling ClusterRoles..."
kubectl delete clusterrole kyverno:webhook --ignore-not-found || true
kubectl delete clusterrolebinding kyverno:webhook --ignore-not-found || true

print_success "Fortress was removed from $CONTEXT."
echo -e "ArgoCD CRDs are kept by Helm on purpose. Remove them manually if you no longer need them."
