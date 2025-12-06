#!/bin/bash
# ============================================================================
# AUTH-VAULT: Centralized Authentication & Secrets Management
# Native Installation Script (No Docker)
# ============================================================================
#
# This script installs and manages Keycloak + Vault for the OSPF Application Suite
# Port: 9120 (Keycloak), 9121 (Vault)
#
# Usage:
#   ./auth-vault.sh install    - Install all dependencies
#   ./auth-vault.sh start      - Start Keycloak and Vault
#   ./auth-vault.sh stop       - Stop all services
#   ./auth-vault.sh status     - Check service status
#   ./auth-vault.sh logs       - View logs
#   ./auth-vault.sh init       - Initialize Vault secrets
#   ./auth-vault.sh help       - Show this help
#
# ============================================================================

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTH_VAULT_HOME="${SCRIPT_DIR}"
DATA_DIR="${AUTH_VAULT_HOME}/data"
LOGS_DIR="${AUTH_VAULT_HOME}/logs"
BIN_DIR="${AUTH_VAULT_HOME}/bin"

# Versions
KEYCLOAK_VERSION="23.0.3"
VAULT_VERSION="1.15.4"

# Ports
KEYCLOAK_PORT=9120
VAULT_PORT=9121

# URLs
KEYCLOAK_URL="http://localhost:${KEYCLOAK_PORT}"
VAULT_URL="http://localhost:${VAULT_PORT}"

# PID files
KEYCLOAK_PID_FILE="${DATA_DIR}/.keycloak.pid"
VAULT_PID_FILE="${DATA_DIR}/.vault.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

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

log_header() {
    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

wait_for_service() {
    local url=$1
    local name=$2
    local max_attempts=${3:-60}
    local attempt=1

    log_info "Waiting for ${name} to be ready at ${url}..."

    while [ $attempt -le $max_attempts ]; do
        if curl -s "${url}" >/dev/null 2>&1; then
            log_success "${name} is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    echo ""
    log_error "${name} failed to start after ${max_attempts} attempts"
    return 1
}

# ============================================================================
# PLATFORM DETECTION
# ============================================================================

detect_platform() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "${OS}" in
        Linux*)
            PLATFORM="linux"
            if [ -f /etc/debian_version ]; then
                PKG_MANAGER="apt"
            elif [ -f /etc/redhat-release ]; then
                PKG_MANAGER="yum"
            elif [ -f /etc/arch-release ]; then
                PKG_MANAGER="pacman"
            else
                PKG_MANAGER="unknown"
            fi
            ;;
        Darwin*)
            PLATFORM="darwin"
            PKG_MANAGER="brew"
            ;;
        MINGW*|CYGWIN*|MSYS*)
            PLATFORM="windows"
            PKG_MANAGER="choco"
            ;;
        *)
            log_error "Unsupported operating system: ${OS}"
            exit 1
            ;;
    esac

    case "${ARCH}" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac

    log_info "Detected platform: ${PLATFORM} (${ARCH})"
    log_info "Package manager: ${PKG_MANAGER}"
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_homebrew() {
    if ! check_command brew; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add to PATH for this session
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -f /usr/local/bin/brew ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        log_success "Homebrew already installed"
    fi
}

install_java() {
    if ! check_command java || ! java -version 2>&1 | grep -q "version \"17\|version \"21"; then
        log_info "Installing Java 17 (required for Keycloak)..."

        case "${PKG_MANAGER}" in
            brew)
                brew install openjdk@17
                # Link Java
                if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
                    sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk 2>/dev/null || true
                    export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
                    export PATH="${JAVA_HOME}/bin:${PATH}"
                fi
                ;;
            apt)
                sudo apt update
                sudo apt install -y openjdk-17-jdk
                ;;
            yum)
                sudo yum install -y java-17-openjdk java-17-openjdk-devel
                ;;
            pacman)
                sudo pacman -S --noconfirm jdk17-openjdk
                ;;
            *)
                log_error "Please install Java 17 manually"
                exit 1
                ;;
        esac

        log_success "Java 17 installed"
    else
        log_success "Java 17+ already installed"
    fi
}

