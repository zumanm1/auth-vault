# Auth-Vault App Configuration Reference

> **Last Verified**: December 9, 2025
> **Status**: All 5 apps validated and working with Auth-Vault

## Quick Status Check

```bash
# Verify all apps are connected to Auth-Vault
curl -s http://localhost:9091/api/health | jq .  # App1: Impact Planner
curl -s http://localhost:9041/api/health | jq .  # App2: NetViz Pro
curl -s http://localhost:9081/api/health | jq .  # App3: NN-JSON
curl -s http://localhost:9101/api/health | jq .  # App4: Tempo-X
curl -s http://localhost:9051/api/health | jq .  # App5: Device Manager

# Expected response includes:
# "database": "connected",
# "authVault": "active",
# "authMode": "keycloak"
```

## Verified Status (December 9, 2025)

| App | Backend Port | Database | authVault | authMode |
|-----|--------------|----------|-----------|----------|
| App1 (Impact Planner) | 9091 | connected | active | keycloak |
| App2 (NetViz Pro) | 9041 | connected | active | keycloak |
| App3 (NN-JSON) | 9081 | connected | active | keycloak |
| App4 (Tempo-X) | 9101 | connected | active | keycloak |
| App5 (Device Manager) | 9051 | connected | active | keycloak |

---

## Keycloak Configuration

### Service Details
| Setting | Value |
|---------|-------|
| URL | http://localhost:9120 |
| Admin Console | http://localhost:9120/admin |
| Admin Username | admin |
| Admin Password | admin |

### Realm Status (Verified)
```bash
# Check all realms exist
curl -s http://localhost:9120/realms/ospf-impact-planner | jq -r '.realm'
curl -s http://localhost:9120/realms/ospf-ll-json-part1 | jq -r '.realm'
curl -s http://localhost:9120/realms/ospf-nn-json | jq -r '.realm'
curl -s http://localhost:9120/realms/ospf-tempo-x | jq -r '.realm'
curl -s http://localhost:9120/realms/ospf-device-manager | jq -r '.realm'
```

---

## Vault Configuration

### Service Details
| Setting | Value |
|---------|-------|
| URL | http://localhost:9121 |
| UI | http://localhost:9121/ui |
| Dev Token | <your-vault-token> |

---

## Per-App Configuration

### App 1: OSPF Impact Planner

| Property | Value |
|----------|-------|
| Directory | `~/OSPF-IMPACT-planner Private/ospf-impact-planner` |
| Frontend Port | 9090 |
| Backend Port | 9091 |
| Keycloak Realm | ospf-impact-planner |
| Keycloak Client | impact-planner-api |
| GitHub | https://github.com/zumanm1/ospf-impact-planner |

**Environment Variables** (add to `.env` or `.env.local`):
```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-impact-planner
KEYCLOAK_CLIENT_ID=impact-planner-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

**Integration Files**:
- `server/src/lib/keycloak-verifier.ts`
- `server/src/lib/vault-client.ts`
- `server/src/middleware/auth-unified.ts`

---

### App 2: NetViz Pro (OSPF-LL-JSON-PART1)

| Property | Value |
|----------|-------|
| Directory | `~/OSPF-LL-JSON-PART1/netviz-pro` |
| Gateway Port | 9040 |
| Auth Server Port | 9041 |
| Vite Dev Port | 9042 |
| Keycloak Realm | ospf-ll-json-part1 |
| Keycloak Client | netviz-pro-api |

**Environment Variables** (in `.env.local`):
```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-ll-json-part1
KEYCLOAK_CLIENT_ID=netviz-pro-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

**Integration Files**:
- `server/lib/keycloak-verifier.js`
- `server/lib/vault-client.js`
- `server/lib/auth-unified.js`

**Start Command**:
```bash
cd ~/OSPF-LL-JSON-PART1/netviz-pro
./netviz.sh start
```

**Verify**:
```bash
curl http://localhost:9041/api/health
# {"authVault":"active","authMode":"keycloak"}
```

---

### App 3: OSPF Visualizer Pro (OSPF-NN-JSON)

| Property | Value |
|----------|-------|
| Directory | `~/OSPF-NN-JSON` |
| Frontend Port | 9080 |
| Backend Port | 9081 |
| Keycloak Realm | ospf-nn-json |
| Keycloak Client | nn-json-api |

**Environment Variables** (in `.env`):
```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-nn-json
KEYCLOAK_CLIENT_ID=nn-json-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

**Integration Files**:
- `server/lib/keycloak-verifier.js`
- `server/lib/vault-client.js`
- `server/lib/auth-unified.js`

**Start Command**:
```bash
cd ~/OSPF-NN-JSON
./start.sh
```

**Verify**:
```bash
curl http://localhost:9081/api/health
# {"authVault":"active","authMode":"keycloak"}
```

---

### App 4: OSPF Tempo-X

| Property | Value |
|----------|-------|
| Directory | `~/OSPF-TEMPO-X` |
| Frontend Port | 9100 |
| Backend Port | 9101 |
| Keycloak Realm | ospf-tempo-x |
| Keycloak Client | tempo-x-api |
| Database | PostgreSQL (ospf_tempo_x) |

**Environment Variables** (in `.env`):
```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-tempo-x
KEYCLOAK_CLIENT_ID=tempo-x-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

