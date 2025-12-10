#!/opt/homebrew/bin/bash
#===============================================================================
# Stop Script for All OSPF Apps (App0 - App5)
# Purpose: Stop all services gracefully
# Author: OSPF Suite DevOps
# Version: 1.0.0
#===============================================================================

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

declare -A APP_STOP_SCRIPTS=(
    [0]="./auth-vault.sh stop"
    [1]="./ospf-planner.sh stop"
    [2]="./netviz.sh stop"
    [3]="./nn-json.sh stop"
    [4]="./ospf-tempo-x.sh stop"
    [5]="./ospf-device-manager.sh stop"
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
# Kill process on port
#-------------------------------------------------------------------------------
kill_port() {
    local port=$1
    local pid=$(lsof -ti :$port 2>/dev/null)
    if [ -n "$pid" ]; then
        kill -9 $pid 2>/dev/null
        return 0
    fi
    return 1
}

#-------------------------------------------------------------------------------
# Stop a single app
#-------------------------------------------------------------------------------
stop_app() {
    local app_num=$1
    local force=${2:-false}
    local app_name="${APP_NAMES[$app_num]}"
    local app_dir="${APPS_ROOT}/${APP_DIRS[$app_num]}"
    local stop_script="${APP_STOP_SCRIPTS[$app_num]}"
    local ports="${APP_PORTS[$app_num]}"

    log_info "Stopping App${app_num}: $app_name..."

    # Check if running
    local first_port=$(echo "$ports" | awk '{print $1}')
    if ! check_port "$first_port"; then
        log_warning "App${app_num} not running (port $first_port not bound)"
        return 0
    fi

    if [ -d "$app_dir" ]; then
        cd "$app_dir"

        # Extract script name
        local script_name=$(echo "$stop_script" | awk '{print $1}')

        if [ -f "$script_name" ] && [ "$force" = "false" ]; then
            chmod +x "$script_name"
            $stop_script &>/dev/null

            # Wait a bit and check
            sleep 3
        fi
    fi

    # Force kill if still running or force mode
    if [ "$force" = "true" ] || check_port "$first_port"; then
        log_info "Force stopping App${app_num} processes..."
        for port in $ports; do
            if check_port $port; then
                kill_port $port
            fi
        done
        sleep 1
    fi

    # Verify stopped
    if ! check_port "$first_port"; then
        log_success "App${app_num} stopped successfully"
        return 0
    else
        log_error "App${app_num} may still be running"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Stop all apps
#-------------------------------------------------------------------------------
stop_all() {
    local force=${1:-false}

    log_header "Stopping All OSPF Apps"

    local stopped=0
    local failed=0

    # Stop apps in reverse order (App0 last as it provides auth)
    for app_num in 5 4 3 2 1 0; do
        if stop_app $app_num $force; then
            stopped=$((stopped + 1))
        else
            failed=$((failed + 1))
        fi

        # Small delay between apps
        sleep 1
    done

    echo ""
    log_header "Stop Summary"
    echo -e "  ${GREEN}Stopped:${NC} $stopped apps"
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
                echo -n -e "${RED}$port running${NC} "
            else
                echo -n -e "${GREEN}$port stopped${NC} "
            fi
        done
        echo ""
    done
}

#-------------------------------------------------------------------------------
# Stop specific app
#-------------------------------------------------------------------------------
stop_specific() {
    local app_num=$1
    local force=${2:-false}

    if [ -z "${APP_NAMES[$app_num]}" ]; then
        log_error "Invalid app number: $app_num (valid: 0-5)"
        exit 1
    fi

    log_header "Stopping App${app_num}: ${APP_NAMES[$app_num]}"
    stop_app $app_num $force
}

#-------------------------------------------------------------------------------
# Kill all OSPF ports
#-------------------------------------------------------------------------------
kill_all_ports() {
    log_header "Force Killing All OSPF Ports"

    local all_ports="9040 9041 9042 9050 9051 9080 9081 9090 9091 9100 9101 9120 9121"

    for port in $all_ports; do
        if check_port $port; then
            log_info "Killing process on port $port..."
            kill_port $port
        fi
    done

    sleep 2

    echo ""
    echo -e "${CYAN}Port Status After Kill:${NC}"
    for port in $all_ports; do
        if check_port $port; then
            echo -e "  Port $port: ${RED}Still running${NC}"
        else
            echo -e "  Port $port: ${GREEN}Stopped${NC}"
        fi
    done
}

#-------------------------------------------------------------------------------
# Show help
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}OSPF Apps Stop Script${NC}"
    echo ""
    echo "Usage: $0 [command] [app_number]"
    echo ""
    echo "Commands:"
    echo "  all           Stop all apps gracefully (default)"
    echo "  force         Force stop all apps (kill -9)"
    echo "  kill          Kill all OSPF ports directly"
    echo "  <number>      Stop specific app (0-5)"
    echo "  help          Show this help"
    echo ""
    echo "Apps:"
    for app_num in 0 1 2 3 4 5; do
        local ports="${APP_PORTS[$app_num]}"
        echo "  $app_num - ${APP_NAMES[$app_num]} (Ports: $ports)"
    done
    echo ""
    echo "Examples:"
    echo "  $0              # Stop all apps gracefully"
    echo "  $0 all          # Stop all apps gracefully"
    echo "  $0 force        # Force stop all apps"
    echo "  $0 kill         # Kill all OSPF ports"
    echo "  $0 0            # Stop App0 (Auth-Vault)"
    echo "  $0 4            # Stop App4 (Tempo-X)"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local command=${1:-all}

    case "$command" in
        all)
            stop_all false
            ;;
        force)
            stop_all true
            ;;
        kill)
            kill_all_ports
            ;;
        [0-5])
            stop_specific $command false
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
