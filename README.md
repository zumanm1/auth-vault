# Auth-Vault: Centralized Security Infrastructure for OSPF Application Suite

## Overview

Auth-Vault provides centralized authentication (Keycloak) and secrets management (HashiCorp Vault) for the OSPF application suite. This architecture implements **logical isolation** with a single Keycloak cluster (5 realms) and a single Vault cluster (5 mount paths).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Auth-Vault Infrastructure                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────────────────────┐  ┌──────────────────────────────────────┐ │
│  │          KEYCLOAK                │  │            VAULT                      │ │
│  │          Port 8080               │  │           Port 8200                   │ │
│  │                                  │  │                                       │ │
│  │  ┌─────────────────────────┐     │  │  ┌─────────────────────────────────┐ │ │
│  │  │ ospf-impact-planner     │     │  │  │ ospf-impact-planner/            │ │ │
│  │  │ (Realm)                 │     │  │  │ ├── config                      │ │ │
│  │  │ ├── impact-admin        │     │  │  │ ├── database                    │ │ │
│  │  │ ├── impact-user         │     │  │  │ └── approle                     │ │ │
│  │  │ └── Clients             │     │  │  └─────────────────────────────────┘ │ │
│  │  └─────────────────────────┘     │  │                                       │ │
│  │                                  │  │  ┌─────────────────────────────────┐ │ │
│  │  ┌─────────────────────────┐     │  │  │ ospf-ll-json-part1/             │ │ │
│  │  │ ospf-ll-json-part1      │     │  │  │ ├── config                      │ │ │
│  │  │ (Realm)                 │     │  │  │ ├── database                    │ │ │
│  │  │ ├── netviz-admin        │     │  │  │ └── approle                     │ │ │
│  │  │ ├── netviz-user         │     │  │  └─────────────────────────────────┘ │ │
│  │  │ └── Clients             │     │  │                                       │ │
│  │  └─────────────────────────┘     │  │  ┌─────────────────────────────────┐ │ │
│  │                                  │  │  │ ospf-nn-json/                   │ │ │
│  │  ┌─────────────────────────┐     │  │  │ ├── config                      │ │ │
│  │  │ ospf-nn-json            │     │  │  │ ├── database                    │ │ │
│  │  │ (Realm)                 │     │  │  │ └── approle                     │ │ │
│  │  │ ├── visualizer-admin    │     │  │  └─────────────────────────────────┘ │ │
│  │  │ ├── visualizer-user     │     │  │                                       │ │
│  │  │ └── Clients             │     │  │  ┌─────────────────────────────────┐ │ │
│  │  └─────────────────────────┘     │  │  │ ospf-tempo-x/                   │ │ │
│  │                                  │  │  │ ├── config                      │ │ │
│  │  ┌─────────────────────────┐     │  │  │ ├── database                    │ │ │
│  │  │ ospf-tempo-x            │     │  │  │ └── approle                     │ │ │
│  │  │ (Realm)                 │     │  │  └─────────────────────────────────┘ │ │
│  │  │ ├── tempo-admin         │     │  │                                       │ │
│  │  │ ├── tempo-user          │     │  │  ┌─────────────────────────────────┐ │ │
│  │  │ └── Clients             │     │  │  │ ospf-device-manager/            │ │ │
│  │  └─────────────────────────┘     │  │  │ ├── config                      │ │ │
│  │                                  │  │  │ ├── database                    │ │ │
│  │  ┌─────────────────────────┐     │  │  │ ├── router-defaults             │ │ │
│  │  │ ospf-device-manager     │     │  │  │ ├── jumphost                    │ │ │
│  │  │ (Realm)                 │     │  │  │ └── approle                     │ │ │
│  │  │ ├── devmgr-admin        │     │  │  └─────────────────────────────────┘ │ │
│  │  │ ├── devmgr-operator     │     │  │                                       │ │
│  │  │ ├── devmgr-viewer       │     │  │  ┌─────────────────────────────────┐ │ │
│  │  │ └── Clients             │     │  │  │ ospf-shared/                    │ │ │
│  │  └─────────────────────────┘     │  │  │ └── keycloak (client secrets)   │ │ │
│  │                                  │  │  └─────────────────────────────────┘ │ │
│  └──────────────────────────────────┘  └──────────────────────────────────────┘ │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Applications Covered