install_curl() {
    if ! check_command curl; then
        log_info "Installing curl..."

        case "${PKG_MANAGER}" in
            brew)
                brew install curl
                ;;
            apt)
                sudo apt update && sudo apt install -y curl
                ;;
            yum)
                sudo yum install -y curl
                ;;
            pacman)
                sudo pacman -S --noconfirm curl
                ;;
        esac
    fi
}

install_wget() {
    if ! check_command wget; then
        log_info "Installing wget..."

        case "${PKG_MANAGER}" in
            brew)
                brew install wget
                ;;
            apt)
                sudo apt update && sudo apt install -y wget
                ;;
            yum)
                sudo yum install -y wget
                ;;
            pacman)
                sudo pacman -S --noconfirm wget
                ;;
        esac
    fi
}

install_unzip() {
    if ! check_command unzip; then
        log_info "Installing unzip..."

        case "${PKG_MANAGER}" in
            brew)
                brew install unzip
                ;;
            apt)
                sudo apt update && sudo apt install -y unzip
                ;;
            yum)
                sudo yum install -y unzip
                ;;
            pacman)
                sudo pacman -S --noconfirm unzip
                ;;
        esac
    fi
}

install_jq() {
    if ! check_command jq; then
        log_info "Installing jq (JSON processor)..."

        case "${PKG_MANAGER}" in
            brew)
                brew install jq
                ;;
            apt)
                sudo apt update && sudo apt install -y jq
                ;;
            yum)
                sudo yum install -y jq
                ;;
            pacman)
                sudo pacman -S --noconfirm jq
                ;;
        esac
    fi
}

# ============================================================================
# KEYCLOAK INSTALLATION
# ============================================================================

install_keycloak() {
    local keycloak_dir="${BIN_DIR}/keycloak-${KEYCLOAK_VERSION}"

    if [ -d "${keycloak_dir}" ]; then
        log_success "Keycloak ${KEYCLOAK_VERSION} already installed"
        return 0
    fi

    log_info "Downloading Keycloak ${KEYCLOAK_VERSION}..."

    local download_url="https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz"
    local temp_file="/tmp/keycloak-${KEYCLOAK_VERSION}.tar.gz"

    mkdir -p "${BIN_DIR}"

    if ! wget -q --show-progress -O "${temp_file}" "${download_url}"; then
        log_error "Failed to download Keycloak"
        exit 1
    fi

    log_info "Extracting Keycloak..."
    tar -xzf "${temp_file}" -C "${BIN_DIR}"
    rm -f "${temp_file}"

    # Create symlink
    ln -sfn "${keycloak_dir}" "${BIN_DIR}/keycloak"

    log_success "Keycloak ${KEYCLOAK_VERSION} installed to ${keycloak_dir}"
}

# ============================================================================
# VAULT INSTALLATION
# ============================================================================

install_vault() {
    if [ -f "${BIN_DIR}/vault" ]; then
        log_success "Vault already installed"
        return 0
    fi

    log_info "Downloading Vault ${VAULT_VERSION}..."

    local vault_os="${PLATFORM}"
    local vault_arch="${ARCH}"

    # Vault uses different naming
    if [ "${vault_arch}" = "amd64" ]; then
        vault_arch="amd64"
    elif [ "${vault_arch}" = "arm64" ]; then
        vault_arch="arm64"
    fi

    local download_url="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_${vault_os}_${vault_arch}.zip"
    local temp_file="/tmp/vault_${VAULT_VERSION}.zip"

    mkdir -p "${BIN_DIR}"

    if ! wget -q --show-progress -O "${temp_file}" "${download_url}"; then
        log_error "Failed to download Vault"
        exit 1
    fi

    log_info "Extracting Vault..."
    unzip -o -q "${temp_file}" -d "${BIN_DIR}"
    rm -f "${temp_file}"

    chmod +x "${BIN_DIR}/vault"

    log_success "Vault ${VAULT_VERSION} installed to ${BIN_DIR}/vault"
}

# ============================================================================
# CONFIGURATION
# ============================================================================

