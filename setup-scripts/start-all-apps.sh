#!/opt/homebrew/bin/bash
#===============================================================================
# Start Script for All OSPF Apps (App0 - App5)
# Purpose: Start all services in the correct order
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

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
declare -A APP_DIRS=(
    [0]="app0-auth-vault"
    [1]="app1-impact-planner"
    [2]="app2-netviz-pro"
    [3]="app3-nn-json"
    [4]="app4-tempo-x"
    [5]="app5-device-manager"
)

declare -A APP_NAMES=(
    [0]="Auth-Vault (Keycloak + Vault)"
    [1]="Impact Planner"
    [2]="NetViz Pro"
    [3]="NN-JSON"
    [4]="Tempo-X"
    [5]="Device Manager"
)

declare -A APP_START_SCRIPTS=(
    [0]="./auth-vault.sh start"
    [1]="./ospf-planner.sh start"
    [2]="./netviz.sh start"
    [3]="./nn-json.sh start"
    [4]="./ospf-tempo-x.sh start"
    [5]="./ospf-device-manager.sh start"
)

declare -A APP_PORTS=(
    [0]="9120 9121"
    [1]="9090 9091"
    [2]="9040 9041 9042"
    [3]="9080 9081"
    [4]="9100 9101"
    [5]="9050 9051"
)

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

#-------------------------------------------------------------------------------
# Check if port is in use
#-------------------------------------------------------------------------------
check_port() {
    local port=$1
    lsof -i :$port >/dev/null 2>&1
}

#-------------------------------------------------------------------------------
# Wait for port to be available
#-------------------------------------------------------------------------------
wait_for_port() {
    local port=$1
    local max_wait=${2:-30}
    local waited=0

    while [ $waited -lt $max_wait ]; do
        if check_port $port; then
            return 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    return 1
}

#-------------------------------------------------------------------------------
# Start a single app
#-------------------------------------------------------------------------------
start_app() {
    local app_num=$1
    local app_name="${APP_NAMES[$app_num]}"
    local app_dir="${APPS_ROOT}/${APP_DIRS[$app_num]}"
    local start_script="${APP_START_SCRIPTS[$app_num]}"
    local ports="${APP_PORTS[$app_num]}"

    log_info "Starting App${app_num}: $app_name..."

    if [ ! -d "$app_dir" ]; then
        log_warning "App${app_num} directory not found: $app_dir"
        return 1
    fi

    cd "$app_dir"

    # Check if already running
    local first_port=$(echo "$ports" | awk '{print $1}')
    if check_port "$first_port"; then
        log_warning "App${app_num} appears to already be running on port $first_port"
        return 0
    fi

    # Extract script name
    local script_name=$(echo "$start_script" | awk '{print $1}')

    if [ -f "$script_name" ]; then
        chmod +x "$script_name"
        $start_script &>/dev/null &

        # Wait a bit and check if started
        sleep 5

        if check_port "$first_port"; then
            log_success "App${app_num} started successfully on port $first_port"
            return 0
        else
            log_warning "App${app_num} may not have started (port $first_port not bound)"
            return 1
        fi
    else
        log_error "Start script not found: $script_name"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Start all apps
#-------------------------------------------------------------------------------
start_all() {
    log_header "Starting All OSPF Apps"

    local started=0
    local failed=0

    # Start apps in order (App0 first as it provides auth)
    for app_num in 0 1 2 3 4 5; do
        if start_app $app_num; then
            started=$((started + 1))
        else
            failed=$((failed + 1))
        fi

        # Small delay between apps
        sleep 2
    done

    echo ""
    log_header "Start Summary"
    echo -e "  ${GREEN}Started:${NC} $started apps"
    echo -e "  ${RED}Failed:${NC}  $failed apps"
    echo ""

    # Show port status
    echo -e "${CYAN}Port Status:${NC}"
    for app_num in 0 1 2 3 4 5; do
        local ports="${APP_PORTS[$app_num]}"
        local app_name="${APP_NAMES[$app_num]}"
        echo -n "  App${app_num} ($app_name): "
        for port in $ports; do
            if check_port $port; then
                echo -n -e "${GREEN}$port✓${NC} "
            else
                echo -n -e "${RED}$port✗${NC} "
            fi
        done
        echo ""
    done
}

#-------------------------------------------------------------------------------
# Start specific app
#-------------------------------------------------------------------------------
start_specific() {
    local app_num=$1

    if [ -z "${APP_NAMES[$app_num]}" ]; then
        log_error "Invalid app number: $app_num (valid: 0-5)"
        exit 1
    fi

    log_header "Starting App${app_num}: ${APP_NAMES[$app_num]}"
    start_app $app_num
}

#-------------------------------------------------------------------------------
# Show help
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}OSPF Apps Start Script${NC}"
    echo ""
    echo "Usage: $0 [command] [app_number]"
    echo ""
    echo "Commands:"
    echo "  all           Start all apps (default)"
    echo "  <number>      Start specific app (0-5)"
    echo "  help          Show this help"
    echo ""
    echo "Apps:"
    for app_num in 0 1 2 3 4 5; do
        local ports="${APP_PORTS[$app_num]}"
        echo "  $app_num - ${APP_NAMES[$app_num]} (Ports: $ports)"
    done
    echo ""
    echo "Examples:"
    echo "  $0              # Start all apps"
    echo "  $0 all          # Start all apps"
    echo "  $0 0            # Start App0 (Auth-Vault)"
    echo "  $0 4            # Start App4 (Tempo-X)"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local command=${1:-all}

    case "$command" in
        all)
            start_all
            ;;
        [0-5])
            start_specific $command
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
