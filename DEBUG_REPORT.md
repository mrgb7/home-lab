# Authentik & Longhorn Debug Report - April 28, 2026

## 1. Authentik Issue: "Secret key missing"

### Symptoms
- `authentik-server` and `authentik-worker` pods were in a `CrashLoopBackOff`.
- Logs showed: `{"event": "Secret key missing, check https://docs.goauthentik.io/docs/install-config/"}`.

### Root Cause Analysis
- The Helm chart (v2026.2.2) values provided in `infrastructure/authentik/values.yaml` used `secret_key_secret` and `secret_key_key` directly under the `authentik` block.
- This version of the chart did not automatically map these to the `AUTHENTIK_SECRET_KEY` environment variable required by the application.
- Additionally, Redis was enabled but the subchart was not present in this specific version's dependencies.

### Debugging Commands
```bash
# Check pod status
kubectl get pods -n authentik

# Inspect logs
kubectl logs authentik-server-<id> -n authentik --tail=100

# Check environment variables inside the pod
kubectl exec authentik-server-<id> -n authentik -- env | grep AUTHENTIK_SECRET

# Verify secret content
kubectl get secret authentik-secrets -n authentik -o yaml
```

### Resolution
- Updated `infrastructure/authentik/values.yaml` to use `global.env`.
- Explicitly mapped `AUTHENTIK_SECRET_KEY` and `AUTHENTIK_POSTGRESQL__PASSWORD` from the existing `authentik-secrets`.
- Removed the invalid `redis` block (Authentik now uses Postgres for caching by default in newer versions).

---

## 2. Longhorn Issue: "Missing" / Hook Failure

### Symptoms
- ArgoCD reported Longhorn as `Missing` and `Degraded`.
- Sync failed with: `waiting for completion of hook batch/Job/longhorn-pre-upgrade`.
- The job failed to create pods because of a missing ServiceAccount.

### Root Cause Analysis
- **GitOps Deadlock:** The `pre-upgrade` hook required a ServiceAccount that hadn't been created yet (first-time install).
- **K3s Paths:** K3s uses `/var/lib/rancher/k3s/agent/kubelet` instead of the standard `/var/lib/kubelet`.
- **Node Dependencies:** Nodes were missing `open-iscsi` and `nfs-common`, which are mandatory for Longhorn.

### Debugging Commands
```bash
# Check application status
kubectl describe application longhorn -n argocd

# Check job failure reason
kubectl describe job longhorn-pre-upgrade -n longhorn-system

# Verify node dependencies (using privileged pod)
kubectl run check-deps --image=alpine --overrides='{"spec": {"hostPID": true, "containers": [{"name": "check-deps", "image": "alpine", "command": ["sh", "-c", "nsenter -t 1 -m -u -i -n -p ls /usr/sbin/iscsid"], "securityContext": {"privileged": true}}]}}'
```

### Resolution
- **Git Config:** Updated `infrastructure/longhorn/app.yaml` with:
    - `preUpgradeChecker.jobEnabled: false` (to disable the problematic hook).
    - `csi.kubeletRootDir: /var/lib/rancher/k3s/agent/kubelet`.
    - Updated version to `1.11.1`.
- **Node Prep:** Manually installed dependencies on nodes via privileged pods:
```bash
apt-get update && apt-get install -y open-iscsi nfs-common
systemctl enable --now iscsid
```
- **ArgoCD Recovery:** Terminated the stuck operation to pick up the new Git configuration:
```bash
kubectl patch application longhorn -n argocd --type merge -p '{"operation": null}'
```

---

## 3. PostgreSQL Storage Migration (Local-Path to Longhorn)

### Symptoms
- ArgoCD sync failure: `StatefulSet.apps "authentik-postgresql" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas'...`.
- Occurred because `volumeClaimTemplates` in StatefulSets are immutable.

### Resolution
1. **Reverted Git config** to use `longhorn` (10Gi).
2. **Manually deleted** the existing `local-path` resources:
```bash
kubectl delete statefulset authentik-postgresql -n authentik
kubectl delete pvc data-authentik-postgresql-0 -n authentik
```
3. **Triggered ArgoCD sync** to recreate resources on Longhorn.

## Final Status
- **Authentik:** Running & Healthy (Storage: Longhorn 10Gi).
- **Longhorn:** Running.
- **Repository:** All fixes committed and pushed to `main`.
