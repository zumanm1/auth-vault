# OSPF Impact Planner - Auth-Vault Integration Guide

## Overview

OSPF Impact Planner is a network impact analysis tool for OSPF routing changes. This guide covers the complete setup and integration with Auth-Vault (Keycloak + Vault).

## Application Details

| Property | Value |
|----------|-------|
| **App Name** | OSPF Impact Planner |
| **Directory** | `OSPF-IMPACT-planner Private` |
| **Frontend Port** | 9090 |
| **Backend Port** | 9091 |
| **Keycloak Realm** | `ospf-impact-planner` |
| **Keycloak Client** | `impact-planner-api` |

## Quick Start

### One-Command Setup

```bash
# From the impact-planner directory
cd ~/OSPF-IMPACT-planner\ Private
./start-with-auth-vault.sh
```

This script will:
1. Check if auth-vault is installed (clone if missing)
2. Install Keycloak and Vault natively if needed
3. Start Auth-Vault services
4. Configure the application
5. Start the Impact Planner servers

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

#### Step 2: Configure Impact Planner

Ensure `.env.local` has auth-vault settings:

```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-impact-planner
KEYCLOAK_CLIENT_ID=impact-planner-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

#### Step 3: Start Impact Planner

```bash
cd ~/OSPF-IMPACT-planner\ Private
./start.sh
```

#### Step 4: Verify Integration

```bash
curl http://localhost:9091/api/health | jq .
# Expected: {"authVault": "active", "authMode": "keycloak"}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    OSPF Impact Planner                          │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (Port 9090)    │  Backend (Port 9091)                 │
│  ┌──────────────┐        │  ┌──────────────┐                    │
│  │ React App    │        │  │ keycloak-    │                    │
│  │ + Auth       │────────┼──│ verifier     │                    │
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
          │ ospf-impact- │                      │ ospf-impact- │
          │ planner      │                      │ planner/     │
          └──────────────┘                      └──────────────┘
```

## Keycloak Configuration

### Realm: `ospf-impact-planner`

| Setting | Value |
|---------|-------|
| **Realm Name** | `ospf-impact-planner` |
| **Frontend Client** | `impact-planner-frontend` (Public, PKCE) |
| **Backend Client** | `impact-planner-api` (Confidential) |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `impact-admin` | `ChangeMe!Admin2025` | admin |
| `impact-user` | `ChangeMe!User2025` | user |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-impact-planner/config` | JWT secret, session secret |
| `ospf-impact-planner/database` | Database credentials |

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check with auth-vault status |
| `/api/auth/config` | GET | Returns auth mode and Keycloak config |
| `/api/auth/login` | POST | User login |
| `/api/auth/logout` | POST | User logout |
| `/api/impact/analyze` | POST | Analyze OSPF impact |

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
curl http://localhost:9120/realms/ospf-impact-planner
```

### Service Won't Start

```bash
# Check if ports are in use
lsof -i :9090
lsof -i :9091

# Check logs
cd ~/OSPF-IMPACT-planner\ Private
tail -f logs/*.log
```

## Environment Variables Reference

```bash
# Required for Auth-Vault
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-impact-planner
KEYCLOAK_CLIENT_ID=impact-planner-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<vault-token>

# Application Settings
FRONTEND_PORT=9090
BACKEND_PORT=9091
```

## Related Documentation

- [Auth-Vault Main README](../../README.md)
- [Security Features](../../docs/SECURITY-AUDIT.md)