configure_keycloak() {
    log_info "Configuring Keycloak..."

    local keycloak_conf="${BIN_DIR}/keycloak/conf/keycloak.conf"

    # Backup existing config
    if [ -f "${keycloak_conf}" ]; then
        cp "${keycloak_conf}" "${keycloak_conf}.bak"
    fi

    # Create configuration
    cat > "${keycloak_conf}" << EOF
# Keycloak Configuration for Auth-Vault
# Port: ${KEYCLOAK_PORT}

# HTTP Configuration
http-enabled=true
http-port=${KEYCLOAK_PORT}
http-host=0.0.0.0

# Hostname
hostname-strict=false
hostname-strict-https=false

# Database (H2 embedded - for development)
# For production, use PostgreSQL
db=dev-file
db-url=jdbc:h2:file:${DATA_DIR}/keycloak/keycloakdb;AUTO_SERVER=TRUE

# Health and Metrics
health-enabled=true
metrics-enabled=true

# Features
features=token-exchange,admin-fine-grained-authz

# Logging
log=console,file
log-file=${LOGS_DIR}/keycloak.log
log-level=INFO

# Cache
cache=local
EOF

    # Create data directory
    mkdir -p "${DATA_DIR}/keycloak"

    log_success "Keycloak configured"
}

configure_vault() {
    log_info "Configuring Vault..."

    mkdir -p "${DATA_DIR}/vault"
    mkdir -p "${LOGS_DIR}"

    # Create Vault configuration
    cat > "${DATA_DIR}/vault/config.hcl" << EOF
# Vault Configuration for Auth-Vault
# Port: ${VAULT_PORT}

storage "file" {
  path = "${DATA_DIR}/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:${VAULT_PORT}"
  tls_disable = 1
}

api_addr = "http://127.0.0.1:${VAULT_PORT}"
cluster_addr = "http://127.0.0.1:${VAULT_PORT}"

ui = true
disable_mlock = true

log_level = "info"
EOF

    mkdir -p "${DATA_DIR}/vault/data"

    log_success "Vault configured"
}

# ============================================================================
# REALM IMPORT
# ============================================================================

