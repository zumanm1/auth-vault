# Auth-Vault: Centralized Security Infrastructure for OSPF Application Suite

## Introduction

Auth-Vault (App0) is the **foundation** of the OSPF Application Suite. It provides centralized authentication via Keycloak and secrets management via HashiCorp Vault for all 6 applications in the suite.

### What is the OSPF Suite?

The OSPF Suite is a collection of 6 integrated network management and visualization applications:

| App | Name | Description | Ports |
|-----|------|-------------|-------|
| **App0** | Auth-Vault | Centralized authentication (Keycloak) & secrets (Vault) | 9120, 9121 |
| **App1** | Impact Planner | Network impact analysis and planning tool | 9090, 9091 |
| **App2** | NetViz Pro | Network visualization with real-time monitoring | 9040, 9041, 9042 |
| **App3** | NN-JSON | JSON-based network node visualizer | 9080, 9081 |
| **App4** | Tempo-X | Network topology analyzer and mapper | 9100, 9101 |
| **App5** | Device Manager | Network device inventory and management | 9050, 9051 |

### Why App0 First?

Auth-Vault must be installed and running **before** any other application because:
1. All apps authenticate through Keycloak (SSO)
2. All apps retrieve secrets from Vault
3. Auth-Vault provides the security backbone for the entire suite

---

## Installation Priority & Order

### Recommended Installation Order

```
Priority 1: App0 (Auth-Vault)     - MUST be first (provides auth for all)
Priority 2: App3 (NN-JSON)        - No external dependencies
Priority 3: App4 (Tempo-X)        - Database required
Priority 4: App2 (NetViz Pro)     - Complex gateway setup
Priority 5: App1 (Impact Planner) - Full feature app
Priority 6: App5 (Device Manager) - Device integration
```

### Visual Installation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     OSPF SUITE INSTALLATION ORDER                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────┐                                                            │
│   │   App0      │  ◄─── START HERE (Required for all apps)                  │
│   │ Auth-Vault  │       Ports: 9120 (Keycloak), 9121 (Vault)                │
│   │  Priority 1 │                                                            │
│   └──────┬──────┘                                                            │
│          │                                                                   │
│          ▼                                                                   │
│   ┌─────────────┐      ┌─────────────┐      ┌─────────────┐                 │
│   │   App3      │      │   App4      │      │   App2      │                 │
│   │  NN-JSON    │ ──► │  Tempo-X    │ ──► │ NetViz Pro  │                 │
│   │  Priority 2 │      │  Priority 3 │      │  Priority 4 │                 │
│   │ 9080, 9081  │      │ 9100, 9101  │      │ 9040-9042   │                 │
│   └─────────────┘      └─────────────┘      └─────────────┘                 │
│                                                    │                         │
│          ┌─────────────┐      ┌─────────────┐      │                         │
│          │   App1      │ ◄────┤   App5      │◄─────┘                         │
│          │   Impact    │      │   Device    │                                │
│          │  Planner    │      │  Manager    │                                │
│          │  Priority 5 │      │  Priority 6 │                                │
│          │ 9090, 9091  │      │ 9050, 9051  │                                │
│          └─────────────┘      └─────────────┘                                │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Start Guide

### Option 1: Install All Apps at Once (Recommended)

```bash
# Clone the repository
git clone https://github.com/zumanm1/auth-vault.git
cd auth-vault/setup-scripts

# Install and start all 6 apps with one command
./setup-all-apps.sh setup

# Validate all apps are running
./validate-all-apps.sh validate
```

### Option 2: Install Apps Individually

```bash
cd auth-vault/setup-scripts

# Step 1: Install Auth-Vault (MUST BE FIRST)
./setup-app0.sh setup

# Step 2-6: Install remaining apps in order
./setup-app3.sh setup    # NN-JSON
./setup-app4.sh setup    # Tempo-X
./setup-app2.sh setup    # NetViz Pro
./setup-app1.sh setup    # Impact Planner
./setup-app5.sh setup    # Device Manager
```

