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
# Setup PostgreSQL password for current user
#-------------------------------------------------------------------------------
setup_postgres_password() {
    local DB_USER=$(whoami)
    local DB_PASS="${DB_USER}"  # Use username as default password for simplicity

    # Log to stderr so it doesn't get captured by command substitution
    echo -e "${BLUE}[STEP]${NC} Setting up PostgreSQL password for user: $DB_USER" >&2

    # Check if we can connect without password (peer auth)
    if sudo -u postgres psql -c "SELECT 1" >/dev/null 2>&1; then
        # Set password for the user
        sudo -u postgres psql -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';" >/dev/null 2>&1 || {
            # User might not exist, create it
            sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;" >/dev/null 2>&1 || true
        }
        echo -e "${GREEN}[SUCCESS]${NC} PostgreSQL password configured for user: $DB_USER" >&2
        echo "$DB_PASS"
    else
        echo -e "${YELLOW}[WARNING]${NC} Could not configure PostgreSQL password (sudo access may be required)" >&2
        echo "$DB_PASS"  # Still return the password even if we couldn't set it
    fi
}

#-------------------------------------------------------------------------------
# Install Tempo-X
#-------------------------------------------------------------------------------
install_app() {
    log_header "Installing $APP_NAME"
    log_progress "Starting installation..."

    cd "$APP4_DIR"

    # Try using ospf-tempo-x.sh first, fallback to direct npm install
    if [ -f "./ospf-tempo-x.sh" ]; then
        log_step "Running ospf-tempo-x.sh install..."
        chmod +x ./ospf-tempo-x.sh
        ./ospf-tempo-x.sh install 2>/dev/null || log_warning "ospf-tempo-x.sh install returned non-zero (continuing...)"

        log_step "Installing dependencies..."
        ./ospf-tempo-x.sh deps 2>/dev/null || {
            log_warning "ospf-tempo-x.sh deps failed, using fallback npm install..."
            npm install --silent 2>/dev/null || npm install
        }
    else
        # Fallback: direct npm install if ospf-tempo-x.sh not found
        log_warning "ospf-tempo-x.sh not found, using direct npm install..."
        npm install --silent 2>/dev/null || npm install
    fi

    # Ensure node_modules exists
    if [ ! -d "node_modules" ]; then
        log_step "Installing npm dependencies (final fallback)..."
        npm install
    fi
    log_success "Dependencies installed"

    # Generate new credentials for fresh install
    log_step "Generating secure credentials..."
    local creds=$(generate_credentials)
    local JWT_SECRET=$(echo "$creds" | cut -d'|' -f1)
    local ADMIN_PASS=$(echo "$creds" | cut -d'|' -f2)
    local DB_USER=$(whoami)
    local DB_PASSWORD=$(setup_postgres_password)

    # Always create/update .env to ensure correct configuration
    # This fixes the issue where .env.example has placeholder values
    log_step "Creating .env configuration file..."

    # If .env.example exists, use it as base, otherwise create from scratch
    if [ -f ".env.example" ] && [ ! -f ".env" ]; then
        cp .env.example .env
        # Replace placeholder values with actual credentials
        sed -i "s/your_postgres_user/$DB_USER/g" .env 2>/dev/null || sed -i '' "s/your_postgres_user/$DB_USER/g" .env
        sed -i "s/your_postgres_password/$DB_PASSWORD/g" .env 2>/dev/null || sed -i '' "s/your_postgres_password/$DB_PASSWORD/g" .env
        log_success "Created .env from .env.example with credentials"
    fi

    # Create/update .env with new credentials (overwrites if needed)
    if [ ! -f ".env" ] || grep -q "your-secret-key-here\|change-me\|your_postgres" .env 2>/dev/null; then
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
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD

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
    else
        log_info ".env already exists with valid configuration"
    fi

    # Store credentials for display
    echo "$ADMIN_PASS" > /tmp/.tempox_admin_pass_$$

    log_success "Installation completed"
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
# FIXED: Use scripts/start.sh which properly starts BOTH frontend AND backend
#-------------------------------------------------------------------------------
start_app() {
    log_header "Starting $APP_NAME Services"
    log_progress "Starting services..."

    cd "$APP4_DIR"

    # Method 1: Use scripts/start.sh (recommended - starts both frontend and backend)
    if [ -f "./scripts/start.sh" ]; then
        log_step "Using scripts/start.sh to start services..."
        chmod +x ./scripts/start.sh
        ./scripts/start.sh &
        disown
        sleep 8
    # Method 2: Use ospf-tempo-x.sh (calls scripts/start.sh internally)
    elif [ -f "./ospf-tempo-x.sh" ]; then
        log_step "Running ospf-tempo-x.sh start..."
        ./ospf-tempo-x.sh start &
        disown
        sleep 8
    # Method 3: Fallback to npm run dev:all (starts both with concurrently)
    elif grep -q '"dev:all"' package.json 2>/dev/null; then
        log_step "Using npm run dev:all..."
        nohup npm run dev:all > /tmp/app4-tempo-x.log 2>&1 &
        disown
        sleep 8
    # Method 4: Ultimate fallback - start frontend and backend separately
    else
        log_warning "Using fallback: starting frontend and backend separately..."
        # Start backend first
        log_step "Starting backend server (port $BACKEND_PORT)..."
        nohup npm run server > /tmp/app4-backend.log 2>&1 &
        disown
        sleep 3
        # Start frontend
        log_step "Starting frontend (port $FRONTEND_PORT)..."
        nohup npm run dev > /tmp/app4-frontend.log 2>&1 &
        disown
        sleep 5
    fi

    # Verify services started
    log_info "Verifying services..."
    local frontend_up=false
    local backend_up=false

    for i in {1..10}; do
        if lsof -i :$FRONTEND_PORT >/dev/null 2>&1; then frontend_up=true; fi
        if lsof -i :$BACKEND_PORT >/dev/null 2>&1; then backend_up=true; fi
        if $frontend_up && $backend_up; then break; fi
        sleep 1
    done

    if $frontend_up; then
        log_success "Frontend (port $FRONTEND_PORT): UP"
    else
        log_warning "Frontend (port $FRONTEND_PORT): DOWN"
    fi

    if $backend_up; then
        log_success "Backend (port $BACKEND_PORT): UP"
    else
        log_warning "Backend (port $BACKEND_PORT): DOWN"
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
