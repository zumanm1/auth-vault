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

### Option 1: Docker Deployment (Recommended)

Docker provides the easiest and most reliable deployment method.

#### Prerequisites
- Docker Desktop (macOS/Windows) or Docker Engine (Linux)
- Docker Compose v2+

#### 1. Configure Environment

```bash
# Clone repository
git clone https://github.com/zumanm1/auth-vault.git
cd auth-vault

# Copy and edit environment file
cp .env.example .env

# Edit .env with your settings:
# - KC_PORT=9120 (Keycloak port)
# - VAULT_PORT=9121 (Vault port)
# - KC_ADMIN_PASSWORD=<secure-password>
# - VAULT_DEV_TOKEN=<secure-token>
```

#### 2. Start Services with Docker

```bash
# Start Docker Desktop first (macOS)
open -a Docker

# Start all services
docker compose up -d

# Check status
docker ps

# View logs
docker compose logs -f
```

#### 3. Verify Services

```bash
# Check Keycloak health
curl http://localhost:9120/health/ready

# Check Vault status
curl http://localhost:9121/v1/sys/health
```

### Option 2: Native Installation

For environments without Docker.

#### Prerequisites

- macOS (Homebrew), Ubuntu/Debian (apt), or RHEL/CentOS (yum)
- Node.js 18+ (for Node.js apps)
- Python 3.11+ (for Device Manager)
- Java 17+ (for Keycloak)

#### 1. Install and Start Auth-Vault

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

---

## NetViz Pro (OSPF-LL-JSON-PART1) Quick Start

Complete guide to get NetViz Pro running with Auth-Vault integration.

### Prerequisites

- **Docker Desktop** (macOS/Windows) or Docker Engine (Linux)
- **Node.js** v18-24 (v20 LTS recommended)
- **Git**

### One-Command Setup Script

Save this as `start-netviz-pro.sh` and run it:

