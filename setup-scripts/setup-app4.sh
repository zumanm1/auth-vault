#!/bin/bash
#===============================================================================
# Setup Script for App4: OSPF Tempo-X
# Purpose: Install, configure, and start Tempo-X services
# Ports: Frontend (9100), Backend API (9101)
# Database: PostgreSQL (ospf_tempo_x)
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
APP4_DIR="$APPS_ROOT/app4-tempo-x"

# Configuration
APP_NAME="App4 - Tempo-X"
FRONTEND_PORT=9100
BACKEND_PORT=9101
DB_NAME="ospf_tempo_x"

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
# Install Tempo-X
#-------------------------------------------------------------------------------
install_app() {
    log_header "Installing $APP_NAME"
    log_progress "Starting installation..."

    cd "$APP4_DIR"

    if [ -f "./ospf-tempo-x.sh" ]; then
        log_step "Running ospf-tempo-x.sh install..."
        chmod +x ./ospf-tempo-x.sh
        ./ospf-tempo-x.sh install

        log_step "Installing dependencies..."
        ./ospf-tempo-x.sh deps

        # Generate new credentials for fresh install
        log_step "Generating secure credentials..."
        local creds=$(generate_credentials)
        local JWT_SECRET=$(echo "$creds" | cut -d'|' -f1)
        local ADMIN_PASS=$(echo "$creds" | cut -d'|' -f2)

        # Create/update .env with new credentials
        if [ ! -f ".env" ] || grep -q "your-secret-key-here\|change-me" .env 2>/dev/null; then
            cat > .env << EOF
# Tempo-X Environment Configuration
# Auto-generated on $(date)

#-------------------------------------------------------------------------------
# Server Configuration
#-------------------------------------------------------------------------------
VITE_PORT=$FRONTEND_PORT
API_PORT=$BACKEND_PORT
NODE_ENV=development
SERVER_HOST=0.0.0.0
ALLOWED_IPS=0.0.0.0

#-------------------------------------------------------------------------------
# Database Configuration
#-------------------------------------------------------------------------------
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=$(whoami)
DB_PASSWORD=

#-------------------------------------------------------------------------------
# JWT Configuration (Renewed on fresh install)
#-------------------------------------------------------------------------------
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d

#-------------------------------------------------------------------------------
# Admin Credentials (Renewed on fresh install)
#-------------------------------------------------------------------------------
ADMIN_USERNAME=netviz_admin
ADMIN_PASSWORD=${ADMIN_PASS}
EOF
            log_success "Generated new .env with fresh credentials"
        fi

        # Store credentials for display
        echo "$ADMIN_PASS" > /tmp/.tempox_admin_pass_$$

        log_success "Installation completed"
    else
        log_error "ospf-tempo-x.sh not found in $APP4_DIR"
        return 1
    fi

    log_progress "Installation complete"
}

#-------------------------------------------------------------------------------
# Setup Database
#-------------------------------------------------------------------------------
setup_db() {
    log_header "Setting up Database for $APP_NAME"
    log_progress "Setting up PostgreSQL database..."

    cd "$APP4_DIR"

    if [ -f "./ospf-tempo-x.sh" ]; then
        log_step "Running ospf-tempo-x.sh db-setup..."
        ./ospf-tempo-x.sh db-setup || log_warning "Database setup may require manual configuration"
        log_success "Database setup completed"
    else
        log_warning "ospf-tempo-x.sh not found, skipping database setup"
    fi

    log_progress "Database setup complete"
}

#-------------------------------------------------------------------------------
# Start Tempo-X Services
#-------------------------------------------------------------------------------
start_app() {
    log_header "Starting $APP_NAME Services"
    log_progress "Starting services..."

    cd "$APP4_DIR"

    if [ -f "./ospf-tempo-x.sh" ]; then
        log_step "Running ospf-tempo-x.sh start..."
        ./ospf-tempo-x.sh start

        # Wait for services to be ready
        log_info "Waiting for services to be ready..."
        sleep 10

        log_success "Services started"
    else
        log_error "ospf-tempo-x.sh not found"
        return 1
    fi

    log_progress "Services started"
}

#-------------------------------------------------------------------------------
# Stop Tempo-X Services
#-------------------------------------------------------------------------------
stop_app() {
    log_header "Stopping $APP_NAME Services"
    log_progress "Stopping services..."

    cd "$APP4_DIR"

    if [ -f "./ospf-tempo-x.sh" ]; then
        ./ospf-tempo-x.sh stop
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

    # Check PostgreSQL
    if command -v pg_isready &>/dev/null; then
        if pg_isready -q 2>/dev/null; then
            echo -e "  PostgreSQL: ${GREEN}Running${NC}"
        else
            echo -e "  PostgreSQL: ${RED}Not Running${NC}"
        fi
    fi

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
# Full Setup (Install + DB Setup + Start)
#-------------------------------------------------------------------------------
full_setup() {
    log_header "Full Setup: $APP_NAME"
    log_progress "Starting full setup..."

    # Step 1: Install
    install_app

    # Step 2: Setup Database
    setup_db

    # Step 3: Start
    start_app

    # Step 4: Show status
    status_app

    # Display access info and credentials
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    SERVICE URLs${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${GREEN}Tempo-X Frontend:${NC} http://localhost:$FRONTEND_PORT"
    echo -e "  ${GREEN}Tempo-X API:${NC} http://localhost:$BACKEND_PORT"
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    CREDENTIALS${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Username:${NC} netviz_admin"
    if [ -f /tmp/.tempox_admin_pass_$$ ]; then
        local admin_pass=$(cat /tmp/.tempox_admin_pass_$$)
        echo -e "  ${YELLOW}Password:${NC} $admin_pass"
        rm -f /tmp/.tempox_admin_pass_$$
    else
        echo -e "  ${YELLOW}Password:${NC} (see .env)"
    fi
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}                    DATABASE${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}Database:${NC} $DB_NAME"
    echo -e "  ${YELLOW}Host:${NC} localhost:5432"
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
    echo "  install    Install Tempo-X dependencies"
    echo "  db-setup   Setup PostgreSQL database"
    echo "  start      Start frontend and backend services"
    echo "  stop       Stop all services"
    echo "  status     Show service status"
    echo "  setup      Full setup (install + db-setup + start)"
    echo "  help       Show this help message"
    echo ""
    echo "Ports:"
    echo "  Frontend: $FRONTEND_PORT"
    echo "  Backend:  $BACKEND_PORT"
    echo "  Database: PostgreSQL ($DB_NAME)"
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
        db-setup)
            setup_db
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
