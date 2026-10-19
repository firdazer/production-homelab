# Argo CD Self-Healing Validation

## Objective

Verify that Argo CD automatically detects and corrects
configuration drift in a Git-managed Kubernetes resource.

## Environment

- Kubernetes: K3s
- GitOps controller: Argo CD
- Application: web-demo
- Namespace: default
- Git revision: 368b179
- Test date: 2026-10-19

## Configuration

The Argo CD Application has automated synchronization enabled:

- selfHeal: true
- prune: false

The web-demo application manages a Deployment, Service,
NetworkPolicy, and PodDisruptionBudget.

## Controlled Drift Test

Resource: PodDisruptionBudget/web-demo-pdb

Desired Git configuration:

    minAvailable: 1

Temporary live configuration:

    minAvailable: 2

Test command:

    kubectl patch pdb web-demo-pdb -n default \
      --type=merge \
      -p '{"spec":{"minAvailable":2}}'

The change temporarily reduced allowed voluntary disruptions
from one to zero. No node drains were performed.

## Recovery Evidence

Argo CD application-controller logs recorded:

- 02:29:55 UTC: PodDisruptionBudget update detected
- 02:29:56 UTC: Application transitioned Synced -> OutOfSync
- 02:29:56 UTC: Automated synchronization initiated
- 02:29:56 UTC: PodDisruptionBudget successfully configured
- 02:29:56 UTC: Application transitioned OutOfSync -> Synced

The sync operation completed successfully.

## Final Verification

- PodDisruptionBudget minAvailable: 1
- Allowed disruptions: 1
- Argo CD: Synced / Healthy
- web-demo Deployment: 2/2 Available

## Conclusion

Argo CD self-healing was successfully validated against an
explicitly Git-managed Kubernetes configuration field.

The controller detected live configuration drift and
automatically restored the desired state from Git.

This test demonstrates configuration reconciliation, not
automatic recovery from node failures or application crashes.

## Operational Considerations

- Prefer Git-based changes over manual production modifications.
- Self-healing can overwrite emergency changes made directly
  to Kubernetes resources.
- Automatic pruning remains disabled.
- Do not perform disruptive node maintenance during PDB tests.
