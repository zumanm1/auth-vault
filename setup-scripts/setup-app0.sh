#!/bin/bash
#===============================================================================
# Setup Script for App0: Auth-Vault (Keycloak + HashiCorp Vault)
# Purpose: Install, configure, and start Auth-Vault services
# Ports: Keycloak (9120), Vault (9121)
# Author: OSPF Suite DevOps
# Version: 1.0.0
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP0_DIR="$(dirname "$SCRIPT_DIR")"
APPS_ROOT="$(dirname "$APP0_DIR")"

# Configuration
APP_NAME="App0 - Auth-Vault"
KEYCLOAK_PORT=9120
VAULT_PORT=9121

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_progress() {
    echo -e "${CYAN}[PROGRESS]${NC} $APP_NAME: $1"
}

#-------------------------------------------------------------------------------
# Check if service is running
#-------------------------------------------------------------------------------
check_port() {
    local port=$1
    lsof -i :$port >/dev/null 2>&1
}

#-------------------------------------------------------------------------------
# Install Auth-Vault
#-------------------------------------------------------------------------------
install_app() {
    log_header "Installing $APP_NAME"
    log_progress "Starting installation..."

    cd "$APP0_DIR"

    if [ -f "./auth-vault.sh" ]; then
        log_step "Running auth-vault.sh install..."
        ./auth-vault.sh install
        log_success "Installation completed"
    else
        log_error "auth-vault.sh not found in $APP0_DIR"
        return 1
    fi

    log_progress "Installation complete"
}

#-------------------------------------------------------------------------------
# Initialize Vault
#-------------------------------------------------------------------------------
init_vault() {
    log_header "Initializing Vault"
    log_progress "Initializing Vault secrets engine..."

    cd "$APP0_DIR"

    if [ -f "./auth-vault.sh" ]; then
        log_step "Running auth-vault.sh init..."
        ./auth-vault.sh init || true
        log_success "Vault initialized"
    fi

    log_progress "Vault initialization complete"
}

#-------------------------------------------------------------------------------
# Start Auth-Vault Services
#-------------------------------------------------------------------------------
start_app() {
    log_header "Starting $APP_NAME Services"
    log_progress "Starting services..."

    cd "$APP0_DIR"

    if [ -f "./auth-vault.sh" ]; then
        log_step "Running auth-vault.sh start..."
        ./auth-vault.sh start

        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 15

        log_success "Services started"
    else
        log_error "auth-vault.sh not found"
        return 1
    fi

    log_progress "Services started"
}

#-------------------------------------------------------------------------------
# Stop Auth-Vault Services
#-------------------------------------------------------------------------------
stop_app() {
    log_header "Stopping $APP_NAME Services"
    log_progress "Stopping services..."

    cd "$APP0_DIR"

    if [ -f "./auth-vault.sh" ]; then
        ./auth-vault.sh stop
        log_success "Services stopped"
    fi

    log_progress "Services stopped"
}

#-------------------------------------------------------------------------------
# Check Status
#-------------------------------------------------------------------------------
status_app() {
    log_header "$APP_NAME Status"

    echo -e "  Keycloak (${KEYCLOAK_PORT}): $(check_port $KEYCLOAK_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"
    echo -e "  Vault (${VAULT_PORT}): $(check_port $VAULT_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"

    # Check if Vault is sealed
    if check_port $VAULT_PORT; then
        local vault_status=$(curl -s http://localhost:$VAULT_PORT/v1/sys/health 2>/dev/null || echo '{}')
        local sealed=$(echo "$vault_status" | grep -o '"sealed":[^,}]*' | cut -d: -f2)
        if [ "$sealed" = "true" ]; then
            echo -e "  Vault State: ${YELLOW}Sealed${NC}"
        else
            echo -e "  Vault State: ${GREEN}Unsealed${NC}"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Full Setup (Install + Start + Init)
#-------------------------------------------------------------------------------
full_setup() {
    log_header "Full Setup: $APP_NAME"
    log_progress "Starting full setup..."

    # Step 1: Install
    install_app

    # Step 2: Start
    start_app

    # Step 3: Initialize Vault
    init_vault

    # Step 4: Show status
    status_app

    # Display credentials if available
    if [ -f "$APP0_DIR/data/vault/vault-keys.json" ]; then
        echo ""
        echo -e "${CYAN}============================================================${NC}"
        echo -e "${CYAN}                    VAULT CREDENTIALS${NC}"
        echo -e "${CYAN}============================================================${NC}"

        local unseal_key=$(grep -o '"unseal_keys_b64".*\[.*"[^"]*"' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null | grep -o '"[A-Za-z0-9+/=]*"$' | tr -d '"')
        local root_token=$(grep -o '"root_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

        echo -e "  ${YELLOW}Vault Unseal Key:${NC} $unseal_key"
        echo -e "  ${YELLOW}Vault Root Token:${NC} $root_token"
        echo ""
        echo -e "  Keys file: $APP0_DIR/data/vault/vault-keys.json"
        echo ""
        echo -e "${CYAN}============================================================${NC}"
        echo -e "${CYAN}                    SERVICE URLs${NC}"
        echo -e "${CYAN}============================================================${NC}"
        echo ""
        echo -e "  ${GREEN}Keycloak Admin Console:${NC} http://localhost:$KEYCLOAK_PORT/admin"
        echo -e "    - Username: admin"
        echo -e "    - Password: admin"
        echo ""
        echo -e "  ${GREEN}Vault UI:${NC} http://localhost:$VAULT_PORT/ui"
        echo -e "    - Token: $root_token"
        echo ""
    fi

    log_success "$APP_NAME full setup completed!"
    log_progress "Full setup complete"
}

#-------------------------------------------------------------------------------
# Show Help
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}Setup Script for $APP_NAME${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  install    Install Auth-Vault dependencies"
    echo "  start      Start Keycloak and Vault services"
    echo "  stop       Stop all services"
    echo "  init       Initialize Vault secrets"
    echo "  status     Show service status"
    echo "  setup      Full setup (install + start + init)"
    echo "  help       Show this help message"
    echo ""
    echo "Ports:"
    echo "  Keycloak: $KEYCLOAK_PORT"
    echo "  Vault:    $VAULT_PORT"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local command=${1:-setup}

    case "$command" in
        install)
            install_app
            ;;
        start)
            start_app
            ;;
        stop)
            stop_app
            ;;
        init)
            init_vault
            ;;
        status)
            status_app
            ;;
        setup)
            full_setup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
