# Auth-Vault Integration Guide: OSPF Impact Planner

## Overview

This document describes how to integrate the OSPF Impact Planner application with the centralized Keycloak + Vault security infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     OSPF Impact Planner                          │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (Express.js)              │
│  Port: 9090                │  Port: 9091                        │
│                            │                                     │
│  ┌──────────────┐          │  ┌──────────────┐                  │
│  │ Keycloak JS  │──────────┼──│ JWT Verify   │                  │
│  │ Adapter      │          │  │ Middleware   │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ Vault Client │                  │
│                            │  │ (AppRole)    │                  │
│                            │  └──────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
            ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
            │   Keycloak   │   │    Vault     │   │  PostgreSQL  │
            │   Port 8080  │   │   Port 8200  │   │   Port 5432  │
            │              │   │              │   │              │
            │ Realm:       │   │ Mount:       │   │              │
            │ ospf-impact- │   │ ospf-impact- │   │              │
            │ planner      │   │ planner/     │   │              │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## Keycloak Configuration

### Realm Details
- **Realm Name**: `ospf-impact-planner`
- **Keycloak URL**: `http://localhost:8080`

### Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `impact-planner-frontend` | Public | React SPA (PKCE flow) |
| `impact-planner-api` | Confidential | Backend API (service account) |
| `vault-oidc` | Confidential | Vault OIDC integration |

### Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| `admin` | Full administrative access | All operations |
| `user` | Standard user | topology:read, topology:write, settings:manage |
| `viewer` | Read-only access | topology:read |

### Default Users (Change on first login!)

| Username | Password | Role |
|----------|----------|------|
| `impact-admin` | `ChangeMe!Admin2025` | admin |
| `impact-user` | `ChangeMe!User2025` | user |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-impact-planner/config` | JWT secret, session secret, environment |
| `ospf-impact-planner/database` | Database connection credentials |
| `ospf-impact-planner/approle` | AppRole credentials for service account |

### Transit Encryption Keys

| Key | Type | Purpose |
|-----|------|---------|
| `jwt-signing` | RSA-4096 | JWT token signing |
| `data-encryption` | AES-256-GCM | Sensitive data encryption |

### AppRole Authentication

```bash
# Get AppRole credentials from Vault
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="your-root-token"

# Read Role ID
vault read auth/approle/role/ospf-impact-planner/role-id

# Generate Secret ID
vault write -f auth/approle/role/ospf-impact-planner/secret-id
```

## Integration Steps

### 1. Frontend Integration (React)

Install the Keycloak adapter:

```bash
npm install keycloak-js
```

Create `src/lib/keycloak.ts`:

```typescript
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'ospf-impact-planner',
  clientId: 'impact-planner-frontend',
});

export const initKeycloak = async (): Promise<boolean> => {
  try {
    const authenticated = await keycloak.init({
      onLoad: 'login-required',
      pkceMethod: 'S256',
      checkLoginIframe: false,
    });
    return authenticated;
  } catch (error) {
    console.error('Keycloak init failed:', error);
    return false;
  }
};

export const getToken = (): string | undefined => keycloak.token;

export const refreshToken = async (): Promise<boolean> => {
  try {
    const refreshed = await keycloak.updateToken(30);
    return refreshed;
  } catch (error) {
    console.error('Token refresh failed:', error);
    keycloak.login();
    return false;
  }
};

export const logout = (): void => {
  keycloak.logout({ redirectUri: window.location.origin });
};

export const hasRole = (role: string): boolean => {
  return keycloak.hasRealmRole(role);
};

export default keycloak;
```

Update `src/main.tsx`:

```typescript
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { initKeycloak } from './lib/keycloak';

initKeycloak().then((authenticated) => {
  if (authenticated) {
    ReactDOM.createRoot(document.getElementById('root')!).render(
      <React.StrictMode>
        <App />
      </React.StrictMode>
    );
  }
});
```

### 2. Backend Integration (Express.js)

Install required packages:

```bash
npm install node-vault keycloak-connect
```

Create `server/src/vault-client.ts`:

```typescript
import vault from 'node-vault';

const vaultClient = vault({
  apiVersion: 'v1',
  endpoint: process.env.VAULT_ADDR || 'http://localhost:8200',
});

let authenticated = false;

export const initVault = async (): Promise<void> => {
  const roleId = process.env.VAULT_ROLE_ID;
  const secretId = process.env.VAULT_SECRET_ID;

  if (!roleId || !secretId) {
    throw new Error('Vault AppRole credentials not configured');
  }

  const result = await vaultClient.approleLogin({
    role_id: roleId,
    secret_id: secretId,
  });

  vaultClient.token = result.auth.client_token;
  authenticated = true;

  // Schedule token renewal
  const ttl = result.auth.lease_duration * 1000 * 0.75;
  setInterval(async () => {
    await vaultClient.tokenRenewSelf();
  }, ttl);
};

export const getSecret = async (path: string): Promise<Record<string, any>> => {
  if (!authenticated) {
    throw new Error('Vault not authenticated');
  }

  const result = await vaultClient.read(`ospf-impact-planner/data/${path}`);
  return result.data.data;
};

