# Auth-Vault Integration Guide: OSPF Device Manager

## Overview

This document describes how to integrate the OSPF Device Manager application (FastAPI + React) with the centralized Keycloak + Vault security infrastructure.

**Note**: This is the most security-critical application as it handles network device credentials (SSH/Telnet).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    OSPF Device Manager                           │
├─────────────────────────────────────────────────────────────────┤
│  Frontend (React)          │  Backend (FastAPI/Python)          │
│  Port: 9050                │  Port: 9051                        │
│                            │                                     │
│  ┌──────────────┐          │  ┌──────────────┐                  │
│  │ Keycloak JS  │──────────┼──│ python-      │                  │
│  │ Adapter      │          │  │ keycloak     │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ hvac (Vault) │                  │
│                            │  └──────────────┘                  │
│                            │         │                          │
│                            │  ┌──────┴──────┐                   │
│                            │  ▼             ▼                   │
│                            │ SQLite     Netmiko                 │
│                            │ (users)    (SSH/Telnet)            │
└─────────────────────────────────────────────────────────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
            ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
            │   Keycloak   │   │    Vault     │   │   Network    │
            │   Port 8080  │   │   Port 8200  │   │   Devices    │
            │              │   │              │   │              │
            │ Realm:       │   │ Mount:       │   │ (Routers/    │
            │ ospf-device- │   │ ospf-device- │   │  Switches)   │
            │ manager      │   │ manager/     │   │              │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## Critical Issues to Fix

### 1. Hardcoded Default Password (CRITICAL)

**Current State** (`backend/modules/auth.py`):
```python
_DEFAULT_USERNAME = "admin"
_DEFAULT_PASSWORD = "admin123"  # EXPOSED IN SOURCE CODE
```

**Fix**: Remove entirely and use Keycloak:
```python
# Delete these lines - authentication handled by Keycloak
# No fallback credentials should exist
```

### 2. Weak PIN Security (CRITICAL)

**Current State**: 5-digit admin reset PIN with no rate limiting.

**Fix**: Remove PIN-based reset, use Keycloak password reset:
```python
# Remove /api/auth/reset-password-with-pin endpoint
# Use Keycloak's built-in password reset flow
```

### 3. Device Credentials in Plaintext (HIGH)

**Current State**: Device passwords encrypted with Fernet, but key stored locally.

**Fix with Vault Transit**:
```python
import hvac

def encrypt_device_password(plaintext: str) -> str:
    """Encrypt device password using Vault Transit."""
    client = get_vault_client()
    response = client.secrets.transit.encrypt_data(
        name='device-credentials',
        mount_point='ospf-device-manager-transit',
        plaintext=base64.b64encode(plaintext.encode()).decode()
    )
    return response['data']['ciphertext']

def decrypt_device_password(ciphertext: str) -> str:
    """Decrypt device password using Vault Transit."""
    client = get_vault_client()
    response = client.secrets.transit.decrypt_data(
        name='device-credentials',
        mount_point='ospf-device-manager-transit',
        ciphertext=ciphertext
    )
    return base64.b64decode(response['data']['plaintext']).decode()
```

### 4. In-Memory Session Storage (HIGH)

**Current State**: Sessions stored in memory, lost on restart.

**Fix**: Move to database-backed sessions or use Keycloak tokens.

### 5. Jumphost Credentials in Plaintext JSON (HIGH)

**Current State**: `backend/jumphost_config.json` contains plaintext credentials.

**Fix**: Store in Vault:
```python
async def get_jumphost_config():
    """Fetch jumphost configuration from Vault."""
    client = get_vault_client()
    secret = client.secrets.kv.v2.read_secret_version(
        path='jumphost',
        mount_point='ospf-device-manager'
    )
    return secret['data']['data']
```

## Keycloak Configuration

### Realm Details
- **Realm Name**: `ospf-device-manager`
- **Keycloak URL**: `http://localhost:8080`

### Clients

| Client ID | Type | Purpose |
|-----------|------|---------|
| `device-manager-frontend` | Public | React SPA (PKCE) |
| `device-manager-api` | Confidential | FastAPI backend |
| `vault-oidc` | Confidential | Vault integration |

### Roles (3-tier RBAC)

| Role | Description | Permissions |
|------|-------------|-------------|
| `admin` | Full system access | All operations |
| `operator` | Device operations | devices:*, automation:*, ssh:* |
| `viewer` | Read-only | devices:read, automation:read |

### Role Permissions Mapping

