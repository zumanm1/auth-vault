#!/bin/bash
#===============================================================================
# Setup Script for App1: OSPF Impact Planner
# Purpose: Install, configure, and start Impact Planner services
# Ports: Frontend (9090), Backend API (9091)
# GitHub: https://github.com/zumanm1/ospf-impact-planner
# Author: OSPF Suite DevOps
# Version: 1.1.0
#
# Features:
#   - Network infrastructure impact analysis
#   - Cost planning and optimization
#   - Multi-site network modeling
#   - Integration with Auth-Vault for authentication
#
# Prerequisites:
#   - Node.js v18+ (v20+ recommended)
#   - PostgreSQL 14+
#   - npm or yarn
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
APP1_DIR="$APPS_ROOT/app1-impact-planner"

# Configuration
APP_NAME="App1 - Impact Planner"
FRONTEND_PORT=9090
BACKEND_PORT=9091
GITHUB_REPO="https://github.com/zumanm1/ospf-impact-planner"
DB_NAME="ospf_planner"

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
    local JWT_SECRET=$(openssl rand -hex 32 2>/dev/null)
    local ADMIN_PASS="V3ry\$trongAdm1n!$(date +%Y)"
    echo "$JWT_SECRET|$ADMIN_PASS"
}

#-------------------------------------------------------------------------------
# Clone or verify repository
#-------------------------------------------------------------------------------
ensure_repo() {
    log_step "Checking App1 repository..."

    if [ ! -d "$APP1_DIR" ]; then
        log_info "App1 directory not found. Cloning from GitHub..."
        cd "$APPS_ROOT"
        git clone "$GITHUB_REPO" app1-impact-planner
        log_success "Repository cloned successfully"
    elif [ ! -f "$APP1_DIR/ospf-planner.sh" ]; then
        log_warning "App1 directory exists but appears incomplete"
        log_info "Re-cloning repository..."
        rm -rf "$APP1_DIR"
        cd "$APPS_ROOT"
        git clone "$GITHUB_REPO" app1-impact-planner
        log_success "Repository re-cloned successfully"
    else
        log_success "App1 repository verified"
    fi
}

#-------------------------------------------------------------------------------
# Install Impact Planner
#-------------------------------------------------------------------------------
install_app() {
    log_header "Installing $APP_NAME"
    log_progress "Starting installation..."

    # Ensure repository exists
    ensure_repo

    cd "$APP1_DIR"

    if [ -f "./ospf-planner.sh" ]; then
        log_step "Running ospf-planner.sh install..."
        chmod +x ./ospf-planner.sh
        ./ospf-planner.sh install 2>/dev/null || log_warning "Install script returned non-zero (may be OK)"

        log_step "Installing frontend dependencies..."
        # Clean install to avoid corrupted node_modules
        if [ -d "node_modules" ] && [ ! -f "node_modules/.package-lock.json" ]; then
            log_warning "Detected potentially corrupted node_modules, reinstalling..."
            rm -rf node_modules
        fi
        npm install --silent 2>/dev/null || npm install
        log_success "Frontend dependencies installed"

        # Install server dependencies
        if [ -d "server" ]; then
            log_step "Installing server dependencies..."
            cd server
            if [ -d "node_modules" ] && [ ! -f "node_modules/.package-lock.json" ]; then
                log_warning "Detected potentially corrupted server node_modules, reinstalling..."
                rm -rf node_modules
            fi
            npm install --silent 2>/dev/null || npm install
            cd "$APP1_DIR"
            log_success "Server dependencies installed"
        fi

        # Create server .env file with correct port
        log_step "Configuring server environment..."
        local creds=$(generate_credentials)
        local JWT_SECRET=$(echo "$creds" | cut -d'|' -f1)
        local ADMIN_PASS=$(echo "$creds" | cut -d'|' -f2)
        local DB_USER=$(whoami)

        mkdir -p "$APP1_DIR/server"
        cat > "$APP1_DIR/server/.env" << EOF
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=

# Server Configuration
PORT=$BACKEND_PORT
NODE_ENV=development
SERVER_HOST=0.0.0.0

# IP Whitelist - Allow all IPs (development mode)
ALLOWED_IPS=0.0.0.0

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

# CORS - Allow all origins
CORS_ORIGINS=*

# Auth-Vault Integration (optional)
AUTH_VAULT_URL=http://localhost:9121
AUTH_VAULT_ENABLED=false
EOF
        log_success "Server .env configured (port: $BACKEND_PORT)"

        # Setup database if PostgreSQL is available
        if command -v psql &> /dev/null; then
            log_step "Setting up database..."
            if psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
                log_info "Database '$DB_NAME' already exists"
            else
                createdb "$DB_NAME" 2>/dev/null && log_success "Database '$DB_NAME' created" || log_warning "Could not create database (may already exist)"
            fi
        else
            log_warning "PostgreSQL not found - skipping database setup"
        fi

        log_success "Installation completed"
    else
        log_error "ospf-planner.sh not found in $APP1_DIR"
        log_info "Try running: git clone $GITHUB_REPO $APP1_DIR"
        return 1
    fi

    log_progress "Installation complete"
}

