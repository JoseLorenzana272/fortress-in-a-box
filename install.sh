#!/bin/bash
set -e

# ============================================================
# FORTRESS IN A BOX - One-Click Installer
# Enterprise-grade security for NGOs, journalists & activists
# ============================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════╗"
    echo "║         FORTRESS IN A BOX v1.0             ║"
    echo "║   Enterprise Security for Those Who Need   ║"
    echo "║              It Most :)                    ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${YELLOW}[FORTRESS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

# ============================================================
# PREFLIGHT CHECKS
# ============================================================
preflight_checks() {
    print_step "Running preflight checks..."

    command -v kubectl >/dev/null 2>&1 || print_error "kubectl not found. Please install kubectl first."
    command -v helm >/dev/null 2>&1 || print_error "helm not found. Please install helm first."

    kubectl cluster-info >/dev/null 2>&1 || print_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."

    print_success "All preflight checks passed."
}

# ============================================================
# COLLECT USER INPUT
# ============================================================
collect_input() {
    print_step "Configuration..."

    echo -e "Enter your GitHub repository URL (e.g. https://github.com/org/repo):"
    read -r GITHUB_REPO

    echo -e "Enter your Discord webhook URL (or press Enter to skip):"
    read -r DISCORD_WEBHOOK

    echo -e "Enter your Grafana admin password (default: fortress-admin):"
    read -r GRAFANA_PASSWORD
    GRAFANA_PASSWORD=${GRAFANA_PASSWORD:-fortress-admin}
}

# ============================================================
# ADD HELM REPOS
# ============================================================
setup_helm_repos() {
    print_step "Adding Helm repositories..."

    helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null || true
    helm repo add falcosecurity https://falcosecurity.github.io/charts 2>/dev/null || true
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
    helm repo update

    print_success "Helm repositories ready."
}

# ============================================================
# INSTALL KYVERNO
# ============================================================
install_kyverno() {
    print_step "Installing Kyverno (admission control)..."

    helm upgrade --install kyverno kyverno/kyverno \
        --namespace kyverno \
        --create-namespace \
        --wait

    print_step "Applying security policies..."
    kubectl apply -f k8s/policies/

    print_success "Kyverno installed. Security policies active."
}

# ============================================================
# INSTALL FALCO
# ============================================================
install_falco() {
    print_step "Installing Falco (runtime threat detection)..."

    if [ -n "$DISCORD_WEBHOOK" ]; then
        helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --create-namespace \
        --set driver.kind=modern_ebpf \
        --set tty=true \
        --set falcosidekick.enabled=true \
        --set falcosidekick.webui.enabled=true \
        --set falcosidekick.replicaCount=1 \
        --set falcosidekick.webui.replicaCount=1 \
        --set falcosidekick.config.discord.webhookurl="$DISCORD_WEBHOOK" \
        --set falcosidekick.config.discord.minimumpriority="critical" \
        --set falcosidekick.config.loki.hostport="http://loki-gateway.monitoring.svc.cluster.local:80" \
        --set falcosidekick.config.loki.minimumpriority="notice" \
        --wait
    else
        helm upgrade --install falco falcosecurity/falco \
        --namespace falco \
        --create-namespace \
        --set driver.kind=modern_ebpf \
        --set tty=true \
        --set falcosidekick.enabled=true \
        --set falcosidekick.webui.enabled=true \
        --set falcosidekick.replicaCount=1 \
        --set falcosidekick.webui.replicaCount=1 \
        --set falcosidekick.config.loki.hostport="http://loki-gateway.monitoring.svc.cluster.local:80" \
        --set falcosidekick.config.loki.minimumpriority="notice" \
        --wait
    fi

    print_success "Falco installed. Runtime monitoring active."
}

# ============================================================
# INSTALL GRAFANA + LOKI
# ============================================================
install_monitoring() {
    print_step "Installing Loki (log storage)..."

    helm upgrade --install loki grafana/loki \
        --namespace monitoring \
        --create-namespace \
        --set loki.auth_enabled=false \
        --set loki.commonConfig.replication_factor=1 \
        --set loki.storage.type=filesystem \
        --set loki.useTestSchema=true \
        --set deploymentMode=SingleBinary \
        --set singleBinary.replicas=1 \
        --set read.replicas=0 \
        --set write.replicas=0 \
        --set backend.replicas=0 \
        --set chunksCache.enabled=false \
        --set resultsCache.enabled=false \
        --wait

    print_step "Installing Grafana (security dashboard)..."

    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --create-namespace \
        --set adminPassword="$GRAFANA_PASSWORD" \
        --set service.type=ClusterIP \
        --set persistence.enabled=false \
        --set sidecar.dashboards.enabled=true \
        --set sidecar.dashboards.label=grafana_dashboard \
        --set sidecar.datasources.enabled=true \
        --set sidecar.datasources.label=grafana_datasource \
        --wait

    print_step "Importing Fortress security dashboard..."
    kubectl create configmap fortress-dashboard \
        --from-file=k8s/grafana/fortress-dashboard.json \
        --namespace monitoring \
        --dry-run=client -o yaml | kubectl apply -f -

    kubectl label configmap fortress-dashboard \
        -n monitoring \
        grafana_dashboard=1 --overwrite

    kubectl apply -f k8s/grafana/datasource-loki.yaml

    print_success "Monitoring stack installed."
}

# ============================================================
# INSTALL ARGOCD
# ============================================================
install_argocd() {
    print_step "Installing ArgoCD (GitOps engine)..."

    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --wait

    print_step "Connecting ArgoCD to your repository..."
    # Replace repo URL in the ArgoCD application manifest
    sed "s|https://github.com/JoseLorenzana272/fortress-in-a-box|$GITHUB_REPO|g" \
        k8s/argocd/fortress-app.yaml | kubectl apply -f -

    print_success "ArgoCD installed. GitOps active."
}

# ============================================================
# PRINT FINAL SUMMARY
# ============================================================
print_summary() {
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)

    echo -e "\n${GREEN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║         FORTRESS IS ACTIVE :D              ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "Access your tools:\n"
    echo -e "  ${BLUE}Grafana Dashboard:${NC}"
    echo -e "  kubectl port-forward svc/grafana -n monitoring 3000:80"
    echo -e "  http://localhost:3000 (admin / $GRAFANA_PASSWORD)\n"
    echo -e "  ${BLUE}ArgoCD:${NC}"
    echo -e "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo -e "  https://localhost:8080 (admin / $ARGOCD_PASSWORD)\n"
    echo -e "  ${BLUE}Falcosidekick UI:${NC}"
    echo -e "  kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802"
    echo -e "  http://localhost:2802\n"
    echo -e "${YELLOW}Your cluster is now protected. Stay safe.${NC}\n"
}

# ============================================================
# MAIN
# ============================================================
print_banner
preflight_checks
collect_input
setup_helm_repos
install_kyverno
install_monitoring
install_falco
install_argocd
print_summary