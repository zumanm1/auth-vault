# Auth-Vault Integration Guide: OSPF NN-JSON (Visualizer Pro)

## Overview

This document describes how to integrate the OSPF Visualizer Pro application with the centralized Keycloak + Vault security infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   OSPF Visualizer Pro                            │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (Express.js)              │
│  Port: 9080                │  Port: 9081                        │
│                            │                                     │
│  ┌──────────────┐          │  ┌──────────────┐                  │
│  │ Keycloak JS  │──────────┼──│ OIDC Verify  │                  │
│  │ Adapter      │          │  │ Middleware   │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ Vault Client │                  │
│                            │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │   SQLite     │                  │
│                            │  │  (encrypted) │                  │
│                            │  └──────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼
            ┌──────────────┐   ┌──────────────┐
            │   Keycloak   │   │    Vault     │
            │   Port 8080  │   │   Port 8200  │
            │              │   │              │
            │ Realm:       │   │ Mount:       │
            │ ospf-nn-json │   │ ospf-nn-json │
            └──────────────┘   └──────────────┘
```

## Keycloak Configuration

### Realm Details
- **Realm Name**: `ospf-nn-json`
- **Keycloak URL**: `http://localhost:8080`

### Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `visualizer-pro-frontend` | Public | React SPA (PKCE flow) |
| `visualizer-pro-api` | Confidential | Backend API |
| `vault-oidc` | Confidential | Vault OIDC integration |

### Roles

| Role | Description |
|------|-------------|
| `admin` | Full administrative access |
| `user` | Standard user access |

### Client Scopes (Fine-grained permissions)

| Scope | Description |
|-------|-------------|
| `topology:read` | Read topology data |
| `topology:write` | Create/modify topology |
| `scenarios:manage` | Manage failure scenarios |
| `settings:manage` | Manage application settings |
| `users:manage` | User management (admin) |
| `links:manage` | Custom link management |

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
| `ospf-nn-json/database` | Database path |
| `ospf-nn-json/approle` | AppRole credentials |

### Transit Keys

| Key | Type | Purpose |
|-----|------|---------|
| `jwt-signing` | RSA-4096 | JWT token signing |
| `data-encryption` | AES-256-GCM | Data encryption |

## Critical Issues to Fix

### 1. CSRF Protection (Missing)

**Current State**: No CSRF protection implemented.

**Solution with Keycloak**:

```javascript
// server/middleware/csrf.js
const crypto = require('crypto');

const csrfProtection = (req, res, next) => {
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
    const csrfToken = req.headers['x-csrf-token'];
    const sessionToken = req.cookies['csrf_token'];

    if (!csrfToken || !sessionToken || csrfToken !== sessionToken) {
      return res.status(403).json({ error: 'Invalid CSRF token' });
    }
  }

  // Generate new CSRF token for response
  const newToken = crypto.randomBytes(32).toString('hex');
  res.cookie('csrf_token', newToken, {
    httpOnly: false, // JavaScript needs to read it
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
  });
  res.setHeader('X-CSRF-Token', newToken);

  next();
};

module.exports = csrfProtection;
```

### 2. Token Blacklist Implementation

**Current State**: Token validation doesn't check session table.

**Solution**:

```javascript
// server/middleware/tokenBlacklist.js
const db = require('../database');

const isTokenBlacklisted = async (tokenHash) => {
  const session = await db.get(
    'SELECT * FROM sessions WHERE token_hash = ? AND is_active = 1',
    [tokenHash]
  );
  return !session;
};

const validateToken = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

  if (await isTokenBlacklisted(tokenHash)) {
    return res.status(401).json({ error: 'Token has been revoked' });
  }

  // Continue with JWT verification
  next();
};
```

### 3. Move Token from localStorage to httpOnly Cookie

**Frontend Changes**:

```typescript
// Remove localStorage token storage
// Before:
localStorage.setItem('authToken', token);

// After: Token handled by Keycloak adapter automatically
// No manual token storage needed
```

**Backend Changes**:

```javascript
// server/index.js
app.use(cookieParser());

// Set secure cookie on login
app.post('/api/auth/login', async (req, res) => {
  // ... authentication logic ...

  res.cookie('auth_token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
  });

  res.json({ user: userInfo }); // Don't return token in body
});
```

