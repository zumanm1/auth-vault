# Auth-Vault Integration Guide: OSPF Tempo-X

## Overview

This document describes how to integrate the OSPF Tempo-X application with the centralized Keycloak + Vault security infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       OSPF Tempo-X                               │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (Express.js)              │
│  Port: 9100                │  Port: 9101                        │
│                            │                                     │
│  ┌──────────────┐          │  ┌──────────────┐                  │
│  │ Keycloak JS  │──────────┼──│ JWT Verify   │                  │
│  │ Adapter      │          │  │ (JWKS)       │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ Vault Client │                  │
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
            │   Port 8080  │   │   Port 8200  │   │   Port 5432  │
            │              │   │              │   │              │
            │ Realm:       │   │ Mount:       │   │              │
            │ ospf-tempo-x │   │ ospf-tempo-x │   │              │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## Critical Issues to Fix

### 1. CORS Misconfiguration (CRITICAL)

**Current State** (`server/index.ts`):
```typescript
app.use(cors({
  origin: true, // DANGEROUS: Allows ALL origins
  credentials: true
}));
```

**Fix with Keycloak**:
```typescript
import cors from 'cors';

const allowedOrigins = [
  'http://localhost:9100',
  'http://localhost:8080', // Keycloak
];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
}));
```

### 2. Weak JWT Secret

**Current State**:
```typescript
const JWT_SECRET = process.env.JWT_SECRET || 'ospf-tempo-x-secret-key-change-in-production';
```

**Fix**: Fetch from Vault at startup:
```typescript
import { getSecrets } from './vault-client';

let JWT_SECRET: string;

async function initSecrets() {
  const secrets = await getSecrets();
  JWT_SECRET = secrets.jwt_secret;
}
```

### 3. Missing Security Headers

**Add Helmet**:
```bash
npm install helmet
```

```typescript
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"], // For styled-components
      imgSrc: ["'self'", 'data:', 'https:'],
      connectSrc: ["'self'", 'http://localhost:8080', 'http://localhost:8200'],
      frameSrc: ["'self'", 'http://localhost:8080'], // For Keycloak iframe
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
  },
}));
```

### 4. Rate Limiting

```bash
npm install express-rate-limit
```

```typescript
import rateLimit from 'express-rate-limit';

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: { error: 'Too many login attempts, please try again later' },
});

app.use('/api/auth/login', authLimiter);

const apiLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 100, // 100 requests
});

app.use('/api/', apiLimiter);
```

## Keycloak Configuration

### Realm Details
- **Realm Name**: `ospf-tempo-x`
- **Keycloak URL**: `http://localhost:8080`

### Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `tempo-x-frontend` | Public | React SPA (PKCE) |
| `tempo-x-api` | Confidential | Backend API |
| `vault-oidc` | Confidential | Vault integration |

### Roles

| Role | Permissions |
|------|-------------|
| `admin` | All operations, user management |
| `user` | topology CRUD, snapshots |

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `tempo-admin` | `ChangeMe!Admin2025` | admin |
| `tempo-user` | `ChangeMe!User2025` | user |

## Vault Configuration

### Secret Paths

| Path | Contents |
|------|----------|
| `ospf-tempo-x/config` | JWT secret, session secret |
| `ospf-tempo-x/database` | PostgreSQL credentials |
| `ospf-tempo-x/approle` | AppRole credentials |

### Transit Keys

| Key | Purpose |
|-----|---------|
| `jwt-signing` | JWT signature |
| `data-encryption` | Topology data encryption |

## Integration Steps

### 1. Install Dependencies

```bash
npm install keycloak-js @keycloak/keycloak-admin-client node-vault helmet express-rate-limit jwks-rsa
```

### 2. Keycloak Frontend Integration

```typescript
// src/lib/keycloak.ts
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'ospf-tempo-x',
  clientId: 'tempo-x-frontend',
});

export const initKeycloak = async (): Promise<boolean> => {
  return keycloak.init({
    onLoad: 'login-required',
    pkceMethod: 'S256',
    checkLoginIframe: false,
  });
};

export const getToken = (): string | undefined => keycloak.token;

export const refreshToken = async (): Promise<void> => {
  try {
    await keycloak.updateToken(30);
  } catch {
    keycloak.login();
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

### 3. Backend JWT Verification with JWKS

```typescript
// server/middleware/auth.ts
import jwt from 'jsonwebtoken';
import jwksRsa from 'jwks-rsa';
import { Request, Response, NextFunction } from 'express';

const jwksClient = jwksRsa({
  jwksUri: 'http://localhost:8080/realms/ospf-tempo-x/protocol/openid-connect/certs',
  cache: true,
  cacheMaxAge: 600000, // 10 minutes
  rateLimit: true,
});

function getKey(header: jwt.JwtHeader, callback: jwt.SigningKeyCallback) {
  jwksClient.getSigningKey(header.kid, (err, key) => {
    if (err) {
      callback(err);
      return;
    }
    callback(null, key?.getPublicKey());
  });
}