```bash
#!/bin/bash
# =============================================================================
# NetViz Pro with Auth-Vault - Complete Setup Script
# =============================================================================
# This script:
# 1. Checks if auth-vault is installed, clones if not
# 2. Starts Docker if not running
# 3. Starts Keycloak and Vault containers
# 4. Waits for services to be healthy
# 5. Clones/updates NetViz Pro if needed
# 6. Configures environment variables
# 7. Starts NetViz Pro
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUTH_VAULT_DIR="${AUTH_VAULT_DIR:-$HOME/auth-vault}"
NETVIZ_PRO_DIR="${NETVIZ_PRO_DIR:-$HOME/OSPF-LL-JSON-PART1}"
KEYCLOAK_PORT=9120
VAULT_PORT=9121
GATEWAY_PORT=9040

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  NetViz Pro + Auth-Vault Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# -----------------------------------------------------------------------------
# Step 1: Check/Install Auth-Vault
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[1/7] Checking Auth-Vault installation...${NC}"

if [ -d "$AUTH_VAULT_DIR" ]; then
    echo -e "${GREEN}✓ Auth-Vault found at $AUTH_VAULT_DIR${NC}"
else
    echo -e "${YELLOW}Auth-Vault not found. Cloning...${NC}"
    git clone https://github.com/zumanm1/auth-vault.git "$AUTH_VAULT_DIR"
    echo -e "${GREEN}✓ Auth-Vault cloned${NC}"
fi

# -----------------------------------------------------------------------------
# Step 2: Check/Start Docker
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[2/7] Checking Docker...${NC}"

if ! docker info > /dev/null 2>&1; then
    echo -e "${YELLOW}Docker not running. Starting Docker Desktop...${NC}"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open -a Docker
        echo "Waiting for Docker to start (up to 60 seconds)..."
        for i in {1..60}; do
            if docker info > /dev/null 2>&1; then
                break
            fi
            sleep 1
            echo -n "."
        done
        echo ""
    else
        echo -e "${RED}Please start Docker manually and re-run this script${NC}"
        exit 1
    fi
fi

if docker info > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker failed to start${NC}"
    exit 1
fi

# -----------------------------------------------------------------------------
# Step 3: Check/Start Auth-Vault Services
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[3/7] Checking Auth-Vault services...${NC}"

cd "$AUTH_VAULT_DIR"

# Check if containers exist and are running
KEYCLOAK_RUNNING=$(docker ps --filter "name=keycloak" --filter "status=running" -q 2>/dev/null)
VAULT_RUNNING=$(docker ps --filter "name=vault" --filter "status=running" -q 2>/dev/null)

if [ -n "$KEYCLOAK_RUNNING" ] && [ -n "$VAULT_RUNNING" ]; then
    echo -e "${GREEN}✓ Keycloak and Vault are already running${NC}"
else
    echo -e "${YELLOW}Starting Auth-Vault services...${NC}"
    
    # Create .env if it doesn't exist
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            echo -e "${GREEN}✓ Created .env from template${NC}"
        fi
    fi
    
    # Start services
    docker compose up -d
    echo -e "${GREEN}✓ Auth-Vault services started${NC}"
fi

# -----------------------------------------------------------------------------
# Step 4: Wait for Services to be Healthy
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[4/7] Waiting for services to be healthy...${NC}"

echo -n "Waiting for Keycloak..."
for i in {1..60}; do
    if curl -s http://localhost:$KEYCLOAK_PORT/health/ready | grep -q "UP"; then
        echo -e " ${GREEN}✓ Ready${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

echo -n "Waiting for Vault..."
for i in {1..30}; do
    if curl -s http://localhost:$VAULT_PORT/v1/sys/health | grep -q "initialized"; then
        echo -e " ${GREEN}✓ Ready${NC}"
        break
    fi
    sleep 1
    echo -n "."
done

# Verify services
echo -e "\n${BLUE}Service Status:${NC}"
curl -s http://localhost:$KEYCLOAK_PORT/health/ready | jq -r '.status' 2>/dev/null && echo "  Keycloak: UP" || echo "  Keycloak: checking..."
curl -s http://localhost:$VAULT_PORT/v1/sys/health | jq -r 'if .initialized then "  Vault: UP" else "  Vault: initializing" end' 2>/dev/null || echo "  Vault: checking..."

# -----------------------------------------------------------------------------
# Step 5: Check/Install NetViz Pro
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[5/7] Checking NetViz Pro installation...${NC}"

if [ -d "$NETVIZ_PRO_DIR" ]; then
    echo -e "${GREEN}✓ NetViz Pro found at $NETVIZ_PRO_DIR${NC}"
else
    echo -e "${YELLOW}NetViz Pro not found. Cloning...${NC}"
    git clone https://github.com/zumanm1/OSPF-LL-JSON-PART1.git "$NETVIZ_PRO_DIR"
    echo -e "${GREEN}✓ NetViz Pro cloned${NC}"
fi

cd "$NETVIZ_PRO_DIR/netviz-pro"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install --legacy-peer-deps
    echo -e "${GREEN}✓ Dependencies installed${NC}"
fi

# -----------------------------------------------------------------------------
# Step 6: Configure Environment
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/7] Configuring environment...${NC}"

# Create .env.local if it doesn't exist
if [ ! -f .env.local ]; then
    if [ -f .env.local.example ]; then
        cp .env.local.example .env.local
    fi
fi

# Ensure Auth-Vault configuration is present
if ! grep -q "KEYCLOAK_URL" .env.local 2>/dev/null; then
    cat >> .env.local << 'EOF'

# ==============================================================================
# AUTH-VAULT INTEGRATION (Keycloak + Vault)
# ==============================================================================
# Keycloak Configuration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api

# Vault Configuration (using dev token)
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=ospf-vault-dev-token-2025
EOF
    echo -e "${GREEN}✓ Auth-Vault configuration added to .env.local${NC}"
else
    echo -e "${GREEN}✓ Auth-Vault configuration already present${NC}"
fi

# -----------------------------------------------------------------------------
# Step 7: Start NetViz Pro
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[7/7] Starting NetViz Pro...${NC}"

# Check if already running
if lsof -i :$GATEWAY_PORT > /dev/null 2>&1; then
    echo -e "${GREEN}✓ NetViz Pro already running on port $GATEWAY_PORT${NC}"
else
    echo -e "${YELLOW}Starting servers...${NC}"
    ./start.sh &
    sleep 10
fi

# -----------------------------------------------------------------------------
# Final Status
# -----------------------------------------------------------------------------
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo -e "  • Keycloak Admin:  http://localhost:$KEYCLOAK_PORT/admin"
echo -e "  • Vault UI:        http://localhost:$VAULT_PORT/ui"
echo -e "  • NetViz Pro:      http://localhost:$GATEWAY_PORT"
echo ""
echo -e "${BLUE}Verify Integration:${NC}"
echo -e "  curl http://localhost:9041/api/health | jq ."
echo ""
echo -e "${YELLOW}Default Credentials:${NC}"
echo -e "  • Keycloak Admin: admin / admin"
echo -e "  • NetViz Pro: See .env.local for credentials"
echo ""
```

