#!/bin/sh
# ============================================================================
# Vault Initialization Script
# Creates mount paths, policies, and OIDC auth for each OSPF application
# ============================================================================

set -e

echo "=============================================="
echo "Initializing Vault for OSPF Application Suite"
echo "=============================================="

# Wait for Vault to be ready
echo "Waiting for Vault to be ready..."
until vault status > /dev/null 2>&1; do
  echo "Vault is not ready yet, waiting..."
  sleep 2
done
echo "Vault is ready!"

# ============================================================================
# Enable Secrets Engines for Each Application
# ============================================================================

echo ""
echo "=== Creating KV-V2 Secret Mounts for Each Application ==="

# App 1: OSPF Impact Planner
echo "Creating mount: ospf-impact-planner/"
vault secrets enable -path=ospf-impact-planner kv-v2 2>/dev/null || echo "Mount ospf-impact-planner already exists"

# App 2: OSPF LL JSON Part1 (NetViz Pro)
echo "Creating mount: ospf-ll-json-part1/"
vault secrets enable -path=ospf-ll-json-part1 kv-v2 2>/dev/null || echo "Mount ospf-ll-json-part1 already exists"

# App 3: OSPF NN JSON (Visualizer Pro)
echo "Creating mount: ospf-nn-json/"
vault secrets enable -path=ospf-nn-json kv-v2 2>/dev/null || echo "Mount ospf-nn-json already exists"

# App 4: OSPF Tempo-X
echo "Creating mount: ospf-tempo-x/"
vault secrets enable -path=ospf-tempo-x kv-v2 2>/dev/null || echo "Mount ospf-tempo-x already exists"

# App 5: OSPF Device Manager
echo "Creating mount: ospf-device-manager/"
vault secrets enable -path=ospf-device-manager kv-v2 2>/dev/null || echo "Mount ospf-device-manager already exists"

# Shared mount for common secrets
echo "Creating mount: ospf-shared/"
vault secrets enable -path=ospf-shared kv-v2 2>/dev/null || echo "Mount ospf-shared already exists"

# ============================================================================
# Enable Transit Engine for Encryption Operations
# ============================================================================

echo ""
echo "=== Enabling Transit Encryption Engine ==="

# Per-app transit engines for encryption keys
vault secrets enable -path=ospf-impact-planner-transit transit 2>/dev/null || echo "Transit ospf-impact-planner-transit already exists"
vault secrets enable -path=ospf-ll-json-part1-transit transit 2>/dev/null || echo "Transit ospf-ll-json-part1-transit already exists"
vault secrets enable -path=ospf-nn-json-transit transit 2>/dev/null || echo "Transit ospf-nn-json-transit already exists"
vault secrets enable -path=ospf-tempo-x-transit transit 2>/dev/null || echo "Transit ospf-tempo-x-transit already exists"
vault secrets enable -path=ospf-device-manager-transit transit 2>/dev/null || echo "Transit ospf-device-manager-transit already exists"

# ============================================================================
# Create Transit Encryption Keys for Each App
# ============================================================================

echo ""
echo "=== Creating Transit Encryption Keys ==="

# Impact Planner keys
vault write -f ospf-impact-planner-transit/keys/jwt-signing type=rsa-4096 2>/dev/null || echo "Key jwt-signing already exists for impact-planner"
vault write -f ospf-impact-planner-transit/keys/data-encryption type=aes256-gcm96 2>/dev/null || echo "Key data-encryption already exists for impact-planner"

# LL JSON Part1 keys
vault write -f ospf-ll-json-part1-transit/keys/jwt-signing type=rsa-4096 2>/dev/null || echo "Key jwt-signing already exists for ll-json-part1"
vault write -f ospf-ll-json-part1-transit/keys/data-encryption type=aes256-gcm96 2>/dev/null || echo "Key data-encryption already exists for ll-json-part1"
vault write -f ospf-ll-json-part1-transit/keys/session-key type=aes256-gcm96 2>/dev/null || echo "Key session-key already exists for ll-json-part1"

# NN JSON keys
vault write -f ospf-nn-json-transit/keys/jwt-signing type=rsa-4096 2>/dev/null || echo "Key jwt-signing already exists for nn-json"
vault write -f ospf-nn-json-transit/keys/data-encryption type=aes256-gcm96 2>/dev/null || echo "Key data-encryption already exists for nn-json"

# Tempo-X keys
vault write -f ospf-tempo-x-transit/keys/jwt-signing type=rsa-4096 2>/dev/null || echo "Key jwt-signing already exists for tempo-x"
vault write -f ospf-tempo-x-transit/keys/data-encryption type=aes256-gcm96 2>/dev/null || echo "Key data-encryption already exists for tempo-x"