```python
ROLE_PERMISSIONS = {
    'admin': [
        'devices:read', 'devices:write', 'devices:delete',
        'automation:execute', 'automation:manage',
        'ssh:connect', 'ssh:execute',
        'jumphost:manage',
        'settings:manage',
        'users:manage',
        'database:manage'
    ],
    'operator': [
        'devices:read', 'devices:write', 'devices:delete',
        'automation:execute', 'automation:manage',
        'ssh:connect', 'ssh:execute'
    ],
    'viewer': [
        'devices:read',
        'automation:read'
    ]
}
```

### Default Users

| Username | Password | Role |
|----------|----------|------|
| `devmgr-admin` | `ChangeMe!Admin2025` | admin |
| `devmgr-operator` | `ChangeMe!Operator2025` | operator |
| `devmgr-viewer` | `ChangeMe!Viewer2025` | viewer |

## Vault Configuration

### Secret Paths

| Path | Description |
|------|-------------|
| `ospf-device-manager/config` | App configuration, session secrets |
| `ospf-device-manager/database` | Database path, encryption key |
| `ospf-device-manager/router-defaults` | Default router credentials |
| `ospf-device-manager/jumphost` | Jumphost SSH configuration |
| `ospf-device-manager/approle` | AppRole credentials |

### Transit Keys

| Key | Purpose |
|-----|---------|
| `device-credentials` | Encrypt device SSH/Telnet passwords |
| `jumphost-credentials` | Encrypt jumphost passwords |
| `jwt-signing` | Sign authentication tokens |

## Integration Steps

### 1. Install Python Dependencies

Add to `requirements.txt`:
```
hvac==2.1.0
python-keycloak==3.7.0
pyjwt[crypto]==2.8.0
```

### 2. Vault Client Module

Create `backend/modules/vault_client.py`:

```python
import hvac
import os
import base64
from functools import lru_cache

_client = None

def get_vault_client() -> hvac.Client:
    """Get authenticated Vault client."""
    global _client
    if _client is None or not _client.is_authenticated():
        _client = hvac.Client(url=os.environ.get('VAULT_ADDR', 'http://localhost:8200'))

        # AppRole authentication
        role_id = os.environ.get('VAULT_ROLE_ID')
        secret_id = os.environ.get('VAULT_SECRET_ID')

        if not role_id or not secret_id:
            raise ValueError("Vault AppRole credentials not configured")

        _client.auth.approle.login(role_id=role_id, secret_id=secret_id)

    return _client

def get_secret(path: str) -> dict:
    """Get secret from Vault KV store."""
    client = get_vault_client()
    secret = client.secrets.kv.v2.read_secret_version(
        path=path,
        mount_point='ospf-device-manager'
    )
    return secret['data']['data']

def encrypt_data(plaintext: str, key_name: str = 'device-credentials') -> str:
    """Encrypt data using Vault Transit."""
    client = get_vault_client()
    response = client.secrets.transit.encrypt_data(
        name=key_name,
        mount_point='ospf-device-manager-transit',
        plaintext=base64.b64encode(plaintext.encode()).decode()
    )
    return response['data']['ciphertext']

def decrypt_data(ciphertext: str, key_name: str = 'device-credentials') -> str:
    """Decrypt data using Vault Transit."""
    client = get_vault_client()
    response = client.secrets.transit.decrypt_data(
        name=key_name,
        mount_point='ospf-device-manager-transit',
        ciphertext=ciphertext
    )
    return base64.b64decode(response['data']['plaintext']).decode()
```

### 3. Keycloak Authentication Middleware

Create `backend/modules/keycloak_auth.py`:

