# Production-Style Cloud & DevOps Homelab

A practical infrastructure engineering portfolio project built using Proxmox VE, Terraform, Ansible, Kubernetes, GitHub Actions, Argo CD, Prometheus, Grafana, and Alertmanager.

This is a production-style learning environment, not a highly available production deployment.

## Architecture

- Physical host: Dell mini-PC running Proxmox VE
- Management VM: mgmt01
- Kubernetes control plane: k3s-cp01
- Kubernetes worker: k3s-w01
- Remote access: Cloudflare Tunnel
- CI/CD: GitHub Actions and GHCR
- GitOps deployment: Argo CD
- Monitoring: Prometheus and Grafana
- Alerting: Alertmanager and Telegram
- Backups: Proxmox vzdump to external USB SSD

## Verified Capabilities

- Terraform infrastructure management and validation
- Ansible configuration management and idempotency
- Two-node K3s cluster with a two-replica application
- Automated container builds and vulnerability scanning
- GitHub branch protection and required PR checks
- Argo CD automated synchronization and tested self-healing
- Kubernetes security hardening and PodDisruptionBudget
- Prometheus alerting with verified Telegram delivery
- Scheduled Proxmox backups and isolated VM recovery
- Backup monitoring with verified alert recovery and suppression

## Documentation

- [Disaster Recovery](docs/disaster-recovery.md)
- [GitOps Self-Healing](docs/gitops/self-healing-test.md)
- [Kubernetes Incident Response](docs/incident-response/kubernetes-replica-mismatch.md)
- [Remote Access](docs/remote-access.md)

## Limitations

- Single physical host; no infrastructure high availability
- Backups stored locally rather than offsite
- Disaster recovery tested in an isolated environment
- Recovery time and recovery point objectives not formally measured
- Independent scheduled-job verification not yet implemented

## Career Focus

Designed to demonstrate practical Cloud Engineer, DevOps Engineer, System Engineer, and Platform Engineer skills.