**Integration Files**:
- `server/lib/keycloak-verifier.ts`
- `server/lib/vault-client.ts`
- `server/lib/auth-unified.ts`

**Start Command**:
```bash
cd ~/OSPF-TEMPO-X
./ospf-tempo-x.sh start
```

**Verify**:
```bash
curl http://localhost:9101/api/health
# {"authVault":"active","authMode":"keycloak"}
```

---

### App 5: OSPF Device Manager

| Property | Value |
|----------|-------|
| Directory | `~/OSPF-LL-DEVICE_MANAGER` |
| Frontend Port | 9050 |
| Backend Port | 9051 |
| Keycloak Realm | ospf-device-manager |
| Keycloak Client | device-manager-api |
| Language | Python (FastAPI) |

**Environment Variables** (in `.env.local`):
```bash
# Auth-Vault Integration
KEYCLOAK_URL=http://localhost:9120
KEYCLOAK_REALM=ospf-device-manager
KEYCLOAK_CLIENT_ID=device-manager-api
VAULT_ADDR=http://localhost:9121
VAULT_TOKEN=<your-vault-token>
```

**Integration Files**:
- `backend/lib/keycloak_verifier.py`
- `backend/lib/vault_client.py`
- `backend/lib/auth_unified.py`

**Start Command**:
```bash
cd ~/OSPF-LL-DEVICE_MANAGER
./start.sh
```

**Verify**:
```bash
curl http://localhost:9051/api/health
# {"authVault":"active","authMode":"keycloak"}
```

---

## Runtime Requirements

### Node.js Version
All Node.js-based apps require **Node.js v24.x LTS (Krypton)** with **npm v11.x**.

```bash
# Install Node v24.11.1 via nvm
nvm install 24.11.1
nvm use 24.11.1
nvm alias default 24.11.1

# Verify installation
node --version  # v24.11.1
npm --version   # 11.6.2
```

### Python Version (App5 Only)
Device Manager backend requires **Python 3.9+** with FastAPI.

---

## Port Summary

| Service | Port | Description |
|---------|------|-------------|
| Keycloak | 9120 | Authentication server |
| Vault | 9121 | Secrets management |
| App2 Gateway | 9040 | NetViz Pro main entry |
| App2 Auth | 9041 | NetViz Pro auth server |
| App2 Vite | 9042 | NetViz Pro dev server |
| App3 Frontend | 9080 | NN-JSON frontend |
| App3 Backend | 9081 | NN-JSON API |
| App1 Frontend | 9090 | Impact Planner frontend |
| App1 Backend | 9091 | Impact Planner API |
| App4 Frontend | 9100 | Tempo-X frontend |
| App4 Backend | 9101 | Tempo-X API |
| App5 Frontend | 9050 | Device Manager frontend |
| App5 Backend | 9051 | Device Manager API |

---

## Troubleshooting

### Auth-Vault Not Activating

1. Check Keycloak is running:
```bash
curl http://localhost:9120/health/ready
```

2. Check realm exists:
```bash
curl http://localhost:9120/realms/<realm-name>
```

3. Check environment variables are set:
```bash
grep KEYCLOAK .env
grep VAULT .env
```

### Import Missing Realms

```bash
cd ~/auth-vault
./auth-vault.sh import
```

If import fails with auth error, use admin/admin credentials:
```bash
# Get admin token
TOKEN=$(curl -s -X POST "http://localhost:9120/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" -d "password=admin" \
  -d "grant_type=password" -d "client_id=admin-cli" | jq -r '.access_token')

# Import realm
curl -X POST "http://localhost:9120/admin/realms" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @keycloak/realms/realm-ospf-<app>.json
```

### Restart Auth-Vault Services

```bash
cd ~/auth-vault
./auth-vault.sh restart
```

---

## Start All Apps Script

Create `~/start-all-ospf-apps.sh`:
```bash
#!/bin/bash
echo "Starting Auth-Vault..."
cd ~/auth-vault && ./auth-vault.sh start
sleep 10

echo "Starting App2: NetViz Pro..."
cd ~/OSPF-LL-JSON-PART1/netviz-pro && ./netviz.sh start &

echo "Starting App3: NN-JSON..."
cd ~/OSPF-NN-JSON && ./start.sh &

echo "Starting App4: Tempo-X..."
cd ~/OSPF-TEMPO-X && ./ospf-tempo-x.sh start &

echo "Starting App5: Device Manager..."
cd ~/OSPF-LL-DEVICE_MANAGER && ./start.sh &

sleep 15
echo "All apps started. Checking health..."
echo "App2: $(curl -s http://localhost:9041/api/health | jq -r '.authMode')"
echo "App3: $(curl -s http://localhost:9081/api/health | jq -r '.authMode')"
echo "App4: $(curl -s http://localhost:9101/api/health | jq -r '.authMode')"
echo "App5: $(curl -s http://localhost:9051/api/health | jq -r '.authMode')"
```
