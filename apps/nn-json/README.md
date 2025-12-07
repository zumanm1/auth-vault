# OSPF Visualizer Pro (NN-JSON) - Auth-Vault Integration Guide

## Overview

OSPF Visualizer Pro is an advanced OSPF network visualization tool with neural network-based analysis. This guide covers the complete setup and integration with Auth-Vault (Keycloak + Vault).

## Application Details

| Property | Value |
|----------|-------|
| **App Name** | OSPF Visualizer Pro |
| **Directory** | `OSPF-NN-JSON` |
| **Frontend Port** | 9080 |
| **Backend Port** | 9081 |
| **Keycloak Realm** | `ospf-nn-json` |
| **Keycloak Client** | `visualizer-pro-api` |

## Quick Start

### One-Command Setup

```bash
# From the visualizer directory
cd ~/OSPF-NN-JSON
./start-with-auth-vault.sh
```

This script will:
1. Check if auth-vault is installed (clone if missing)
2. Install Keycloak and Vault natively if needed
3. Start Auth-Vault services
4. Configure the application
5. Start the Visualizer Pro servers

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

#### Step 2: Configure Visualizer Pro

Ensure `.env.local` has auth-vault settings:

```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-nn-json
KEYCLOAK_CLIENT_ID=visualizer-pro-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

#### Step 3: Start Visualizer Pro

```bash
cd ~/OSPF-NN-JSON
./start.sh
```

#### Step 4: Verify Integration

```bash
curl http://localhost:9081/api/health | jq .
# Expected: {"authVault": "active", "authMode": "keycloak"}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   OSPF Visualizer Pro                           │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (Port 9080)    │  Backend (Port 9081)                 │
│  ┌──────────────┐        │  ┌──────────────┐                    │
│  │ React App    │        │  │ keycloak-    │                    │
│  │ + D3.js      │────────┼──│ verifier     │                    │
│  └──────────────┘        │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ auth-unified │                    │
│                          │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ vault-client │                    │
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
          │ ospf-nn-json │                      │ ospf-nn-json/│
          └──────────────┘                      └──────────────┘
```

## Keycloak Configuration

### Realm: `ospf-nn-json`

| Setting | Value |
|---------|-------|
| **Realm Name** | `ospf-nn-json` |
| **Frontend Client** | `visualizer-pro-frontend` (Public, PKCE) |
| **Backend Client** | `visualizer-pro-api` (Confidential) |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `visualizer-admin` | `ChangeMe!Admin2025` | admin |
| `visualizer-user` | `ChangeMe!User2025` | user |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-nn-json/config` | JWT secret, session secret |
| `ospf-nn-json/database` | Database credentials |

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check with auth-vault status |
| `/api/auth/config` | GET | Returns auth mode and Keycloak config |
| `/api/auth/login` | POST | User login |
| `/api/auth/logout` | POST | User logout |
| `/api/topology` | GET/POST | Topology management |
| `/api/visualize` | POST | Generate visualization |

## Authentication Modes

### Keycloak Mode (Auth-Vault Active)
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256)
- Centralized session management

### Legacy Mode (Fallback)
- Local JWT authentication
- SQLite user database

## Troubleshooting

### Auth-Vault Not Connecting

```bash
# Check services are running
cd ~/auth-vault && ./auth-vault.sh status

# Check Keycloak realm
curl http://localhost:9120/realms/ospf-nn-json
```

### Service Won't Start

```bash
# Check if ports are in use
lsof -i :9080
lsof -i :9081

# Check logs
cd ~/OSPF-NN-JSON
tail -f logs/*.log
```

## Environment Variables Reference

```bash
# Required for Auth-Vault
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-nn-json
KEYCLOAK_CLIENT_ID=visualizer-pro-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<vault-token>

# Application Settings
FRONTEND_PORT=9080
BACKEND_PORT=9081
```

## Related Documentation

- [Auth-Vault Main README](../../README.md)
- [Security Features](../../docs/SECURITY-AUDIT.md)
