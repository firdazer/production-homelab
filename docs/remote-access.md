# Secure Remote Homelab Access with Cloudflare

## Overview

Remote administrative access to the homelab is provided through Cloudflare Tunnel and Cloudflare Access.

The design allows remote access to both the Proxmox web interface and the management VM without exposing Proxmox or SSH ports directly to the Internet.

## Architecture

```text
                         Internet
                            │
                    Cloudflare Access
                  Identity Authentication
                            │
                    Cloudflare Network
                            │
                     Cloudflare Tunnel
                            │
                            ▼
                  cloudflared01 (LXC)
                    192.168.100.21
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
     Proxmox Web Interface             SSH
       192.168.100.14:8006      192.168.100.16:22
              │                           │
              ▼                           ▼
            pve01                       mgmt01
```

## Public Endpoints

| Purpose | Public Hostname | Internal Destination |
|---|---|---|
| Proxmox administration | `proxmox.artdevops.com` | `https://192.168.100.14:8006` |
| SSH management | `ssh.artdevops.com` | `ssh://192.168.100.16:22` |

No inbound router port forwarding is required.

## Why Cloudflare Tunnel?

A traditional remote-access configuration could expose services through router port forwarding:

```text
Internet
   │
Public IP
   │
Router Port Forward
   │
Proxmox / SSH
```

This would expose administrative services directly to unsolicited Internet traffic.

The homelab instead uses an outbound Cloudflare Tunnel:

```text
Homelab
   │
Outbound Tunnel
   │
Cloudflare
   │
Authenticated User
```

The tunnel connector initiates the connection from inside the network, removing the requirement to expose TCP/22 or the Proxmox management port through the home router.

## Dedicated Tunnel Connector

Cloudflare Tunnel runs inside a dedicated lightweight LXC container:

```text
cloudflared01
IP: 192.168.100.21
```

The connector is separated from the Proxmox host rather than installing `cloudflared` directly on the hypervisor.

This provides separation of responsibilities:

- Proxmox provides virtualization.
- `cloudflared01` provides remote-access connectivity.
- `mgmt01` provides infrastructure management and automation.

## SSH Architecture

Remote SSH follows this path:

```text
Remote Workstation
       │
       │ OpenSSH
       ▼
cloudflared client
       │
       ▼
Cloudflare Access
       │
       ▼
ssh.artdevops.com
       │
       ▼
Cloudflare Tunnel
       │
       ▼
cloudflared01
       │
       ▼
mgmt01:22
       │
       ▼
OpenSSH Server
```

The internal management server remains on the private LAN:

```text
mgmt01
192.168.100.16
TCP/22
```

It is not directly exposed to the public Internet.

## Authentication Layers

Remote SSH uses two independent authentication layers.

### Layer 1 — Cloudflare Access

Cloudflare Access determines whether the remote identity is authorized to reach the SSH service.

```text
Remote User
    │
    ▼
Cloudflare Identity Authentication
    │
    ▼
Access Policy
    │
    ▼
Tunnel
```

Access is restricted to explicitly authorized identities rather than allowing unrestricted public access.

### Layer 2 — OpenSSH Public-Key Authentication

After Cloudflare authorizes access to the service, Ubuntu still performs SSH authentication.

```text
Cloudflare Access
       │
       ▼
mgmt01 SSH Server
       │
       ▼
Public-Key Authentication
       │
       ▼
Linux Account
```

Password authentication is disabled on `mgmt01`.

Important SSH hardening settings include:

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
X11Forwarding no
```

Therefore, passing Cloudflare authentication alone does not grant a Linux shell.

The connecting device must also possess an SSH private key corresponding to an authorized public key on `mgmt01`.

## Device-Specific SSH Keys

Separate SSH keys are used for different administrative devices.

Example:

```text
Personal Workstation
      │
      └── SSH Key A ─────────┐
                             │
                             ▼
                           mgmt01
                             ▲
                             │
Office Workstation           │
      └── SSH Key B ─────────┘