| App | Directory | Frontend Port | Backend Port | Realm |
|-----|-----------|---------------|--------------|-------|
| OSPF Impact Planner | `/Users/macbook/OSPF-IMPACT-planner` | 9090 | 9091 | ospf-impact-planner |
| NetViz Pro (LL-JSON-Part1) | `/Users/macbook/OSPF-LL-JSON-PART1` | 9040 | 9041 | ospf-ll-json-part1 |
| OSPF Visualizer Pro (NN-JSON) | `/Users/macbook/OSPF-NN-JSON` | 9080 | 9081 | ospf-nn-json |
| OSPF Tempo-X | `/Users/macbook/OSPF-TEMPO-X` | 9100 | 9101 | ospf-tempo-x |
| OSPF Device Manager | `/Users/macbook/OSPF-LL-DEVICE_MANAGER` | 9050 | 9051 | ospf-device-manager |

## Quick Start

### Prerequisites

- Docker & Docker Compose
- Node.js 18+ (for apps)
- Python 3.11+ (for Device Manager)

### 1. Start Auth-Vault Infrastructure

```bash
# Clone repository
git clone https://github.com/yourusername/auth-vault.git
cd auth-vault

# Copy and configure environment
cp .env.example .env
# Edit .env with secure passwords

# Start services
docker-compose up -d

# Wait for services to be ready
docker-compose logs -f keycloak  # Wait for "Running the server in development mode"
```

### 2. Access Admin Consoles

- **Keycloak Admin**: http://localhost:8080/admin
  - Default: admin / admin_change_me_in_production
- **Vault UI**: http://localhost:8200/ui
  - Default Token: vault-root-token-change-me

### 3. Verify Vault Initialization

```bash
# Check Vault status
docker exec vault vault status

# List secret mounts
docker exec vault vault secrets list
```

## Directory Structure

```
auth-vault/
├── docker-compose.yml          # Main infrastructure
├── .env.example               # Environment template
├── .env                       # Local configuration (gitignored)
├── keycloak/
│   ├── realms/                # Realm configurations (auto-imported)
│   │   ├── realm-ospf-impact-planner.json
│   │   ├── realm-ospf-ll-json-part1.json
│   │   ├── realm-ospf-nn-json.json
│   │   ├── realm-ospf-tempo-x.json
│   │   └── realm-ospf-device-manager.json
│   └── themes/                # Custom login themes (optional)
├── vault/
│   ├── config/                # Vault configuration
│   ├── policies/              # Vault policies
│   └── init-scripts/
│       └── init-vault.sh      # Initialization script
├── apps/                      # Per-app integration guides
│   ├── impact-planner/
│   │   └── README-AUTH-VAULT.md
│   ├── ll-json-part1/
│   │   └── README-AUTH-VAULT.md
│   ├── nn-json/
│   │   └── README-AUTH-VAULT.md
│   ├── tempo-x/
│   │   └── README-AUTH-VAULT.md
│   └── device-manager/
│       └── README-AUTH-VAULT.md
└── docs/
    ├── SECURITY-AUDIT.md      # Initial security findings
    └── MIGRATION-GUIDE.md     # Migration steps
```

## Security Features

### Keycloak Features

- **Brute Force Protection**: 5 failures = 15 min lockout
- **Password Policy**: 12+ chars, uppercase, lowercase, digit, special char
- **Session Management**: 30 min idle timeout, 10 hour max session
- **PKCE**: Required for public clients (SPAs)
- **Audit Logging**: All login events logged

### Vault Features

- **AppRole Authentication**: Service accounts per app
- **Transit Encryption**: AES-256-GCM for sensitive data
- **Strict Policies**: Apps can only access their own secrets
- **Audit Logging**: All secret access logged
- **Dynamic Secrets**: Support for database credentials (future)

## Default Credentials

⚠️ **CHANGE ALL PASSWORDS ON FIRST USE** ⚠️

### Keycloak Admin
- Username: `admin`
- Password: `admin_change_me_in_production`

### Per-Realm Default Users