# Device Manager keys (extra keys for SSH credentials)
vault write -f ospf-device-manager-transit/keys/jwt-signing type=rsa-4096 2>/dev/null || echo "Key jwt-signing already exists for device-manager"
vault write -f ospf-device-manager-transit/keys/device-credentials type=aes256-gcm96 2>/dev/null || echo "Key device-credentials already exists for device-manager"
vault write -f ospf-device-manager-transit/keys/jumphost-credentials type=aes256-gcm96 2>/dev/null || echo "Key jumphost-credentials already exists for device-manager"

# ============================================================================
# Seed Initial Secrets for Each Application
# ============================================================================

echo ""
echo "=== Seeding Initial Secrets ==="

# Generate random secrets for each app
APP1_JWT_SECRET=$(head -c 32 /dev/urandom | base64)
APP2_JWT_SECRET=$(head -c 32 /dev/urandom | base64)
APP3_JWT_SECRET=$(head -c 32 /dev/urandom | base64)
APP4_JWT_SECRET=$(head -c 32 /dev/urandom | base64)
APP5_JWT_SECRET=$(head -c 32 /dev/urandom | base64)

APP1_SESSION_SECRET=$(head -c 32 /dev/urandom | base64)
APP2_SESSION_SECRET=$(head -c 32 /dev/urandom | base64)
APP3_SESSION_SECRET=$(head -c 32 /dev/urandom | base64)
APP4_SESSION_SECRET=$(head -c 32 /dev/urandom | base64)
APP5_SESSION_SECRET=$(head -c 32 /dev/urandom | base64)

# OSPF Impact Planner secrets
vault kv put ospf-impact-planner/config \
  jwt_secret="$APP1_JWT_SECRET" \
  session_secret="$APP1_SESSION_SECRET" \
  jwt_expires_in="7d" \
  environment="production"

vault kv put ospf-impact-planner/database \
  host="localhost" \
  port="5432" \
  name="ospf_planner" \
  user="ospf_planner_user" \
  password="CHANGE_ME_SECURE_DB_PASSWORD"

# OSPF LL JSON Part1 secrets
vault kv put ospf-ll-json-part1/config \
  jwt_secret="$APP2_JWT_SECRET" \
  session_secret="$APP2_SESSION_SECRET" \
  jwt_expires_in="7d" \
  admin_reset_pin="$(head -c 16 /dev/urandom | xxd -p)" \
  environment="production"

vault kv put ospf-ll-json-part1/database \
  path="./server/users.db"

# OSPF NN JSON secrets
vault kv put ospf-nn-json/config \
  jwt_secret="$APP3_JWT_SECRET" \
  session_secret="$APP3_SESSION_SECRET" \
  jwt_expires_in="7d" \
  environment="production"

vault kv put ospf-nn-json/database \
  path="./data/ospf-visualizer.db"

# OSPF Tempo-X secrets
vault kv put ospf-tempo-x/config \
  jwt_secret="$APP4_JWT_SECRET" \
  session_secret="$APP4_SESSION_SECRET" \
  jwt_expires_in="24h" \
  environment="production"

vault kv put ospf-tempo-x/database \
  host="localhost" \
  port="5432" \
  name="ospf_tempo_x" \
  user="ospf_tempo_user" \
  password="CHANGE_ME_SECURE_DB_PASSWORD"

# OSPF Device Manager secrets (most sensitive - contains network device credentials)
vault kv put ospf-device-manager/config \
  jwt_secret="$APP5_JWT_SECRET" \
  session_secret="$APP5_SESSION_SECRET" \
  session_timeout="3600" \
  admin_pin_hash="$(echo -n 'CHANGE_THIS_ADMIN_PIN' | sha256sum | cut -d' ' -f1)" \
  environment="production"

vault kv put ospf-device-manager/database \
  path="./backend/devices.db" \
  encryption_key="$(head -c 32 /dev/urandom | base64)"

vault kv put ospf-device-manager/router-defaults \
  username="CHANGE_ME" \
  password="CHANGE_ME"

vault kv put ospf-device-manager/jumphost \
  enabled="false" \
  host="" \
  port="22" \
  username="" \
  password=""

