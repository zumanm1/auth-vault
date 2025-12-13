#!/usr/bin/env bash
#===============================================================================
# OSPF Suite - Comprehensive Validation Script
# Purpose: Validate all apps (App0-App5) are running correctly
# Author: OSPF Suite DevOps
# Version: 1.1.0
#
# Apps Validated:
#   App0 - Auth-Vault:     9120, 9121  (github.com/zumanm1/auth-vault)
#   App1 - Impact Planner: 9090, 9091  (github.com/zumanm1/ospf-impact-planner)
#   App2 - NetViz Pro:     9040-9042   (github.com/zumanm1/OSPF-LL-JSON-PART1)
#   App3 - NN-JSON:        9080, 9081  (github.com/zumanm1/OSPF-NN-JSON)
#   App4 - Tempo-X:        9100, 9101  (github.com/zumanm1/OSPF-TEMPO-X)
#   App5 - Device Manager: 9050, 9051  (github.com/zumanm1/OSPF2-LL-DEVICE_MANAGER)
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Colors
#-------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

#-------------------------------------------------------------------------------
# Get script directory
#-------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP0_DIR="$(dirname "$SCRIPT_DIR")"
APPS_ROOT="$(dirname "$APP0_DIR")"

#-------------------------------------------------------------------------------
# App Definitions
#-------------------------------------------------------------------------------
declare -A APP_NAMES=(
    [0]="Auth-Vault"
    [1]="Impact Planner"
    [2]="NetViz Pro"
    [3]="NN-JSON"
    [4]="Tempo-X"
    [5]="Device Manager"
)

declare -A APP_DIRS=(
    [0]="app0-auth-vault"
    [1]="app1-impact-planner"
    [2]="app2-netviz-pro"
    [3]="app3-nn-json"
    [4]="app4-tempo-x"
    [5]="app5-device-manager"
)

# Port definitions: "service:port service:port ..."
declare -A APP_PORTS=(
    [0]="Keycloak:9120 Vault:9121"
    [1]="Frontend:9090 Backend:9091"
    [2]="Gateway:9040 Auth:9041 Vite:9042"
    [3]="Frontend:9080 Backend:9081"
    [4]="Frontend:9100 Backend:9101"
    [5]="Frontend:9050 Backend:9051"
)

# Health check endpoints
declare -A APP_HEALTH_ENDPOINTS=(
    [0]="http://localhost:9120/health/ready http://localhost:9121/v1/sys/health"
    [1]="http://localhost:9091/api/health"
    [2]="http://localhost:9040/api/health"
    [3]="http://localhost:9081/api/health"
    [4]="http://localhost:9101/api/health"
    [5]="http://localhost:9051/api/health"
)

# Database names (for apps that use PostgreSQL)
# Note: App5 uses SQLite, not PostgreSQL
declare -A APP_DATABASES=(
    [1]="ospf_planner"
    [4]="ospf_tempo_x"
)

# Frontend URLs for each app
declare -A APP_FRONTEND_URLS=(
    [0]="http://localhost:9120/admin"
    [1]="http://localhost:9090"
    [2]="http://localhost:9042"
    [3]="http://localhost:9080"
    [4]="http://localhost:9100"
    [5]="http://localhost:9050"
)

# Auth config endpoints
declare -A APP_AUTH_CONFIG=(
    [1]="http://localhost:9091/api/auth/config"
    [3]="http://localhost:9081/api/auth/config"
    [4]="http://localhost:9101/api/auth/config"
    [5]="http://localhost:9051/api/auth/config"
)

# API root endpoints (for CORS/API check)
declare -A APP_API_ROOT=(
    [1]="http://localhost:9091"
    [2]="http://localhost:9040"
    [3]="http://localhost:9081"
    [4]="http://localhost:9101"
    [5]="http://localhost:9051"
)

# App components - what each app has
# Format: "frontend backend api database auth cors websocket"
declare -A APP_COMPONENTS=(
    [0]="keycloak vault"
    [1]="frontend backend api database auth"
    [2]="gateway auth-server vite"
    [3]="frontend backend api auth"
    [4]="frontend backend api database auth"
    [5]="frontend backend api database auth"
)