```

This allows an individual device to be revoked without replacing credentials used by other devices.

Private SSH keys are never stored in the Git repository.

## Windows SSH Client Configuration

A remote Windows workstation uses OpenSSH together with `cloudflared`.

Example SSH configuration:

```text
Host homelab
    HostName ssh.artdevops.com
    User firdazer
    IdentityFile ~/.ssh/homelab_office_ed25519
    IdentitiesOnly yes
    ProxyCommand "C:\Program Files (x86)\cloudflared\cloudflared.exe" access ssh --hostname %h
```

This allows the administrator to connect using:

```powershell
ssh homelab
```

OpenSSH launches `cloudflared` through `ProxyCommand`, which transports the SSH session through Cloudflare Access and the existing Cloudflare Tunnel.

## Security Properties

The remote-access design provides:

- No public router port-forward for TCP/22.
- No direct public exposure of the Proxmox management interface.
- Cloudflare identity authentication before SSH access.
- SSH public-key authentication at the Linux host.
- Password SSH authentication disabled.
- Root SSH login disabled.
- Dedicated SSH credentials per administrative device.
- Dedicated Cloudflare Tunnel connector.
- Separation between virtualization, remote access, and management services.

## Secret Management

The following information must never be committed to Git:

- Cloudflare Tunnel tokens
- SSH private keys
- Proxmox API tokens
- Cloudflare credentials
- Terraform secrets

Only public SSH keys may be distributed to servers.

The repository `.gitignore` contains exclusions for sensitive files such as:

```text
*.key
*.pem
*.p12
*.pfx
*.secret
.env
.env.*
id_rsa
id_ed25519
```

## Validation

The remote SSH implementation was validated progressively.

### DNS

The SSH hostname was confirmed to resolve:

```powershell
Resolve-DnsName ssh.artdevops.com
```

### Tunnel Connectivity

Direct testing with `cloudflared` successfully reached the Ubuntu OpenSSH server and returned an SSH banner.

Example:

```text
SSH-2.0-OpenSSH_9.6p1 Ubuntu
```

This demonstrated that the path:

```text
Cloudflare
→ Tunnel
→ cloudflared01
→ mgmt01:22
```

was functioning.

### Cloudflare Access

Authentication was validated using:

```powershell
cloudflared access login https://ssh.artdevops.com
```

Successful token retrieval confirmed the Access application and policy were functioning.

### SSH Authentication

The final test was:

```powershell
ssh homelab
```

Successful login confirmed the complete chain:

```text
DNS
  ↓
Cloudflare Access
  ↓
Cloudflare Tunnel
  ↓
Private LAN
  ↓
OpenSSH
  ↓
SSH public-key authentication
  ↓
mgmt01 shell
```

## Troubleshooting Lessons

Several failures were intentionally investigated layer by layer.

### Private IP Timeout

Attempting to connect directly to:

```text
192.168.100.16
```

from an external network timed out.

This is expected because RFC1918 private addresses are not Internet-routable.

### DNS Failure

Before the SSH hostname was created:

```text
ssh.artdevops.com
```

could not be resolved.

Creating the Cloudflare published hostname resolved the issue.

### Missing Access Application

Tunnel connectivity worked, but:

```text
cloudflared access login
```

initially reported that no Access application existed.

The tunnel route and Access application are separate components.

Creating an Access self-hosted application for:

```text
ssh.artdevops.com
```

resolved the issue.

### SSH Public-Key Failure

After Cloudflare connectivity was established, SSH returned:

```text
Permission denied (publickey)
```

This demonstrated that the network and Cloudflare layers were working but Linux authentication was rejecting the client.

A dedicated SSH key was created and its public key added to:

```text
~/.ssh/authorized_keys
```

on `mgmt01`.

This completed the authentication chain.

## Design Limitation

Cloudflare Tunnel improves remote-access security but does not make the homelab highly available.

The environment still contains single points of failure including:

- Single physical Proxmox host
- Single home Internet connection
- Single tunnel connector instance
- Single management VM

This project therefore describes the architecture as **production-inspired**, rather than claiming enterprise production availability.

## Future Improvements

Potential future improvements include:

- Additional Cloudflare Tunnel connector
- Centralized authentication
- Short-lived SSH credentials
- SSH certificate authority
- Centralized audit logging
- Infrastructure firewall segmentation
- VLAN separation
- Secondary Proxmox host
- Off-site backup infrastructure
