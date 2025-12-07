# OSPF Tempo-X - Auth-Vault Integration Guide

## Overview

OSPF Tempo-X is a temporal analysis tool for OSPF network changes over time. This guide covers the complete setup and integration with Auth-Vault (Keycloak + Vault).

## Application Details

| Property | Value |
|----------|-------|
| **App Name** | OSPF Tempo-X |
| **Directory** | `OSPF-TEMPO-X` |
| **Frontend Port** | 9100 |
| **Backend Port** | 9101 |
| **Keycloak Realm** | `ospf-tempo-x` |
| **Keycloak Client** | `tempo-x-api` |

## Quick Start

### One-Command Setup

```bash
# From the tempo-x directory
cd ~/OSPF-TEMPO-X
./start-with-auth-vault.sh
```

This script will:
1. Check if auth-vault is installed (clone if missing)
2. Install Keycloak and Vault natively if needed
3. Start Auth-Vault services
4. Configure the application
5. Start the Tempo-X servers

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

#### Step 2: Configure Tempo-X

Ensure `.env.local` has auth-vault settings:

```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-tempo-x
KEYCLOAK_CLIENT_ID=tempo-x-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

#### Step 3: Start Tempo-X

```bash
cd ~/OSPF-TEMPO-X
./start.sh
```

#### Step 4: Verify Integration

```bash
curl http://localhost:9101/api/health | jq .
# Expected: {"authVault": "active", "authMode": "keycloak"}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       OSPF Tempo-X                              │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (Port 9100)    │  Backend (Port 9101)                 │
│  ┌──────────────┐        │  ┌──────────────┐                    │
│  │ React App    │        │  │ keycloak-    │                    │
│  │ + Timeline   │────────┼──│ verifier     │                    │
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
          │ ospf-tempo-x │                      │ ospf-tempo-x/│
          └──────────────┘                      └──────────────┘
```

## Keycloak Configuration

### Realm: `ospf-tempo-x`

| Setting | Value |
|---------|-------|
| **Realm Name** | `ospf-tempo-x` |
| **Frontend Client** | `tempo-x-frontend` (Public, PKCE) |
| **Backend Client** | `tempo-x-api` (Confidential) |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `tempo-admin` | `ChangeMe!Admin2025` | admin |
| `tempo-user` | `ChangeMe!User2025` | user |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-tempo-x/config` | JWT secret, session secret |
| `ospf-tempo-x/database` | Database credentials |

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check with auth-vault status |
| `/api/auth/config` | GET | Returns auth mode and Keycloak config |
| `/api/auth/login` | POST | User login |
| `/api/auth/logout` | POST | User logout |
| `/api/timeline` | GET/POST | Timeline data management |
| `/api/snapshots` | GET/POST | Network snapshots |

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
curl http://localhost:9120/realms/ospf-tempo-x
```

### Service Won't Start

```bash
# Check if ports are in use
lsof -i :9100
lsof -i :9101

# Check logs
cd ~/OSPF-TEMPO-X
tail -f logs/*.log
```

## Environment Variables Reference

```bash
# Required for Auth-Vault
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-tempo-x
KEYCLOAK_CLIENT_ID=tempo-x-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<vault-token>

# Application Settings
FRONTEND_PORT=9100
BACKEND_PORT=9101
```

## Related Documentation

- [Auth-Vault Main README](../../README.md)
- [Security Features](../../docs/SECURITY-AUDIT.md)