#-------------------------------------------------------------------------------
# Counters
#-------------------------------------------------------------------------------
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

declare -A APP_STATUS
declare -A APP_ISSUES

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  $1${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_section() {
    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${WHITE} $1${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────────────┘${NC}"
}

log_app_header() {
    local app_num=$1
    local app_name="${APP_NAMES[$app_num]}"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}  App${app_num}: ${app_name}${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_check() {
    local status=$1
    local message=$2
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    case $status in
        "PASS")
            echo -e "  ${GREEN}[PASS]${NC} $message"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            ;;
        "FAIL")
            echo -e "  ${RED}[FAIL]${NC} $message"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            ;;
        "WARN")
            echo -e "  ${YELLOW}[WARN]${NC} $message"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            ;;
        "INFO")
            echo -e "  ${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Check Functions
#-------------------------------------------------------------------------------
check_port() {
    local port=$1
    lsof -i :$port >/dev/null 2>&1
}

check_http_response() {
    local url=$1
    local expected_code=${2:-200}
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null)
    [ "$response_code" = "$expected_code" ]
}

check_http_content() {
    local url=$1
    local pattern=$2
    curl -s --connect-timeout 5 "$url" 2>/dev/null | grep -q "$pattern"
}

get_http_response() {
    curl -s --connect-timeout 5 "$1" 2>/dev/null
}

check_directory_exists() {
    [ -d "$1" ]
}

check_file_exists() {
    [ -f "$1" ]
}

check_postgres_db() {
    local db_name=$1
    psql -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$db_name"
}

check_postgres_running() {
    pg_isready -q 2>/dev/null
}

#-------------------------------------------------------------------------------
# Check Frontend Response
#-------------------------------------------------------------------------------
check_frontend() {
    local url=$1
    local response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null)
    # Accept 200 (OK), 301/302 (redirects - e.g., Keycloak redirects to login), and 304 (not modified)
    [[ "$response_code" =~ ^(200|301|302|304)$ ]]
}

#-------------------------------------------------------------------------------
# Check API CORS headers
#-------------------------------------------------------------------------------
check_cors() {
    local url=$1
    local cors_header=$(curl -s -I --connect-timeout 5 "$url" 2>/dev/null | grep -i "access-control-allow")
    [ -n "$cors_header" ]
}

#-------------------------------------------------------------------------------
# Check Auth Config
#-------------------------------------------------------------------------------
check_auth_config() {
    local url=$1
    local response=$(curl -s --connect-timeout 5 "$url" 2>/dev/null)
    if [ -n "$response" ]; then
        echo "$response"
        return 0
    fi
    return 1
}

