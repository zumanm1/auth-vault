#!/bin/bash
#===============================================================================
# OSPF Application Suite - Master Management Script
# Purpose: Install, start, stop, and manage all 6 OSPF applications
# Author: DevOps Automation
# Version: 1.0.0
#===============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory (app0-auth-vault)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# Parent directory where all apps are cloned
APPS_ROOT="$(dirname "$SCRIPT_DIR")"

# App directories
APP0_DIR="$APPS_ROOT/app0-auth-vault"
APP1_DIR="$APPS_ROOT/app1-impact-planner"
APP2_DIR="$APPS_ROOT/app2-netviz-pro/netviz-pro"
APP3_DIR="$APPS_ROOT/app3-nn-json"
APP4_DIR="$APPS_ROOT/app4-tempo-x"
APP5_DIR="$APPS_ROOT/app5-device-manager"

# Ports
PORT_KEYCLOAK=9120
PORT_VAULT=9121
PORT_APP1_FRONTEND=9090
PORT_APP1_BACKEND=9091
PORT_APP2_FRONTEND=9040
PORT_APP2_BACKEND=9041
PORT_APP3_FRONTEND=9080
PORT_APP3_BACKEND=9081
PORT_APP4_FRONTEND=9100
PORT_APP4_BACKEND=9101
PORT_APP5_FRONTEND=9050
PORT_APP5_BACKEND=9051

# Additional internal ports
PORT_APP2_INTERNAL=9042

# All ports list (including internal ports)
ALL_PORTS="$PORT_KEYCLOAK $PORT_VAULT $PORT_APP1_FRONTEND $PORT_APP1_BACKEND $PORT_APP2_FRONTEND $PORT_APP2_BACKEND $PORT_APP2_INTERNAL $PORT_APP3_FRONTEND $PORT_APP3_BACKEND $PORT_APP4_FRONTEND $PORT_APP4_BACKEND $PORT_APP5_FRONTEND $PORT_APP5_BACKEND"

# Log file
LOG_DIR="$SCRIPT_DIR/logs"
MASTER_LOG="$LOG_DIR/manage-all-apps.log"

#-------------------------------------------------------------------------------
# Utility Functions
#-------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "$MASTER_LOG" 2>/dev/null || true
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$MASTER_LOG" 2>/dev/null || true
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$MASTER_LOG" 2>/dev/null || true
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$MASTER_LOG" 2>/dev/null || true
}

log_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Load nvm for Node.js apps
#-------------------------------------------------------------------------------
load_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh"
        return 0
    fi
    return 1
}