# Shared secrets (Keycloak client secrets)
vault kv put ospf-shared/keycloak \
  impact_planner_client_secret="$(head -c 32 /dev/urandom | base64)" \
  ll_json_part1_client_secret="$(head -c 32 /dev/urandom | base64)" \
  nn_json_client_secret="$(head -c 32 /dev/urandom | base64)" \
  tempo_x_client_secret="$(head -c 32 /dev/urandom | base64)" \
  device_manager_client_secret="$(head -c 32 /dev/urandom | base64)"

# ============================================================================
# Create Policies for Each Application
# ============================================================================

echo ""
echo "=== Creating Vault Policies ==="

# Impact Planner Policy
vault policy write ospf-impact-planner-policy - <<EOF
# OSPF Impact Planner Policy
# Allows access only to impact-planner secrets and transit

# Read/Write to own secrets
path "ospf-impact-planner/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ospf-impact-planner/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

# Transit encryption operations
path "ospf-impact-planner-transit/encrypt/*" {
  capabilities = ["update"]
}

path "ospf-impact-planner-transit/decrypt/*" {
  capabilities = ["update"]
}

path "ospf-impact-planner-transit/keys/*" {
  capabilities = ["read"]
}

# Read shared Keycloak secrets
path "ospf-shared/data/keycloak" {
  capabilities = ["read"]
}

# Deny access to other apps
path "ospf-ll-json-part1/*" {
  capabilities = ["deny"]
}

path "ospf-nn-json/*" {
  capabilities = ["deny"]
}

path "ospf-tempo-x/*" {
  capabilities = ["deny"]
}

path "ospf-device-manager/*" {
  capabilities = ["deny"]
}
EOF

# LL JSON Part1 Policy
vault policy write ospf-ll-json-part1-policy - <<EOF
# OSPF LL JSON Part1 Policy

