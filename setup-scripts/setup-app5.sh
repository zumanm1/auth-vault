#!/bin/bash
#===============================================================================
# Setup Script for App5: Device Manager
# Purpose: Install, configure, and start Device Manager services
# Ports: Frontend (9050), Backend API (9051)
# Backend: Python/FastAPI
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
APP5_DIR="$APPS_ROOT/app5-device-manager"

# Configuration
APP_NAME="App5 - Device Manager"
FRONTEND_PORT=9050
BACKEND_PORT=9051

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
    local SECRET_KEY=$(openssl rand -hex 32 2>/dev/null)
    local ADMIN_PASS="V3ry\$trongAdm1n!$(date +%Y)"
    echo "$SECRET_KEY|$ADMIN_PASS"
}

#-------------------------------------------------------------------------------
# Install Device Manager
#-------------------------------------------------------------------------------
install_app() {
    log_header "Installing $APP_NAME"
    log_progress "Starting installation..."

    cd "$APP5_DIR"

    if [ -f "./install.sh" ]; then
        log_step "Running install.sh..."
        chmod +x ./install.sh
        ./install.sh

        # Generate new credentials for fresh install
        log_step "Generating secure credentials..."
        local creds=$(generate_credentials)
        local SECRET_KEY=$(echo "$creds" | cut -d'|' -f1)
        local ADMIN_PASS=$(echo "$creds" | cut -d'|' -f2)

        # Create/update backend/.env with new credentials
        if [ -d "backend" ]; then
            cat > backend/.env << EOF
# Device Manager Backend Configuration
# Auto-generated on $(date)

#-------------------------------------------------------------------------------
# Server Configuration
#-------------------------------------------------------------------------------
HOST=0.0.0.0
PORT=$BACKEND_PORT
DEBUG=false
ENVIRONMENT=production

#-------------------------------------------------------------------------------
# Security (Renewed on fresh install)
#-------------------------------------------------------------------------------
SECRET_KEY=${SECRET_KEY}
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440

#-------------------------------------------------------------------------------
# Admin Credentials (Renewed on fresh install)
#-------------------------------------------------------------------------------
ADMIN_USERNAME=netviz_admin
ADMIN_PASSWORD=${ADMIN_PASS}

#-------------------------------------------------------------------------------
# Database
#-------------------------------------------------------------------------------
DATABASE_URL=sqlite:///./data/devices.db

#-------------------------------------------------------------------------------
# CORS
#-------------------------------------------------------------------------------
ALLOWED_ORIGINS=http://localhost:$FRONTEND_PORT,http://127.0.0.1:$FRONTEND_PORT
EOF
            log_success "Generated new backend/.env with fresh credentials"
        fi

        # Store credentials for display
        echo "$ADMIN_PASS" > /tmp/.devmgr_admin_pass_$$

        log_success "Installation completed"
    else
        log_error "install.sh not found in $APP5_DIR"
        return 1
    fi

    log_progress "Installation complete"
}

#-------------------------------------------------------------------------------
# Start Device Manager Services
#-------------------------------------------------------------------------------
start_app() {
    log_header "Starting $APP_NAME Services"
    log_progress "Starting services..."

    cd "$APP5_DIR"

    if [ -f "./start.sh" ]; then
        log_step "Running start.sh --force..."
        chmod +x ./start.sh
        ./start.sh --force

        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 8

        log_success "Services started"
    else
        log_error "start.sh not found"
        return 1
    fi

    log_progress "Services started"
}

#-------------------------------------------------------------------------------
# Stop Device Manager Services
#-------------------------------------------------------------------------------
stop_app() {
    log_header "Stopping $APP_NAME Services"
    log_progress "Stopping services..."

    cd "$APP5_DIR"

    if [ -f "./stop.sh" ]; then
        chmod +x ./stop.sh
        ./stop.sh
        log_success "Services stopped"
    else
        # Fallback: kill by port
        for port in $FRONTEND_PORT $BACKEND_PORT; do
            local pids=$(lsof -ti:$port 2>/dev/null || true)
            if [ -n "$pids" ]; then
                echo "$pids" | xargs kill -9 2>/dev/null || true
            fi
        done
        log_success "Services stopped (fallback)"
    fi

    log_progress "Services stopped"
}

#-------------------------------------------------------------------------------
# Check Status
#-------------------------------------------------------------------------------
status_app() {
    log_header "$APP_NAME Status"

    echo -e "  Frontend (${FRONTEND_PORT}): $(check_port $FRONTEND_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"
    echo -e "  Backend (${BACKEND_PORT}): $(check_port $BACKEND_PORT && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")"

    # Check API health
    if check_port $BACKEND_PORT; then
        local health=$(curl -s http://localhost:$BACKEND_PORT/api/health 2>/dev/null || echo '{}')
        if echo "$health" | grep -q "ok\|healthy\|status"; then
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
    echo -e "  ${GREEN}Device Manager Frontend:${NC} http://localhost:$FRONTEND_PORT"
    echo -e "  ${GREEN}Device Manager API:${NC} http://localhost:$BACKEND_PORT"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    CREDENTIALS${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Username:${NC} netviz_admin"
    if [ -f /tmp/.devmgr_admin_pass_$$ ]; then
        local admin_pass=$(cat /tmp/.devmgr_admin_pass_$$)
        echo -e "  ${YELLOW}Password:${NC} $admin_pass"
        rm -f /tmp/.devmgr_admin_pass_$$
    else
        echo -e "  ${YELLOW}Password:${NC} (see backend/.env)"
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
    echo "  install    Install Device Manager dependencies"
    echo "  start      Start frontend and backend services"
    echo "  stop       Stop all services"
    echo "  status     Show service status"
    echo "  setup      Full setup (install + start)"
    echo "  help       Show this help message"
    echo ""
    echo "Ports:"
    echo "  Frontend: $FRONTEND_PORT"
    echo "  Backend:  $BACKEND_PORT (Python/FastAPI)"
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