---

## Scripts Reference

### Directory Structure

```
app0-auth-vault/
├── auth-vault.sh                 # Main Auth-Vault management script
├── README.md                     # This documentation
├── setup-scripts/                # Suite orchestration scripts
│   ├── setup-all-apps.sh         # Master installer (all 6 apps)
│   ├── setup-app0.sh             # Auth-Vault setup
│   ├── setup-app1.sh             # Impact Planner setup
│   ├── setup-app2.sh             # NetViz Pro setup
│   ├── setup-app3.sh             # NN-JSON setup
│   ├── setup-app4.sh             # Tempo-X setup
│   ├── setup-app5.sh             # Device Manager setup
│   ├── start-all-apps.sh         # Start all apps
│   ├── stop-all-apps.sh          # Stop all apps
│   └── validate-all-apps.sh      # Validate all apps
├── keycloak/                     # Keycloak realm configurations
├── vault/                        # Vault policies and configs
└── apps/                         # Per-app integration guides
```

### Available Scripts Summary

| Script | Purpose | Commands |
|--------|---------|----------|
| `setup-all-apps.sh` | Master orchestrator | `setup`, `start`, `stop`, `status` |
| `setup-app[0-5].sh` | Individual app setup | `setup`, `install`, `start`, `stop`, `status` |
| `start-all-apps.sh` | Start all apps | `all`, `0-5`, `help` |
| `stop-all-apps.sh` | Stop all apps | `all`, `force`, `kill`, `0-5` |
| `validate-all-apps.sh` | Validate all apps | `validate`, `quick`, `status`, `json` |

---

## Per-App Installation Guide

### App0: Auth-Vault (Keycloak + Vault)

**Ports:** 9120 (Keycloak), 9121 (Vault)

```bash
# Using setup script
cd setup-scripts
./setup-app0.sh setup

# Or using main script
cd app0-auth-vault
./auth-vault.sh install
./auth-vault.sh start

# Verify
curl http://localhost:9120/health/ready
curl http://localhost:9121/v1/sys/health
```

**Access:**
- Keycloak Admin: http://localhost:9120/admin (admin/admin)
- Vault UI: http://localhost:9121/ui (use root token)

---

### App1: Impact Planner

**GitHub Repository:** https://github.com/zumanm1/ospf-impact-planner

**Ports:**
- 9090 - Frontend (Vite React)
- 9091 - Backend API (Express + PostgreSQL)

**Description:** Network infrastructure impact analysis and cost planning tool. Provides multi-site network modeling with real-time cost calculations.

**Features:**
- Network infrastructure impact analysis
- Cost planning and optimization
- Multi-site network modeling
- Integration with Auth-Vault for authentication
- PostgreSQL database backend

**Prerequisites:**
- Node.js v18+ (v20+ recommended)
- PostgreSQL 14+
- npm

```bash
# Using setup script (RECOMMENDED)
cd setup-scripts
./setup-app1.sh setup

# Or manually
cd app1-impact-planner
./ospf-planner.sh install    # Install Node.js requirements
./ospf-planner.sh deps       # Install npm dependencies
./ospf-planner.sh db-setup   # Setup PostgreSQL database
./ospf-planner.sh start      # Start frontend + backend

# Verify
curl http://localhost:9091/api/health
# Expected: {"status":"healthy","database":"connected",...}
```

**Access URLs:**
- Frontend: http://localhost:9090
- API Health: http://localhost:9091/api/health

**Default Credentials:**
- Username: `netviz_admin`
- Password: `V3ry$trongAdm1n!2025`

**Troubleshooting:**
```bash
# Check status
./setup-app1.sh status

# Restart services
cd app1-impact-planner && ./ospf-planner.sh stop && ./ospf-planner.sh start

# View logs
tail -f app1-impact-planner/.api-server.log
```

---