path "ospf-ll-json-part1/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ospf-ll-json-part1/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "ospf-ll-json-part1-transit/encrypt/*" {
  capabilities = ["update"]
}

path "ospf-ll-json-part1-transit/decrypt/*" {
  capabilities = ["update"]
}

path "ospf-ll-json-part1-transit/keys/*" {
  capabilities = ["read"]
}

path "ospf-shared/data/keycloak" {
  capabilities = ["read"]
}

path "ospf-impact-planner/*" {
  capabilities = ["deny"]
}

path "ospf-nn-json/*" {
  capabilities = ["deny"]
}

path "ospf-tempo-x/*" {
  capabilities = ["deny"]
}

path "ospf-device-manager/*" {
  capabilities = ["deny"]
}
EOF

# NN JSON Policy
vault policy write ospf-nn-json-policy - <<EOF
# OSPF NN JSON Policy

path "ospf-nn-json/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ospf-nn-json/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "ospf-nn-json-transit/encrypt/*" {
  capabilities = ["update"]
}

path "ospf-nn-json-transit/decrypt/*" {
  capabilities = ["update"]
}

path "ospf-nn-json-transit/keys/*" {
  capabilities = ["read"]
}

path "ospf-shared/data/keycloak" {
  capabilities = ["read"]
}

path "ospf-impact-planner/*" {
  capabilities = ["deny"]
}

path "ospf-ll-json-part1/*" {
  capabilities = ["deny"]
}

path "ospf-tempo-x/*" {
  capabilities = ["deny"]
}

path "ospf-device-manager/*" {
  capabilities = ["deny"]
}
EOF

# Tempo-X Policy
vault policy write ospf-tempo-x-policy - <<EOF
# OSPF Tempo-X Policy

path "ospf-tempo-x/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ospf-tempo-x/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "ospf-tempo-x-transit/encrypt/*" {
  capabilities = ["update"]
}

path "ospf-tempo-x-transit/decrypt/*" {
  capabilities = ["update"]
}

path "ospf-tempo-x-transit/keys/*" {
  capabilities = ["read"]
}

path "ospf-shared/data/keycloak" {
  capabilities = ["read"]
}

path "ospf-impact-planner/*" {
  capabilities = ["deny"]
}

path "ospf-ll-json-part1/*" {
  capabilities = ["deny"]
}

path "ospf-nn-json/*" {
  capabilities = ["deny"]
}

path "ospf-device-manager/*" {
  capabilities = ["deny"]
}
EOF

# Device Manager Policy (most restricted due to sensitive network credentials)
vault policy write ospf-device-manager-policy - <<EOF
# OSPF Device Manager Policy
# Extra security for network device credentials

path "ospf-device-manager/data/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "ospf-device-manager/metadata/*" {
  capabilities = ["list", "read", "delete"]
}

path "ospf-device-manager-transit/encrypt/*" {
  capabilities = ["update"]
}

path "ospf-device-manager-transit/decrypt/*" {
  capabilities = ["update"]
}

path "ospf-device-manager-transit/keys/*" {
  capabilities = ["read"]
}

path "ospf-shared/data/keycloak" {
  capabilities = ["read"]
}

# Strict denial of all other app secrets
path "ospf-impact-planner/*" {
  capabilities = ["deny"]
}

path "ospf-ll-json-part1/*" {
  capabilities = ["deny"]
}

path "ospf-nn-json/*" {
  capabilities = ["deny"]
}

path "ospf-tempo-x/*" {
  capabilities = ["deny"]
}
EOF

# Admin policy for managing all apps
vault policy write ospf-admin-policy - <<EOF
# OSPF Admin Policy - Full access to all app secrets

path "ospf-*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/*" {
  capabilities = ["read", "list"]
}

path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

# ============================================================================
# Enable OIDC Authentication Method
# ============================================================================

echo ""
echo "=== Enabling OIDC Authentication ==="

vault auth enable oidc 2>/dev/null || echo "OIDC auth already enabled"

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready at ${KC_URL}..."
max_attempts=60
attempt=0
until curl -s "${KC_URL}/health/ready" >/dev/null 2>&1 || [ $attempt -ge $max_attempts ]; do
  echo "Keycloak not ready yet, waiting... (attempt $((attempt+1))/$max_attempts)"
  sleep 3
  attempt=$((attempt+1))
done
if [ $attempt -ge $max_attempts ]; then
  echo "WARNING: Keycloak may not be fully ready, but continuing..."
else
  echo "Keycloak is ready!"
fi

# Note: OIDC configuration should be done after realms are imported
# This is a placeholder - actual configuration requires realm-specific client secrets

echo ""
echo "=== Creating AppRole Authentication for Service Accounts ==="

vault auth enable approle 2>/dev/null || echo "AppRole auth already enabled"

# Create AppRole for each application
for APP in "ospf-impact-planner" "ospf-ll-json-part1" "ospf-nn-json" "ospf-tempo-x" "ospf-device-manager"; do
  echo "Creating AppRole for ${APP}..."

  vault write auth/approle/role/${APP} \
    token_policies="${APP}-policy" \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=24h \
    secret_id_num_uses=0 \
    bind_secret_id=true

  # Get Role ID
  ROLE_ID=$(vault read -field=role_id auth/approle/role/${APP}/role-id)
  echo "Role ID for ${APP}: ${ROLE_ID}"

  # Generate Secret ID
  SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/${APP}/secret-id)
  echo "Secret ID generated for ${APP} (save this securely!)"

  # Store the AppRole credentials in the app's own secrets
  vault kv put ${APP}/approle \
    role_id="${ROLE_ID}" \
    secret_id="${SECRET_ID}"
done

# ============================================================================
# Enable Audit Logging
# ============================================================================

echo ""
echo "=== Enabling Audit Logging ==="

vault audit enable file file_path=/vault/logs/vault-audit.log 2>/dev/null || echo "File audit already enabled"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=============================================="
echo "Vault Initialization Complete!"
echo "=============================================="
echo ""
echo "Created Secrets Mounts:"
echo "  - ospf-impact-planner (KV-V2)"
echo "  - ospf-ll-json-part1 (KV-V2)"
echo "  - ospf-nn-json (KV-V2)"
echo "  - ospf-tempo-x (KV-V2)"
echo "  - ospf-device-manager (KV-V2)"
echo "  - ospf-shared (KV-V2)"
echo ""
echo "Created Transit Engines:"
echo "  - ospf-impact-planner-transit"
echo "  - ospf-ll-json-part1-transit"
echo "  - ospf-nn-json-transit"
echo "  - ospf-tempo-x-transit"
echo "  - ospf-device-manager-transit"
echo ""
echo "Created Policies:"
echo "  - ospf-impact-planner-policy"
echo "  - ospf-ll-json-part1-policy"
echo "  - ospf-nn-json-policy"
echo "  - ospf-tempo-x-policy"
echo "  - ospf-device-manager-policy"
echo "  - ospf-admin-policy"
echo ""
echo "Authentication Methods:"
echo "  - AppRole (for service accounts)"
echo "  - OIDC (configured per-realm with Keycloak)"
echo ""
echo "IMPORTANT: Update the following:"
echo "  1. Database passwords in each app's secrets"
echo "  2. Admin PIN for device-manager"
echo "  3. Router default credentials in device-manager"
echo "  4. Jumphost credentials if needed"
echo "  5. OIDC client secrets from Keycloak"
echo ""
echo "=============================================="