import_keycloak_realms() {
    log_info "Importing Keycloak realms..."

    local keycloak_bin="${BIN_DIR}/keycloak/bin"
    local realms_dir="${AUTH_VAULT_HOME}/keycloak/realms"

    if [ ! -d "${realms_dir}" ]; then
        log_warning "Realms directory not found: ${realms_dir}"
        return 0
    fi

    # Wait for Keycloak to be ready
    wait_for_service "${KEYCLOAK_URL}" "Keycloak" 120

    # Get admin token
    log_info "Authenticating with Keycloak admin..."

    local admin_user="${KC_ADMIN_USER:-admin}"
    local admin_pass="${KC_ADMIN_PASSWORD:-admin}"

    local token_response
    token_response=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${admin_user}" \
        -d "password=${admin_pass}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli")

    local access_token
    access_token=$(echo "${token_response}" | jq -r '.access_token')

    if [ "${access_token}" = "null" ] || [ -z "${access_token}" ]; then
        log_error "Failed to get admin token. Response: ${token_response}"
        return 1
    fi

    # Import each realm
    for realm_file in "${realms_dir}"/*.json; do
        if [ -f "${realm_file}" ]; then
            local realm_name
            realm_name=$(jq -r '.realm' "${realm_file}")

            log_info "Importing realm: ${realm_name}"

            # Check if realm exists
            local existing
            existing=$(curl -s -o /dev/null -w "%{http_code}" \
                -H "Authorization: Bearer ${access_token}" \
                "${KEYCLOAK_URL}/admin/realms/${realm_name}")

            if [ "${existing}" = "200" ]; then
                log_warning "Realm ${realm_name} already exists, skipping..."
                continue
            fi

            # Import realm
            local import_response
            import_response=$(curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
                -H "Authorization: Bearer ${access_token}" \
                -H "Content-Type: application/json" \
                -d @"${realm_file}")

            if [ -z "${import_response}" ]; then
                log_success "Realm ${realm_name} imported successfully"
            else
                log_warning "Realm import response: ${import_response}"
            fi
        fi
    done

    log_success "Realm import completed"
}

# ============================================================================
# VAULT INITIALIZATION
# ============================================================================

init_vault() {
    log_header "Initializing Vault"

    export VAULT_ADDR="${VAULT_URL}"
    local vault_bin="${BIN_DIR}/vault"

    # Check if Vault is already initialized
    local status
    status=$("${vault_bin}" status -format=json 2>/dev/null || echo '{"initialized": false}')

    local initialized
    initialized=$(echo "${status}" | jq -r '.initialized')

    if [ "${initialized}" = "true" ]; then
        log_warning "Vault is already initialized"

        # Check if sealed
        local sealed
        sealed=$(echo "${status}" | jq -r '.sealed')

        if [ "${sealed}" = "true" ]; then
            log_info "Vault is sealed. Please unseal manually using:"
            log_info "  export VAULT_ADDR=${VAULT_URL}"
            log_info "  ${vault_bin} operator unseal <unseal_key>"
            return 1
        fi

        return 0
    fi

    log_info "Initializing Vault with 1 key share, 1 key threshold (development mode)..."

    local init_output
    init_output=$("${vault_bin}" operator init -key-shares=1 -key-threshold=1 -format=json)

    # Save keys securely
    local keys_file="${DATA_DIR}/vault/vault-keys.json"
    echo "${init_output}" > "${keys_file}"
    chmod 600 "${keys_file}"

    local unseal_key
    unseal_key=$(echo "${init_output}" | jq -r '.unseal_keys_b64[0]')

    local root_token
    root_token=$(echo "${init_output}" | jq -r '.root_token')

    log_success "Vault initialized!"
    log_warning "IMPORTANT: Save these credentials securely!"
    echo ""
    echo "  Unseal Key: ${unseal_key}"
    echo "  Root Token: ${root_token}"
    echo ""
    echo "  Keys saved to: ${keys_file}"
    echo ""

    # Unseal Vault
    log_info "Unsealing Vault..."
    "${vault_bin}" operator unseal "${unseal_key}"

    # Login with root token
    export VAULT_TOKEN="${root_token}"

    # Run initialization script
    if [ -f "${AUTH_VAULT_HOME}/vault/init-scripts/init-vault.sh" ]; then
        log_info "Running Vault initialization script..."
        export KC_URL="${KEYCLOAK_URL}"
        bash "${AUTH_VAULT_HOME}/vault/init-scripts/init-vault.sh"
    fi

    log_success "Vault initialization complete!"

    # Save environment for future use
    cat > "${DATA_DIR}/.vault-env" << EOF
export VAULT_ADDR=${VAULT_URL}
export VAULT_TOKEN=${root_token}
EOF
    chmod 600 "${DATA_DIR}/.vault-env"

    log_info "Vault environment saved to: ${DATA_DIR}/.vault-env"
    log_info "Source it with: source ${DATA_DIR}/.vault-env"
}

# ============================================================================
# SERVICE MANAGEMENT
# ============================================================================

start_keycloak() {
    log_info "Starting Keycloak on port ${KEYCLOAK_PORT}..."

    if [ -f "${KEYCLOAK_PID_FILE}" ]; then
        local pid
        pid=$(cat "${KEYCLOAK_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_warning "Keycloak is already running (PID: ${pid})"
            return 0
        fi
        rm -f "${KEYCLOAK_PID_FILE}"
    fi

    local keycloak_bin="${BIN_DIR}/keycloak/bin/kc.sh"

    if [ ! -f "${keycloak_bin}" ]; then
        log_error "Keycloak not installed. Run: ./auth-vault.sh install"
        exit 1
    fi

    # Set Java home if needed
    if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk@17"
        export PATH="${JAVA_HOME}/bin:${PATH}"
    fi

    # Set admin credentials from environment or defaults
    export KEYCLOAK_ADMIN="${KC_ADMIN_USER:-admin}"
    export KEYCLOAK_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin}"

    mkdir -p "${LOGS_DIR}"

    # Start Keycloak in background
    nohup "${keycloak_bin}" start-dev \
        --http-port=${KEYCLOAK_PORT} \
        --import-realm \
        > "${LOGS_DIR}/keycloak.log" 2>&1 &

    local pid=$!
    echo "${pid}" > "${KEYCLOAK_PID_FILE}"

    log_success "Keycloak started (PID: ${pid})"
    log_info "Keycloak URL: ${KEYCLOAK_URL}"
    log_info "Admin Console: ${KEYCLOAK_URL}/admin"
    log_info "Credentials: ${KEYCLOAK_ADMIN} / ${KEYCLOAK_ADMIN_PASSWORD}"
}

start_vault() {
    log_info "Starting Vault on port ${VAULT_PORT}..."

    if [ -f "${VAULT_PID_FILE}" ]; then
        local pid
        pid=$(cat "${VAULT_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_warning "Vault is already running (PID: ${pid})"
            return 0
        fi
        rm -f "${VAULT_PID_FILE}"
    fi

    local vault_bin="${BIN_DIR}/vault"

    if [ ! -f "${vault_bin}" ]; then
        log_error "Vault not installed. Run: ./auth-vault.sh install"
        exit 1
    fi

    mkdir -p "${LOGS_DIR}"
    mkdir -p "${DATA_DIR}/vault/data"

    # Start Vault in background
    nohup "${vault_bin}" server -config="${DATA_DIR}/vault/config.hcl" \
        > "${LOGS_DIR}/vault.log" 2>&1 &

    local pid=$!
    echo "${pid}" > "${VAULT_PID_FILE}"

    log_success "Vault started (PID: ${pid})"
    log_info "Vault URL: ${VAULT_URL}"
    log_info "Vault UI: ${VAULT_URL}/ui"
}

stop_keycloak() {
    log_info "Stopping Keycloak..."

    if [ -f "${KEYCLOAK_PID_FILE}" ]; then
        local pid
        pid=$(cat "${KEYCLOAK_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}"
            sleep 2
            if kill -0 "${pid}" 2>/dev/null; then
                kill -9 "${pid}"
            fi
            log_success "Keycloak stopped"
        else
            log_warning "Keycloak process not found"
        fi
        rm -f "${KEYCLOAK_PID_FILE}"
    else
        log_warning "Keycloak PID file not found"
        # Try to find and kill by port
        local pid
        pid=$(lsof -ti:${KEYCLOAK_PORT} 2>/dev/null || true)
        if [ -n "${pid}" ]; then
            kill "${pid}" 2>/dev/null || true
            log_success "Keycloak stopped (found by port)"
        fi
    fi
}

stop_vault() {
    log_info "Stopping Vault..."

    if [ -f "${VAULT_PID_FILE}" ]; then
        local pid
        pid=$(cat "${VAULT_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}"
            sleep 2
            if kill -0 "${pid}" 2>/dev/null; then
                kill -9 "${pid}"
            fi
            log_success "Vault stopped"
        else
            log_warning "Vault process not found"
        fi
        rm -f "${VAULT_PID_FILE}"
    else
        log_warning "Vault PID file not found"
        # Try to find and kill by port
        local pid
        pid=$(lsof -ti:${VAULT_PORT} 2>/dev/null || true)
        if [ -n "${pid}" ]; then
            kill "${pid}" 2>/dev/null || true
            log_success "Vault stopped (found by port)"
        fi
    fi
}

# ============================================================================
# STATUS CHECKING
# ============================================================================

check_status() {
    log_header "Auth-Vault Status"

    echo "Configuration:"
    echo "  Keycloak Port: ${KEYCLOAK_PORT}"
    echo "  Vault Port: ${VAULT_PORT}"
    echo "  Data Directory: ${DATA_DIR}"
    echo "  Logs Directory: ${LOGS_DIR}"
    echo ""

    # Check Keycloak
    echo -n "Keycloak: "
    if [ -f "${KEYCLOAK_PID_FILE}" ]; then
        local pid
        pid=$(cat "${KEYCLOAK_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            if curl -s "${KEYCLOAK_URL}" >/dev/null 2>&1; then
                echo -e "${GREEN}Running${NC} (PID: ${pid}, Port: ${KEYCLOAK_PORT})"
            else
                echo -e "${YELLOW}Starting${NC} (PID: ${pid})"
            fi
        else
            echo -e "${RED}Stopped${NC} (stale PID file)"
        fi
    else
        echo -e "${RED}Stopped${NC}"
    fi

    # Check Vault
    echo -n "Vault: "
    if [ -f "${VAULT_PID_FILE}" ]; then
        local pid
        pid=$(cat "${VAULT_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            if curl -s "${VAULT_URL}/v1/sys/health" >/dev/null 2>&1; then
                local vault_status
                vault_status=$(curl -s "${VAULT_URL}/v1/sys/health" | jq -r '.sealed // "unknown"')
                if [ "${vault_status}" = "false" ]; then
                    echo -e "${GREEN}Running (Unsealed)${NC} (PID: ${pid}, Port: ${VAULT_PORT})"
                else
                    echo -e "${YELLOW}Running (Sealed)${NC} (PID: ${pid})"
                fi
            else
                echo -e "${YELLOW}Starting${NC} (PID: ${pid})"
            fi
        else
            echo -e "${RED}Stopped${NC} (stale PID file)"
        fi
    else
        echo -e "${RED}Stopped${NC}"
    fi

    echo ""
    echo "URLs:"
    echo "  Keycloak Admin: ${KEYCLOAK_URL}/admin"
    echo "  Vault UI: ${VAULT_URL}/ui"
}

# ============================================================================
# LOG VIEWING
# ============================================================================

view_logs() {
    local service="${1:-all}"

    case "${service}" in
        keycloak)
            if [ -f "${LOGS_DIR}/keycloak.log" ]; then
                tail -f "${LOGS_DIR}/keycloak.log"
            else
                log_error "Keycloak log file not found"
            fi
            ;;
        vault)
            if [ -f "${LOGS_DIR}/vault.log" ]; then
                tail -f "${LOGS_DIR}/vault.log"
            else
                log_error "Vault log file not found"
            fi
            ;;
        all|*)
            log_info "Viewing all logs (Ctrl+C to exit)..."
            tail -f "${LOGS_DIR}"/*.log 2>/dev/null || log_error "No log files found"
            ;;
    esac
}

# ============================================================================
# INSTALLATION
# ============================================================================

install_all() {
    log_header "Installing Auth-Vault Dependencies"

    detect_platform

    # Create directories
    mkdir -p "${DATA_DIR}" "${LOGS_DIR}" "${BIN_DIR}"

    # Install package manager (macOS)
    if [ "${PLATFORM}" = "darwin" ]; then
        install_homebrew
    fi

    # Install dependencies
    install_curl
    install_wget
    install_unzip
    install_jq
    install_java

    # Install services
    install_keycloak
    install_vault

    # Configure services
    configure_keycloak
    configure_vault

    log_header "Installation Complete!"

    echo "Next steps:"
    echo "  1. Start services:    ./auth-vault.sh start"
    echo "  2. Initialize Vault:  ./auth-vault.sh init"
    echo "  3. Check status:      ./auth-vault.sh status"
    echo ""
    echo "Default credentials:"
    echo "  Keycloak Admin: admin / admin"
    echo "  (Change these immediately in production!)"
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    echo ""
    echo "Auth-Vault: Centralized Authentication & Secrets Management"
    echo ""
    echo "Usage: ./auth-vault.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  install       Install all dependencies (Keycloak, Vault, Java, etc.)"
    echo "  start         Start Keycloak and Vault services"
    echo "  stop          Stop all services"
    echo "  restart       Restart all services"
    echo "  status        Show service status"
    echo "  init          Initialize Vault (create keys, secrets, policies)"
    echo "  logs [svc]    View logs (keycloak, vault, or all)"
    echo "  import        Import Keycloak realms"
    echo "  help          Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Keycloak Port: ${KEYCLOAK_PORT}"
    echo "  Vault Port: ${VAULT_PORT}"
    echo "  Data Dir: ${DATA_DIR}"
    echo ""
    echo "Environment Variables:"
    echo "  KC_ADMIN_USER      Keycloak admin username (default: admin)"
    echo "  KC_ADMIN_PASSWORD  Keycloak admin password (default: admin)"
    echo ""
    echo "Examples:"
    echo "  ./auth-vault.sh install          # First-time setup"
    echo "  ./auth-vault.sh start            # Start services"
    echo "  ./auth-vault.sh init             # Initialize Vault"
    echo "  ./auth-vault.sh logs keycloak    # View Keycloak logs"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local command="${1:-help}"
    shift || true

    case "${command}" in
        install)
            install_all
            ;;
        start)
            start_vault
            start_keycloak
            log_info "Waiting for services to start..."
            sleep 5
            check_status
            ;;
        stop)
            stop_keycloak
            stop_vault
            ;;
        restart)
            stop_keycloak
            stop_vault
            sleep 2
            start_vault
            start_keycloak
            log_info "Waiting for services to restart..."
            sleep 5
            check_status
            ;;
        status)
            check_status
            ;;
        init)
            init_vault
            ;;
        import)
            import_keycloak_realms
            ;;
        logs)
            view_logs "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
