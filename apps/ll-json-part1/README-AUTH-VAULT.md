# Auth-Vault Integration Guide: OSPF LL-JSON-PART1 (NetViz Pro)

## Overview

This document describes how to integrate the NetViz Pro application with the centralized Keycloak + Vault security infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       NetViz Pro                                 │
├─────────────────────────────────────────────────────────────────┤
│  Gateway (Port 9040)     │  Auth Server (Port 9041)             │
│  ┌──────────────┐        │  ┌──────────────┐                    │
│  │ Session      │────────┼──│ Keycloak     │                    │
│  │ Validation   │        │  │ OIDC Client  │                    │
│  └──────────────┘        │  └──────────────┘                    │
│         │                │         │                            │
│         │                │         ▼                            │
│         │                │  ┌──────────────┐                    │
│         │                │  │ Vault Client │                    │
│         ▼                │  │ (Secrets)    │                    │
│  ┌──────────────┐        │  └──────────────┘                    │
│  │ Vite Server  │        │         │                            │
│  │ (Port 9042)  │        │         ▼                            │
│  └──────────────┘        │  ┌──────────────┐                    │
│                          │  │   SQLite     │                    │
│                          │  │   users.db   │                    │
│                          │  └──────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
                                     │
                  ┌──────────────────┼──────────────────┐
                  ▼                  ▼                  ▼
          ┌──────────────┐   ┌──────────────┐
          │   Keycloak   │   │    Vault     │
          │   Port 8080  │   │   Port 8200  │
          │              │   │              │
          │ Realm:       │   │ Mount:       │
          │ ospf-ll-     │   │ ospf-ll-     │
          │ json-part1   │   │ json-part1/  │
          └──────────────┘   └──────────────┘
```

## Keycloak Configuration

### Realm Details
- **Realm Name**: `ospf-ll-json-part1`
- **Keycloak URL**: `http://localhost:8080`

### Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `netviz-pro-frontend` | Public | React SPA (PKCE flow) |
| `netviz-pro-api` | Confidential | Backend API (service account) |
| `vault-oidc` | Confidential | Vault OIDC integration |

### Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| `admin` | Full administrative access | All operations, user management |
| `user` | Standard user | topology operations, export |

### Default Users (Change on first login!)

| Username | Password | Role |
|----------|----------|------|
| `netviz-admin` | `ChangeMe!Admin2025` | admin |
| `netviz-user` | `ChangeMe!User2025` | user |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-ll-json-part1/config` | JWT secret, session secret, admin reset PIN |
| `ospf-ll-json-part1/database` | Database path configuration |
| `ospf-ll-json-part1/approle` | AppRole credentials for service account |

### Transit Encryption Keys

| Key | Type | Purpose |
|-----|------|---------|
| `jwt-signing` | RSA-4096 | JWT token signing |
| `data-encryption` | AES-256-GCM | Sensitive data encryption |
| `session-key` | AES-256-GCM | Session token encryption |

## Integration Steps

### 1. Remove Hardcoded Secrets

**CRITICAL**: Remove these from `.env.local`:
- `APP_SECRET_KEY` → Fetch from Vault
- `ADMIN_RESET_PIN` → Fetch from Vault
- `APP_ADMIN_PASSWORD` → Use Keycloak authentication

### 2. Update Gateway Server

Modify `server/gateway.js`:

```javascript
const Keycloak = require('keycloak-connect');
const session = require('express-session');

// Session store for Keycloak
const memoryStore = new session.MemoryStore();

app.use(session({
  secret: process.env.SESSION_SECRET || 'should-be-from-vault',
  resave: false,
  saveUninitialized: true,
  store: memoryStore
}));

const keycloak = new Keycloak({
  store: memoryStore
}, {
  realm: 'ospf-ll-json-part1',
  'auth-server-url': 'http://localhost:8080/',
  'ssl-required': 'external',
  resource: 'netviz-pro-api',
  'confidential-port': 0,
  'bearer-only': true
});

app.use(keycloak.middleware());

// Protect routes with Keycloak
app.get('/api/*', keycloak.protect(), (req, res, next) => {
  next();
});
```

### 3. Vault Client Integration

Create `server/vault-client.js`:

```javascript
const vault = require('node-vault')({
  apiVersion: 'v1',
  endpoint: process.env.VAULT_ADDR || 'http://localhost:8200',
});

let vaultToken = null;

async function initVault() {
  const roleId = process.env.VAULT_ROLE_ID;
  const secretId = process.env.VAULT_SECRET_ID;

  if (!roleId || !secretId) {
    throw new Error('Vault AppRole credentials not configured');
  }

  const result = await vault.approleLogin({
    role_id: roleId,
    secret_id: secretId,
  });

  vault.token = result.auth.client_token;
  vaultToken = result.auth.client_token;

  // Auto-renew token
  const ttl = result.auth.lease_duration * 1000 * 0.75;
  setInterval(async () => {
    await vault.tokenRenewSelf();
  }, ttl);

  console.log('Vault authentication successful');
}

