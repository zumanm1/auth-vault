# Auth-Vault Integration: OSPF Tempo-X

## Status: ✅ INTEGRATED

This application has been fully integrated with the Auth-Vault infrastructure (Keycloak + HashiCorp Vault).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       OSPF Tempo-X                               │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (Express.js/TypeScript)   │
│  Port: 9100                │  Port: 9101                        │
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
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │  PostgreSQL  │                  │
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
            │ ospf-tempo-x │   │ ospf-tempo-x │   │              │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## Integrated Components

### Backend Files Added

| File | Purpose |
|------|---------|
| `server/lib/keycloak-verifier.ts` | JWT token verification via JWKS (RS256) |
| `server/lib/vault-client.ts` | AppRole authentication & secrets fetching |
| `server/lib/auth-unified.ts` | Hybrid auth middleware (legacy + Keycloak) |

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
KEYCLOAK_REALM=ospf-tempo-x
KEYCLOAK_CLIENT_ID=tempo-x-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>
# OR use token auth:
VAULT_TOKEN=<vault-token>
```

### Keycloak Realm Details

- **Realm Name**: `ospf-tempo-x`
- **Frontend Client**: `tempo-x-frontend` (Public, PKCE)
- **Backend Client**: `tempo-x-api` (Confidential)

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `tempo-admin` | `ChangeMe!Admin2025` | admin |
| `tempo-user` | `ChangeMe!User2025` | user |

### Vault Secret Paths

| Path | Description |
|------|-------------|
| `ospf-tempo-x/config` | JWT secret, session secret |
| `ospf-tempo-x/database` | PostgreSQL credentials |

## Authentication Modes

The application supports dual authentication:

### 1. Keycloak Mode (Auth-Vault)
- Activated when Keycloak is available at startup
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256)

### 2. Legacy Mode (Fallback)
- Activated when Keycloak is unavailable
- Uses existing JWT authentication
- Local PostgreSQL user table

## How It Works

### Server Startup (index.ts)

```typescript
import { initAuthVault, getAuthMode, isAuthVaultActive } from './lib/auth-unified.js';

async function startServer() {
  // ... database init ...

  // Initialize Auth-Vault
  const authVaultActive = await initAuthVault();

  app.listen(PORT, SERVER_HOST, () => {
    console.log('Auth-Vault:');
    console.log(`  Status:       ${authVaultActive ? 'Active' : 'Inactive'}`);
    console.log(`  Mode:         ${getAuthMode()}`);
  });
}
```

### Health Endpoint

```typescript
app.get('/api/health', async (req, res) => {
  res.json({
    status: dbHealthy ? 'healthy' : 'unhealthy',
    database: dbHealthy ? 'connected' : 'disconnected',
    authVault: isAuthVaultActive() ? 'active' : 'inactive',
    authMode: getAuthMode()
  });
});
```

## Usage

### Starting with Auth-Vault

```bash
# 1. Ensure auth-vault is running
cd /path/to/auth-vault
./auth-vault.sh start

# 2. Start the application
cd /path/to/OSPF-TEMPO-X
npm run dev
```

### Checking Auth Status

```bash
# Check health endpoint
curl http://localhost:9101/api/health

# Response includes:
{
  "status": "healthy",
  "database": "connected",
  "authVault": "active",    # or "inactive"
  "authMode": "keycloak"    # or "legacy"
}

# Check auth config (for frontend)
curl http://localhost:9101/api/auth/config
```

## Security Features

- **JWKS Token Verification**: RS256 with automatic key rotation
- **IP Whitelisting**: Configured via ALLOWED_IPS environment variable
- **Graceful Degradation**: Falls back to legacy auth if Keycloak unavailable
- **Secrets from Vault**: JWT secret and DB credentials from Vault when available

## Troubleshooting

### Keycloak Mode Not Activating

```bash
# Check Keycloak is running
curl http://localhost:9120/health/ready

# Check realm exists
curl http://localhost:9120/realms/ospf-tempo-x
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
echo $VAULT_ROLE_ID
echo $VAULT_SECRET_ID
```

## Migration Notes

This integration maintains backward compatibility:
- Existing PostgreSQL users continue to work
- Keycloak SSO available when configured
- IP whitelisting continues to work
- No breaking changes to API