### App2: NetViz Pro

**Ports:** 9040 (Gateway), 9041 (Auth Server), 9042 (Vite Dev)

```bash
# Using setup script
cd setup-scripts
./setup-app2.sh setup

# Or manually
cd app2-netviz-pro
./netviz.sh start

# Verify
curl http://localhost:9041/health
```

**Access:** http://localhost:9042

---

### App3: NN-JSON

**Ports:** 9080 (Frontend), 9081 (Backend)

```bash
# Using setup script
cd setup-scripts
./setup-app3.sh setup

# Or manually
cd app3-nn-json
./nn-json.sh install
./nn-json.sh start

# Verify
curl http://localhost:9081/api/health
```

**Access:** http://localhost:9080

---

### App4: Tempo-X

**Ports:** 9100 (Frontend), 9101 (Backend)

```bash
# Using setup script
cd setup-scripts
./setup-app4.sh setup

# Or manually
cd app4-tempo-x
./ospf-tempo-x.sh install
./ospf-tempo-x.sh deps
./ospf-tempo-x.sh db-setup
./ospf-tempo-x.sh start

# Verify
curl http://localhost:9101/api/health
```

**Access:** http://localhost:9100

---

### App5: Device Manager

**Ports:** 9050 (Frontend), 9051 (Backend)

```bash
# Using setup script
cd setup-scripts
./setup-app5.sh setup

# Or manually
cd app5-device-manager
./ospf-device-manager.sh install
./ospf-device-manager.sh deps
./ospf-device-manager.sh db-setup
./ospf-device-manager.sh start

# Verify
curl http://localhost:9051/api/health
```

**Access:** http://localhost:9050

---

## Start, Stop, and Validate Operations

### Starting Apps

```bash
cd app0-auth-vault/setup-scripts

# Start ALL apps
./start-all-apps.sh all

# Start specific app
./start-all-apps.sh 0    # Auth-Vault only
./start-all-apps.sh 4    # Tempo-X only

# Using individual scripts
./setup-app0.sh start
./setup-app1.sh start
```

### Stopping Apps

```bash
cd app0-auth-vault/setup-scripts

# Stop ALL apps gracefully
./stop-all-apps.sh all

# Force stop all apps
./stop-all-apps.sh force

# Kill all OSPF ports directly
./stop-all-apps.sh kill

# Stop specific app
./stop-all-apps.sh 0     # Auth-Vault only
./stop-all-apps.sh 4     # Tempo-X only

# Using individual scripts
./setup-app0.sh stop
./setup-app1.sh stop
```

### Validating Apps

```bash
cd app0-auth-vault/setup-scripts

# Full validation with detailed output
./validate-all-apps.sh validate

# Quick status check (for CI/CD)
./validate-all-apps.sh quick

# Port status only
./validate-all-apps.sh status

# JSON output for automation
./validate-all-apps.sh json > status.json
```

---

## Validation Script Details

The `validate-all-apps.sh` performs comprehensive checks:

### Checks Performed

| Check | Description |
|-------|-------------|
| **Directory** | Verifies app directory exists |
| **Ports** | Checks all service ports are listening |
| **Health Endpoints** | Tests API health endpoints |
| **Database** | Checks PostgreSQL connection and database |
| **Frontend** | HTTP response validation |
| **API Root** | Endpoint accessibility |
| **Auth Config** | `/api/auth/config` endpoint |
| **CORS** | Header detection via OPTIONS |
| **Configuration** | Verifies .env file |
| **Log Analysis** | Scans for errors, shows recent entries |

### Component Checks Per App

| App | Components Validated |
|-----|---------------------|
| App0 | keycloak, vault |
| App1 | frontend, backend, api, database, auth |
| App2 | gateway, auth-server, vite |
| App3 | frontend, backend, api, auth |
| App4 | frontend, backend, api, database, auth |
| App5 | frontend, backend, api, database, auth |

### Sample Validation Output

