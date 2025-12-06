# Auth-Vault Integration: NetViz Pro (OSPF-LL-JSON-PART1)

## Status: ✅ INTEGRATED

This application has been fully integrated with the Auth-Vault infrastructure (Keycloak + HashiCorp Vault).

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
                  ▼                  ▼
          ┌──────────────┐   ┌──────────────┐
          │   Keycloak   │   │    Vault     │
          │   Port 9120  │   │   Port 9121  │
          │              │   │              │
          │ Realm:       │   │ Mount:       │
          │ ospf-ll-     │   │ ospf-ll-     │
          │ json-part1   │   │ json-part1/  │
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
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>
# OR use token auth:
VAULT_TOKEN=<vault-token>
```

### Keycloak Realm Details

- **Realm Name**: `ospf-ll-json-part1`
- **Frontend Client**: `netviz-pro-frontend` (Public, PKCE)
- **Backend Client**: `netviz-pro-api` (Confidential)

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `netviz-admin` | `ChangeMe!Admin2025` | admin |
| `netviz-user` | `ChangeMe!User2025` | user |

### Vault Secret Paths

| Path | Description |
|------|-------------|
| `ospf-ll-json-part1/config` | JWT secret, session secret |
| `ospf-ll-json-part1/database` | Database configuration |

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

  // Start server...
}
```

### Updated requireAuth Middleware

The `requireAuth` middleware now supports both legacy JWT and Keycloak tokens:

```javascript
const requireAuth = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  // Try unified auth (supports both legacy and Keycloak)
  const verifiedUser = await verifyToken(token, JWT_SECRET);

  if (verifiedUser) {
    if (verifiedUser.authSource === 'keycloak') {
      // Keycloak token - use directly
      req.user = verifiedUser;
      return next();
    }
    // Legacy token - verify against local database
    // ...existing logic...
  }
};
```

## Usage

### Starting with Auth-Vault

```bash
# 1. Ensure auth-vault is running
cd /path/to/auth-vault
./auth-vault.sh start

# 2. Start the application
cd /path/to/OSPF-LL-JSON-PART1/netviz-pro
npm run start
```

### Checking Auth Status

```bash
# Check health endpoint
curl http://localhost:9041/api/health

# Response includes:
{
  "status": "healthy",
  "authVault": "active",    # or "inactive"
  "authMode": "keycloak"    # or "legacy"
}

# Check auth config (for frontend)
curl http://localhost:9041/api/auth/config
```

## Security Features

- **JWKS Token Verification**: RS256 with automatic key rotation
- **Graceful Degradation**: Falls back to legacy auth if Keycloak unavailable
- **Secrets from Vault**: JWT secret fetched from Vault when available
- **Backward Compatible**: Existing SQLite users continue to work

## Troubleshooting

### Keycloak Mode Not Activating

```bash
# Check Keycloak is running
curl http://localhost:9120/health/ready

# Check realm exists
curl http://localhost:9120/realms/ospf-ll-json-part1
```

### Token Validation Fails

1. Verify JWKS endpoint accessible
2. Check token issuer matches realm URL
3. Verify clock sync between services

### Vault Secrets Not Loading

```bash
# Check Vault is running
curl http://localhost:9121/v1/sys/health

# Verify AppRole credentials are set
```

## Migration Notes

This integration maintains backward compatibility:
- Existing SQLite users continue to work
- Keycloak SSO available when configured
- No breaking changes to API
