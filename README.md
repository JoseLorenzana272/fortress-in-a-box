# 🏰 Fortress in a Box

> Enterprise-grade Kubernetes security for NGOs, journalists, and activists —
> delivered in a single command.

![License](https://img.shields.io/badge/license-MIT-blue)
![Security](https://img.shields.io/badge/security-hardened-green)
![Kubernetes](https://img.shields.io/badge/kubernetes-ready-blue)
![Made with](https://img.shields.io/badge/made%20with-❤️%20for%20NGOs-red)

<img width="1280" height="720" alt="fortress-logo" src="https://github.com/user-attachments/assets/b399b965-9f2b-43fb-9b2c-182e6c9d7d63" />

## Who This Is For

If you are a small investigative journalism group, a human rights organization,
or an activist collective running a website or application — and you are terrified
of getting hacked — this project is for you.

State-sponsored hackers regularly target NGOs because they know these organizations
handle sensitive data (whistleblower identities, refugee tracking, corruption evidence)
but have zero security budget.

**Fortress in a Box gives you the same security infrastructure used by Fortune 500
companies — completely free, in under 5 minutes.**

## Why This Exists

This is not a theoretical problem. NGOs get hacked constantly:

- **Red Cross (2022)** — 515,000+ vulnerable people's data stolen, including 
  missing persons and detainees. The "Restoring Family Links" program had to 
  shut down. Real people couldn't find their missing relatives.
- **Amnesty International (2022)** — Breached by state-sponsored attackers. 
  An organization that exists to protect human rights was itself being surveilled.
- **Bellingcat (ongoing)** — The investigative journalism group that exposed 
  war crimes is constantly targeted by state actors trying to destroy their evidence.

The pattern is always the same: small team, critical data, zero security budget.
**Fortress in a Box exists to change that.**

---

## What It Protects You From

| Threat | How Fortress Stops It |
|--------|----------------------|
| Hacker opens a shell in your container | Falco detects it in seconds and alerts you on Discord |
| Developer deploys an app running as root | Kyverno blocks it before it ever reaches the cluster |
| Vulnerable image with known CVEs | Trivy scans every image in CI/CD — pipeline fails if vulnerabilities found |
| Someone deletes your security policies | ArgoCD detects the drift and restores them automatically |
| Junior dev uses `:latest` image tag | Kyverno blocks it — only pinned versions allowed |

---

## The 4 Layers of Protection
```
┌─────────────────────────────────────────────────────┐
│                    YOUR APPLICATION                 │
├─────────────────────────────────────────────────────┤
│  LAYER 1 — CI/CD (GitHub Actions + Trivy)           │
│  Every image is scanned before it can be deployed   │
├─────────────────────────────────────────────────────┤
│  LAYER 2 — Admission Control (Kyverno)              │
│  Bad deployments are blocked before they run        │
├─────────────────────────────────────────────────────┤
│  LAYER 3 — Runtime Detection (Falco)                │
│  Suspicious behavior is detected in real time       │
├─────────────────────────────────────────────────────┤
│  LAYER 4 — GitOps (ArgoCD)                          │
│  Git is the source of truth — drift is auto-fixed   │
└─────────────────────────────────────────────────────┘
```

---

## Prerequisites

Before running the installer, make sure you have:

- A Kubernetes cluster (local k3s, DigitalOcean, Linode, or any cloud provider)
- `kubectl` installed and configured (`kubectl cluster-info` should work)
- `helm` v3+ installed
- A GitHub repository for your application
- (Optional) A Discord webhook URL for real-time alerts

---

## Installation
```bash
git clone https://github.com/JoseLorenzana272/fortress-in-a-box.git
cd fortress-in-a-box
chmod +x install.sh
./install.sh
```

The installer will ask you for:
1. Your application's GitHub repository URL
2. Your Discord webhook URL (optional but recommended)
3. A Grafana admin password

In about 5 minutes, you will see:
```
╔════════════════════════════════════════════╗
║         FORTRESS IS ACTIVE :D              ║
╚════════════════════════════════════════════╝

Access your tools:

  Grafana Dashboard:
  kubectl port-forward svc/grafana -n monitoring 3000:80
  http://localhost:3000

  ArgoCD:
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  https://localhost:8080

  Falcosidekick UI:
  kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802
  http://localhost:2802
```

---

## Verifying It Works

**Test 1 — Kyverno blocks a bad deployment:**
```bash
# This should be DENIED
kubectl run hacker-pod --image=nginx:latest
# Expected: FORTRESS SECURITY: Using 'latest' image tag is not allowed!
```

**Test 2 — Falco detects a shell in a container:**
```bash
# Deploy the example app first
kubectl apply -f k8s/examples/secure-deployment-example.yaml

# Simulate an attacker opening a shell
kubectl exec -it <your-pod-name> -- /bin/sh

# Expected: Alert fires in Discord and Grafana within seconds
```

**Test 3 — ArgoCD restores deleted policies:**
```bash
# Delete a security policy
kubectl delete validatingpolicy disallow-root-user

# Wait 3 minutes, then check
kubectl get validatingpolicy disallow-root-user
# Expected: Policy is back — ArgoCD restored it from Git
```

---

## How It Protects Your Existing Apps

Once installed, Fortress automatically protects **every app running in your cluster** 
— no additional configuration needed.
```
Your cluster after ./install.sh:

├── Your refugee tracking app     ← Falco watches this automatically
├── Your whistleblower portal     ← Falco watches this automatically  
├── Your internal comms tool      ← Falco watches this automatically
└── Fortress (Falco, Kyverno, Grafana, ArgoCD)

If a hacker gets into ANY of your apps and opens a shell:
→ Falco detects it in seconds
→ Discord alert fires immediately  
→ Grafana dashboard lights up red

If anyone tries to deploy something insecure:
→ Kyverno blocks it with a clear error message
→ Nothing insecure ever reaches your cluster
```
---

## Deploying Your Application Inside the Fortress

Copy the example workflow and deployment into your own repository:
```
your-app/
├── Dockerfile
├── .github/
│   └── workflows/
│       └── build.yml        ← copy from k8s/examples/example-workflow.yml
└── k8s/
    └── deployment.yaml      ← copy from k8s/examples/secure-deployment-example.yaml
```

Your deployment(s) must satisfy all 6 security policies:

| Policy | What It Requires |
|--------|-----------------|
| `disallow-root-user` | `runAsNonRoot: true` at pod and container level |
| `disallow-privileged-containers` | `privileged: false` |
| `require-resource-limits` | CPU and memory limits defined |
| `disallow-latest-tag` | Image pinned to a specific version or SHA |
| `require-readonly-rootfs` | `readOnlyRootFilesystem: true` |
| `disallow-host-network` | `hostNetwork` not set or `false` |

If your app needs to write to disk, use `emptyDir` volumes for specific paths:
```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

---

## Architecture
```
GitHub Repository (Source of Truth)
         │
         ▼
GitHub Actions CI/CD
  ├── docker build
  ├── trivy scan ──── FAIL if CVEs found
  ├── docker push to GHCR
  └── update deployment image tag
         │
         ▼
ArgoCD (watches repo every 3 min)
  └── kubectl apply (automatic)
         │
         ▼
Kubernetes Cluster
  ├── Kyverno ──── blocks bad deployments
  ├── Falco ───── detects runtime threats
  │     └── Falcosidekick
  │           ├── Discord alerts
  │           └── Loki (log storage)
  └── Grafana ─── security dashboard
```

---

## Security Policies Reference

| Policy | Threat It Prevents |
|--------|-------------------|
| `disallow-root-user` | Container escape via root privileges |
| `disallow-privileged-containers` | Full host kernel access |
| `require-resource-limits` | Denial of service via resource exhaustion |
| `disallow-latest-tag` | Supply chain attacks via mutable image tags |
| `require-readonly-rootfs` | Malware installation at runtime |
| `disallow-host-network` | Network traffic sniffing |

---

## Contributing

This project exists to protect people who need it most. Contributions are welcome:

- **New Kyverno policies** — add them to `k8s/policies/`
- **New Falco rules** — add them to `k8s/falco/`
- **Grafana dashboard improvements** — export JSON and add to `k8s/grafana/`
- **Bug reports and issues** — open a GitHub issue

---

## License

MIT — free to use, modify, and distribute.

---

*Built for the people who protect others.*

---

## Author

Built by [Jose Lorenzana](https://github.com/JoseLorenzana272)  
Connect on [LinkedIn](https://www.linkedin.com/in/jose-lorenzana-medina/)
