# Kubernetes Monitoring

Production-inspired monitoring for the K3s homelab.

## Components

- Prometheus
- Grafana
- Prometheus Operator
- kube-state-metrics
- Node Exporter

Helm chart: prometheus-community/kube-prometheus-stack
Pinned chart version: 92.2.0

## Prerequisites

- Working K3s cluster
- kubectl configured
- Helm installed
- local-path StorageClass available

## Install or upgrade

Run these commands from the repository root:

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --version 92.2.0 --namespace monitoring --create-namespace --values kubernetes/infrastructure/monitoring/values.yaml --wait --timeout 10m

## Verify

    helm list -n monitoring
    kubectl -n monitoring get pods
    kubectl -n monitoring get pvc
    kubectl -n monitoring get prometheusrules

## Grafana access

URL: https://grafana.artdevops.com

Grafana uses a ClusterIP service. Remote access is protected by
Cloudflare Access and Grafana authentication.

Traffic reaches Grafana through Cloudflare Tunnel, a restricted
SSH tunnel, and a localhost-only kubectl port-forward.

Do not expose Grafana through a public NodePort.

## Storage

- Grafana PVC: 1Gi
- Prometheus PVC: 3Gi
- Prometheus retention: 7 days, limited to 2500MB
- StorageClass: local-path

Local-path storage is tied to the hosting node and is not highly available.

## K3s-specific monitoring

The scheduler, controller-manager, and kube-proxy monitoring integrations
are disabled because their expected standalone endpoints are unavailable
in this K3s deployment.

Alertmanager is disabled to conserve resources.

Prometheus evaluates Kubernetes alerts, but external alert notifications
are not configured.

## Recovery

The Helm configuration can recreate the monitoring applications.

It does not automatically restore historical Prometheus metrics,
Grafana dashboards stored in its database, or persistent volume data.

Back up persistent volumes and Kubernetes configuration separately.
