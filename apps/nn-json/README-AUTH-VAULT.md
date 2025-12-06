# Auth-Vault Integration: OSPF Visualizer Pro (OSPF-NN-JSON)

## Status: ✅ INTEGRATED

This application has been fully integrated with the Auth-Vault infrastructure (Keycloak + HashiCorp Vault).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   OSPF Visualizer Pro                            │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (Express.js)              │
│  Port: 9080                │  Port: 9081                        │
│                            │                                     │
│  ┌──────────────┐          │  ┌──────────────┐                  │
│  │ Keycloak     │──────────┼──│ keycloak-    │                  │
│  │ (optional)   │          │  │ verifier.js  │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│  ┌──────────────┐          │         ▼                          │
│  │ Legacy Auth  │──────────┼──│ auth-unified │                  │
│  │ (fallback)   │          │  │     .js      │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ vault-client │                  │
│                            │  │     .js      │                  │
│                            │  └──────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼
            ┌──────────────┐   ┌──────────────┐
            │   Keycloak   │   │    Vault     │
            │   Port 9120  │   │   Port 9121  │
            │              │   │              │
            │ Realm:       │   │ Mount:       │
            │ ospf-nn-json │   │ ospf-nn-json │
            └──────────────┘   └──────────────┘
```

## Integrated Components

### Backend Files Added

| File | Purpose |
|------|---------|
| `server/lib/keycloak-verifier.js` | JWT token verification via JWKS (RS256) |
| `server/lib/vault-client.js` | AppRole authentication & secrets fetching |
| `server/lib/auth-unified.js` | Hybrid auth middleware (legacy + Keycloak) |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/auth/config` | GET | Returns auth mode and Keycloak config for frontend |
| `/api/health` | GET | Includes `authVault` and `authMode` status |

## Configuration

### Environment Variables

```bash
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-nn-json
KEYCLOAK_CLIENT_ID=visualizer-pro-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>
# OR use token auth:
VAULT_TOKEN=<vault-token>
```

### Keycloak Realm Details

- **Realm Name**: `ospf-nn-json`
- **Frontend Client**: `visualizer-pro-frontend` (Public, PKCE)
- **Backend Client**: `visualizer-pro-api` (Confidential)

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `visualizer-admin` | `ChangeMe!Admin2025` | admin |
| `visualizer-user` | `ChangeMe!User2025` | user |

### Vault Secret Paths

| Path | Description |
|------|-------------|
| `ospf-nn-json/config` | JWT secret, session secret |
| `ospf-nn-json/database` | Database configuration |

## Authentication Modes

The application supports dual authentication:

### 1. Keycloak Mode (Auth-Vault)
- Activated when Keycloak is available at startup
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256)

### 2. Legacy Mode (Fallback)
- Activated when Keycloak is unavailable
- Uses existing JWT authentication
- Local SQLite user database

## How It Works

### Startup Sequence

```javascript
// In server/index.js
async function startServer() {
  // Initialize Auth-Vault
  const authVaultActive = await initAuthVault();

  if (authVaultActive) {
    console.log(`Auth-Vault: Active (mode: ${getAuthMode()})`);
  } else {
    console.log('Auth-Vault: Inactive (using legacy mode)');
  }

  // ... rest of startup
}

startServer();
```

## Usage

### Starting with Auth-Vault

```bash
# 1. Ensure auth-vault is running
cd /path/to/auth-vault
./auth-vault.sh start

# 2. Start the application
cd /path/to/OSPF-NN-JSON
npm run start
```

### Checking Auth Status

```bash
# Check health endpoint
curl http://localhost:9081/api/health

# Response includes:
{
  "status": "healthy",
  "authVault": "active",    # or "inactive"
  "authMode": "keycloak"    # or "legacy"
}

# Check auth config (for frontend)
curl http://localhost:9081/api/auth/config
```

## Security Features

- **JWKS Token Verification**: RS256 with automatic key rotation
- **Graceful Degradation**: Falls back to legacy auth if Keycloak unavailable
- **Secrets from Vault**: JWT secret fetched from Vault when available
- **Backward Compatible**: Existing local users continue to work

## Troubleshooting

### Keycloak Mode Not Activating

```bash
# Check Keycloak is running
curl http://localhost:9120/health/ready

# Check realm exists
curl http://localhost:9120/realms/ospf-nn-json
```

### Token Validation Fails

1. Verify JWKS endpoint accessible
2. Check token issuer matches realm URL
3. Verify clock sync between services

## Migration Notes

This integration maintains backward compatibility:
- Existing local users continue to work
- Keycloak SSO available when configured
- No breaking changes to API
