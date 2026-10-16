# Kubernetes Replica Mismatch Incident Report

## Summary
Controlled incident simulation on Proxmox and k3s.
Alert: KubeDeploymentReplicasMismatch
Result: PASS. No production impact observed.

## Failure and Detection
The alert-test deployment had 0/1 ready replicas.
Prometheus detected the mismatch and fired the alert.
Telegram received the firing notification.

## Remediation and Recovery
The test deployment was scaled from 0/1 to 0/0.
Prometheus subsequently cleared the alert.
Telegram received the resolved notification.

## Cleanup and Verification
The homelab-alert-test namespace was deleted.
The production web-demo deployment remained 2/2 ready.
All listed monitoring pods were running after cleanup.

## Lessons Learned
- Verify both firing and resolved notifications.
- Confirm recovery using Prometheus alert state.
- Keep failure simulations isolated from production.
- Verify application health after cleanup.

**Final result: PASS**
