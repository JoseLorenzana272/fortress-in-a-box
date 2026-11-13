# 🏰 Fortress in a Box

> Enterprise-grade Kubernetes security for NGOs, journalists, and activists —
> delivered in a single command.

![License](https://img.shields.io/badge/license-MIT-blue)
![Security](https://img.shields.io/badge/security-hardened-green)
![Kubernetes](https://img.shields.io/badge/kubernetes-ready-blue)
![Made with](https://img.shields.io/badge/made%20with-❤️%20for%20NGOs-red)

<img width="1920" height="1080" alt="FORTRESS-logo" src="https://github.com/user-attachments/assets/7aef3e3a-c75a-4869-812a-1d45cf0bdbe6" />

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
| A manifest copied from a tutorial adds `SYS_ADMIN` or other root powers | Kyverno blocks it — containers cannot add Linux capabilities or escalate privileges |
| Someone attaches a privileged debug container to a running app | Kyverno blocks it — debug containers must be non-root, read-only and unprivileged |

### What Fortress does not protect

Fortress raises the bar, but it is not a complete security program:

- **Cluster and ArgoCD admins.** Anyone with admin access to the cluster or the ArgoCD UI can turn Fortress off. Protect these credentials and change the ArgoCD password after installing.
- **Platform namespaces.** `kube-system`, `argocd`, `monitoring`, `falco` and `kyverno` are not checked by the policies (Falco needs privileges to work). Your apps cannot deploy there, but cluster admins can.
- **`kubectl debug` access.** Debug containers are restricted, but they can still see your app's processes and network. Only give this permission to people you trust.
- **What you delete from Git.** ArgoCD removes from the cluster whatever you remove from your app repository, including volumes and their data.
- **Alert history.** Loki and Grafana do not use persistent storage yet, so stored alerts are lost when their pods restart. Discord alerts are not affected.
- **Learning mode.** While Fortress is in learning mode, the pod policies only warn, so insecure workloads are allowed. Use it while you fix your apps, then switch to enforce.
- **Outside the cluster.** Phishing, stolen GitHub accounts, secrets committed to code and backups are out of scope.

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

Falco needs privileged pods and a Linux kernel 5.8+ (most clusters; not GKE Autopilot).

---

## Installation
```bash
git clone --branch v2.0.0 https://github.com/JoseLorenzana272/fortress-in-a-box.git
cd fortress-in-a-box
chmod +x install.sh
./install.sh
```

The installer will ask you for:
1. Your application's GitHub repository URL
2. Your Discord webhook URL (optional but recommended)
3. The local path to your application's code (to auto-inject the Trivy workflow)
4. A Grafana admin password
5. Learning or enforce mode (it recommends one, see [Learning and enforce mode](#learning-and-enforce-mode))
6. Whether to install the `fortress` command

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
  https://localhost:8080 (username: admin)
  To see your password, run:
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  Tip: after your first login, change it in User Info and delete that secret:
  kubectl -n argocd delete secret argocd-initial-admin-secret

  Falcosidekick UI:
  kubectl port-forward svc/falco-falcosidekick-ui -n falco 2802:2802
  http://localhost:2802

  Fortress mode: LEARNING (policies warn, nothing is blocked yet)
  See what to fix:          fortress audit report
  When everything is fixed: fortress mode enforce
```

### Versions and updates

- **Release (recommended):** `git clone --branch <version> ...` keeps your cluster on that version. Changes on `main` never reach it until you update. This applies to releases from v2.0.0 onwards.
- **Development (`main`):** every change merged into `main` reaches your cluster within about 3 minutes. The installer warns you and asks before continuing (Enter continues).

To update, install the new release the same way, in a new folder:
```bash
git clone --branch <new-version> https://github.com/JoseLorenzana272/fortress-in-a-box.git fortress-<new-version>
cd fortress-<new-version>
./install.sh
```
The installer asks the same questions as the first time, so have your app repository URL and the same Grafana password ready. Your apps keep running during the update.

To use your own fork, edit `k8s/argocd/fortress-app.yaml` in your fork and set `repoURL` to your fork and `targetRevision` to your branch or tag. Fortress reads this file from Git, so the change must be committed there.

---

## Learning and enforce mode

| Mode | Insecure workloads |
|------|--------------------|
| **Learning** | Allowed. You get a warning when you deploy them, and they appear in `fortress audit report`. |
| **Enforce** | Blocked. |

In both modes, debug containers stay blocked, apps cannot deploy into platform namespaces, Falco keeps alerting and ArgoCD keeps restoring Fortress.

The installer recommends **learning** if your cluster already runs apps, so nothing breaks while you fix them, and **enforce** if it is empty.

To move from learning to enforce:
```bash
fortress audit report    # what to fix, with instructions
# fix your manifests and redeploy
fortress mode enforce    # refuses while any app would break
```
In enforce mode, an app that does not meet the policies keeps running but cannot start again after a restart. That is why `fortress mode enforce` refuses until everything is fixed. `fortress mode enforce --force` switches anyway after you type `enforce`.

### The `fortress` command

The installer can add `fortress` to your PATH (`~/.local/bin`). Otherwise, run `./fortress` from this folder.

| Command | What it does |
|---------|--------------|
| `fortress status` | Mode, version and health of the policies, isolation, Falco and Kyverno. Warns if someone modified Fortress. |
| `fortress audit report` | Workloads that do not meet the policies, and how to fix each one |
| `fortress audit status` | One-line summary |
| `fortress mode enforce` | Switch to enforce mode (refuses if an app would break) |
| `fortress mode learning` | Switch to learning mode (asks first) |

```
$ fortress audit report
Namespace    Workload   Policy                   Status
───────────────────────────────────────────────────────
radio-libre  wordpress  disallow-latest-tag      FAIL
radio-libre  wordpress  require-resource-limits  FAIL

How to fix:
  radio-libre/wordpress
    • Container "wordpress" must use a pinned image version (like nginx:1.27) or a sha256 digest, not :latest or no tag.
    • Container "wordpress" must set resources.limits.cpu and resources.limits.memory.
```

Use the CLI from the folder you installed from. It refuses to change modes if that folder is a different Fortress version than the cluster.

---

## Verifying It Works

**Test 1 — Kyverno blocks a bad deployment:**
```bash
# This should be DENIED in enforce mode (in learning mode you get warnings instead)
kubectl run hacker-pod --image=nginx:latest
# Expected: FORTRESS SECURITY: Container "hacker-pod" ... (the message says what to fix)
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

# Wait a few seconds, then check
kubectl get validatingpolicy disallow-root-user
# Expected: Policy is back — ArgoCD restored it from Git
```

**Test 4 — Everything at a glance:**
```bash
fortress status
# Expected: every line marked ✓
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

During setup, `install.sh` automatically scaffolds a `trivy-security.yml` file for you (either injecting it directly into your local app repository or placing it in your current directory). 

Move/Commit this file to enable Layer 1 (CI/CD scanning). Then, deploy your app using our secure template:
```
your-app/
├── Dockerfile
├── .github/
│   └── workflows/
│       └── trivy-security.yml   ← automatically generated by install.sh
└── k8s/
    └── deployment.yaml          ← copy from k8s/examples/secure-deployment-example.yaml
```

Fortress enforces 9 security policies. Your deployment(s) must satisfy these 8 (the 9th, `disallow-insecure-ephemeral-containers`, only applies when someone runs `kubectl debug` — see [Debugging a running pod](#debugging-a-running-pod-kubectl-debug)):

| Policy | What It Requires |
|--------|-----------------|
| `disallow-root-user` | `runAsNonRoot: true` on the pod (or on each container) |
| `disallow-privileged-containers` | `privileged: false` |
| `require-resource-limits` | CPU and memory limits defined |
| `disallow-latest-tag` | Image pinned to a specific version or SHA |
| `require-readonly-rootfs` | `readOnlyRootFilesystem: true` |
| `disallow-host-network` | `hostNetwork` not set or `false` |
| `disallow-host-namespaces` | `hostPID` and `hostIPC` not set or `false` |
| `disallow-capabilities-and-escalation` | No added Linux capabilities (except `NET_BIND_SERVICE`) and `allowPrivilegeEscalation` not set to `true` |

Most apps never declare capabilities, so they pass without changes. Apps that genuinely need extra capabilities (for example a VPN sidecar that needs `NET_ADMIN`) will be rejected; ask your cluster admin before adding them.

If your app needs to write to disk, use `emptyDir` volumes for specific paths:
```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

### Debugging a running pod (`kubectl debug`)

The `disallow-insecure-ephemeral-containers` policy rejects plain `kubectl debug` (it runs as root by default), in learning mode too. Save this profile as `fortress-debug.json`:

```json
{
  "securityContext": {
    "runAsNonRoot": true,
    "runAsUser": 65534,
    "readOnlyRootFilesystem": true,
    "allowPrivilegeEscalation": false,
    "capabilities": { "drop": ["ALL"] }
  }
}
```

Then debug with a pinned image (tested with kubectl 1.31):

```bash
kubectl debug -it <pod> --image=busybox:1.36 --target=<container> \
  --profile=restricted --custom=fortress-debug.json
```

If it is rejected, the error message names the exact field to fix. Debug containers can see the app's processes and network, but cannot mount the pod's volumes, so mounted secrets stay out of reach.

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
| `disallow-host-namespaces` | Inspecting host processes and shared memory |
| `disallow-insecure-ephemeral-containers` | Stealing data or escalating privileges through debug containers added to running pods |
| `disallow-capabilities-and-escalation` | Regaining root powers piece by piece (e.g. `SYS_ADMIN`) without `privileged: true` |

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
