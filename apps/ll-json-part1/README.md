# NetViz Pro (OSPF-LL-JSON-PART1) - Auth-Vault Integration Guide

## Overview

NetViz Pro is an OSPF Network Topology Visualizer with enterprise-grade authentication. This guide covers the complete setup and integration with Auth-Vault (Keycloak + Vault).

## Application Details

| Property | Value |
|----------|-------|
| **App Name** | NetViz Pro |
| **Directory** | `OSPF-LL-JSON-PART1/netviz-pro` |
| **Gateway Port** | 9040 (public-facing) |
| **Auth Server Port** | 9041 (internal) |
| **Vite Dev Port** | 9042 (internal) |
| **Keycloak Realm** | `ospf-ll-json-part1` |
| **Keycloak Client** | `netviz-pro-api` |

## Quick Start

### One-Command Setup

```bash
# From the netviz-pro directory
cd /Users/macbook/OSPF-LL-JSON-PART1/netviz-pro
./start-with-auth-vault.sh
```

This script will:
1. Check if auth-vault is installed
2. Start Docker if not running
3. Start Keycloak and Vault containers
4. Wait for services to be healthy
5. Start NetViz Pro servers

### Manual Setup

#### Step 1: Start Auth-Vault Services

```bash
# Navigate to auth-vault
cd /Users/macbook/auth-vault

# Option A: Docker (Recommended)
docker compose up -d

# Option B: Native
./auth-vault.sh start

# Verify services
curl http://localhost:9120/health/ready
curl http://localhost:9121/v1/sys/health
```

#### Step 2: Configure NetViz Pro

Ensure `.env.local` has auth-vault settings:

```bash
# /Users/macbook/OSPF-LL-JSON-PART1/netviz-pro/.env.local

# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=ospf-vault-dev-token-2025
```

#### Step 3: Start NetViz Pro

```bash
cd /Users/macbook/OSPF-LL-JSON-PART1/netviz-pro
./start.sh
```

#### Step 4: Verify Integration

```bash
curl http://localhost:9041/api/health | jq .
# Expected: {"authVault": "active", "authMode": "keycloak"}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       NetViz Pro                                 │
├─────────────────────────────────────────────────────────────────┤
│  Gateway (Port 9040)     │  Auth Server (Port 9041)             │
│  ┌──────────────┐        │  ┌──────────────┐                    │
│  │ Static Files │        │  │ keycloak-    │                    │
│  │ + Proxy      │────────┼──│ verifier.js  │                    │
│  └──────────────┘        │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ auth-unified │                    │
│                          │  │     .js      │                    │
│                          │  └──────────────┘                    │
│                          │         │                            │
│                          │         ▼                            │
│                          │  ┌──────────────┐                    │
│                          │  │ vault-client │                    │
│                          │  │     .js      │                    │
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
          │ ospf-ll-     │                      │ ospf-ll-     │
          │ json-part1   │                      │ json-part1/  │
          └──────────────┘                      └──────────────┘
```

## Integrated Components

### Backend Files

| File | Purpose |
|------|---------|
| `server/lib/keycloak-verifier.js` | JWT token verification via JWKS (RS256) |
| `server/lib/vault-client.js` | AppRole authentication & secrets fetching |
| `server/lib/auth-unified.js` | Hybrid auth middleware (legacy + Keycloak) |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/health` | GET | Health check with auth-vault status |
| `/api/auth/config` | GET | Returns auth mode and Keycloak config |
| `/api/auth/login` | POST | User login (legacy mode) |
| `/api/auth/logout` | POST | User logout |
| `/api/auth/validate` | GET | Validate session token |
| `/api/auth/me` | GET | Get current user info |
| `/api/admin/users` | GET | List users (admin only) |

## Keycloak Configuration

### Realm: `ospf-ll-json-part1`

| Setting | Value |
|---------|-------|
| **Realm Name** | `ospf-ll-json-part1` |
| **Frontend Client** | `netviz-pro-frontend` (Public, PKCE) |
| **Backend Client** | `netviz-pro-api` (Confidential) |
| **Token Lifespan** | 1 hour |
| **Refresh Token** | 8 hours |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `netviz-admin` | `ChangeMe!Admin2025` | admin |
| `netviz-user` | `ChangeMe!User2025` | user |

### Roles

| Role | Permissions |
|------|-------------|
| `admin` | Full access, user management |
| `user` | Standard access, view/edit topologies |
| `viewer` | Read-only access |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-ll-json-part1/config` | JWT secret, session secret |
| `ospf-ll-json-part1/database` | Database credentials |

### Secrets Structure

```json
{
  "jwt_secret": "<auto-generated>",
  "session_secret": "<auto-generated>",
  "jwt_expires_in": "3600",
  "environment": "development"
}
```

## Authentication Modes

### Keycloak Mode (Auth-Vault Active)

When Keycloak is available:
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256)
- Centralized session management
- Secrets fetched from Vault

### Legacy Mode (Fallback)

When Keycloak is unavailable:
- Local JWT authentication
- SQLite user database
- Local session management

## Security Features

- **Rate Limiting**: 5 login attempts per 15 minutes
- **CORS Protection**: Configurable origins
- **Helmet Headers**: CSP, HSTS, X-Frame-Options
- **HttpOnly Cookies**: Secure session tokens
- **JWKS Verification**: RS256 token validation

## Troubleshooting

### Auth-Vault Not Connecting

```bash
# Check services are running
docker ps | grep -E "keycloak|vault"

# Check Keycloak realm
curl http://localhost:9120/realms/ospf-ll-json-part1

# Check NetViz Pro health
curl http://localhost:9041/api/health
```

### Token Validation Fails

```bash
# Verify JWKS endpoint
curl http://localhost:9120/realms/ospf-ll-json-part1/protocol/openid-connect/certs

# Check auth config
curl http://localhost:9041/api/auth/config
```

### Rate Limited

The auth endpoint has a 5 attempts / 15 minute limit. Wait for the rate limit to reset or restart the server for development.

## Environment Variables Reference

```bash
# Required for Auth-Vault
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<vault-token>

# Optional (for AppRole auth)
VAULT_ROLE_ID=<role-id>
VAULT_SECRET_ID=<secret-id>

# Application Settings
GATEWAY_PORT=9040
AUTH_SERVER_PORT=9041
VITE_PORT=9042
APP_SECRET_KEY=<secure-key>
ADMIN_RESET_PIN=<8-char-pin>
```

## Related Documentation

- [Auth-Vault Main README](/Users/macbook/auth-vault/README.md)
- [NetViz Pro README](/Users/macbook/OSPF-LL-JSON-PART1/netviz-pro/README.md)
- [NetViz Pro Auth-Vault Integration](/Users/macbook/OSPF-LL-JSON-PART1/README-AUTH-VAULT.md)