```python
from keycloak import KeycloakOpenID
from fastapi import HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import os

security = HTTPBearer()

keycloak_openid = KeycloakOpenID(
    server_url=os.environ.get('KEYCLOAK_URL', 'http://localhost:8080/'),
    client_id=os.environ.get('KEYCLOAK_CLIENT_ID', 'device-manager-api'),
    realm_name=os.environ.get('KEYCLOAK_REALM', 'ospf-device-manager'),
    client_secret_key=os.environ.get('KEYCLOAK_CLIENT_SECRET'),
    verify=True
)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)):
    """Validate JWT token and extract user info."""
    token = credentials.credentials

    try:
        # Decode and validate token
        token_info = keycloak_openid.decode_token(
            token,
            key=keycloak_openid.public_key(),
            algorithms=['RS256'],
            options={
                "verify_signature": True,
                "verify_aud": True,
                "verify_exp": True
            }
        )

        return {
            'user_id': token_info.get('sub'),
            'username': token_info.get('preferred_username'),
            'email': token_info.get('email'),
            'roles': token_info.get('realm_access', {}).get('roles', []),
            'token_info': token_info
        }

    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")

def require_role(required_role: str):
    """Dependency to check if user has required role."""
    async def role_checker(user = Depends(get_current_user)):
        if required_role not in user['roles']:
            raise HTTPException(
                status_code=403,
                detail=f"Role '{required_role}' required"
            )
        return user
    return role_checker

def require_permission(permission: str):
    """Dependency to check if user has required permission."""
    async def permission_checker(user = Depends(get_current_user)):
        user_permissions = []
        for role in user['roles']:
            user_permissions.extend(ROLE_PERMISSIONS.get(role, []))

        if permission not in user_permissions:
            raise HTTPException(
                status_code=403,
                detail=f"Permission '{permission}' required"
            )
        return user
    return permission_checker

# Permission mapping
ROLE_PERMISSIONS = {
    'admin': [
        'devices:read', 'devices:write', 'devices:delete',
        'automation:execute', 'automation:manage',
        'ssh:connect', 'ssh:execute',
        'jumphost:manage', 'settings:manage',
        'users:manage', 'database:manage'
    ],
    'operator': [
        'devices:read', 'devices:write', 'devices:delete',
        'automation:execute', 'automation:manage',
        'ssh:connect', 'ssh:execute'
    ],
    'viewer': [
        'devices:read', 'automation:read'
    ]
}
```

### 4. Update Device Encryption

Replace `backend/modules/device_encryption.py`:

```python
from .vault_client import encrypt_data, decrypt_data

def encrypt_password(password: str) -> str:
    """Encrypt device password using Vault Transit."""
    if not password:
        return password
    return encrypt_data(password, 'device-credentials')

def decrypt_password(encrypted: str) -> str:
    """Decrypt device password using Vault Transit."""
    if not encrypted or not encrypted.startswith('vault:'):
        return encrypted
    return decrypt_data(encrypted, 'device-credentials')

def is_encrypted(password: str) -> bool:
    """Check if password is Vault-encrypted."""
    return password and password.startswith('vault:v1:')

def migrate_legacy_encryption(password: str, legacy_key: bytes) -> str:
    """Migrate from old Fernet encryption to Vault Transit."""
    from cryptography.fernet import Fernet

    # Decrypt with old key
    fernet = Fernet(legacy_key)
    plaintext = fernet.decrypt(password.encode()).decode()

    # Re-encrypt with Vault
    return encrypt_password(plaintext)
```

### 5. Update Jumphost Configuration

Replace `backend/modules/connection_manager.py` jumphost handling:

```python
from .vault_client import get_secret, encrypt_data, decrypt_data

async def get_jumphost_config():
    """Get jumphost configuration from Vault."""
    try:
        config = get_secret('jumphost')
        if config.get('password'):
            config['password'] = decrypt_data(config['password'], 'jumphost-credentials')
        return config
    except Exception:
        return {'enabled': False}

async def save_jumphost_config(config: dict):
    """Save jumphost configuration to Vault."""
    from .vault_client import get_vault_client

    if config.get('password'):
        config['password'] = encrypt_data(config['password'], 'jumphost-credentials')

    client = get_vault_client()
    client.secrets.kv.v2.create_or_update_secret(
        path='jumphost',
        mount_point='ospf-device-manager',
        secret=config
    )
```

### 6. Update Server Startup

Modify `backend/server.py`:

```python
from fastapi import FastAPI, Depends
from modules.keycloak_auth import get_current_user, require_role, require_permission
from modules.vault_client import get_vault_client, get_secret
import os

app = FastAPI(title="OSPF Device Manager API")

@app.on_event("startup")
async def startup():
    """Initialize Vault and verify connectivity."""
    try:
        client = get_vault_client()
        print("✓ Vault connected and authenticated")

        # Load configuration from Vault
        config = get_secret('config')
        os.environ['SESSION_TIMEOUT'] = str(config.get('session_timeout', 3600))
        print("✓ Configuration loaded from Vault")

    except Exception as e:
        print(f"✗ Vault initialization failed: {e}")
        raise

# Protected endpoints
@app.get("/api/devices")
async def list_devices(user = Depends(require_permission('devices:read'))):
    """List all devices."""
    # ... implementation

@app.post("/api/automation/connect")
async def connect_device(
    device_id: str,
    user = Depends(require_permission('ssh:connect'))
):
    """Connect to device via SSH."""
    # ... implementation

@app.post("/api/admin/database/{name}/reset")
async def reset_database(
    name: str,
    user = Depends(require_role('admin'))
):
    """Reset database (admin only)."""
    # ... implementation
```

