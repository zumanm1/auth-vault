# Auth-Vault Integration: OSPF Impact Planner

## Status: ✅ INTEGRATED

This application has been fully integrated with the Auth-Vault infrastructure (Keycloak + HashiCorp Vault).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     OSPF Impact Planner                          │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (Express.js/TypeScript)   │
│  Port: 9090                │  Port: 9091                        │
│                            │                                     │
│  ┌──────────────┐          │  ┌──────────────┐                  │
│  │ Keycloak     │──────────┼──│ keycloak-    │                  │
│  │ (optional)   │          │  │ verifier.ts  │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│  ┌──────────────┐          │         ▼                          │
│  │ Legacy Auth  │──────────┼──│ auth-unified │                  │
│  │ (fallback)   │          │  │     .ts      │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ vault-client │                  │
│                            │  │     .ts      │                  │
│                            │  └──────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
            ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
            │   Keycloak   │   │    Vault     │   │  PostgreSQL  │
            │   Port 9120  │   │   Port 9121  │   │   Port 5432  │
            │              │   │              │   │              │
            │ Realm:       │   │ Mount:       │   │              │
            │ ospf-impact- │   │ ospf-impact- │   │              │
            │ planner      │   │ planner/     │   │              │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## Integrated Components

### Backend Files Added

| File | Purpose |
|------|---------|
| `server/src/lib/keycloak-verifier.ts` | JWT token verification via JWKS (RS256) |
| `server/src/lib/vault-client.ts` | AppRole authentication & secrets fetching |
| `server/src/middleware/auth-unified.ts` | Hybrid auth middleware (legacy + Keycloak) |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/auth/config` | GET | Returns auth mode and Keycloak config for frontend |
| `/api/health` | GET | Includes `authVault` and `authMode` status |

### Frontend Files Added

| File | Purpose |
|------|---------|
| `src/lib/keycloak.ts` | Keycloak OIDC integration for frontend |
| `src/store/authStore.ts` | Updated with Keycloak support |
| `src/components/LoginPage.tsx` | SSO button when Keycloak available |

## Configuration

### Environment Variables

```bash
# Keycloak Configuration (Backend)
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-impact-planner
KEYCLOAK_CLIENT_ID=impact-planner-api           # Backend client (confidential)
KEYCLOAK_FRONTEND_CLIENT_ID=impact-planner-frontend  # Frontend client (public, for SSO)

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

> **Note:** The `/api/auth/config` endpoint returns `KEYCLOAK_FRONTEND_CLIENT_ID` (defaults to `impact-planner-frontend`) for the frontend OIDC flow. The backend uses `KEYCLOAK_CLIENT_ID` for token verification.

### Keycloak Realm Details

- **Realm Name**: `ospf-impact-planner`
- **Frontend Client**: `impact-planner-frontend` (Public, PKCE)
- **Backend Client**: `impact-planner-api` (Confidential)

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `netviz_admin` | `V3ry$trongAdm1n!2025` | admin |
| `impact-user` | `ChangeMe!User2025` | user |

### Vault Secret Paths

| Path | Description |
|------|-------------|
| `ospf-impact-planner/config` | JWT secret, session secret |
| `ospf-impact-planner/database` | Database credentials |

## Authentication Modes

The application supports dual authentication:

### 1. Keycloak Mode (Auth-Vault)
- Activated when Keycloak is available at startup
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256)
- Frontend shows "Enterprise Auth" badge and SSO button

### 2. Legacy Mode (Fallback)
- Activated when Keycloak is unavailable
- Uses existing JWT authentication
- Local session management
- Frontend shows "Database Mode" badge

## How It Works

### Startup Sequence

1. Server starts and calls `initAuthVault()`
2. Checks if Keycloak is available at `KEYCLOAK_URL`
3. Checks if Vault is available at `VAULT_ADDR`
4. Sets `authMode` to 'keycloak' or 'legacy'
5. Logs status to console

### Token Verification Flow

```
Request with Authorization header
         │
         ▼
┌─────────────────────┐
│  auth-unified.ts    │
│  authMiddleware()   │
└─────────────────────┘
         │
         ├─── If authMode === 'keycloak'
         │         │
         │         ▼
         │    ┌─────────────────────┐
         │    │ keycloak-verifier   │
         │    │ verifyToken()       │
         │    │ (JWKS/RS256)        │
         │    └─────────────────────┘
         │
         └─── If authMode === 'legacy'
                   │
                   ▼
              ┌─────────────────────┐
              │ Legacy JWT verify   │
              │ (HS256 + local key) │
              └─────────────────────┘
```

## Usage

### Starting with Auth-Vault

```bash
# 1. Ensure auth-vault is running
cd /path/to/auth-vault
./auth-vault.sh start

# 2. Start the application
cd /path/to/OSPF-IMPACT-planner
npm run dev
```

### Checking Auth Status

```bash
# Check health endpoint
curl http://localhost:9091/api/health

# Response includes:
{
  "status": "healthy",
  "authVault": "active",    # or "inactive"
  "authMode": "keycloak"    # or "legacy"
}

# Check auth config (for frontend)
curl http://localhost:9091/api/auth/config

# Response:
{
  "authMode": "keycloak",
  "keycloak": {
    "url": "http://localhost:9120",
    "realm": "ospf-impact-planner",
    "clientId": "impact-planner-frontend"
  }
}
```

## Security Features

- **PKCE (Proof Key for Code Exchange)**: S256 code challenge for public clients
- **JWKS Token Verification**: RS256 with key rotation support
- **Automatic Token Refresh**: Frontend handles token expiry
- **Graceful Degradation**: Falls back to legacy auth if Keycloak unavailable
- **Secrets from Vault**: JWT secret fetched from Vault when available

### PKCE Implementation

The frontend uses PKCE for secure authorization code flow:

```
1. Generate code_verifier (32 random bytes, base64url)
2. Generate code_challenge = SHA256(code_verifier), base64url
3. Send code_challenge + code_challenge_method=S256 in auth request
4. Send code_verifier in token exchange
```

This prevents authorization code interception attacks.

## Troubleshooting

### Keycloak Mode Not Activating

```bash
# Check Keycloak is running
curl http://localhost:9120/health/ready

# Check realm exists
curl http://localhost:9120/realms/ospf-impact-planner

# Check server logs for auth initialization
```

### Token Validation Fails

1. Verify JWKS endpoint: `curl http://localhost:9120/realms/ospf-impact-planner/protocol/openid-connect/certs`
2. Check token issuer matches realm URL
3. Verify clock sync between services

### Vault Secrets Not Loading

```bash
# Check Vault is running
curl http://localhost:9121/v1/sys/health

# Verify AppRole credentials are set
echo $VAULT_ROLE_ID
echo $VAULT_SECRET_ID
```

## Migration Notes

This integration maintains backward compatibility:
- Existing local users continue to work in legacy mode
- Keycloak users work when Keycloak is available
- No changes required to existing deployments
- Simply add env vars and restart to enable Auth-Vault