#-------------------------------------------------------------------------------
# Kill processes on specific ports
#-------------------------------------------------------------------------------
kill_port() {
    local port=$1
    local pids=$(lsof -ti:$port 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "$pids" | xargs kill -9 2>/dev/null || true
        log_info "Killed processes on port $port"
    fi
}

clean_all_ports() {
    log_header "Cleaning All Ports"

    for port in $ALL_PORTS; do
        kill_port $port
    done

    log_success "All ports cleaned"
}

#-------------------------------------------------------------------------------
# Clone Repositories
#-------------------------------------------------------------------------------
clone_all() {
    log_header "Cloning All Repositories"

    mkdir -p "$APPS_ROOT"
    cd "$APPS_ROOT"

    # Clone each app
    clone_repo "app0-auth-vault" "https://github.com/zumanm1/auth-vault"
    clone_repo "app1-impact-planner" "https://github.com/zumanm1/ospf-impact-planner"
    clone_repo "app2-netviz-pro" "https://github.com/zumanm1/OSPF-LL-JSON-PART1"
    clone_repo "app3-nn-json" "https://github.com/zumanm1/OSPF-NN-JSON"
    clone_repo "app4-tempo-x" "https://github.com/zumanm1/OSPF-TEMPO-X"
    clone_repo "app5-device-manager" "https://github.com/zumanm1/OSPF2-LL-DEVICE_MANAGER"

    log_success "All repositories cloned"
}

clone_repo() {
    local app_name=$1
    local repo_url=$2
    local app_dir="$APPS_ROOT/$app_name"

    if [ -d "$app_dir" ]; then
        log_warning "$app_name already exists, skipping clone"
    else
        log_info "Cloning $app_name from $repo_url..."
        git clone "$repo_url" "$app_name"
        log_success "Cloned $app_name"
    fi
}

#-------------------------------------------------------------------------------
# Install App0 (Auth-Vault)
#-------------------------------------------------------------------------------
install_app0() {
    log_header "Installing App0: Auth-Vault"

    cd "$APP0_DIR"
    ./auth-vault.sh install

    log_success "App0 installed"
}

#-------------------------------------------------------------------------------
# Start App0 (Auth-Vault)
#-------------------------------------------------------------------------------
start_app0() {
    log_header "Starting App0: Auth-Vault"

    cd "$APP0_DIR"

    # Start services
    ./auth-vault.sh start

    # Wait for services
    log_info "Waiting for Auth-Vault services to be ready..."
    sleep 30

    # Check if Vault needs unsealing
    local vault_health=$(curl -s http://localhost:$PORT_VAULT/v1/sys/health 2>/dev/null || echo '{}')
    local sealed=$(echo "$vault_health" | grep -o '"sealed":[^,}]*' | cut -d: -f2)

    if [ "$sealed" = "true" ]; then
        log_info "Unsealing Vault..."
        local unseal_key=""
        # Use jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            unseal_key=$(jq -r '.unseal_keys_b64[0]' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null)
        else
            # Fallback to grep - extract the first unseal key from the JSON
            unseal_key=$(grep -o '"unseal_keys_b64"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null | grep -o '"[A-Za-z0-9+/=]*"' | head -1 | tr -d '"')
        fi
        if [ -n "$unseal_key" ] && [ "$unseal_key" != "null" ]; then
            export VAULT_ADDR=http://localhost:$PORT_VAULT
            "$APP0_DIR/bin/vault" operator unseal "$unseal_key" 2>/dev/null || true
            log_success "Vault unsealed"
        else
            log_warning "No unseal key found. Please unseal Vault manually."
        fi
    fi

    log_success "App0 started"
    display_app0_credentials
}

display_app0_credentials() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  AUTH-VAULT CREDENTIALS${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""

    if [ -f "$APP0_DIR/data/vault/vault-keys.json" ]; then
        # Use jq if available, otherwise use grep
        if command -v jq >/dev/null 2>&1; then
            local unseal_key=$(jq -r '.unseal_keys_b64[0]' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null)
            local root_token=$(jq -r '.root_token' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null)
        else
            local unseal_key=$(grep -o '"unseal_keys_b64".*' "$APP0_DIR/data/vault/vault-keys.json" | head -1 | sed 's/.*\[.*"\(.*\)".*/\1/')
            local root_token=$(grep -o '"root_token":.*' "$APP0_DIR/data/vault/vault-keys.json" | sed 's/.*: "\(.*\)".*/\1/')
        fi

        echo -e "  ${YELLOW}Vault Unseal Key:${NC} $unseal_key"
        echo -e "  ${YELLOW}Vault Root Token:${NC} $root_token"
        echo ""
    fi

    echo -e "  ${GREEN}Keycloak Admin:${NC} http://localhost:$PORT_KEYCLOAK/admin"
    echo -e "    Username: admin / Password: admin"
    echo ""
    echo -e "  ${GREEN}Vault UI:${NC} http://localhost:$PORT_VAULT/ui"
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Install Node.js Apps
#-------------------------------------------------------------------------------
install_nodejs_app() {
    local app_dir=$1
    local app_name=$2

    log_header "Installing $app_name"

    if [ ! -d "$app_dir" ]; then
        log_error "App directory not found: $app_dir"
        return 1
    fi

    cd "$app_dir"

    # Load nvm
    load_nvm || log_warning "nvm not found, using system Node.js"

    # npm install
    log_info "Running npm install..."
    npm install 2>&1 || npm install --legacy-peer-deps 2>&1

    # Server dependencies if exists
    if [ -d "server" ]; then
        cd server && npm install 2>&1 && cd ..
    fi

    log_success "$app_name installed"
}

#-------------------------------------------------------------------------------
# Install Python App (App5)
#-------------------------------------------------------------------------------
install_python_app() {
    local app_dir=$1
    local app_name=$2

    log_header "Installing $app_name"

    if [ ! -d "$app_dir" ]; then
        log_error "App directory not found: $app_dir"
        return 1
    fi

    cd "$app_dir"

    # Frontend dependencies
    if [ -f "package.json" ]; then
        load_nvm || true
        log_info "Installing frontend dependencies..."
        npm install 2>&1
    fi

    # Backend Python dependencies
    if [ -d "backend" ] && [ -f "backend/requirements.txt" ]; then
        log_info "Installing Python dependencies..."
        cd backend

        # Create virtual environment if it doesn't exist
        if [ ! -d "venv" ]; then
            python3 -m venv venv
        fi

        # Activate and install
        . venv/bin/activate
        pip install -r requirements.txt
        deactivate 2>/dev/null || true

        cd ..
    fi

    log_success "$app_name installed"
}

#-------------------------------------------------------------------------------
# Start Node.js App
#-------------------------------------------------------------------------------
start_nodejs_app() {
    local app_dir=$1
    local app_name=$2
    local frontend_port=$3
    local backend_port=$4

    log_header "Starting $app_name"

    if [ ! -d "$app_dir" ]; then
        log_error "App directory not found: $app_dir"
        return 1
    fi

    cd "$app_dir"

    # Load nvm
    load_nvm || log_warning "nvm not found, using system Node.js"

    # Kill existing processes on ports
    kill_port $frontend_port
    kill_port $backend_port

    mkdir -p "$LOG_DIR"

    # Start backend if exists
    if [ -d "server" ]; then
        cd server
        nohup npm run dev > "$LOG_DIR/${app_name}-backend.log" 2>&1 &
        cd ..
    fi

    # Start frontend
    nohup npm run dev > "$LOG_DIR/${app_name}-frontend.log" 2>&1 &

    sleep 3
    log_success "$app_name started on ports $frontend_port, $backend_port"
}

#-------------------------------------------------------------------------------
# Start Python App (App5)
#-------------------------------------------------------------------------------
start_python_app() {
    local app_dir=$1
    local app_name=$2
    local frontend_port=$3
    local backend_port=$4

    log_header "Starting $app_name"

    if [ ! -d "$app_dir" ]; then
        log_error "App directory not found: $app_dir"
        return 1
    fi

    cd "$app_dir"

    # Kill existing processes
    kill_port $frontend_port
    kill_port $backend_port

    mkdir -p "$LOG_DIR"

    # Start backend
    if [ -d "backend" ]; then
        cd backend
        # Determine the correct Python entry point
        local python_entry=""
        if [ -f "server.py" ]; then
            python_entry="server.py"
        elif [ -f "app.py" ]; then
            python_entry="app.py"
        elif [ -f "main.py" ]; then
            python_entry="main.py"
        fi

        if [ -n "$python_entry" ]; then
            if [ -d "venv" ]; then
                . venv/bin/activate
                nohup python "$python_entry" > "$LOG_DIR/${app_name}-backend.log" 2>&1 &
                deactivate 2>/dev/null || true
            else
                nohup python3 "$python_entry" > "$LOG_DIR/${app_name}-backend.log" 2>&1 &
            fi
        else
            log_warning "No Python entry point found for $app_name backend"
        fi
        cd ..
    fi

    # Start frontend
    load_nvm || true
    nohup npm run dev > "$LOG_DIR/${app_name}-frontend.log" 2>&1 &

    sleep 3
    log_success "$app_name started on ports $frontend_port, $backend_port"
}

#-------------------------------------------------------------------------------
# Stop All Apps
#-------------------------------------------------------------------------------
stop_all() {
    log_header "Stopping All Applications"

    # Stop App0
    cd "$APP0_DIR"
    ./auth-vault.sh stop 2>/dev/null || true

    # Clean all ports
    clean_all_ports

    log_success "All applications stopped"
}

#-------------------------------------------------------------------------------
# Install All
#-------------------------------------------------------------------------------
install_all() {
    log_header "Installing All Applications"

    # First clone if needed
    clone_all

    # Install App0 (Auth-Vault)
    install_app0

    # Install App1 (Impact Planner)
    install_nodejs_app "$APP1_DIR" "app1-impact-planner"

    # Install App2 (NetViz Pro)
    install_nodejs_app "$APP2_DIR" "app2-netviz-pro"

    # Install App3 (NN-JSON)
    install_nodejs_app "$APP3_DIR" "app3-nn-json"

    # Install App4 (Tempo-X)
    install_nodejs_app "$APP4_DIR" "app4-tempo-x"

    # Install App5 (Device Manager)
    install_python_app "$APP5_DIR" "app5-device-manager"

    log_success "All applications installed"
}

#-------------------------------------------------------------------------------
# Start All
#-------------------------------------------------------------------------------
start_all() {
    log_header "Starting All Applications"

    # Clean ports first
    clean_all_ports

    # Start App0 (Auth-Vault) - Required by all other apps
    start_app0

    # Wait for Auth-Vault to be fully ready
    log_info "Waiting for Auth-Vault services..."
    sleep 10

    # Start App1 (Impact Planner)
    start_nodejs_app "$APP1_DIR" "app1-impact-planner" $PORT_APP1_FRONTEND $PORT_APP1_BACKEND

    # Start App2 (NetViz Pro)
    start_nodejs_app "$APP2_DIR" "app2-netviz-pro" $PORT_APP2_FRONTEND $PORT_APP2_BACKEND

    # Start App3 (NN-JSON)
    start_nodejs_app "$APP3_DIR" "app3-nn-json" $PORT_APP3_FRONTEND $PORT_APP3_BACKEND

    # Start App4 (Tempo-X)
    start_nodejs_app "$APP4_DIR" "app4-tempo-x" $PORT_APP4_FRONTEND $PORT_APP4_BACKEND

    # Start App5 (Device Manager)
    start_python_app "$APP5_DIR" "app5-device-manager" $PORT_APP5_FRONTEND $PORT_APP5_BACKEND

    show_status
    log_success "All applications started"
}

#-------------------------------------------------------------------------------
# Show Status
#-------------------------------------------------------------------------------
show_status() {
    log_header "Application Status"

    echo -e "${CYAN}App0 - Auth-Vault:${NC}"
    echo -n "  Keycloak ($PORT_KEYCLOAK): "
    if curl -s http://localhost:$PORT_KEYCLOAK/health/ready >/dev/null 2>&1; then
        echo -e "${GREEN}UP${NC}"
    else
        echo -e "${RED}DOWN${NC}"
    fi

    echo -n "  Vault ($PORT_VAULT): "
    local vault_health=$(curl -s http://localhost:$PORT_VAULT/v1/sys/health 2>/dev/null)
    if [ -n "$vault_health" ]; then
        local sealed=$(echo "$vault_health" | grep -o '"sealed":[^,}]*' | cut -d: -f2)
        if [ "$sealed" = "false" ]; then
            echo -e "${GREEN}UP (Unsealed)${NC}"
        elif [ "$sealed" = "true" ]; then
            echo -e "${YELLOW}UP (Sealed)${NC}"
        else
            echo -e "${RED}DOWN${NC}"
        fi
    else
        echo -e "${RED}DOWN${NC}"
    fi

    echo ""
    echo -e "${CYAN}App1 - Impact Planner:${NC}"
    check_service_status $PORT_APP1_FRONTEND "Frontend"
    check_service_status $PORT_APP1_BACKEND "Backend"

    echo ""
    echo -e "${CYAN}App2 - NetViz Pro:${NC}"
    check_service_status $PORT_APP2_FRONTEND "Frontend"
    check_service_status $PORT_APP2_BACKEND "Backend"

    echo ""
    echo -e "${CYAN}App3 - NN-JSON:${NC}"
    check_service_status $PORT_APP3_FRONTEND "Frontend"
    check_service_status $PORT_APP3_BACKEND "Backend"

    echo ""
    echo -e "${CYAN}App4 - Tempo-X:${NC}"
    check_service_status $PORT_APP4_FRONTEND "Frontend"
    check_service_status $PORT_APP4_BACKEND "Backend"

    echo ""
    echo -e "${CYAN}App5 - Device Manager:${NC}"
    check_service_status $PORT_APP5_FRONTEND "Frontend"
    check_service_status $PORT_APP5_BACKEND "Backend"

    echo ""
}

check_service_status() {
    local port=$1
    local name=$2
    echo -n "  $name ($port): "
    if lsof -i:$port >/dev/null 2>&1; then
        echo -e "${GREEN}UP${NC}"
    else
        echo -e "${RED}DOWN${NC}"
    fi
}

#-------------------------------------------------------------------------------
# Show Help
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}OSPF Application Suite - Master Management Script${NC}"
    echo ""
    echo "Usage: ./manage-all-apps.sh <command>"
    echo ""
    echo "Commands:"
    echo "  clone      Clone all 6 applications from GitHub"
    echo "  install    Install all applications (clone + dependencies)"
    echo "  start      Start all applications (App0 first, then App1-5)"
    echo "  stop       Stop all applications"
    echo "  restart    Stop and start all applications"
    echo "  status     Show status of all applications"
    echo "  clean      Kill all processes on app ports"
    echo "  credentials Show Auth-Vault credentials"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./manage-all-apps.sh install    # First-time setup"
    echo "  ./manage-all-apps.sh start      # Start all apps"
    echo "  ./manage-all-apps.sh stop       # Stop all apps"
    echo "  ./manage-all-apps.sh status     # Check status"
    echo ""
    echo "Application URLs:"
    echo "  App0 (Auth-Vault):"
    echo "    Keycloak: http://localhost:$PORT_KEYCLOAK/admin"
    echo "    Vault: http://localhost:$PORT_VAULT/ui"
    echo "  App1 (Impact Planner): http://localhost:$PORT_APP1_FRONTEND"
    echo "  App2 (NetViz Pro): http://localhost:$PORT_APP2_FRONTEND"
    echo "  App3 (NN-JSON): http://localhost:$PORT_APP3_FRONTEND"
    echo "  App4 (Tempo-X): http://localhost:$PORT_APP4_FRONTEND"
    echo "  App5 (Device Manager): http://localhost:$PORT_APP5_FRONTEND"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local command="${1:-help}"

    case "$command" in
        clone)
            clone_all
            ;;
        install)
            install_all
            ;;
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            stop_all
            sleep 3
            start_all
            ;;
        status)
            show_status
            ;;
        clean)
            clean_all_ports
            ;;
        credentials|creds)
            display_app0_credentials
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
