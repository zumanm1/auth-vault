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
KC_STATUS=$(curl -s http://localhost:$KEYCLOAK_PORT/health/ready 2>/dev/null | grep -o '"status":"[^"]*"' | head -1 || echo "")
VAULT_STATUS=$(curl -s http://localhost:$VAULT_PORT/v1/sys/health 2>/dev/null | grep -o '"initialized":true' || echo "")

if [ -n "$KC_STATUS" ]; then
    echo -e "  ${GREEN}✓ Keycloak: UP${NC}"
else
    echo -e "  ${YELLOW}⚠ Keycloak: Starting...${NC}"
fi

if [ -n "$VAULT_STATUS" ]; then
    echo -e "  ${GREEN}✓ Vault: UP${NC}"
else
    echo -e "  ${YELLOW}⚠ Vault: Starting...${NC}"
fi

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
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

# -----------------------------------------------------------------------------
# Step 6: Configure Environment
# -----------------------------------------------------------------------------
echo -e "\n${YELLOW}[6/7] Configuring environment...${NC}"

# Create .env.local if it doesn't exist
if [ ! -f .env.local ]; then
    if [ -f .env.local.example ]; then
        cp .env.local.example .env.local
        echo -e "${GREEN}✓ Created .env.local from template${NC}"
    else
        touch .env.local
        echo -e "${GREEN}✓ Created empty .env.local${NC}"
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
    
    # Start in background
    nohup ./start.sh > /tmp/netviz-pro.log 2>&1 &
    
    # Wait for startup
    echo -n "Waiting for NetViz Pro to start..."
    for i in {1..30}; do
        if lsof -i :$GATEWAY_PORT > /dev/null 2>&1; then
            echo -e " ${GREEN}✓ Started${NC}"
            break
        fi
        sleep 1
        echo -n "."
    done
    
    if ! lsof -i :$GATEWAY_PORT > /dev/null 2>&1; then
        echo -e "\n${YELLOW}⚠ NetViz Pro may still be starting. Check logs: tail -f /tmp/netviz-pro.log${NC}"
    fi
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
echo -e "  • Keycloak Admin: admin / SecureAdm1n!2025"
echo -e "  • NetViz Pro: See .env.local for credentials"
echo ""

# Show health check
echo -e "${BLUE}Health Check:${NC}"
HEALTH=$(curl -s http://localhost:9041/api/health 2>/dev/null || echo '{"status":"starting"}')
echo "  $HEALTH"
echo ""
