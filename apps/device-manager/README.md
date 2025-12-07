# OSPF Device Manager - Auth-Vault Integration Guide

## Overview

OSPF Device Manager is a network device management tool with SSH/Telnet connectivity for OSPF router configuration. This guide covers the complete setup and integration with Auth-Vault (Keycloak + Vault).

## Application Details

| Property | Value |
|----------|-------|
| **App Name** | OSPF Device Manager |
| **Directory** | `OSPF-LL-DEVICE_MANAGER` |
| **Frontend Port** | 9050 |
| **Backend Port** | 9051 |
| **Keycloak Realm** | `ospf-device-manager` |
| **Keycloak Client** | `device-manager-api` |
| **Language** | Python 3.11+ |

## Quick Start

### One-Command Setup

```bash
# From the device-manager directory
cd ~/OSPF-LL-DEVICE_MANAGER
./start-with-auth-vault.sh
```

This script will:
1. Check if auth-vault is installed (clone if missing)
2. Install Keycloak and Vault natively if needed
3. Start Auth-Vault services
4. Configure the application
5. Start the Device Manager servers

### Manual Setup

#### Step 1: Install and Start Auth-Vault

```bash
# Navigate to auth-vault
cd ~/auth-vault

# Install (first time only)
./auth-vault.sh install

# Start services
./auth-vault.sh start

# Verify services
curl http://localhost:9120/health/ready
curl http://localhost:9121/v1/sys/health
```

#### Step 2: Configure Device Manager

Ensure `.env` or `config.py` has auth-vault settings:

```python
# Auth-Vault Integration
KEYCLOAK_URL = "http://localhost:9120"
KEYCLOAK_REALM = "ospf-device-manager"
KEYCLOAK_CLIENT_ID = "device-manager-api"

# Vault Configuration
VAULT_ADDR = "http://localhost:9121"
VAULT_TOKEN = "<your-vault-token>"
```

#### Step 3: Start Device Manager

```bash
cd ~/OSPF-LL-DEVICE_MANAGER
./start.sh
# Or with Python directly:
python3 app.py
```

#### Step 4: Verify Integration

```bash
curl http://localhost:9051/api/health | jq .
# Expected: {"authVault": "active", "authMode": "keycloak"}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    OSPF Device Manager                          │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (Port 9050)    │  Backend (Port 9051)                 │
│  ┌──────────────┐        │  ┌──────────────┐                    │
│  │ React/Vue    │        │  │ keycloak-    │                    │
│  │ Dashboard    │────────┼──│ verifier.py  │                    │
│  └──────────────┘        │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ auth-unified │                    │
│                          │  │    .py       │                    │
│                          │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ vault-client │                    │
│                          │  │    .py       │                    │
│                          │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ SSH/Telnet   │                    │
│                          │  │ Connections  │                    │
│                          │  └──────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  ▼                                     ▼
          ┌──────────────┐                      ┌──────────────┐
          │   Keycloak   │                      │    Vault     │
          │   Port 9120  │                      │   Port 9121  │
          │              │                      │              │
          │ Realm:       │                      │ Mount:       │
          │ ospf-device- │                      │ ospf-device- │
          │ manager      │                      │ manager/     │
          └──────────────┘                      └──────────────┘
```

## Keycloak Configuration

### Realm: `ospf-device-manager`

| Setting | Value |
|---------|-------|
| **Realm Name** | `ospf-device-manager` |
| **Frontend Client** | `device-manager-frontend` (Public, PKCE) |
| **Backend Client** | `device-manager-api` (Confidential) |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `devmgr-admin` | `ChangeMe!Admin2025` | admin |
| `devmgr-operator` | `ChangeMe!Operator2025` | operator |
| `devmgr-viewer` | `ChangeMe!Viewer2025` | viewer |

### Roles

| Role | Permissions |
|------|-------------|
| `admin` | Full access, user management, device configuration |
| `operator` | Device configuration, SSH/Telnet access |
| `viewer` | Read-only access, view device status |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-device-manager/config` | JWT secret, session secret |
| `ospf-device-manager/database` | Database credentials |
| `ospf-device-manager/router-defaults` | Default router credentials |
| `ospf-device-manager/jumphost` | Jump host SSH credentials |

### Router Credentials Storage

Device Manager uses Vault to securely store router credentials:

```bash
# Store router credentials
vault kv put ospf-device-manager/routers/router1 \
    username=admin \
    password=secret \
    enable_password=enable_secret
```

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check with auth-vault status |
| `/api/auth/config` | GET | Returns auth mode and Keycloak config |
| `/api/auth/login` | POST | User login |
| `/api/auth/logout` | POST | User logout |
| `/api/devices` | GET/POST | Device management |
| `/api/devices/{id}/connect` | POST | SSH/Telnet connection |
| `/api/devices/{id}/commands` | POST | Execute commands |

## Authentication Modes

### Keycloak Mode (Auth-Vault Active)
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256)
- Centralized session management
- Role-based access control (admin/operator/viewer)

### Legacy Mode (Fallback)
- Local JWT authentication
- SQLite user database

## Security Features

### Credential Management
- Router credentials stored in Vault (encrypted)
- No plaintext passwords in config files
- Automatic credential rotation support

### Connection Security
- SSH key-based authentication supported
- Telnet only for legacy devices (with warnings)
- Connection audit logging

## Troubleshooting

### Auth-Vault Not Connecting

```bash
# Check services are running
cd ~/auth-vault && ./auth-vault.sh status

# Check Keycloak realm
curl http://localhost:9120/realms/ospf-device-manager
```

### Service Won't Start

```bash
# Check if ports are in use
lsof -i :9050
lsof -i :9051

# Check Python dependencies
pip3 install -r requirements.txt

# Check logs
cd ~/OSPF-LL-DEVICE_MANAGER
tail -f logs/*.log
```

### SSH Connection Issues

```bash
# Test SSH connectivity
ssh -v user@router_ip

# Check Vault for credentials
vault kv get ospf-device-manager/routers/router1
```

## Environment Variables Reference

```bash
# Required for Auth-Vault
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-device-manager
KEYCLOAK_CLIENT_ID=device-manager-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<vault-token>

# Application Settings
FRONTEND_PORT=9050
BACKEND_PORT=9051

# SSH/Telnet Settings
SSH_TIMEOUT=30
TELNET_TIMEOUT=30
```

## Python Dependencies

```txt
# requirements.txt
flask>=2.0
flask-cors>=3.0
python-jose>=3.3
hvac>=1.0  # HashiCorp Vault client
paramiko>=2.10  # SSH client
netmiko>=4.0  # Network device SSH
requests>=2.28
```

## Related Documentation

- [Auth-Vault Main README](../../README.md)
- [Security Features](../../docs/SECURITY-AUDIT.md)