export const encrypt = async (plaintext: string): Promise<string> => {
  const result = await vaultClient.write(
    'ospf-impact-planner-transit/encrypt/data-encryption',
    { plaintext: Buffer.from(plaintext).toString('base64') }
  );
  return result.data.ciphertext;
};

export const decrypt = async (ciphertext: string): Promise<string> => {
  const result = await vaultClient.write(
    'ospf-impact-planner-transit/decrypt/data-encryption',
    { ciphertext }
  );
  return Buffer.from(result.data.plaintext, 'base64').toString();
};

export default vaultClient;
```

Update `server/src/middleware/auth.ts`:

```typescript
import jwt from 'jsonwebtoken';
import jwksRsa from 'jwks-rsa';
import { Request, Response, NextFunction } from 'express';

const jwksClient = jwksRsa({
  jwksUri: 'http://localhost:8080/realms/ospf-impact-planner/protocol/openid-connect/certs',
  cache: true,
  rateLimit: true,
});

const getKey = (header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) => {
  jwksClient.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    const signingKey = key?.getPublicKey();
    callback(null, signingKey);
  });
};

export const authenticateToken = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    res.status(401).json({ error: 'Access token required' });
    return;
  }

  jwt.verify(
    token,
    getKey,
    {
      algorithms: ['RS256'],
      issuer: 'http://localhost:8080/realms/ospf-impact-planner',
      audience: 'account',
    },
    (err, decoded) => {
      if (err) {
        res.status(403).json({ error: 'Invalid token' });
        return;
      }
      req.user = decoded;
      next();
    }
  );
};

export const requireRole = (role: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const roles = req.user?.realm_access?.roles || [];
    if (!roles.includes(role)) {
      res.status(403).json({ error: 'Insufficient permissions' });
      return;
    }
    next();
  };
};
```

### 3. Environment Variables

Create `.env.production`:

```env
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=ospf-impact-planner
KEYCLOAK_CLIENT_ID=impact-planner-api
KEYCLOAK_CLIENT_SECRET=FROM_VAULT

# Vault Configuration
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=FROM_VAULT_INIT
VAULT_SECRET_ID=FROM_VAULT_INIT

# DO NOT PUT SECRETS HERE - THEY COME FROM VAULT
# Database credentials, JWT secrets, etc. are fetched from Vault at runtime
```

### 4. Startup Script

Update `start.sh`:

```bash
#!/bin/bash

# Ensure auth-vault is running
if ! docker ps | grep -q keycloak; then
  echo "ERROR: Keycloak is not running. Start auth-vault first:"
  echo "  cd /path/to/auth-vault && docker-compose up -d"
  exit 1
fi

if ! docker ps | grep -q vault; then
  echo "ERROR: Vault is not running. Start auth-vault first:"
  echo "  cd /path/to/auth-vault && docker-compose up -d"
  exit 1
fi

# Get AppRole credentials from Vault (first time only)
if [ ! -f .vault-credentials ]; then
  echo "Fetching AppRole credentials from Vault..."
  VAULT_TOKEN=${VAULT_ROOT_TOKEN:-vault-root-token-change-me}

  ROLE_ID=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
    http://localhost:8200/v1/auth/approle/role/ospf-impact-planner/role-id | jq -r '.data.role_id')

  SECRET_ID=$(curl -s -X POST -H "X-Vault-Token: $VAULT_TOKEN" \
    http://localhost:8200/v1/auth/approle/role/ospf-impact-planner/secret-id | jq -r '.data.secret_id')

  echo "VAULT_ROLE_ID=$ROLE_ID" > .vault-credentials
  echo "VAULT_SECRET_ID=$SECRET_ID" >> .vault-credentials
  chmod 600 .vault-credentials
fi

source .vault-credentials

# Start the application
npm run start
```

## Security Checklist

- [ ] Changed default Keycloak admin password
- [ ] Changed default user passwords (ChangeMe!Admin2025)
- [ ] Updated database credentials in Vault
- [ ] Configured HTTPS for production
- [ ] Restricted CORS origins
- [ ] Set IP whitelist
- [ ] Enabled audit logging
- [ ] Tested role-based access
- [ ] Verified token refresh works
- [ ] Checked session timeout behavior

## Troubleshooting

### "Invalid token" error
1. Check Keycloak is running: `curl http://localhost:8080/realms/ospf-impact-planner`
2. Verify JWKS endpoint: `curl http://localhost:8080/realms/ospf-impact-planner/protocol/openid-connect/certs`
3. Check token issuer matches configuration

### "Vault permission denied"
1. Verify AppRole credentials are correct
2. Check policy allows access to requested path
3. Verify Vault is unsealed: `vault status`

### CORS errors
1. Ensure Keycloak client has correct web origins
2. Check backend CORS configuration
3. Verify redirect URIs in Keycloak client

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Vault AppRole Auth](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Keycloak JS Adapter](https://www.keycloak.org/docs/latest/securing_apps/#_javascript_adapter)