#-------------------------------------------------------------------------------
# Parse Health Response
#-------------------------------------------------------------------------------
parse_health_response() {
    local response=$1
    local db_status=$(echo "$response" | grep -oE '"database"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4)
    local auth_mode=$(echo "$response" | grep -oE '"authMode"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4)
    local auth_vault=$(echo "$response" | grep -oE '"authVault"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4)
    local status=$(echo "$response" | grep -oE '"status"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4)

    echo "status:$status|db:$db_status|authMode:$auth_mode|authVault:$auth_vault"
}

#-------------------------------------------------------------------------------
# Show recent log errors
#-------------------------------------------------------------------------------
show_recent_log_errors() {
    local log_dir=$1
    local max_lines=${2:-5}

    echo -e "    ${YELLOW}Recent error entries:${NC}"
    for log_file in "$log_dir"/*.log; do
        if [ -f "$log_file" ]; then
            local log_name=$(basename "$log_file")
            local recent_errors=$(grep -iE "error|exception|fatal|failed" "$log_file" 2>/dev/null | tail -n "$max_lines")
            if [ -n "$recent_errors" ]; then
                echo -e "    ${CYAN}[$log_name]:${NC}"
                echo "$recent_errors" | while IFS= read -r line; do
                    # Truncate long lines
                    if [ ${#line} -gt 100 ]; then
                        echo -e "      ${RED}${line:0:100}...${NC}"
                    else
                        echo -e "      ${RED}${line}${NC}"
                    fi
                done
            fi
        fi
    done
}

#-------------------------------------------------------------------------------
# Display App0 Credentials and Service URLs
#-------------------------------------------------------------------------------
display_app0_credentials() {
    local app_path=$1
    local vault_keys_file="$app_path/data/vault/vault-keys.json"

    echo ""
    echo -e "  ${CYAN}============================================================${NC}"
    echo -e "  ${CYAN}              VAULT CREDENTIALS${NC}"
    echo -e "  ${CYAN}============================================================${NC}"

    if [ -f "$vault_keys_file" ]; then
        local unseal_key=$(grep -o '"unseal_keys_b64":\s*\["[^"]*"\]' "$vault_keys_file" 2>/dev/null | grep -o '\["[^"]*"\]' | tr -d '[]"' | head -1)
        local root_token=$(grep -o '"root_token":\s*"[^"]*"' "$vault_keys_file" 2>/dev/null | cut -d'"' -f4)

        if [ -n "$unseal_key" ]; then
            echo -e "  ${YELLOW}Vault Unseal Key:${NC} $unseal_key"
        else
            echo -e "  ${YELLOW}Vault Unseal Key:${NC} (not found in keys file)"
        fi

        if [ -n "$root_token" ]; then
            echo -e "  ${YELLOW}Vault Root Token:${NC} $root_token"
        else
            echo -e "  ${YELLOW}Vault Root Token:${NC} (not found in keys file)"
        fi

        echo ""
        echo -e "  ${YELLOW}Keys file:${NC} $vault_keys_file"
    else
        echo -e "  ${RED}Vault keys file not found${NC}"
        echo -e "  ${YELLOW}Expected location:${NC} $vault_keys_file"
    fi

    echo ""
    echo -e "  ${CYAN}============================================================${NC}"
    echo -e "  ${CYAN}              SERVICE URLs${NC}"
    echo -e "  ${CYAN}============================================================${NC}"
    echo ""
    echo -e "  ${GREEN}Keycloak Admin Console:${NC} http://localhost:9120/admin"
    echo -e "    - Username: admin"
    echo -e "    - Password: admin"
    echo ""
    echo -e "  ${GREEN}Vault UI:${NC} http://localhost:9121/ui"

    if [ -f "$vault_keys_file" ]; then
        local root_token=$(grep -o '"root_token":\s*"[^"]*"' "$vault_keys_file" 2>/dev/null | cut -d'"' -f4)
        if [ -n "$root_token" ]; then
            echo -e "    - Token: $root_token"
        fi
    fi

    echo ""
    echo -e "  ${CYAN}============================================================${NC}"
}

#-------------------------------------------------------------------------------
# Validate Single App
#-------------------------------------------------------------------------------
validate_app() {
    local app_num=$1
    local app_name="${APP_NAMES[$app_num]}"
    local app_dir="${APP_DIRS[$app_num]}"
    local app_path="$APPS_ROOT/$app_dir"
    local ports="${APP_PORTS[$app_num]}"
    local health_endpoints="${APP_HEALTH_ENDPOINTS[$app_num]}"
    local db_name="${APP_DATABASES[$app_num]}"

    local app_passed=0
    local app_failed=0
    local app_warnings=0
    local issues=""

    log_app_header $app_num

    # Check 1: Directory exists
    echo -e "  ${CYAN}Directory Check:${NC}"
    if check_directory_exists "$app_path"; then
        log_check "PASS" "Directory exists: $app_dir"
        app_passed=$((app_passed + 1))
    else
        log_check "FAIL" "Directory missing: $app_dir"
        app_failed=$((app_failed + 1))
        issues="${issues}Directory missing; "
        APP_STATUS[$app_num]="MISSING"
        APP_ISSUES[$app_num]="$issues"
        return
    fi

    # Check 2: Port binding
    echo -e "  ${CYAN}Port Checks:${NC}"
    local all_ports_up=true
    for port_def in $ports; do
        local service_name=$(echo "$port_def" | cut -d: -f1)
        local port=$(echo "$port_def" | cut -d: -f2)

        if check_port $port; then
            log_check "PASS" "$service_name port $port is listening"
            app_passed=$((app_passed + 1))
        else
            log_check "FAIL" "$service_name port $port is NOT listening"
            app_failed=$((app_failed + 1))
            issues="${issues}Port $port down; "
            all_ports_up=false
        fi
    done

    # Check 3: HTTP Health Endpoints
    echo -e "  ${CYAN}Health Endpoint Checks:${NC}"
    for endpoint in $health_endpoints; do
        local port=$(echo "$endpoint" | grep -oE ':[0-9]+' | head -1 | tr -d ':')

        if ! check_port $port; then
            log_check "FAIL" "Health check skipped (port $port not listening): $endpoint"
            app_failed=$((app_failed + 1))
            continue
        fi

        local response=$(get_http_response "$endpoint")

        if [ -n "$response" ]; then
            # Check for common healthy indicators
            # - status: healthy/ok/UP
            # - Vault: initialized:true with sealed:false
            # - Keycloak: status:UP or valid JSON health response
            if echo "$response" | grep -qiE '"status"\s*:\s*"(healthy|ok|UP)"'; then
                log_check "PASS" "Health endpoint responding: $endpoint"
                app_passed=$((app_passed + 1))
            elif echo "$response" | grep -qE '"initialized"\s*:\s*true.*"sealed"\s*:\s*false|"sealed"\s*:\s*false.*"initialized"\s*:\s*true'; then
                log_check "PASS" "Health endpoint responding: $endpoint"
                app_passed=$((app_passed + 1))
            elif echo "$response" | grep -qE '^\s*\{.*"status"\s*:\s*"'; then
                # Valid JSON with status field (Keycloak health)
                log_check "PASS" "Health endpoint responding: $endpoint"
                app_passed=$((app_passed + 1))
            elif echo "$response" | grep -qi "error\|failed\|unhealthy"; then
                log_check "FAIL" "Health endpoint reports errors: $endpoint"
                app_failed=$((app_failed + 1))
                issues="${issues}Health check failed; "
            else
                log_check "WARN" "Health endpoint response unclear: $endpoint"
                app_warnings=$((app_warnings + 1))
            fi
        else
            log_check "FAIL" "Health endpoint not responding: $endpoint"
            app_failed=$((app_failed + 1))
            issues="${issues}Health endpoint failed; "
        fi
    done

    # Check 4: Database (if applicable)
    if [ -n "$db_name" ]; then
        echo -e "  ${CYAN}Database Checks:${NC}"

        if check_postgres_running; then
            log_check "PASS" "PostgreSQL is running"
            app_passed=$((app_passed + 1))

            if check_postgres_db "$db_name"; then
                log_check "PASS" "Database '$db_name' exists"
                app_passed=$((app_passed + 1))
            else
                log_check "WARN" "Database '$db_name' not found (may need migration)"
                app_warnings=$((app_warnings + 1))
                issues="${issues}DB not found; "
            fi
        else
            log_check "FAIL" "PostgreSQL is NOT running"
            app_failed=$((app_failed + 1))
            issues="${issues}PostgreSQL down; "
        fi
    fi

    # Special App0: Display Vault credentials and Service URLs
    if [ "$app_num" -eq 0 ]; then
        display_app0_credentials "$app_path"
    fi

    # Check 4b: Component-specific checks (Frontend, API, Auth, CORS)
    local components="${APP_COMPONENTS[$app_num]}"
    local frontend_url="${APP_FRONTEND_URLS[$app_num]}"
    local auth_config_url="${APP_AUTH_CONFIG[$app_num]}"
    local api_root="${APP_API_ROOT[$app_num]}"

    echo -e "  ${CYAN}Component Checks:${NC}"
    log_check "INFO" "Components: $components"

    # Frontend check
    if [ -n "$frontend_url" ]; then
        if check_frontend "$frontend_url"; then
            log_check "PASS" "Frontend responding: $frontend_url"
            app_passed=$((app_passed + 1))
        else
            log_check "FAIL" "Frontend not responding: $frontend_url"
            app_failed=$((app_failed + 1))
            issues="${issues}Frontend down; "
        fi
    fi

    # API root check
    if [ -n "$api_root" ]; then
        local api_response=$(curl -s --connect-timeout 5 "$api_root" 2>/dev/null)
        if [ -n "$api_response" ]; then
            log_check "PASS" "API root accessible: $api_root"
            app_passed=$((app_passed + 1))
        else
            log_check "WARN" "API root not responding: $api_root"
            app_warnings=$((app_warnings + 1))
        fi
    fi

    # Auth config check
    if [ -n "$auth_config_url" ]; then
        local auth_response=$(curl -s --connect-timeout 5 "$auth_config_url" 2>/dev/null)
        if [ -n "$auth_response" ]; then
            local auth_mode=$(echo "$auth_response" | grep -oE '"auth[Mm]ode"\s*:\s*"[^"]*"' | head -1 | cut -d'"' -f4)
            if [ -n "$auth_mode" ]; then
                log_check "PASS" "Auth config: mode=$auth_mode"
                app_passed=$((app_passed + 1))
            else
                log_check "WARN" "Auth config returned but mode unclear"
                app_warnings=$((app_warnings + 1))
            fi
        else
            log_check "WARN" "Auth config not accessible: $auth_config_url"
            app_warnings=$((app_warnings + 1))
        fi
    fi

    # CORS check (send OPTIONS request)
    if [ -n "$api_root" ]; then
        local cors_headers=$(curl -s -I -X OPTIONS --connect-timeout 5 "$api_root" 2>/dev/null | grep -i "access-control")
        if [ -n "$cors_headers" ]; then
            log_check "PASS" "CORS headers present"
            app_passed=$((app_passed + 1))
        else
            log_check "INFO" "CORS headers not detected (may be configured differently)"
        fi
    fi

    # Check 5: Environment file (app-specific paths)
    echo -e "  ${CYAN}Configuration Checks:${NC}"
    local env_found=false
    local env_file=""

    # App-specific .env locations
    case $app_num in
        0) # App0: Auth-Vault uses data/.vault-env
            if [ -f "$app_path/data/.vault-env" ]; then
                env_file="$app_path/data/.vault-env"
                env_found=true
            elif [ -f "$app_path/.env" ]; then
                env_file="$app_path/.env"
                env_found=true
            fi
            ;;
        1) # App1: Impact Planner uses server/.env
            if [ -f "$app_path/server/.env" ]; then
                env_file="$app_path/server/.env"
                env_found=true
            fi
            ;;
        2) # App2: NetViz Pro uses netviz-pro/.env.local
            if [ -f "$app_path/netviz-pro/.env.local" ]; then
                env_file="$app_path/netviz-pro/.env.local"
                env_found=true
            fi
            ;;
        *) # Default: check root .env or .env.local
            if [ -f "$app_path/.env" ]; then
                env_file="$app_path/.env"
                env_found=true
            elif [ -f "$app_path/.env.local" ]; then
                env_file="$app_path/.env.local"
                env_found=true
            fi
            ;;
    esac

    if [ "$env_found" = true ]; then
        log_check "PASS" ".env file exists"
        app_passed=$((app_passed + 1))

        # Check for placeholder values
        if grep -qE "your-secret|change-me|CHANGEME|TODO" "$env_file" 2>/dev/null; then
            log_check "WARN" ".env contains placeholder values"
            app_warnings=$((app_warnings + 1))
            issues="${issues}Placeholder in .env; "
        fi
    else
        log_check "WARN" "No .env file found"
        app_warnings=$((app_warnings + 1))
        issues="${issues}No .env file; "
    fi

    # Check 6: Log files for errors (if logs exist)
    echo -e "  ${CYAN}Log Analysis:${NC}"
    local log_dir="$app_path/.logs"
    if [ -d "$log_dir" ]; then
        local error_count=0
        local has_logs=false
        local log_files_found=""
        for log_file in "$log_dir"/*.log; do
            if [ -f "$log_file" ]; then
                has_logs=true
                local log_name=$(basename "$log_file")
                local file_size=$(ls -lh "$log_file" 2>/dev/null | awk '{print $5}')
                local errors
                errors=$(grep -ciE "error|exception|fatal|failed" "$log_file" 2>/dev/null | head -1 || true)
                if [[ "$errors" =~ ^[0-9]+$ ]]; then
                    error_count=$((error_count + errors))
                    log_files_found="${log_files_found}${log_name}(${file_size}, ${errors} errors) "
                else
                    log_files_found="${log_files_found}${log_name}(${file_size}) "
                fi
            fi
        done

        if [ "$has_logs" = false ]; then
            log_check "INFO" "No log files found"
        else
            log_check "INFO" "Log files: $log_files_found"
            if [ "$error_count" -eq 0 ]; then
                log_check "PASS" "No errors in log files"
                app_passed=$((app_passed + 1))
            elif [ "$error_count" -lt 10 ]; then
                log_check "WARN" "$error_count potential errors in logs"
                app_warnings=$((app_warnings + 1))
                # Show recent errors
                show_recent_log_errors "$log_dir" 3
            else
                log_check "WARN" "$error_count errors found in logs (review recommended)"
                app_warnings=$((app_warnings + 1))
                issues="${issues}Errors in logs; "
                # Show recent errors
                show_recent_log_errors "$log_dir" 5
            fi
        fi
    else
        log_check "INFO" "No log directory found"
    fi

    # Determine overall app status
    if [ $app_failed -eq 0 ] && [ $app_warnings -eq 0 ]; then
        APP_STATUS[$app_num]="HEALTHY"
    elif [ $app_failed -eq 0 ]; then
        APP_STATUS[$app_num]="WARNING"
    else
        APP_STATUS[$app_num]="UNHEALTHY"
    fi

    APP_ISSUES[$app_num]="${issues:-None}"

    # App Summary
    echo ""
    echo -e "  ${CYAN}App${app_num} Summary:${NC}"
    echo -e "    Passed: ${GREEN}$app_passed${NC}  |  Failed: ${RED}$app_failed${NC}  |  Warnings: ${YELLOW}$app_warnings${NC}"
}

#-------------------------------------------------------------------------------
# Validate All Apps
#-------------------------------------------------------------------------------
validate_all() {
    log_header "OSPF Suite - Comprehensive Validation"

    echo -e "  ${WHITE}Validation Started:${NC} $(date)"
    echo -e "  ${WHITE}Apps Root:${NC} $APPS_ROOT"
    echo ""

    # System Prerequisites
    log_section "System Prerequisites"

    echo -e "  ${CYAN}Required Services:${NC}"

    # Check PostgreSQL
    if check_postgres_running; then
        log_check "PASS" "PostgreSQL is running"
    else
        log_check "FAIL" "PostgreSQL is NOT running"
    fi

    # Check Node.js
    if command -v node &>/dev/null; then
        local node_version=$(node --version 2>/dev/null)
        log_check "PASS" "Node.js installed ($node_version)"
    else
        log_check "FAIL" "Node.js is NOT installed"
    fi

    # Check npm
    if command -v npm &>/dev/null; then
        local npm_version=$(npm --version 2>/dev/null)
        log_check "PASS" "npm installed (v$npm_version)"
    else
        log_check "FAIL" "npm is NOT installed"
    fi

    # Validate each app
    for app_num in 0 1 2 3 4 5; do
        validate_app $app_num
    done
}

#-------------------------------------------------------------------------------
# Print Summary
#-------------------------------------------------------------------------------
print_summary() {
    log_header "VALIDATION SUMMARY"

    echo -e "  ${WHITE}Overall Statistics:${NC}"
    echo -e "    Total Checks:  $TOTAL_CHECKS"
    echo -e "    ${GREEN}Passed:${NC}        $PASSED_CHECKS"
    echo -e "    ${RED}Failed:${NC}        $FAILED_CHECKS"
    echo -e "    ${YELLOW}Warnings:${NC}      $WARNING_CHECKS"
    echo ""

    # Calculate success rate
    if [ $TOTAL_CHECKS -gt 0 ]; then
        local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
        echo -e "  ${WHITE}Success Rate:${NC} ${success_rate}%"
    fi

    echo ""
    log_section "App Status Overview"
    echo ""

    printf "  ${WHITE}%-6s %-20s %-12s %s${NC}\n" "App" "Name" "Status" "Issues"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────────────────${NC}"

    for app_num in 0 1 2 3 4 5; do
        local status="${APP_STATUS[$app_num]}"
        local issues="${APP_ISSUES[$app_num]}"
        local status_color

        case $status in
            "HEALTHY")   status_color="${GREEN}" ;;
            "WARNING")   status_color="${YELLOW}" ;;
            "UNHEALTHY") status_color="${RED}" ;;
            "MISSING")   status_color="${RED}" ;;
            *)           status_color="${NC}" ;;
        esac

        printf "  %-6s %-20s ${status_color}%-12s${NC} %s\n" \
            "App$app_num" "${APP_NAMES[$app_num]}" "$status" "$issues"
    done

    echo ""

    # Port Summary Table
    log_section "Port Status Overview"
    echo ""

    printf "  ${WHITE}%-6s %-15s %-8s %s${NC}\n" "App" "Service" "Port" "Status"
    echo -e "  ${CYAN}──────────────────────────────────────────────────────────────────${NC}"

    for app_num in 0 1 2 3 4 5; do
        local ports="${APP_PORTS[$app_num]}"
        local first=true

        for port_def in $ports; do
            local service_name=$(echo "$port_def" | cut -d: -f1)
            local port=$(echo "$port_def" | cut -d: -f2)
            local port_status

            if check_port $port; then
                port_status="${GREEN}UP${NC}"
            else
                port_status="${RED}DOWN${NC}"
            fi

            if [ "$first" = true ]; then
                printf "  %-6s %-15s %-8s %b\n" "App$app_num" "$service_name" "$port" "$port_status"
                first=false
            else
                printf "  %-6s %-15s %-8s %b\n" "" "$service_name" "$port" "$port_status"
            fi
        done
    done

    echo ""

    # Final Verdict
    log_section "Final Verdict"
    echo ""

    if [ $FAILED_CHECKS -eq 0 ]; then
        if [ $WARNING_CHECKS -eq 0 ]; then
            echo -e "  ${GREEN}${BOLD}ALL SYSTEMS OPERATIONAL${NC}"
            echo -e "  ${GREEN}All apps are running correctly with no issues detected.${NC}"
        else
            echo -e "  ${YELLOW}${BOLD}SYSTEMS OPERATIONAL WITH WARNINGS${NC}"
            echo -e "  ${YELLOW}All apps are running but some warnings need attention.${NC}"
        fi
    else
        echo -e "  ${RED}${BOLD}SYSTEM ISSUES DETECTED${NC}"
        echo -e "  ${RED}$FAILED_CHECKS checks failed. Please review the details above.${NC}"
    fi

    echo ""
    echo -e "  ${WHITE}Validation Completed:${NC} $(date)"
    echo ""
}

#-------------------------------------------------------------------------------
# Quick Check Mode (for CI/scripts)
#-------------------------------------------------------------------------------
quick_check() {
    local exit_code=0

    echo "OSPF Suite Quick Validation"
    echo "==========================="

    for app_num in 0 1 2 3 4 5; do
        local app_name="${APP_NAMES[$app_num]}"
        local ports="${APP_PORTS[$app_num]}"
        local all_up=true

        for port_def in $ports; do
            local port=$(echo "$port_def" | cut -d: -f2)
            if ! check_port $port; then
                all_up=false
            fi
        done

        if [ "$all_up" = true ]; then
            echo -e "App$app_num ($app_name): ${GREEN}OK${NC}"
        else
            echo -e "App$app_num ($app_name): ${RED}FAIL${NC}"
            exit_code=1
        fi
    done

    exit $exit_code
}

#-------------------------------------------------------------------------------
# JSON Output Mode
#-------------------------------------------------------------------------------
json_output() {
    # Run validation silently first
    exec 3>&1 4>&2
    exec 1>/dev/null 2>&1
    validate_all
    exec 1>&3 2>&4

    echo "{"
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"summary\": {"
    echo "    \"total_checks\": $TOTAL_CHECKS,"
    echo "    \"passed\": $PASSED_CHECKS,"
    echo "    \"failed\": $FAILED_CHECKS,"
    echo "    \"warnings\": $WARNING_CHECKS"
    echo "  },"
    echo "  \"apps\": {"

    local first_app=true
    for app_num in 0 1 2 3 4 5; do
        [ "$first_app" = false ] && echo ","
        first_app=false

        local ports_json=""
        local first_port=true
        for port_def in ${APP_PORTS[$app_num]}; do
            local service=$(echo "$port_def" | cut -d: -f1)
            local port=$(echo "$port_def" | cut -d: -f2)
            local status="down"
            check_port $port && status="up"

            [ "$first_port" = false ] && ports_json="$ports_json, "
            first_port=false
            ports_json="$ports_json{\"service\": \"$service\", \"port\": $port, \"status\": \"$status\"}"
        done

        echo -n "    \"app$app_num\": {"
        echo -n "\"name\": \"${APP_NAMES[$app_num]}\", "
        echo -n "\"status\": \"${APP_STATUS[$app_num]}\", "
        echo -n "\"issues\": \"${APP_ISSUES[$app_num]}\", "
        echo -n "\"ports\": [$ports_json]"
        echo -n "}"
    done

    echo ""
    echo "  }"
    echo "}"
}

#-------------------------------------------------------------------------------
# Help
#-------------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${CYAN}OSPF Suite Validation Script${NC}"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  validate   Full validation with detailed output (default)"
    echo "  quick      Quick check - returns exit code 0/1"
    echo "  json       Output results as JSON"
    echo "  status     Show port status only"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run full validation"
    echo "  $0 quick        # Quick status check"
    echo "  $0 json > status.json  # Export to JSON"
    echo ""
}

#-------------------------------------------------------------------------------
# Status Only Mode
#-------------------------------------------------------------------------------
status_only() {
    echo ""
    echo -e "${CYAN}OSPF Suite - Port Status${NC}"
    echo ""

    printf "%-6s %-20s %-15s %-8s %s\n" "App" "Name" "Service" "Port" "Status"
    echo "──────────────────────────────────────────────────────────────────────"

    for app_num in 0 1 2 3 4 5; do
        local ports="${APP_PORTS[$app_num]}"
        local first=true

        for port_def in $ports; do
            local service_name=$(echo "$port_def" | cut -d: -f1)
            local port=$(echo "$port_def" | cut -d: -f2)
            local port_status

            if check_port $port; then
                port_status="${GREEN}UP${NC}"
            else
                port_status="${RED}DOWN${NC}"
            fi

            if [ "$first" = true ]; then
                printf "%-6s %-20s %-15s %-8s %b\n" "App$app_num" "${APP_NAMES[$app_num]}" "$service_name" "$port" "$port_status"
                first=false
            else
                printf "%-6s %-20s %-15s %-8s %b\n" "" "" "$service_name" "$port" "$port_status"
            fi
        done
    done

    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    local command=${1:-validate}

    case "$command" in
        validate|full)
            validate_all
            print_summary
            ;;
        quick)
            quick_check
            ;;
        json)
            json_output
            ;;
        status)
            status_only
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