#-------------------------------------------------------------------------------
# Start Impact Planner Services
#-------------------------------------------------------------------------------
start_app() {
    log_header "Starting $APP_NAME Services"
    log_progress "Starting services..."

    cd "$APP1_DIR"

    if [ -f "./ospf-planner.sh" ]; then
        log_step "Running ospf-planner.sh start..."
        ./ospf-planner.sh start

        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 10

        log_success "Services started"
    else
        log_error "ospf-planner.sh not found"
        return 1
    fi

    log_progress "Services started"
}

#-------------------------------------------------------------------------------
# Stop Impact Planner Services
#-------------------------------------------------------------------------------
stop_app() {
    log_header "Stopping $APP_NAME Services"
    log_progress "Stopping services..."

    cd "$APP1_DIR"

    if [ -f "./ospf-planner.sh" ]; then
        ./ospf-planner.sh stop
        log_success "Services stopped"
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

    # Display access info
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    SERVICE URLs${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${GREEN}Impact Planner Frontend:${NC} http://localhost:$FRONTEND_PORT"
    echo -e "  ${GREEN}Impact Planner API:${NC} http://localhost:$BACKEND_PORT"
    echo ""

    log_success "$APP_NAME full setup completed!"
    log_progress "Full setup complete"
}

#-------------------------------------------------------------------------------
# Show Help
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           App1 - OSPF Impact Planner Setup                    ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Description:${NC}"
    echo "  Network infrastructure impact analysis and cost planning tool."
    echo "  Provides multi-site network modeling with Auth-Vault integration."
    echo ""
    echo -e "${GREEN}Usage:${NC} $0 <command>"
    echo ""
    echo -e "${GREEN}Commands:${NC}"
    echo "  install    Install Impact Planner and all dependencies"
    echo "  start      Start frontend (9090) and backend API (9091) services"
    echo "  stop       Stop all running services"
    echo "  status     Show current service status and health"
    echo "  setup      Full setup (install + start) - Recommended for first run"
    echo "  help       Show this help message"
    echo ""
    echo -e "${GREEN}Ports:${NC}"
    echo "  Frontend: http://localhost:$FRONTEND_PORT"
    echo "  Backend:  http://localhost:$BACKEND_PORT"
    echo "  API Health: http://localhost:$BACKEND_PORT/api/health"
    echo ""
    echo -e "${GREEN}Default Credentials:${NC}"
    echo "  Username: netviz_admin"
    echo "  Password: V3ry\$trongAdm1n!2025"
    echo ""
    echo -e "${GREEN}GitHub:${NC} $GITHUB_REPO"
    echo ""
    echo -e "${GREEN}Examples:${NC}"
    echo "  ./setup-app1.sh setup      # First time setup"
    echo "  ./setup-app1.sh start      # Start services"
    echo "  ./setup-app1.sh status     # Check if running"
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
