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
│  │          Port 9120               │  │           Port 9121                   │ │
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
│  │  │ ├── devmgr-viewer       │     │  │                                       │ │
│  │  │ └── Clients             │     │  │                                       │ │
│  │  └─────────────────────────┘     │  │                                       │ │
│  │                                  │  │                                       │ │
│  └──────────────────────────────────┘  └──────────────────────────────────────┘ │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Applications Covered

| App | Directory | Frontend Port | Backend Port | Realm | Status |
|-----|-----------|---------------|--------------|-------|--------|
| OSPF Impact Planner | `OSPF-IMPACT-planner Private` | 9090 | 9091 | ospf-impact-planner | ✅ Integrated |
| NetViz Pro (LL-JSON-Part1) | `OSPF-LL-JSON-PART1` | 9040 | 9041 | ospf-ll-json-part1 | ✅ Integrated |
| OSPF Visualizer Pro (NN-JSON) | `OSPF-NN-JSON` | 9080 | 9081 | ospf-nn-json | ✅ Integrated |
| OSPF Tempo-X | `OSPF-TEMPO-X` | 9100 | 9101 | ospf-tempo-x | ✅ Integrated |
| OSPF Device Manager | `OSPF-LL-DEVICE_MANAGER` | 9050 | 9051 | ospf-device-manager | ✅ Integrated |

## Quick Start (Native Installation - No Docker)

### Prerequisites

- macOS (Homebrew), Ubuntu/Debian (apt), or RHEL/CentOS (yum)
- Node.js 18+ (for Node.js apps)
- Python 3.11+ (for Device Manager)
- Java 17+ (for Keycloak)

### 1. Install and Start Auth-Vault

```bash
# Clone repository
git clone https://github.com/zumanm1/auth-vault.git
cd auth-vault

# Install Keycloak and Vault natively
./auth-vault.sh install

# Start services
./auth-vault.sh start

# Check status
./auth-vault.sh status
```

### 2. Access Admin Consoles

- **Keycloak Admin**: http://localhost:9120/admin
  - Default: admin / admin
- **Vault UI**: http://localhost:9121/ui
  - Use root token from installation output

### 3. Verify Installation

```bash
# Check Keycloak health
curl http://localhost:9120/health/ready

# Check Vault status
curl http://localhost:9121/v1/sys/health
```

## Directory Structure

```
auth-vault/
├── auth-vault.sh              # Native installation & management script
├── docker-compose.yml         # Alternative Docker setup
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

## Management Commands

```bash
# Installation
./auth-vault.sh install         # Install Keycloak and Vault

# Service Management
./auth-vault.sh start           # Start both services
./auth-vault.sh stop            # Stop both services
./auth-vault.sh status          # Check service status
./auth-vault.sh restart         # Restart both services

# Individual Services
./auth-vault.sh start-keycloak  # Start only Keycloak
./auth-vault.sh start-vault     # Start only Vault
./auth-vault.sh stop-keycloak   # Stop only Keycloak
./auth-vault.sh stop-vault      # Stop only Vault

# Realm Management
./auth-vault.sh create-realms   # Create all 5 OSPF realms

# Uninstall
./auth-vault.sh uninstall       # Remove installations
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
- **KV-V2 Secret Engine**: Versioned secrets per app

## Default Credentials

⚠️ **CHANGE ALL PASSWORDS ON FIRST USE** ⚠️

### Keycloak Admin
- Username: `admin`
- Password: `admin` (change immediately!)

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

## Integration Details

Each application has been integrated with the following components:

### Backend Integration (per app)

| File | Purpose |
|------|---------|
| `keycloak-verifier.ts/js/py` | JWT token verification via JWKS (RS256) |
| `vault-client.ts/js/py` | AppRole authentication & secrets fetching |
| `auth-unified.ts/js/py` | Hybrid auth middleware (legacy + Keycloak) |

### API Endpoints (per app)

| Endpoint | Purpose |
|----------|---------|
| `GET /api/auth/config` | Returns auth mode (legacy/keycloak) and Keycloak config for frontend |
| `GET /api/health` | Includes `authVault` and `authMode` status |

### Environment Variables (per app)

```bash
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=<app-specific-realm>
KEYCLOAK_CLIENT_ID=<app-specific-client>

# Vault Configuration
VAULT_ADDR=http://localhost:9121
VAULT_ROLE_ID=<from-vault-init>
VAULT_SECRET_ID=<from-vault-init>
# OR use token auth:
VAULT_TOKEN=<vault-token>
```

## Authentication Modes

Each app supports dual authentication modes:

### Legacy Mode
- Uses existing JWT authentication
- Default when Keycloak is unavailable
- Sessions managed locally

### Keycloak Mode (Auth-Vault)
- SSO via Keycloak OIDC
- JWT tokens verified via JWKS
- Centralized session management
- Automatic mode detection on startup

## Production Deployment

### Security Hardening

1. **Change all default passwords** (Keycloak admin, realm users)
2. **Enable HTTPS** for all services
3. **Configure proper CORS origins**
4. **Restrict network access** with IP whitelists
5. **Enable audit logging** in both Keycloak and Vault
6. **Use proper Vault unsealing** (not dev mode)
7. **Backup encryption keys** securely

### HTTPS Configuration

For production, configure TLS certificates:

```bash
# Keycloak with HTTPS
export KC_HTTPS_CERTIFICATE_FILE=/path/to/tls.crt
export KC_HTTPS_CERTIFICATE_KEY_FILE=/path/to/tls.key

# Vault with HTTPS
export VAULT_ADDR=https://localhost:9121
```

## Troubleshooting

### Keycloak Won't Start

```bash
# Check logs
tail -f ~/.keycloak/logs/keycloak.log

# Common issues:
# - Port 9120 in use: lsof -i :9120
# - Java not installed: java -version
# - Memory issues: Increase heap size
```

### Vault Initialization Failed

```bash
# Check Vault status
./auth-vault.sh status

# Manual check
export VAULT_ADDR=http://localhost:9121
vault status
```

### App Can't Connect to Auth-Vault

```bash
# Verify services are running
./auth-vault.sh status

# Check Keycloak realm exists
curl http://localhost:9120/realms/<realm-name>

# Check Vault mount exists
curl -H "X-Vault-Token: <token>" http://localhost:9121/v1/sys/mounts
```

### Token Validation Fails

1. Verify JWKS endpoint accessible: `curl http://localhost:9120/realms/{realm}/protocol/openid-connect/certs`
2. Check token issuer matches configuration
3. Verify clock sync between services

## App-Specific Documentation

See the README-AUTH-VAULT.md in each app's directory:

- [OSPF Impact Planner](./apps/impact-planner/README-AUTH-VAULT.md)
- [NetViz Pro](./apps/ll-json-part1/README-AUTH-VAULT.md)
- [OSPF Visualizer Pro](./apps/nn-json/README-AUTH-VAULT.md)
- [OSPF Tempo-X](./apps/tempo-x/README-AUTH-VAULT.md)
- [OSPF Device Manager](./apps/device-manager/README-AUTH-VAULT.md)

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
