# Auth-Vault Integration: OSPF Device Manager

## Status: ✅ INTEGRATED

This application has been fully integrated with the Auth-Vault infrastructure (Keycloak + HashiCorp Vault).

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
│  │ Keycloak     │──────────┼──│ keycloak_    │                  │
│  │ (optional)   │          │  │ verifier.py  │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│  ┌──────────────┐          │         ▼                          │
│  │ Legacy Auth  │──────────┼──│ auth_unified │                  │
│  │ (fallback)   │          │  │     .py      │                  │
│  └──────────────┘          │  └──────────────┘                  │
│                            │         │                          │
│                            │         ▼                          │
│                            │  ┌──────────────┐                  │
│                            │  │ vault_client │                  │
│                            │  │     .py      │                  │
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
            │   Port 9120  │   │   Port 9121  │   │   Devices    │
            │              │   │              │   │              │
            │ Realm:       │   │ Mount:       │   │ (Routers/    │
            │ ospf-device- │   │ ospf-device- │   │  Switches)   │
            │ manager      │   │ manager/     │   │              │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## Integrated Components

### Backend Files Added

| File | Purpose |
|------|---------|
| `backend/lib/__init__.py` | Package initialization |
| `backend/lib/keycloak_verifier.py` | JWT token verification via JWKS (RS256) using PyJWT |
| `backend/lib/vault_client.py` | AppRole authentication & secrets fetching |
| `backend/lib/auth_unified.py` | Hybrid auth middleware (legacy + Keycloak) |

### API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/auth/config` | GET | Returns auth mode and Keycloak config for frontend |
| `/api/health` | GET | Includes `auth_vault` status |

## Configuration

### Environment Variables

```bash
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-device-manager
KEYCLOAK_CLIENT_ID=device-manager-api

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>
# OR use token auth:
VAULT_TOKEN=<vault-token>
```

### Python Dependencies

The following packages are required (add to requirements.txt if not present):

```
PyJWT>=2.8.0
```

### Keycloak Realm Details

- **Realm Name**: `ospf-device-manager`
- **Frontend Client**: `device-manager-frontend` (Public, PKCE)
- **Backend Client**: `device-manager-api` (Confidential)

### Default Users (3-tier RBAC)

| Username | Password | Role |
|----------|----------|------|
| `devmgr-admin` | `ChangeMe!Admin2025` | admin |
| `devmgr-operator` | `ChangeMe!Operator2025` | operator |
| `devmgr-viewer` | `ChangeMe!Viewer2025` | viewer |

### Vault Secret Paths

| Path | Description |
|------|-------------|
| `ospf-device-manager/config` | App config, session secrets |
| `ospf-device-manager/database` | Database path, encryption key |
| `ospf-device-manager/router-defaults` | Default router credentials |
| `ospf-device-manager/jumphost` | Jumphost SSH configuration |

## Authentication Modes

The application supports dual authentication:

### 1. Keycloak Mode (Auth-Vault)
- Activated when Keycloak is available at startup
- SSO via OIDC with PKCE
- JWT verified via JWKS (RS256) using PyJWT
- 3-tier role mapping (admin, operator, viewer)

### 2. Legacy Mode (Fallback)
- Activated when Keycloak is unavailable
- Uses existing JWT authentication
- Local SQLite user database

## How It Works

### Server Startup (server.py)

```python
from lib.auth_unified import (
    init_auth_vault, get_auth_mode, is_auth_vault_active, get_auth_config
)

@app.on_event("startup")
async def startup_event():
    # ... existing startup code ...

    # Initialize Auth-Vault
    auth_vault_active = await init_auth_vault()
    if auth_vault_active:
        logger.info(f"Auth-Vault: Active (mode: {get_auth_mode()})")
    else:
        logger.info("Auth-Vault: Inactive (using legacy mode)")
```

### Auth Config Endpoint

```python
@app.get("/api/auth/config")
async def get_auth_configuration():
    return get_auth_config()
```

### Keycloak Token Verification

```python
# backend/lib/keycloak_verifier.py
async def verify_token(self, token: str) -> VerifiedUser:
    # Get signing key from JWKS
    jwks_client = self._get_jwks_client()
    signing_key = jwks_client.get_signing_key_from_jwt(token)

    # Verify and decode token
    payload = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        issuer=self._get_issuer()
    )

    # Extract roles
    realm_roles = payload.get('realm_access', {}).get('roles', [])
    client_roles = payload.get('resource_access', {}).get(self.client_id, {}).get('roles', [])

    # Determine app role
    if 'admin' in realm_roles or 'admin' in client_roles:
        app_role = 'admin'
    elif 'operator' in realm_roles or 'operator' in client_roles:
        app_role = 'operator'
    else:
        app_role = 'viewer'

    return VerifiedUser(...)
```

## Usage

### Starting with Auth-Vault

```bash
# 1. Ensure auth-vault is running
cd /path/to/auth-vault
./auth-vault.sh start

# 2. Start the application
cd /path/to/OSPF-LL-DEVICE_MANAGER
./start.sh
# OR
python backend/server.py
```

### Checking Auth Status

```bash
# Check health endpoint
curl http://localhost:9051/api/health

# Response includes auth status

# Check auth config (for frontend)
curl http://localhost:9051/api/auth/config

# Response:
{
  "auth_mode": "keycloak",  # or "legacy"
  "keycloak": {
    "url": "http://localhost:9120",
    "realm": "ospf-device-manager",
    "client_id": "device-manager-frontend"
  }
}
```

## Role-Based Access Control

### Role Permissions

| Role | Permissions |
|------|-------------|
| admin | All operations, user management, database management |
| operator | Device operations, SSH/Telnet, automation |
| viewer | Read-only access to devices and automation |

## Security Features

- **JWKS Token Verification**: RS256 with PyJWKClient caching
- **3-Tier RBAC**: Admin, Operator, Viewer roles
- **Graceful Degradation**: Falls back to legacy auth if Keycloak unavailable
- **Secrets from Vault**: JWT secret and device credentials from Vault when available
- **Device Credential Encryption**: Vault Transit for SSH/Telnet passwords

## Troubleshooting

### Keycloak Mode Not Activating

```bash
# Check Keycloak is running
curl http://localhost:9120/health/ready

# Check realm exists
curl http://localhost:9120/realms/ospf-device-manager

# Check PyJWT is installed
pip show PyJWT
```

### Token Validation Fails

1. Verify JWKS endpoint: `curl http://localhost:9120/realms/ospf-device-manager/protocol/openid-connect/certs`
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
- Existing SQLite users continue to work
- Keycloak SSO available when configured
- Device credential encryption unchanged
- No breaking changes to API