| Realm | Username | Password | Role |
|-------|----------|----------|------|
| ospf-impact-planner | impact-admin | ChangeMe!Admin2025 | admin |
| ospf-impact-planner | impact-user | ChangeMe!User2025 | user |
| ospf-ll-json-part1 | netviz-admin | ChangeMe!Admin2025 | admin |
| ospf-ll-json-part1 | netviz-user | ChangeMe!User2025 | user |
| ospf-nn-json | visualizer-admin | ChangeMe!Admin2025 | admin |
| ospf-nn-json | visualizer-user | ChangeMe!User2025 | user |
| ospf-tempo-x | tempo-admin | ChangeMe!Admin2025 | admin |
| ospf-tempo-x | tempo-user | ChangeMe!User2025 | user |
| ospf-device-manager | devmgr-admin | ChangeMe!Admin2025 | admin |
| ospf-device-manager | devmgr-operator | ChangeMe!Operator2025 | operator |
| ospf-device-manager | devmgr-viewer | ChangeMe!Viewer2025 | viewer |

## Integrating an Application

### Step 1: Get AppRole Credentials

```bash
# From Vault, get credentials for your app
export VAULT_ADDR="http://localhost:8200"
export VAULT_TOKEN="your-root-token"

# Get Role ID
vault read auth/approle/role/ospf-impact-planner/role-id

# Generate Secret ID
vault write -f auth/approle/role/ospf-impact-planner/secret-id
```

### Step 2: Install SDK

**Node.js:**
```bash
npm install keycloak-js node-vault
```

**Python:**
```bash
pip install python-keycloak hvac
```

### Step 3: Follow App-Specific Guide

See the README-AUTH-VAULT.md in each app's directory:

- [OSPF Impact Planner](./apps/impact-planner/README-AUTH-VAULT.md)
- [NetViz Pro](./apps/ll-json-part1/README-AUTH-VAULT.md)
- [OSPF Visualizer Pro](./apps/nn-json/README-AUTH-VAULT.md)
- [OSPF Tempo-X](./apps/tempo-x/README-AUTH-VAULT.md)
- [OSPF Device Manager](./apps/device-manager/README-AUTH-VAULT.md)

## Production Deployment

### Security Hardening

1. **Change all default passwords** (Keycloak admin, Vault root token)
2. **Enable HTTPS** for all services
3. **Configure proper CORS origins**
4. **Restrict network access** with IP whitelists
5. **Enable audit logging** in both Keycloak and Vault
6. **Use proper Vault unsealing** (not dev mode)
7. **Backup encryption keys** securely

### Environment Variables

```bash
# Production .env
KC_ADMIN_PASSWORD=<strong-random-password>
KC_DB_PASSWORD=<strong-random-password>
VAULT_DEV_TOKEN=<DO-NOT-USE-IN-PRODUCTION>

# For production Vault, use:
# - Shamir key unsealing
# - Auto-unseal with cloud KMS
# - HA cluster with Raft storage
```

### HTTPS Configuration

```yaml
# docker-compose.override.yml for production
services:
  keycloak:
    environment:
      KC_HOSTNAME_STRICT_HTTPS: true
      KC_HTTPS_CERTIFICATE_FILE: /etc/x509/https/tls.crt
      KC_HTTPS_CERTIFICATE_KEY_FILE: /etc/x509/https/tls.key
    volumes:
      - /path/to/certs:/etc/x509/https:ro
```

## Troubleshooting

### Keycloak Won't Start

```bash
# Check logs
docker-compose logs keycloak

# Common issues:
# - Database not ready: Wait for keycloak-db health check
# - Port conflict: Change KC_PORT in .env
# - Memory: Increase Docker memory allocation
```

### Vault Initialization Failed

```bash
# Check init script logs
docker-compose logs vault-init

# Manual initialization
docker exec -it vault sh
vault secrets list
vault auth list
```

### CORS Errors

1. Check Keycloak client's "Web Origins" configuration
2. Verify backend CORS configuration
3. Check browser developer tools for specific error

### Token Validation Fails

1. Verify JWKS endpoint accessible: `curl http://localhost:8080/realms/{realm}/protocol/openid-connect/certs`
2. Check token issuer matches configuration
3. Verify clock sync between services

## Contributing

1. Fork the repository
2. Create feature branch
3. Follow security best practices
4. Submit pull request

## License

MIT

## Support

For issues and questions:
- Open an issue on GitHub
- Check the troubleshooting section
- Review app-specific README files