### Manual Step-by-Step Setup

If you prefer manual setup:

#### Step 1: Install and Start Auth-Vault

```bash
# Clone auth-vault if not installed
if [ ! -d ~/auth-vault ]; then
    git clone https://github.com/zumanm1/auth-vault.git ~/auth-vault
fi

# Start Docker Desktop (macOS)
open -a Docker

# Wait for Docker, then start services
cd ~/auth-vault
docker compose up -d

# Verify services are healthy
curl http://localhost:9120/health/ready
curl http://localhost:9121/v1/sys/health
```

#### Step 2: Install and Start NetViz Pro

```bash
# Clone NetViz Pro if not installed
if [ ! -d ~/OSPF-LL-JSON-PART1 ]; then
    git clone https://github.com/zumanm1/OSPF-LL-JSON-PART1.git ~/OSPF-LL-JSON-PART1
fi

cd ~/OSPF-LL-JSON-PART1/netviz-pro

# Install dependencies
npm install --legacy-peer-deps

# Configure environment (add to .env.local)
cat >> .env.local << 'EOF'
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=ospf-vault-dev-token-2025
EOF

# Start the application
./start.sh
```

#### Step 3: Verify Integration

```bash
# Check health endpoint
curl http://localhost:9041/api/health | jq .

# Expected response:
{
  "status": "ok",
  "authVault": "active",
  "authMode": "keycloak"
}
```

### Ports Reference

| Service | Port | URL |
|---------|------|-----|
| NetViz Pro Gateway | 9040 | http://localhost:9040 |
| NetViz Pro Auth Server | 9041 | http://localhost:9041/api |
| NetViz Pro Vite Dev | 9042 | http://localhost:9042 |
| Keycloak | 9120 | http://localhost:9120 |
| Vault | 9121 | http://localhost:9121 |

### Troubleshooting NetViz Pro

#### Auth-Vault Not Active

```bash
# Check if Keycloak is accessible
curl http://localhost:9120/realms/ospf-ll-json-part1

# Check environment variables
grep KEYCLOAK ~/OSPF-LL-JSON-PART1/netviz-pro/.env.local

# Restart NetViz Pro after fixing
cd ~/OSPF-LL-JSON-PART1/netviz-pro
./stop.sh && ./start.sh
```

#### Rate Limiting Issues

The application has rate limiting (5 attempts per 15 minutes) on auth endpoints. If you see "Too many authentication attempts", wait 15 minutes or restart the auth server.

#### Docker Services Not Starting

```bash
# Check Docker status
docker ps -a

# View logs
cd ~/auth-vault
docker compose logs keycloak
docker compose logs vault

# Restart services
docker compose restart
```

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
