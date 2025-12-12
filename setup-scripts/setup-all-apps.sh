#!/bin/bash
#===============================================================================
# Master Setup Script for OSPF Application Suite
# Purpose: Install, configure, and start all 6 applications with progress monitoring
# Author: OSPF Suite DevOps
# Version: 1.0.0
#
# Order: App0 (Auth-Vault) -> App3 -> App4 -> App2 -> App1 -> App5
# This order ensures dependencies are met (Auth-Vault first, then dependent apps)
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP0_DIR="$(dirname "$SCRIPT_DIR")"
APPS_ROOT="$(dirname "$APP0_DIR")"

# Configuration
TOTAL_APPS=6
CURRENT_APP=0
START_TIME=$(date +%s)

# Track results
declare -A APP_STATUS
declare -A APP_CREDENTIALS

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_banner() {
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                                          ║${NC}"
    echo -e "${MAGENTA}║     ██████╗ ███████╗██████╗ ███████╗    ███████╗██╗   ██╗██╗████████╗    ║${NC}"
    echo -e "${MAGENTA}║    ██╔═══██╗██╔════╝██╔══██╗██╔════╝    ██╔════╝██║   ██║██║╚══██╔══╝    ║${NC}"
    echo -e "${MAGENTA}║    ██║   ██║███████╗██████╔╝█████╗      ███████╗██║   ██║██║   ██║       ║${NC}"
    echo -e "${MAGENTA}║    ██║   ██║╚════██║██╔═══╝ ██╔══╝      ╚════██║██║   ██║██║   ██║       ║${NC}"
    echo -e "${MAGENTA}║    ╚██████╔╝███████║██║     ██║         ███████║╚██████╔╝██║   ██║       ║${NC}"
    echo -e "${MAGENTA}║     ╚═════╝ ╚══════╝╚═╝     ╚═╝         ╚══════╝ ╚═════╝ ╚═╝   ╚═╝       ║${NC}"
    echo -e "${MAGENTA}║                                                                          ║${NC}"
    echo -e "${MAGENTA}║              OSPF Application Suite - Master Setup                       ║${NC}"
    echo -e "${MAGENTA}║                                                                          ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_header() {
    echo ""
    echo -e "${CYAN}┌──────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│  $1${NC}"
    echo -e "${CYAN}└──────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

log_progress() {
    local app_num=$1
    local app_name=$2
    local status=$3
    local percent=$((app_num * 100 / TOTAL_APPS))

    # Progress bar
    local bar_width=50
    local filled=$((percent * bar_width / 100))
    local empty=$((bar_width - filled))

    printf "\r${BLUE}[PROGRESS]${NC} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${percent}%% - ${app_name}: ${status}"
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

#-------------------------------------------------------------------------------
# Check if service is running
#-------------------------------------------------------------------------------
check_port() {
    local port=$1
    lsof -i :$port >/dev/null 2>&1
}

#-------------------------------------------------------------------------------
# Run setup script with timeout (FIXED: prevents hanging)
# Usage: run_with_timeout <timeout_seconds> <script_path> <args>
#-------------------------------------------------------------------------------
APP_SETUP_TIMEOUT=${APP_SETUP_TIMEOUT:-300}  # Default 5 minutes per app

run_with_timeout() {
    local timeout_sec=$1
    local script_path=$2
    shift 2
    local args="$@"

    # Check if 'timeout' command exists (GNU coreutils)
    if command -v timeout &>/dev/null; then
        timeout --foreground "$timeout_sec" "$script_path" $args
        return $?
    # Check if 'gtimeout' exists (macOS with coreutils)
    elif command -v gtimeout &>/dev/null; then
        gtimeout --foreground "$timeout_sec" "$script_path" $args
        return $?
    else
        # Fallback: run with background process and manual timeout
        "$script_path" $args &
        local pid=$!

        local count=0
        while kill -0 $pid 2>/dev/null && [ $count -lt $timeout_sec ]; do
            sleep 1
            count=$((count + 1))
        done

        if kill -0 $pid 2>/dev/null; then
            log_warning "Setup script timed out after ${timeout_sec}s, terminating..."
            kill -9 $pid 2>/dev/null
            wait $pid 2>/dev/null
            return 124  # Same exit code as 'timeout' command
        fi

        wait $pid
        return $?
    fi
}

#-------------------------------------------------------------------------------
# Setup Individual Apps (with progress tracking)
#-------------------------------------------------------------------------------
setup_app0() {
    CURRENT_APP=1
    log_progress $CURRENT_APP "App0 - Auth-Vault" "Setting up..."

    if [ -f "$SCRIPT_DIR/setup-app0.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-app0.sh"
        if "$SCRIPT_DIR/setup-app0.sh" setup; then
            APP_STATUS[0]="✅ UP"
            log_success "App0 - Auth-Vault setup completed"
        else
            APP_STATUS[0]="❌ FAILED"
            log_error "App0 - Auth-Vault setup failed"
        fi
    else
        APP_STATUS[0]="❌ MISSING"
        log_error "setup-app0.sh not found"
    fi
}

setup_app1() {
    CURRENT_APP=5
    log_progress $CURRENT_APP "App1 - Impact Planner" "Setting up..."

    if [ -f "$SCRIPT_DIR/setup-app1.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-app1.sh"
        # FIXED: Use timeout to prevent hanging
        if run_with_timeout $APP_SETUP_TIMEOUT "$SCRIPT_DIR/setup-app1.sh" setup; then
            APP_STATUS[1]="✅ UP"
            log_success "App1 - Impact Planner setup completed"
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                APP_STATUS[1]="⚠️ TIMEOUT"
                log_warning "App1 - Impact Planner setup timed out (services may still be starting)"
            else
                APP_STATUS[1]="❌ FAILED"
                log_error "App1 - Impact Planner setup failed"
            fi
        fi
    else
        APP_STATUS[1]="❌ MISSING"
        log_error "setup-app1.sh not found"
    fi
}

setup_app2() {
    CURRENT_APP=4
    log_progress $CURRENT_APP "App2 - NetViz Pro" "Setting up..."

    if [ -f "$SCRIPT_DIR/setup-app2.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-app2.sh"
        if "$SCRIPT_DIR/setup-app2.sh" setup; then
            APP_STATUS[2]="✅ UP"
            log_success "App2 - NetViz Pro setup completed"
        else
            APP_STATUS[2]="❌ FAILED"
            log_error "App2 - NetViz Pro setup failed"
        fi
    else
        APP_STATUS[2]="❌ MISSING"
        log_error "setup-app2.sh not found"
    fi
}

setup_app3() {
    CURRENT_APP=2
    log_progress $CURRENT_APP "App3 - NN-JSON" "Setting up..."

    if [ -f "$SCRIPT_DIR/setup-app3.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-app3.sh"
        if "$SCRIPT_DIR/setup-app3.sh" setup; then
            APP_STATUS[3]="✅ UP"
            log_success "App3 - NN-JSON setup completed"
        else
            APP_STATUS[3]="❌ FAILED"
            log_error "App3 - NN-JSON setup failed"
        fi
    else
        APP_STATUS[3]="❌ MISSING"
        log_error "setup-app3.sh not found"
    fi
}

setup_app4() {
    CURRENT_APP=3
    log_progress $CURRENT_APP "App4 - Tempo-X" "Setting up..."

    if [ -f "$SCRIPT_DIR/setup-app4.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-app4.sh"
        # FIXED: Use timeout to prevent hanging
        if run_with_timeout $APP_SETUP_TIMEOUT "$SCRIPT_DIR/setup-app4.sh" setup; then
            APP_STATUS[4]="✅ UP"
            log_success "App4 - Tempo-X setup completed"
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                APP_STATUS[4]="⚠️ TIMEOUT"
                log_warning "App4 - Tempo-X setup timed out (services may still be starting)"
            else
                APP_STATUS[4]="❌ FAILED"
                log_error "App4 - Tempo-X setup failed"
            fi
        fi
    else
        APP_STATUS[4]="❌ MISSING"
        log_error "setup-app4.sh not found"
    fi
}

setup_app5() {
    CURRENT_APP=6
    log_progress $CURRENT_APP "App5 - Device Manager" "Setting up..."

    if [ -f "$SCRIPT_DIR/setup-app5.sh" ]; then
        chmod +x "$SCRIPT_DIR/setup-app5.sh"
        if "$SCRIPT_DIR/setup-app5.sh" setup; then
            APP_STATUS[5]="✅ UP"
            log_success "App5 - Device Manager setup completed"
        else
            APP_STATUS[5]="❌ FAILED"
            log_error "App5 - Device Manager setup failed"
        fi
    else
        APP_STATUS[5]="❌ MISSING"
        log_error "setup-app5.sh not found"
    fi
}

#-------------------------------------------------------------------------------
# Check All Services Status
#-------------------------------------------------------------------------------
check_all_status() {
    log_header "Checking All Services Status"

    # Check each port
    APP_STATUS[0]=$(check_port 9120 && check_port 9121 && echo "✅ UP" || echo "❌ DOWN")
    APP_STATUS[1]=$(check_port 9090 && check_port 9091 && echo "✅ UP" || echo "❌ DOWN")
    APP_STATUS[2]=$(check_port 9040 && echo "✅ UP" || echo "❌ DOWN")
    APP_STATUS[3]=$(check_port 9080 && echo "✅ UP" || echo "❌ DOWN")
    APP_STATUS[4]=$(check_port 9100 && echo "✅ UP" || echo "❌ DOWN")
    APP_STATUS[5]=$(check_port 9050 && echo "✅ UP" || echo "❌ DOWN")
}

#-------------------------------------------------------------------------------
# Show Final Summary
#-------------------------------------------------------------------------------
show_summary() {
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    local MINUTES=$((DURATION / 60))
    local SECONDS=$((DURATION % 60))

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    SETUP COMPLETED SUCCESSFULLY                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Service URLs and Credentials:${NC}"
    echo ""
    echo -e "  | App  | Name           | Frontend URL                | Backend Port | Status |"
    echo -e "  |------|----------------|-----------------------------|--------------|--------|"
    echo -e "  | App0 | Auth-Vault     | http://localhost:9120/admin | 9121         | ${APP_STATUS[0]} |"
    echo -e "  | App1 | Impact Planner | http://localhost:9090       | 9091         | ${APP_STATUS[1]} |"
    echo -e "  | App2 | NetViz Pro     | http://localhost:9040       | 9041         | ${APP_STATUS[2]} |"
    echo -e "  | App3 | NN-JSON        | http://localhost:9080       | 9081         | ${APP_STATUS[3]} |"
    echo -e "  | App4 | Tempo-X        | http://localhost:9100       | 9101         | ${APP_STATUS[4]} |"
    echo -e "  | App5 | Device Manager | http://localhost:9050       | 9051         | ${APP_STATUS[5]} |"
    echo ""

    # Display Vault credentials if available
    if [ -f "$APP0_DIR/data/vault/vault-keys.json" ]; then
        local unseal_key=$(grep -o '"unseal_keys_b64".*\[.*"[^"]*"' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null | grep -o '"[A-Za-z0-9+/=]*"$' | tr -d '"')
        local root_token=$(grep -o '"root_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$APP0_DIR/data/vault/vault-keys.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

        echo -e "  ${CYAN}============================================================${NC}"
        echo -e "  ${CYAN}                VAULT CREDENTIALS${NC}"
        echo -e "  ${CYAN}============================================================${NC}"
        echo -e "  ${YELLOW}Vault Unseal Key:${NC} $unseal_key"
        echo -e "  ${YELLOW}Vault Root Token:${NC} $root_token"
        echo ""
        echo -e "  Keys file: $APP0_DIR/data/vault/vault-keys.json"
        echo ""
        echo -e "  ${CYAN}============================================================${NC}"
        echo -e "  ${CYAN}                SERVICE URLs${NC}"
        echo -e "  ${CYAN}============================================================${NC}"
        echo ""
        echo -e "  ${GREEN}Keycloak Admin Console:${NC} http://localhost:9120/admin"
        echo -e "    - Username: admin"
        echo -e "    - Password: admin"
        echo ""
        echo -e "  ${GREEN}Vault UI:${NC} http://localhost:9121/ui"
        echo -e "    - Token: $root_token"
        echo -e "  ${CYAN}============================================================${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}Total setup time:${NC} ${MINUTES}m ${SECONDS}s"
    echo ""
}

#-------------------------------------------------------------------------------
# Stop All Apps
#-------------------------------------------------------------------------------
stop_all() {
    log_header "Stopping All Applications"

    for i in 5 4 3 2 1 0; do
        if [ -f "$SCRIPT_DIR/setup-app${i}.sh" ]; then
            log_info "Stopping App${i}..."
            "$SCRIPT_DIR/setup-app${i}.sh" stop 2>/dev/null || true
        fi
    done

    log_success "All applications stopped"
}

#-------------------------------------------------------------------------------
# Start All Apps (without reinstalling)
#-------------------------------------------------------------------------------
start_all() {
    log_header "Starting All Applications"

    # Order: App0 -> App3 -> App4 -> App2 -> App1 -> App5
    for i in 0 3 4 2 1 5; do
        if [ -f "$SCRIPT_DIR/setup-app${i}.sh" ]; then
            log_info "Starting App${i}..."
            "$SCRIPT_DIR/setup-app${i}.sh" start 2>/dev/null || true
            sleep 3
        fi
    done

    check_all_status
    show_summary
}

#-------------------------------------------------------------------------------
# Full Setup All Apps
#-------------------------------------------------------------------------------
setup_all() {
    log_banner
    log_header "Starting Full Setup of OSPF Application Suite"
    log_info "Setup order: App0 -> App3 -> App4 -> App2 -> App1 -> App5"
    echo ""

    # Setup in order: App0 (Auth-Vault first), then App3, App4, App2, App1, App5
    setup_app0
    sleep 5

    setup_app3
    sleep 5

    setup_app4
    sleep 5

    setup_app2
    sleep 5

    setup_app1
    sleep 5

    setup_app5
    sleep 3

    # Final status check
    check_all_status

    # Show summary
    show_summary
}

#-------------------------------------------------------------------------------
# Show Status
#-------------------------------------------------------------------------------
status_all() {
    log_banner
    check_all_status
    show_summary
}

#-------------------------------------------------------------------------------
# Show Help
#-------------------------------------------------------------------------------
show_help() {
    log_banner
    echo "Usage: $0 <command>"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  setup      Full setup all 6 applications (install + start)"
    echo "  start      Start all applications (without reinstalling)"
    echo "  stop       Stop all running applications"
    echo "  status     Show status of all applications"
    echo "  help       Show this help message"
    echo ""
    echo -e "${CYAN}Individual App Setup:${NC}"
    echo "  ./setup-app0.sh    Setup Auth-Vault (Keycloak + Vault)"
    echo "  ./setup-app1.sh    Setup Impact Planner"
    echo "  ./setup-app2.sh    Setup NetViz Pro"
    echo "  ./setup-app3.sh    Setup NN-JSON"
    echo "  ./setup-app4.sh    Setup Tempo-X"
    echo "  ./setup-app5.sh    Setup Device Manager"
    echo ""
    echo -e "${CYAN}Setup Order:${NC}"
    echo "  App0 (Auth-Vault) -> App3 (NN-JSON) -> App4 (Tempo-X) -> "
    echo "  App2 (NetViz Pro) -> App1 (Impact Planner) -> App5 (Device Manager)"
    echo ""
    echo -e "${CYAN}Port Mapping:${NC}"
    echo "  App0: 9120 (Keycloak), 9121 (Vault)"
    echo "  App1: 9090 (Frontend), 9091 (Backend)"
    echo "  App2: 9040 (Gateway), 9041 (Auth), 9042 (Vite)"
    echo "  App3: 9080 (Frontend), 9081 (Backend)"
    echo "  App4: 9100 (Frontend), 9101 (Backend)"
    echo "  App5: 9050 (Frontend), 9051 (Backend)"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local command=${1:-help}

    case "$command" in
        setup)
            setup_all
            ;;
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        status)
            status_all
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