async function getConfig() {
  const result = await vault.read('ospf-ll-json-part1/data/config');
  return result.data.data;
}

async function getAdminResetPin() {
  const config = await getConfig();
  return config.admin_reset_pin;
}

async function getJwtSecret() {
  const config = await getConfig();
  return config.jwt_secret;
}

module.exports = {
  initVault,
  getConfig,
  getAdminResetPin,
  getJwtSecret,
  vault,
};
```

### 4. Update Auth Server

Modify `server/index.js`:

```javascript
const { initVault, getJwtSecret, getAdminResetPin } = require('./vault-client');

// Initialize Vault before starting server
async function startServer() {
  try {
    await initVault();

    // Get JWT secret from Vault instead of environment
    const JWT_SECRET = await getJwtSecret();

    // Update JWT signing to use Vault secret
    // ... rest of your auth logic

    app.listen(AUTH_PORT, () => {
      console.log(`Auth server running on port ${AUTH_PORT}`);
    });
  } catch (error) {
    console.error('Failed to initialize:', error);
    process.exit(1);
  }
}

startServer();
```

### 5. Update Admin Reset PIN Logic

```javascript
// Replace hardcoded PIN check with Vault lookup
app.post('/api/auth/reset-admin', adminResetLimiter, async (req, res) => {
  const { pin } = req.body;

  // Get PIN from Vault (hashed)
  const storedPinHash = await getAdminResetPin();
  const inputHash = crypto.createHash('sha256').update(pin).digest('hex');

  if (inputHash !== storedPinHash) {
    return res.status(401).json({ error: 'Invalid PIN' });
  }

  // ... rest of reset logic
});
```

### 6. Environment Variables

Create `.env.production`:

```env
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api
KEYCLOAK_CLIENT_SECRET=FROM_VAULT

# Vault Configuration
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=FROM_VAULT_INIT
VAULT_SECRET_ID=FROM_VAULT_INIT

# Server Configuration
AUTH_PORT=9041
GATEWAY_PORT=9040
VITE_INTERNAL_PORT=9042

# Removed: APP_SECRET_KEY, ADMIN_RESET_PIN, APP_ADMIN_PASSWORD
# These are now fetched from Vault at runtime
```

### 7. Frontend Integration

Update React app to use Keycloak:

```typescript
// src/hooks/useAuth.tsx
import { useKeycloak } from '@react-keycloak/web';

export const useAuth = () => {
  const { keycloak, initialized } = useKeycloak();

  return {
    isAuthenticated: keycloak.authenticated,
    isAdmin: keycloak.hasRealmRole('admin'),
    user: keycloak.tokenParsed,
    login: () => keycloak.login(),
    logout: () => keycloak.logout(),
    token: keycloak.token,
    loading: !initialized,
  };
};
```

## Migration Path

### Phase 1: Parallel Authentication
1. Keep existing local auth working
2. Add Keycloak as alternative
3. Test with subset of users

### Phase 2: Vault Integration
1. Move secrets to Vault
2. Update server to fetch from Vault
3. Remove hardcoded values

### Phase 3: Full Migration
1. Disable local auth
2. Remove local user database (or archive)
3. All auth through Keycloak

## Security Improvements Over Current Implementation

| Current Issue | With Auth-Vault |
|---------------|-----------------|
| Exposed secrets in .env.local | Secrets in Vault, dynamic fetch |
| Weak admin reset PIN (16 chars) | Strong PIN in Vault, rate limited |
| Session in memory (lost on restart) | Keycloak manages sessions |
| No CSRF protection | Keycloak handles CSRF |
| Unsafe CSP headers | Proper CSP with nonces |
| Token in localStorage | Keycloak handles securely |

## Security Checklist

- [ ] Changed default Keycloak admin password
- [ ] Changed default user passwords
- [ ] Removed hardcoded secrets from code
- [ ] Removed .env.local from repository
- [ ] Updated admin reset PIN in Vault
- [ ] Configured HTTPS for production
- [ ] Tested session expiry
- [ ] Verified role-based access
- [ ] Enabled audit logging in Keycloak

## Troubleshooting

### "ADMIN_RESET_PIN not found"
1. Verify Vault is running and initialized
2. Check AppRole credentials are correct
3. Verify secret exists: `vault kv get ospf-ll-json-part1/config`

### Gateway shows "Keycloak not available"
1. Check Keycloak is running: `docker ps | grep keycloak`
2. Verify realm exists: `curl http://localhost:8080/realms/ospf-ll-json-part1`
3. Check network connectivity between containers

### Token validation fails
1. Verify client secret matches in Keycloak
2. Check issuer URL matches configuration
3. Ensure clock sync between servers

## References

- [Keycloak Node.js Adapter](https://www.keycloak.org/docs/latest/securing_apps/#_nodejs_adapter)
- [Vault Node.js Client](https://github.com/kr1sp1n/node-vault)
- [Express Session Store](https://www.npmjs.com/package/express-session)
