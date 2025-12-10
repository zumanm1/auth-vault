#!/bin/bash
#===============================================================================
# Setup Script for App2: NetViz Pro
# Purpose: Install, configure, and start NetViz Pro services
# Ports: Gateway (9040), Auth API (9041), Vite Dev (9042)
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
APP2_DIR="$APPS_ROOT/app2-netviz-pro/netviz-pro"

# Configuration
APP_NAME="App2 - NetViz Pro"
GATEWAY_PORT=9040
AUTH_PORT=9041
VITE_PORT=9042

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_header() {
    echo ""
    echo -e "${CYAN}+==============================================================+${NC}"
    echo -e "${CYAN}|  $1${NC}"
    echo -e "${CYAN}+==============================================================+${NC}"
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
# Generate secure credentials
#-------------------------------------------------------------------------------
generate_credentials() {
    # Generate secure random values
    local SECRET_KEY=$(openssl rand -base64 32 2>/dev/null | tr -d '/+=' | head -c 32)
    local RESET_PIN=$(openssl rand -hex 8 2>/dev/null)
    local ADMIN_PASS="V3ry\$trongAdm1n!$(date +%Y)"

    echo "$SECRET_KEY|$RESET_PIN|$ADMIN_PASS"
}

#-------------------------------------------------------------------------------
# Install NetViz Pro
#-------------------------------------------------------------------------------
install_app() {
    log_header "Installing $APP_NAME"
    log_progress "Starting installation..."

    cd "$APP2_DIR"

    if [ -f "./netviz.sh" ]; then
        log_step "Running netviz.sh install..."
        chmod +x ./netviz.sh
        ./netviz.sh install

        log_step "Installing dependencies..."
        ./netviz.sh deps

        # Generate new credentials for fresh install
        log_step "Generating secure credentials..."
        local creds=$(generate_credentials)
        local SECRET_KEY=$(echo "$creds" | cut -d'|' -f1)
        local RESET_PIN=$(echo "$creds" | cut -d'|' -f2)
        local ADMIN_PASS=$(echo "$creds" | cut -d'|' -f3)

        # Create/update .env.local with new credentials
        cat > .env.local << EOF
# NetViz Pro Environment Configuration
# Auto-generated on $(date)

# ==============================================================================
# SECURITY - AUTO-GENERATED (Renewed on each fresh install)
# ==============================================================================
APP_SECRET_KEY=${SECRET_KEY}
ADMIN_RESET_PIN=${RESET_PIN}

# ==============================================================================
# ADMIN ACCOUNT
# ==============================================================================
APP_ADMIN_USERNAME=netviz_admin
APP_ADMIN_PASSWORD=${ADMIN_PASS}

# ==============================================================================
# SERVER CONFIGURATION
# ==============================================================================
AUTH_PORT=9041
GATEWAY_PORT=9040
VITE_INTERNAL_PORT=9042
APP_SESSION_TIMEOUT=3600
SERVER_HOST=0.0.0.0
LOCALHOST_ONLY=false

# ==============================================================================
# IP ACCESS CONTROL
# ==============================================================================
ALLOWED_IPS=0.0.0.0
EOF

        log_success "Installation completed"

        # Store credentials for display
        echo "$ADMIN_PASS" > /tmp/.netviz_admin_pass_$$
    else
        log_error "netviz.sh not found in $APP2_DIR"
        return 1
    fi

    log_progress "Installation complete"
}

#-------------------------------------------------------------------------------
# Start NetViz Pro Services
#-------------------------------------------------------------------------------
start_app() {
    log_header "Starting $APP_NAME Services"
    log_progress "Starting services..."

    cd "$APP2_DIR"

    if [ -f "./netviz.sh" ]; then
        log_step "Running netviz.sh start..."
        ./netviz.sh start

        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 10

        log_success "Services started"
    else
        log_error "netviz.sh not found"
        return 1
    fi

    log_progress "Services started"
}

#-------------------------------------------------------------------------------
# Stop NetViz Pro Services
#-------------------------------------------------------------------------------
stop_app() {
    log_header "Stopping $APP_NAME Services"
    log_progress "Stopping services..."

    cd "$APP2_DIR"

    if [ -f "./netviz.sh" ]; then
        ./netviz.sh stop
        log_success "Services stopped"
    fi

    log_progress "Services stopped"
}

#-------------------------------------------------------------------------------
# Check Status
#-------------------------------------------------------------------------------
status_app() {
    log_header "$APP_NAME Status"

    echo -e "  Gateway (${GATEWAY_PORT}): $(check_port $GATEWAY_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"
    echo -e "  Auth API (${AUTH_PORT}): $(check_port $AUTH_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"
    echo -e "  Vite Dev (${VITE_PORT}): $(check_port $VITE_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"

    # Check API health
    if check_port $AUTH_PORT; then
        local health=$(curl -s http://localhost:$AUTH_PORT/api/health 2>/dev/null || echo '{}')
        if echo "$health" | grep -q "ok\|healthy"; then
            echo -e "  API Health: ${GREEN}Healthy${NC}"
        else
            echo -e "  API Health: ${YELLOW}Unknown${NC}"
        fi
    fi
}

#-------------------------------------------------------------------------------
# Full Setup (Install + Start)
#-------------------------------------------------------------------------------
full_setup() {
    log_header "Full Setup: $APP_NAME"
    log_progress "Starting full setup..."

    # Step 1: Install
    install_app

    # Step 2: Start
    start_app

    # Step 3: Show status
    status_app

    # Display access info and credentials
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    SERVICE URLs${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${GREEN}NetViz Pro Gateway:${NC} http://localhost:$GATEWAY_PORT"
    echo -e "  ${GREEN}Auth API:${NC} http://localhost:$AUTH_PORT"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    CREDENTIALS${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Username:${NC} netviz_admin"
    if [ -f /tmp/.netviz_admin_pass_$$ ]; then
        local admin_pass=$(cat /tmp/.netviz_admin_pass_$$)
        echo -e "  ${YELLOW}Password:${NC} $admin_pass"
        rm -f /tmp/.netviz_admin_pass_$$
    else
        echo -e "  ${YELLOW}Password:${NC} (see .env.local)"
    fi
    echo ""

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
    echo "  install    Install NetViz Pro dependencies"
    echo "  start      Start Gateway, Auth, and Vite servers"
    echo "  stop       Stop all services"
    echo "  status     Show service status"
    echo "  setup      Full setup (install + start)"
    echo "  help       Show this help message"
    echo ""
    echo "Ports:"
    echo "  Gateway:  $GATEWAY_PORT"
    echo "  Auth API: $AUTH_PORT"
    echo "  Vite:     $VITE_PORT"
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
