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

## Quick Start

### Option 1: Native Installation (Recommended)

Native installation provides the most reliable deployment without Docker dependencies.

#### Prerequisites
- macOS (Homebrew) or Linux (apt/yum)
- The script will auto-install: Java 17, wget, unzip, jq

#### 1. Clone and Install

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

#### 2. Verify Services

```bash
# Check Keycloak health
curl http://localhost:9120/health/ready

# Check Vault status
curl http://localhost:9121/v1/sys/health
```

#### 3. Access Admin Consoles

- **Keycloak Admin**: http://localhost:9120/admin (admin / admin)
- **Vault UI**: http://localhost:9121/ui (use root token)

### Option 2: Docker Deployment

For environments that prefer containerized deployment.

#### Prerequisites
- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Docker Compose v2+

#### 1. Configure and Start

```bash
# Clone repository
git clone https://github.com/zumanm1/auth-vault.git
cd auth-vault

# Copy environment file
cp .env.example .env

# Start with Docker Compose
docker compose up -d

# Check status
docker ps
```

#### 2. Verify Services

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

See the README in each app's directory under `apps/`:

- [OSPF Impact Planner](./apps/impact-planner/README.md)
- [NetViz Pro (LL-JSON-Part1)](./apps/ll-json-part1/README.md)
- [OSPF Visualizer Pro (NN-JSON)](./apps/nn-json/README.md)
- [OSPF Tempo-X](./apps/tempo-x/README.md)
- [OSPF Device Manager](./apps/device-manager/README.md)

---

## Running Applications

### Start All Applications

To run all 5 OSPF applications with Auth-Vault:

```bash
#!/bin/bash
# start-all-apps.sh - Start Auth-Vault and all OSPF applications

# Step 1: Start Auth-Vault
cd /Users/macbook/auth-vault
docker compose up -d

# Wait for services
echo "Waiting for Keycloak and Vault..."
sleep 30

# Verify services
curl -s http://localhost:9120/health/ready
curl -s http://localhost:9121/v1/sys/health

# Step 2: Start each application
echo "Starting OSPF Impact Planner..."
cd /Users/macbook/OSPF-IMPACT-planner\ Private && ./start.sh &

echo "Starting NetViz Pro..."
cd /Users/macbook/OSPF-LL-JSON-PART1/netviz-pro && ./start.sh &

echo "Starting OSPF Visualizer Pro..."
cd /Users/macbook/OSPF-NN-JSON && ./start.sh &

echo "Starting OSPF Tempo-X..."
cd /Users/macbook/OSPF-TEMPO-X && ./start.sh &

echo "Starting OSPF Device Manager..."
cd /Users/macbook/OSPF-LL-DEVICE_MANAGER && ./start.sh &

echo "All applications started!"
```

### Start Individual Applications

#### NetViz Pro (OSPF-LL-JSON-PART1)

| Property | Value |
|----------|-------|
| Directory | `/Users/macbook/OSPF-LL-JSON-PART1/netviz-pro` |
| Gateway Port | 9040 |
| Auth Server Port | 9041 |
| Realm | `ospf-ll-json-part1` |

```bash
# Option 1: One-command start (handles Auth-Vault automatically)
cd /Users/macbook/OSPF-LL-JSON-PART1/netviz-pro
./start-with-auth-vault.sh

# Option 2: Manual start (Auth-Vault must be running)
cd /Users/macbook/auth-vault && docker compose up -d
cd /Users/macbook/OSPF-LL-JSON-PART1/netviz-pro && ./start.sh

# Verify
curl http://localhost:9041/api/health
# Expected: {"authVault": "active", "authMode": "keycloak"}
```

**Access:** http://localhost:9040

#### OSPF Impact Planner

| Property | Value |
|----------|-------|
| Directory | `/Users/macbook/OSPF-IMPACT-planner Private` |
| Frontend Port | 9090 |
| Backend Port | 9091 |
| Realm | `ospf-impact-planner` |

```bash
# Start Auth-Vault first
cd /Users/macbook/auth-vault && docker compose up -d

# Start the application
cd "/Users/macbook/OSPF-IMPACT-planner Private" && ./start.sh

# Verify
curl http://localhost:9091/api/health
```

**Access:** http://localhost:9090

#### OSPF Visualizer Pro (NN-JSON)

| Property | Value |
|----------|-------|
| Directory | `/Users/macbook/OSPF-NN-JSON` |
| Frontend Port | 9080 |
| Backend Port | 9081 |
| Realm | `ospf-nn-json` |

```bash
# Start Auth-Vault first
cd /Users/macbook/auth-vault && docker compose up -d

# Start the application
cd /Users/macbook/OSPF-NN-JSON && ./start.sh

# Verify
curl http://localhost:9081/api/health
```

**Access:** http://localhost:9080

#### OSPF Tempo-X

| Property | Value |
|----------|-------|
| Directory | `/Users/macbook/OSPF-TEMPO-X` |
| Frontend Port | 9100 |
| Backend Port | 9101 |
| Realm | `ospf-tempo-x` |

```bash
# Start Auth-Vault first
cd /Users/macbook/auth-vault && docker compose up -d

# Start the application
cd /Users/macbook/OSPF-TEMPO-X && ./start.sh

# Verify
curl http://localhost:9101/api/health
```

**Access:** http://localhost:9100

#### OSPF Device Manager

| Property | Value |
|----------|-------|
| Directory | `/Users/macbook/OSPF-LL-DEVICE_MANAGER` |
| Frontend Port | 9050 |
| Backend Port | 9051 |
| Realm | `ospf-device-manager` |

```bash
# Start Auth-Vault first
cd /Users/macbook/auth-vault && docker compose up -d

# Start the application
cd /Users/macbook/OSPF-LL-DEVICE_MANAGER && ./start.sh

# Verify
curl http://localhost:9051/api/health
```

**Access:** http://localhost:9050

### Stop All Applications

```bash
#!/bin/bash
# stop-all-apps.sh - Stop all OSPF applications and Auth-Vault

# Stop applications (kill by port)
for port in 9040 9041 9042 9050 9051 9080 9081 9090 9091 9100 9101; do
    lsof -ti :$port | xargs kill -9 2>/dev/null || true
done

# Stop Auth-Vault
cd /Users/macbook/auth-vault
docker compose down

echo "All applications stopped!"
```

### Verify All Services

```bash
#!/bin/bash
# check-all-services.sh - Verify all services are running

echo "=== Auth-Vault Services ==="
echo "Keycloak: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:9120/health/ready)"
echo "Vault: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:9121/v1/sys/health)"

echo ""
echo "=== OSPF Applications ==="
echo "NetViz Pro (9041): $(curl -s http://localhost:9041/api/health 2>/dev/null | grep -o '"authMode":"[^"]*"' || echo 'Not running')"
echo "Impact Planner (9091): $(curl -s http://localhost:9091/api/health 2>/dev/null | grep -o '"authMode":"[^"]*"' || echo 'Not running')"
echo "Visualizer Pro (9081): $(curl -s http://localhost:9081/api/health 2>/dev/null | grep -o '"authMode":"[^"]*"' || echo 'Not running')"
echo "Tempo-X (9101): $(curl -s http://localhost:9101/api/health 2>/dev/null | grep -o '"authMode":"[^"]*"' || echo 'Not running')"
echo "Device Manager (9051): $(curl -s http://localhost:9051/api/health 2>/dev/null | grep -o '"authMode":"[^"]*"' || echo 'Not running')"
```

---

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