export const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader?.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  jwt.verify(token, getKey, {
    algorithms: ['RS256'],
    issuer: 'http://localhost:8080/realms/ospf-tempo-x',
  }, (err, decoded) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = decoded;
    next();
  });
};

export const requireRole = (role: string) => {
  return (req: Request, res: Response, next: NextFunction) => {
    const roles = req.user?.realm_access?.roles || [];
    if (!roles.includes(role)) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    next();
  };
};
```

### 4. Vault Client

```typescript
// server/vault-client.ts
import vault from 'node-vault';

const vaultClient = vault({
  apiVersion: 'v1',
  endpoint: process.env.VAULT_ADDR || 'http://localhost:8200',
});

export async function initVault(): Promise<void> {
  const result = await vaultClient.approleLogin({
    role_id: process.env.VAULT_ROLE_ID!,
    secret_id: process.env.VAULT_SECRET_ID!,
  });

  vaultClient.token = result.auth.client_token;

  // Schedule renewal
  setInterval(async () => {
    await vaultClient.tokenRenewSelf();
  }, result.auth.lease_duration * 750);
}

export async function getConfig(): Promise<Record<string, string>> {
  const result = await vaultClient.read('ospf-tempo-x/data/config');
  return result.data.data;
}

export async function getDatabaseCredentials(): Promise<{
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}> {
  const result = await vaultClient.read('ospf-tempo-x/data/database');
  return result.data.data;
}
```

### 5. Update Database Connection

```typescript
// server/db/index.ts
import { Pool } from 'pg';
import { getDatabaseCredentials } from '../vault-client';

let pool: Pool;

export async function initDatabase(): Promise<Pool> {
  const credentials = await getDatabaseCredentials();

  pool = new Pool({
    host: credentials.host,
    port: credentials.port,
    database: credentials.database,
    user: credentials.user,
    password: credentials.password,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: true } : false,
  });

  return pool;
}

export function getPool(): Pool {
  return pool;
}
```

### 6. Updated Server Startup

```typescript
// server/index.ts
import express from 'express';
import { initVault, getConfig } from './vault-client';
import { initDatabase } from './db';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import cors from 'cors';

async function startServer() {
  // Initialize Vault first
  await initVault();
  console.log('Vault initialized');

  // Get configuration from Vault
  const config = await getConfig();
  console.log('Configuration loaded from Vault');

  // Initialize database with Vault credentials
  await initDatabase();
  console.log('Database connected');

  const app = express();

  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        connectSrc: ["'self'", 'http://localhost:8080'],
        frameSrc: ["'self'", 'http://localhost:8080'],
      },
    },
  }));

  // CORS - properly configured
  const allowedOrigins = ['http://localhost:9100', 'http://localhost:8080'];
  app.use(cors({
    origin: allowedOrigins,
    credentials: true,
  }));

  // Rate limiting
  app.use('/api/auth/', rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 10,
  }));

  // ... rest of routes

  app.listen(9101, () => {
    console.log('Tempo-X API running on port 9101');
  });
}

startServer().catch(console.error);
```

### 7. Environment Configuration

```env
# .env.production
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>

KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=ospf-tempo-x
KEYCLOAK_CLIENT_ID=tempo-x-api

# Remove these - now from Vault:
# JWT_SECRET=xxx
# DB_PASSWORD=xxx
```

## Migration Path

### Phase 1: Add Security Headers & Rate Limiting
1. Add Helmet middleware
2. Implement rate limiting
3. Fix CORS configuration
4. Test existing functionality

### Phase 2: Vault Integration
1. Deploy auth-vault infrastructure
2. Add Vault client
3. Migrate secrets to Vault
4. Update database connection

### Phase 3: Keycloak Integration
1. Configure Keycloak realm
2. Update frontend authentication
3. Switch backend to JWKS verification
4. Migrate users to Keycloak

## Security Improvements

| Current Issue | With Auth-Vault |
|---------------|-----------------|
| CORS allows all origins | Strict origin whitelist |
| Weak JWT secret | Strong secret from Vault |
| No security headers | Helmet with strict CSP |
| No rate limiting | Per-endpoint limits |
| Token in localStorage | Keycloak handles securely |
| Hardcoded DB password | Dynamic from Vault |

## Security Checklist

- [ ] Fixed CORS configuration
- [ ] Added Helmet security headers
- [ ] Implemented rate limiting
- [ ] Keycloak realm configured
- [ ] Changed default passwords
- [ ] Vault secrets populated
- [ ] Database credentials in Vault
- [ ] HTTPS enabled
- [ ] Audit logging enabled

## Troubleshooting

### CORS Errors
1. Check origin is in allowedOrigins array
2. Verify Keycloak client redirect URIs
3. Check browser developer tools network tab

### JWT Verification Failed
1. Verify JWKS endpoint accessible
2. Check issuer matches configuration
3. Verify token not expired

### Vault Connection Issues
1. Ensure Vault is unsealed
2. Check AppRole credentials
3. Verify network connectivity

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Vault Node.js](https://github.com/kr1sp1n/node-vault)
- [Helmet.js](https://helmetjs.github.io/)
- [Express Rate Limit](https://www.npmjs.com/package/express-rate-limit)