```
╔══════════════════════════════════════════════════════════════════════╗
║  OSPF Suite - Comprehensive Validation                                ║
╚══════════════════════════════════════════════════════════════════════╝

App0: Auth-Vault
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Components: keycloak vault
  [PASS] Directory exists: app0-auth-vault
  [PASS] Keycloak port 9120 is listening
  [PASS] Vault port 9121 is listening

  ============================================================
              VAULT CREDENTIALS
  ============================================================
  Vault Unseal Key: <generated>
  Vault Root Token: <generated>
  ============================================================

App4: Tempo-X
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Components: frontend backend api database auth
  [PASS] Directory exists: app4-tempo-x
  [PASS] Frontend port 9100 is listening
  [PASS] Backend port 9101 is listening
  [PASS] Health endpoint responding
  [PASS] Frontend accessible (HTTP 200)
  [PASS] API root accessible
  [PASS] Auth config: mode=legacy
  [PASS] CORS headers present

╔══════════════════════════════════════════════════════════════════════╗
║  VALIDATION SUMMARY                                                   ║
╚══════════════════════════════════════════════════════════════════════╝

  Port Status: 13 ports checked
    UP: 9040 9041 9042 9050 9051 9080 9081 9090 9091 9100 9101 9120 9121

  Overall Statistics:
    Total Checks:  74
    Passed:        49
    Failed:        2
    Warnings:      9
    Success Rate:  66%

  Final Verdict: SYSTEMS OPERATIONAL WITH WARNINGS
```

---

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

---

## Default Credentials

**CHANGE ALL PASSWORDS ON FIRST USE**

### Keycloak Admin
- Username: `admin`
- Password: `admin`

### Per-Realm Users

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

---

## Management Commands

### Auth-Vault Main Script

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

---

## Troubleshooting

### Common Issues

#### Keycloak Won't Start
```bash
# Check logs
tail -f ~/.keycloak/logs/keycloak.log

# Check port
lsof -i :9120

# Check Java
java -version
```

#### Vault Initialization Failed
```bash
./auth-vault.sh status
export VAULT_ADDR=http://localhost:9121
vault status
```

#### App Can't Connect to Auth-Vault
```bash
# Verify services
./auth-vault.sh status

# Check realm
curl http://localhost:9120/realms/<realm-name>

# Check Vault mount
curl -H "X-Vault-Token: <token>" http://localhost:9121/v1/sys/mounts
```

#### Port Already in Use
```bash
# Find process
lsof -i :<port>

# Kill process
kill -9 <pid>

# Or use stop script
./stop-all-apps.sh kill
```

---

## Security Features

### Keycloak
- Brute Force Protection: 5 failures = 15 min lockout
- Password Policy: 12+ chars, mixed case, digit, special char
- Session Management: 30 min idle, 10 hour max
- PKCE: Required for SPAs
- Audit Logging: All events logged

### Vault
- AppRole Authentication per app
- Transit Encryption: AES-256-GCM
- Strict Policies: Apps access only their secrets
- Audit Logging: All access logged
- KV-V2: Versioned secrets

---

## Production Deployment

### Security Hardening

1. **Change all default passwords**
2. **Enable HTTPS** for all services
3. **Configure proper CORS origins**
4. **Restrict network access** with IP whitelists
5. **Enable audit logging**
6. **Use proper Vault unsealing** (not dev mode)
7. **Backup encryption keys** securely

### HTTPS Configuration

```bash
# Keycloak
export KC_HTTPS_CERTIFICATE_FILE=/path/to/tls.crt
export KC_HTTPS_CERTIFICATE_KEY_FILE=/path/to/tls.key

# Vault
export VAULT_ADDR=https://localhost:9121
```

---

## Support

- Open an issue on [GitHub](https://github.com/zumanm1/auth-vault/issues)
- Check the troubleshooting section
- Review app-specific README files in `apps/` directory

---

## License

MIT
