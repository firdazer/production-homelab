# Disaster Recovery Runbook

## Overview

**Exercise date:** 12 October 2026
**Result:** PASS — isolated Kubernetes application recovery

This runbook records a tested recovery of a Proxmox-hosted K3s control-plane VM and an Nginx application from an external USB backup. Production VMs remained running throughout the isolated exercise.

**Scope:** Recovery of a single control-plane VM and a two-replica test application. This was **not** a complete multi-node cluster failover.

## Recovery architecture

| Component | Technology |
|---|---|
| Hypervisor | Proxmox VE |
| Kubernetes | K3s with SQLite control-plane datastore |
| Backup | Proxmox `vzdump`, snapshot mode, Zstandard compression |
| Backup storage | External USB SSD, Proxmox storage ID `usb-backup` |
| Restored VM | Separate recovery VM (VM301 during the exercise) |
| Isolation | Dedicated Linux bridge `vmbr99`, no physical uplink |
| Test workload | Nginx `web-demo`, two replicas |

## Safety requirements

- **Never connect a cloned Kubernetes control plane to production while the original is running.** The restored VM may retain production IP addresses, credentials, certificates, and cluster state.
- Confirm the recovery bridge has no physical uplink and no production guests attached.
- Use a new VM ID and disable recovery VM autostart.
- Never commit Kubernetes tokens, encryption keys, kubeconfigs, VM configuration dumps, or backup archives to Git.
- The commands below are a reference procedure; verify storage IDs, VM IDs, network isolation, and file paths for each exercise.

## Recovery procedure

### 1. Identify and verify a backup

On the Proxmox host:

```bash
pvesm list usb-backup --content backup
zstd -t /path/to/selected-backup.vma.zst
```

A successful `zstd -t` checks compressed archive integrity; it does not establish that the VM or application can be recovered.

### 2. Restore to a separate VM

```bash
qmrestore /path/to/selected-backup.vma.zst 301 \
  --storage local-lvm --unique 1
qm set 301 --onboot 0
```

Before booting, configure VM301's virtual NIC to use an **isolated bridge without a physical uplink**. Verify its configuration and the bridge membership:

```bash
qm config 301
bridge link show master vmbr99
```

Do not connect the recovery clone to the production LAN. In the exercise, the isolated bridge was temporary and was not added to the persistent Proxmox network configuration.

### 3. Check the restored control plane

Start the recovery VM only after confirming network isolation. Inside the recovered VM (or via its QEMU guest agent):

```bash
systemctl is-active k3s
k3s kubectl get --raw=/readyz
k3s kubectl get nodes -o wide
```

Expected Kubernetes API readiness response: `ok`.

In this exercise, the restored SQLite database passed `PRAGMA integrity_check` with `ok`. Original node objects became `NotReady` because the real production nodes were unreachable from the isolated clone. **Historical pod status is not proof that a workload has been recovered.**

### 4. Transfer the required image offline

The recovered VM had no Nginx image and could not access a container registry. The production worker already had `docker.io/library/nginx:1.28.0` cached. Export the image from its K3s containerd store:

```bash
k3s ctr -n k8s.io images export \
  /root/nginx-1.28.0.tar \
  docker.io/library/nginx:1.28.0
```

The exercise transferred the image through the Proxmox host using QEMU guest-agent file operations, **without connecting the recovery VM to production**. Verify the archive checksum at both ends:

```bash
sha256sum /root/nginx-1.28.0.tar
```

Then, on the isolated recovery VM:

```bash
chmod 600 /root/nginx-1.28.0.tar
k3s ctr -n k8s.io images import /root/nginx-1.28.0.tar
k3s crictl images
```

### 5. Recover and validate the test deployment

The original `web-demo` deployment had a node selector requiring the unavailable production worker. The selector was removed **only in the isolated recovery cluster**:

```bash
k3s kubectl patch deployment web-demo \
  -n default --type=merge \
  -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'

k3s kubectl get deployment web-demo -n default
k3s kubectl get pods -n default -l app=web-demo -o wide
```

Test HTTP against the IP of a **newly created recovery pod**:

```bash
curl --noproxy '*' --connect-timeout 3 --max-time 10 \
  -sS -o /dev/null -w 'HTTP_STATUS=%{http_code}\n' \
  http://RECOVERY_POD_IP:80/
```

Replace `RECOVERY_POD_IP` with the actual pod IP observed in the isolated cluster.

### 6. Shut down and secure the recovery VM

On Proxmox:

```bash
qm shutdown 301 --timeout 120
qm status 301
qm set 301 --onboot 0
qm config 301 | grep -E '^(onboot|net0):'
```

Verify that production VMs remain running. Keep the recovery VM disconnected from production. Retain or delete the test VM according to the lab's cleanup policy.

## Observed results — 12 October 2026

| Validation | Observed result |
|---|---|
| VM restore from external USB backup | PASS |
| Restored SQLite integrity | `ok` |
| Recovered K3s service | Active |
| Kubernetes API `/readyz` | `ok` |
| Recovery VM network isolation | `vmbr99`, no physical uplink |
| Offline Nginx image transfer | SHA-256 matched |
| Nginx image import | PASS |
| Recovered `web-demo` deployment | **2/2 available** |
| New Nginx pods | **2/2 Ready**, zero restarts |
| HTTP request to recovered pod | **200 OK** |
| Production control plane and worker | Running during exercise |
| Recovery VM shutdown | Stopped |
| Recovery VM autostart | Disabled (`onboot: 0`) |

The HTTP request was made from inside the isolated recovery VM to a recovered Nginx pod. This demonstrates application availability in the test environment, not public ingress recovery.

## Limitations and follow-up work

- Full multi-node failover and original worker recovery were not tested.
- Other deployments, persistent volumes, databases, and historical monitoring data were not restored or validated.
- DNS, Cloudflare Tunnel, and external ingress recovery were not tested.
- The separately encrypted SQLite recovery bundle was integrity-checked but **not used** for this VM restore.
- Recovery time objective (RTO) and recovery point objective (RPO) were not formally measured.
- The USB SSD is separate storage, but not an offsite backup.
- Scheduled backup execution and retention should be verified over time.

Recommended next exercises: persistent-volume restore, independently protected offsite backups, full-cluster recovery, and measured RTO/RPO.

## Interview summary

Performed an isolated disaster recovery exercise for a Proxmox-hosted K3s homelab. Restored the Kubernetes control-plane VM from an external USB backup, validated SQLite integrity and Kubernetes API readiness, transferred and imported a cached Nginx image offline through the QEMU guest agent, and recovered a two-replica application to **2/2 availability** with an **HTTP 200** response. Production VMs remained operational, and the recovery clone was shut down with autostart disabled. The exercise validated application recovery on an isolated node, not full production failover.