## Integration Steps

### 1. Install Dependencies

```bash
npm install keycloak-js keycloak-connect node-vault cookie-parser
```

### 2. Keycloak Frontend Setup

```typescript
// src/lib/keycloak.ts
import Keycloak from 'keycloak-js';

const keycloakConfig = {
  url: 'http://localhost:8080',
  realm: 'ospf-nn-json',
  clientId: 'visualizer-pro-frontend',
};

const keycloak = new Keycloak(keycloakConfig);

export const initKeycloak = (): Promise<boolean> => {
  return keycloak.init({
    onLoad: 'login-required',
    pkceMethod: 'S256',
    checkLoginIframe: false,
  });
};

export const getToken = (): string | undefined => keycloak.token;

export const logout = (): void => {
  keycloak.logout({ redirectUri: window.location.origin });
};

export const hasRole = (role: string): boolean => {
  return keycloak.hasRealmRole(role);
};

export default keycloak;
```

### 3. Vault Integration

```javascript
// server/vault-client.js
const vault = require('node-vault')({
  endpoint: process.env.VAULT_ADDR || 'http://localhost:8200',
});

async function initVault() {
  const { role_id, secret_id } = process.env;

  const authResult = await vault.approleLogin({
    role_id: process.env.VAULT_ROLE_ID,
    secret_id: process.env.VAULT_SECRET_ID,
  });

  vault.token = authResult.auth.client_token;

  // Schedule renewal
  setInterval(async () => {
    await vault.tokenRenewSelf();
  }, authResult.auth.lease_duration * 750);

  return vault;
}

async function getSecrets() {
  const result = await vault.read('ospf-nn-json/data/config');
  return result.data.data;
}

module.exports = { initVault, getSecrets, vault };
```

### 4. Update Server Startup

```javascript
// server/index.js
const { initVault, getSecrets } = require('./vault-client');

async function startServer() {
  // Initialize Vault
  await initVault();
  const secrets = await getSecrets();

  // Use secrets from Vault
  const JWT_SECRET = secrets.jwt_secret;
  const SESSION_SECRET = secrets.session_secret;

  // ... rest of server setup using these secrets
}

startServer().catch(console.error);
```

### 5. Environment Configuration

```env
# .env.production
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=ospf-nn-json
KEYCLOAK_CLIENT_ID=visualizer-pro-api

VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>

# Remove these - now from Vault:
# JWT_SECRET=xxx
# SESSION_SECRET=xxx
```

## Security Improvements Summary

| Issue | Current | With Auth-Vault |
|-------|---------|-----------------|
| CSRF Protection | None | Keycloak + double-submit |
| Token Blacklist | Not checked | DB-backed verification |
| Token Storage | localStorage | httpOnly cookies |
| Secrets | .env file | Vault with AppRole |
| Password Hashing | bcrypt | bcrypt (unchanged) |
| Session Management | Manual | Keycloak managed |
| Audit Logging | Limited | Keycloak events + Vault |

## Security Checklist

- [ ] Keycloak realm created and configured
- [ ] Changed default user passwords
- [ ] Vault secrets populated
- [ ] CSRF protection implemented
- [ ] Token blacklist working
- [ ] Tokens in httpOnly cookies
- [ ] Rate limiting per user (not just IP)
- [ ] Account lockout after failures
- [ ] HTTPS enabled
- [ ] CSP headers tightened

## Troubleshooting

### CSRF Token Mismatch
1. Check cookie is being set correctly
2. Verify frontend sends X-CSRF-Token header
3. Check SameSite attribute

### Keycloak Login Redirect Loop
1. Verify redirect URIs in Keycloak client
2. Check CORS configuration
3. Verify SSL settings match environment

### Vault Connection Refused
1. Check Vault is running: `vault status`
2. Verify VAULT_ADDR is correct
3. Check AppRole credentials

## References

- [Keycloak Security Best Practices](https://www.keycloak.org/docs/latest/server_admin/#security-best-practices)
- [OWASP CSRF Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
- [Vault AppRole](https://developer.hashicorp.com/vault/docs/auth/approle)