### 7. Frontend Keycloak Integration

Update React app:

```typescript
// src/lib/keycloak.ts
import Keycloak from 'keycloak-js';

const keycloak = new Keycloak({
  url: 'http://localhost:8080',
  realm: 'ospf-device-manager',
  clientId: 'device-manager-frontend',
});

export const initKeycloak = async (): Promise<boolean> => {
  return keycloak.init({
    onLoad: 'login-required',
    pkceMethod: 'S256',
  });
};

export const getToken = (): string | undefined => keycloak.token;

export const hasRole = (role: string): boolean => {
  return keycloak.hasRealmRole(role);
};

export const hasPermission = (permission: string): boolean => {
  const roles = keycloak.realmAccess?.roles || [];
  const rolePermissions: Record<string, string[]> = {
    admin: ['devices:read', 'devices:write', 'devices:delete', 'ssh:connect', 'ssh:execute', 'automation:execute', 'automation:manage', 'settings:manage', 'users:manage'],
    operator: ['devices:read', 'devices:write', 'devices:delete', 'ssh:connect', 'ssh:execute', 'automation:execute', 'automation:manage'],
    viewer: ['devices:read', 'automation:read'],
  };

  for (const role of roles) {
    if (rolePermissions[role]?.includes(permission)) {
      return true;
    }
  }
  return false;
};

export const logout = (): void => {
  keycloak.logout({ redirectUri: window.location.origin });
};

export default keycloak;
```

### 8. Environment Configuration

```env
# .env.production

# Keycloak
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=ospf-device-manager
KEYCLOAK_CLIENT_ID=device-manager-api
KEYCLOAK_CLIENT_SECRET=FROM_KEYCLOAK

# Vault
VAULT_ADDR=http://localhost:8200
VAULT_ROLE_ID=FROM_VAULT_INIT
VAULT_SECRET_ID=FROM_VAULT_INIT

# Remove these - now from Vault:
# APP_ADMIN_PASSWORD
# APP_SECRET_KEY
# ROUTER_USERNAME
# ROUTER_PASSWORD
# JUMPHOST_PASSWORD
```

## Security Improvements

| Current Issue | With Auth-Vault |
|---------------|-----------------|
| Hardcoded admin123 | Keycloak authentication |
| Weak 5-digit PIN | Keycloak password reset |
| Local Fernet key | Vault Transit encryption |
| In-memory sessions | Keycloak token management |
| Plaintext jumphost.json | Vault encrypted storage |
| SHA-256 user passwords | Keycloak PBKDF2/Argon2 |
| No rate limiting | Keycloak + FastAPI limiter |

## Migration Checklist

- [ ] Deploy auth-vault infrastructure
- [ ] Configure Keycloak realm with 3 roles
- [ ] Populate Vault with initial secrets
- [ ] Install Python dependencies (hvac, python-keycloak)
- [ ] Replace auth.py with Keycloak integration
- [ ] Migrate device passwords to Vault Transit
- [ ] Migrate jumphost config to Vault
- [ ] Update frontend to use Keycloak JS
- [ ] Remove all hardcoded credentials
- [ ] Remove PIN-based password reset
- [ ] Enable audit logging
- [ ] Test all SSH/automation workflows
- [ ] Test role-based access for all 3 roles

## Troubleshooting

### Vault Transit Encryption Fails
1. Verify transit key exists: `vault list ospf-device-manager-transit/keys`
2. Check AppRole has transit permissions
3. Verify key type matches operation

### Device Connection Fails After Migration
1. Check password decryption works
2. Verify Vault is accessible from backend
3. Test with: `curl -H "X-Vault-Token: xxx" http://localhost:8200/v1/ospf-device-manager-transit/encrypt/device-credentials`

### Keycloak Token Validation Fails
1. Verify realm public key
2. Check token issuer matches
3. Verify client configuration

## References

- [python-keycloak](https://python-keycloak.readthedocs.io/)
- [hvac (Vault Python client)](https://hvac.readthedocs.io/)
- [FastAPI Security](https://fastapi.tiangolo.com/tutorial/security/)
- [Vault Transit](https://developer.hashicorp.com/vault/docs/secrets/transit)
