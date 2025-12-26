#!/bin/bash
#
#===============================================================================
#
#   DOGECOIN NODE SETUP SCRIPT FOR DEBIAN 13
#   
#   A fully interactive setup script for deploying and managing Dogecoin nodes
#   on Debian 13 (Trixie) systems, with support for both standard wallet
#   nodes and mining pool backend configurations.
#
#===============================================================================
#
#   USAGE:
#       sudo ./setup-dogecoin.sh
#
#   CAPABILITIES:
#       • Fresh Installation - Build and install Dogecoin node from source
#       • Update - Update Dogecoin binaries while preserving configuration
#       • Reconfigure - Change node settings without reinstalling
#       • Wallet Management - Create or import wallets (for mining pools)
#
#   REQUIREMENTS:
#       - Debian 13 (Trixie) or compatible Debian-based system
#       - Root/sudo access
#       - Minimum 4GB RAM (8GB recommended for compilation)
#       - Minimum 120GB disk space for full node (10GB for pruned)
#       - Internet connection for downloading source code
#
#   NODE TYPES:
#       - Standard Node: For personal wallet use, remote wallet connections
#       - Mining Pool Node: Optimized backend for mining pool software
#
#   BLOCKCHAIN MODES:
#       - Full Node: Complete blockchain (~100GB), maximum security
#       - Pruned Node: Reduced blockchain (~4GB), still validates all blocks
#
#   CONFIGURATION FILES:
#       - /etc/dogecoin/dogecoin.conf     - Main daemon configuration
#       - /etc/dogecoin/pool-wallet.conf  - Pool wallet info (pool mode only)
#       - /etc/systemd/system/dogecoind.service - Systemd service file
#
#   DEFAULT PATHS:
#       - Binaries:    /opt/dogecoin/
#       - Blockchain:  /var/lib/dogecoin/
#       - Wallets:     /var/lib/dogecoin/wallets/
#       - Logs:        /var/log/dogecoin/
#       - Config:      /etc/dogecoin/
#       - Source:      /usr/local/src/dogecoin/
#
#   NETWORK PORTS:
#       - 22556/tcp: P2P (peer-to-peer network connections)
#       - 22555/tcp: RPC (wallet/pool software connections)
#       - 28332/tcp: ZMQ hashblock (block notifications, mining pool mode only)
#       - 28333/tcp: ZMQ rawblock (raw block data, mining pool mode only)
#
#   REPOSITORY:
#       https://github.com/wattfource/dogecoin-node-installer
#
#   LICENSE:
#       MIT License - See repository for details
#
#===============================================================================

# Don't use set -e - we handle errors explicitly for better user feedback
# set -e

#===============================================================================
# CONFIGURATION DEFAULTS
#===============================================================================

# Script version and update URL
SCRIPT_VERSION="1.0.0"
SCRIPT_REPO="https://github.com/wattfource/dogecoin-node-installer"
SCRIPT_RAW_URL="https://raw.githubusercontent.com/wattfource/dogecoin-node-installer/main/setup-dogecoin.sh"
SCRIPT_VERSION_URL="https://raw.githubusercontent.com/wattfource/dogecoin-node-installer/main/VERSION"

# Dogecoin version and source
DOGECOIN_VERSION="v1.14.9"
DOGECOIN_REPO="https://github.com/dogecoin/dogecoin.git"

# Default installation paths
INSTALL_DIR="/opt/dogecoin"
DATA_DIR="/var/lib/dogecoin"
WALLET_DIR="/var/lib/dogecoin/wallets"
CONFIG_DIR="/etc/dogecoin"
LOG_DIR="/var/log/dogecoin"
SOURCE_DIR="/usr/local/src/dogecoin"
DOGECOIN_USER="dogecoin"

# Default network configuration
RPC_BIND_IP="0.0.0.0"
RPC_PORT="22555"
P2P_PORT="22556"
ZMQ_HASHBLOCK_PORT="28332"
ZMQ_RAWBLOCK_PORT="28333"

# Default mode settings
NODE_TYPE="standard"           # standard or pool
BLOCKCHAIN_MODE="full"         # full or pruned
PRUNE_SIZE="4000"              # Prune target in MB (4GB)
CONFIGURE_FIREWALL="Y"
RPC_USERNAME=""
RPC_PASSWORD=""

# Block notification settings (for mining pool)
ENABLE_ZMQ="N"                 # ZMQ block notifications (can have issues)
ENABLE_BLOCKNOTIFY="N"         # blocknotify script (alternative to ZMQ)
BLOCKNOTIFY_CMD=""             # Command to run on new block

# Pool wallet settings
POOL_WALLET_ADDRESS=""
CREATE_POOL_WALLET="N"

# Installation mode
SETUP_MODE="fresh"             # fresh, update, reconfigure

# Build settings
BUILD_JOBS=$(nproc)

#===============================================================================
# TERMINAL COLORS
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║               DOGECOIN NODE SETUP FOR DEBIAN 13                      ║"
    echo "║                                                                      ║"
    echo "║                    Interactive Setup Wizard                          ║"
    echo "║                                                                      ║"
    echo -e "║                        Version ${SCRIPT_VERSION}                               ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_subsection() {
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "${MAGENTA}[STEP $1]${NC} $2"
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local result
    
    echo "" >/dev/tty
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
    if [[ "$default" == "Y" ]]; then
        echo -e "  ${BOLD}${prompt}${NC}" >/dev/tty
        echo "" >/dev/tty
        echo -e "  Type ${GREEN}${BOLD}Y${NC} for Yes, ${CYAN}N${NC} for No" >/dev/tty
        echo -e "  ${GREEN}(Press Enter to accept default: Yes)${NC}" >/dev/tty
    else
        echo -e "  ${BOLD}${prompt}${NC}" >/dev/tty
        echo "" >/dev/tty
        echo -e "  Type ${CYAN}Y${NC} for Yes, ${GREEN}${BOLD}N${NC} for No" >/dev/tty
        echo -e "  ${GREEN}(Press Enter to accept default: No)${NC}" >/dev/tty
    fi
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
    echo "" >/dev/tty
    echo -ne "  ${BOLD}Your choice [Y/N]:${NC} " >/dev/tty
    
    read -r result </dev/tty
    result="${result:-$default}"
    
    if [[ "$result" =~ ^[Yy]$ ]]; then
        echo -e "  ${GREEN}✓ Yes${NC}" >/dev/tty
        return 0
    else
        echo -e "  ${CYAN}✓ No${NC}" >/dev/tty
        return 1
    fi
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local result
    
    # Output display to /dev/tty so it shows when function is called with $()
    echo "" >/dev/tty
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
    echo -e "  ${BOLD}${prompt}${NC}" >/dev/tty
    echo "" >/dev/tty
    echo -e "  Default value: ${GREEN}${default}${NC}" >/dev/tty
    echo -e "  ${CYAN}(Press Enter to accept default, or type a new value)${NC}" >/dev/tty
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
    echo "" >/dev/tty
    echo -ne "  ${BOLD}Enter value:${NC} " >/dev/tty
    read -r result </dev/tty
    
    if [[ -z "$result" ]]; then
        echo -e "  ${GREEN}✓ Using default: ${default}${NC}" >/dev/tty
        echo "$default"
    else
        echo -e "  ${GREEN}✓ Set to: ${result}${NC}" >/dev/tty
        echo "$result"
    fi
}

prompt_input_required() {
    local prompt="$1"
    local result=""
    
    # Output display to /dev/tty so it shows when function is called with $()
    echo "" >/dev/tty
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
    echo -e "  ${BOLD}${prompt}${NC} ${RED}(required - no default)${NC}" >/dev/tty
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
    echo "" >/dev/tty
    
    while [[ -z "$result" ]]; do
        echo -ne "  ${BOLD}Enter value:${NC} " >/dev/tty
        read -r result </dev/tty
        if [[ -z "$result" ]]; then
            echo "" >/dev/tty
            echo -e "${YELLOW}[!]${NC} This field is required - please enter a value" >/dev/tty
            echo "" >/dev/tty
        fi
    done
    
    echo -e "  ${GREEN}✓ Set to: ${result}${NC}" >/dev/tty
    echo "$result"
}

prompt_secret() {
    local prompt="$1"
    local result
    
    echo -ne "${YELLOW}${prompt}:${NC} " >/dev/tty
    read -rs result </dev/tty
    echo "" >/dev/tty
    echo "$result"
}

prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice
    local valid=false
    local num_options=${#options[@]}
    
    # Output display to /dev/tty so it shows when function is called with $()
    echo "" >/dev/tty
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════╗${NC}" >/dev/tty
    echo -e "${CYAN}║${NC}  ${BOLD}${prompt}${NC}" >/dev/tty
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}" >/dev/tty
    echo -e "${CYAN}║${NC}" >/dev/tty
    
    for i in "${!options[@]}"; do
        local num=$((i+1))
        if [[ $num -eq 1 ]]; then
            echo -e "${CYAN}║${NC}    ${GREEN}${BOLD}>> Type [1]${NC}  ${options[$i]} ${GREEN}(default)${NC}" >/dev/tty
        else
            echo -e "${CYAN}║${NC}    ${YELLOW}${BOLD}>> Type [$num]${NC}  ${options[$i]}" >/dev/tty
        fi
    done
    
    echo -e "${CYAN}║${NC}" >/dev/tty
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════╝${NC}" >/dev/tty
    echo "" >/dev/tty
    
    while [[ "$valid" == false ]]; do
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
        echo -e "${YELLOW}  YOUR SELECTION: Type a number (1-${num_options}) and press Enter${NC}" >/dev/tty
        echo -e "${YELLOW}  Or just press Enter to accept the default [1]${NC}" >/dev/tty
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >/dev/tty
        echo "" >/dev/tty
        echo -ne "  ${BOLD}Enter choice [1-${num_options}]:${NC} " >/dev/tty
        read -r choice </dev/tty
        
        # Default to 1 if empty
        if [[ -z "$choice" ]]; then
            choice=1
            valid=true
            echo "" >/dev/tty
            echo -e "  ${GREEN}✓ Selected option 1 (default)${NC}" >/dev/tty
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$num_options" ]]; then
            valid=true
            echo "" >/dev/tty
            echo -e "  ${GREEN}✓ Selected option ${choice}${NC}" >/dev/tty
        else
            echo "" >/dev/tty
            echo -e "${YELLOW}[!]${NC} Invalid! Please type a number between 1 and ${num_options}" >/dev/tty
            echo "" >/dev/tty
        fi
    done
    
    echo "" >/dev/tty
    # Only the choice number goes to stdout (for capture)
    echo "$choice"
}

#===============================================================================
# SELF-UPDATE MECHANISM
#===============================================================================

check_for_script_update() {
    # Skip update check if no internet or curl not available
    if ! command -v curl &> /dev/null; then
        return 0
    fi
    
    print_info "Checking for script updates..."
    
    # Try to get remote version
    local remote_version
    remote_version=$(curl -sL --connect-timeout 5 "$SCRIPT_VERSION_URL" 2>/dev/null | head -1 | tr -d '[:space:]')
    
    # If we can't get remote version, try to extract from remote script
    if [[ -z "$remote_version" ]] || [[ ! "$remote_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        remote_version=$(curl -sL --connect-timeout 5 "$SCRIPT_RAW_URL" 2>/dev/null | grep -m1 'SCRIPT_VERSION="' | cut -d'"' -f2)
    fi
    
    # If still can't get version, skip update check
    if [[ -z "$remote_version" ]]; then
        print_warning "Could not check for updates (no internet?)"
        return 0
    fi
    
    # Compare versions
    if [[ "$remote_version" == "$SCRIPT_VERSION" ]]; then
        print_success "Script is up to date (v${SCRIPT_VERSION})"
        return 0
    fi
    
    # Version comparison (simple string compare works for semver)
    if [[ "$remote_version" > "$SCRIPT_VERSION" ]]; then
        echo ""
        echo -e "${YELLOW}╭─────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "${YELLOW}│${NC}  ${BOLD}NEW VERSION AVAILABLE!${NC}                                            ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}                                                                     ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  Current version: ${RED}v${SCRIPT_VERSION}${NC}                                          ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  Latest version:  ${GREEN}v${remote_version}${NC}                                          ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}                                                                     ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  It's recommended to update for bug fixes and new features.        ${YELLOW}│${NC}"
        echo -e "${YELLOW}╰─────────────────────────────────────────────────────────────────────╯${NC}"
        echo ""
        
        if prompt_yes_no "Download and install the latest version?" "Y"; then
            update_script
        else
            print_warning "Continuing with current version (v${SCRIPT_VERSION})"
            echo "  You can update later by re-running the bootstrap command."
        fi
    else
        print_success "Script is up to date (v${SCRIPT_VERSION})"
    fi
}

update_script() {
    print_info "Downloading latest version..."
    
    local script_path="$0"
    local tmp_script="/tmp/setup-dogecoin-new.sh"
    
    # Download new version to temp file
    if curl -sL "$SCRIPT_RAW_URL" -o "$tmp_script" 2>/dev/null; then
        # Verify it's a valid bash script
        if head -1 "$tmp_script" | grep -q "^#!/bin/bash"; then
            # Check syntax
            if bash -n "$tmp_script" 2>/dev/null; then
                # Backup current script
                cp "$script_path" "${script_path}.backup" 2>/dev/null || true
                
                # Replace with new version
                mv "$tmp_script" "$script_path"
                chmod +x "$script_path"
                
                print_success "Script updated successfully!"
                echo ""
                echo -e "${GREEN}Restarting with new version...${NC}"
                echo ""
                sleep 2
                
                # Re-execute the new script with same arguments
                exec "$script_path" "$@"
            else
                print_error "Downloaded script has syntax errors - keeping current version"
                rm -f "$tmp_script"
            fi
        else
            print_error "Downloaded file is not a valid script - keeping current version"
            rm -f "$tmp_script"
        fi
    else
        print_error "Failed to download update - keeping current version"
    fi
}

#===============================================================================
# SYSTEM CHECKS
#===============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        echo ""
        echo "Usage: sudo ./setup-dogecoin.sh"
        exit 1
    fi
    print_success "Running as root"
}

check_debian() {
    if [[ ! -f /etc/debian_version ]]; then
        print_error "This script is designed for Debian-based systems"
        exit 1
    fi
    local version=$(cat /etc/debian_version)
    print_success "Detected Debian version: ${version}"
}

check_cpu() {
    local cpu_cores=$(nproc)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    
    print_info "CPU: ${cpu_model}"
    print_info "CPU cores: ${cpu_cores}"
    
    # Update BUILD_JOBS based on available cores
    BUILD_JOBS=$cpu_cores
    
    if [[ $cpu_cores -lt 2 ]]; then
        print_warning "Only ${cpu_cores} CPU core(s) detected!"
        echo "         Compilation will be very slow."
        echo "         2 cores minimum | 4 cores recommended"
        BUILD_JOBS=1
    elif [[ $cpu_cores -lt 4 ]]; then
        print_warning "Only ${cpu_cores} CPU cores - 4 recommended for mining pool"
        echo "         Compilation will work but may take longer."
    else
        print_success "CPU cores: ${cpu_cores} (sufficient for mining pool)"
    fi
}

check_existing_installation() {
    local found=false
    
    if [[ -f "$INSTALL_DIR/bin/dogecoind" ]]; then
        found=true
        local current_version=$("$INSTALL_DIR/bin/dogecoind" --version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1 || echo "unknown")
        print_info "Existing Dogecoin installation found: ${current_version}"
    fi
    
    if [[ -f "$CONFIG_DIR/dogecoin.conf" ]]; then
        found=true
        print_info "Existing configuration found"
    fi
    
    if systemctl is-active --quiet dogecoind 2>/dev/null; then
        print_info "Dogecoin daemon is currently running"
    fi
    
    if [[ "$found" == true ]]; then
        return 0
    else
        return 1
    fi
}

check_disk_space() {
    local available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    print_info "Available disk space: ${available_gb}GB"
    
    local required_gb=120
    local recommended_gb=200
    if [[ "$BLOCKCHAIN_MODE" == "pruned" ]]; then
        required_gb=20
        recommended_gb=50
    fi
    
    # Check for SSD (mining pool recommendation)
    local disk_type="unknown"
    local root_device=$(df / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//')
    if [[ -f "/sys/block/$(basename $root_device)/queue/rotational" ]]; then
        local rotational=$(cat "/sys/block/$(basename $root_device)/queue/rotational" 2>/dev/null || echo "1")
        if [[ "$rotational" == "0" ]]; then
            disk_type="SSD/NVMe"
            print_success "Storage type: ${disk_type} (recommended)"
        else
            disk_type="HDD"
            print_warning "Storage type: ${disk_type}"
            if [[ "$NODE_TYPE" == "pool" ]]; then
                echo ""
                echo -e "${YELLOW}         ⚠ WARNING: HDD detected!${NC}"
                echo "         Mining pool nodes require SSD/NVMe for acceptable performance."
                echo "         RPC response times will be too slow on spinning disks."
                echo ""
                if ! prompt_yes_no "Continue anyway (not recommended)?" "N"; then
                    print_error "Setup aborted - SSD recommended for mining pool"
                    exit 1
                fi
            fi
        fi
    fi
    
    if [[ $available_gb -lt $required_gb ]]; then
        echo ""
        print_error "Insufficient disk space!"
        if [[ "$BLOCKCHAIN_MODE" == "full" ]]; then
            echo "         Full Dogecoin blockchain requires ~100GB"
            echo "         Plus ~20GB for txindex, compilation, and overhead"
            echo "         Minimum: ${required_gb}GB | Recommended: ${recommended_gb}GB"
            echo "         Consider using a pruned node if space is limited"
        else
            echo "         Pruned Dogecoin blockchain requires ~4GB"
            echo "         Plus ~15GB for compilation and temporary files"
            echo "         Minimum: ${required_gb}GB | Recommended: ${recommended_gb}GB"
        fi
        echo ""
        if ! prompt_yes_no "Continue anyway?" "N"; then
            print_error "Setup aborted due to insufficient disk space"
            exit 1
        fi
    elif [[ $available_gb -lt $recommended_gb ]]; then
        echo ""
        print_warning "Disk space is below recommended (${recommended_gb}GB)"
        echo "         Current: ${available_gb}GB"
        echo "         The blockchain grows over time."
        echo ""
    fi
}

check_memory() {
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_gb=$((total_mem_kb / 1024 / 1024))
    local total_mem_mb=$((total_mem_kb / 1024))
    print_info "Available RAM: ${total_mem_gb}GB (${total_mem_mb}MB)"
    
    if [[ $total_mem_gb -lt 4 ]]; then
        print_warning "Less than 4GB RAM detected!"
        echo "         Compilation requires significant memory."
        echo "         4GB minimum | 8GB recommended for mining pool"
        echo ""
        echo "         To add swap space if compilation fails:"
        echo "           sudo fallocate -l 4G /swapfile"
        echo "           sudo chmod 600 /swapfile"
        echo "           sudo mkswap /swapfile"
        echo "           sudo swapon /swapfile"
        echo ""
        if ! prompt_yes_no "Continue with low memory?" "N"; then
            print_error "Setup aborted - insufficient RAM"
            exit 1
        fi
    elif [[ $total_mem_gb -lt 8 ]]; then
        print_warning "Less than 8GB RAM - recommended for mining pool nodes"
        echo "         Compilation will work but may be slower."
        echo "         Consider 8GB for optimal dbcache performance."
    else
        print_success "RAM: ${total_mem_gb}GB (sufficient for mining pool)"
    fi
}

load_existing_config() {
    if [[ -f "$CONFIG_DIR/dogecoin.conf" ]]; then
        print_info "Loading existing configuration..."
        
        # Parse existing config
        if grep -q "^prune=" "$CONFIG_DIR/dogecoin.conf" 2>/dev/null; then
            BLOCKCHAIN_MODE="pruned"
        else
            BLOCKCHAIN_MODE="full"
        fi
        
        if grep -q "^zmqpubhashblock=" "$CONFIG_DIR/dogecoin.conf" 2>/dev/null; then
            NODE_TYPE="pool"
        else
            NODE_TYPE="standard"
        fi
        
        # Get RPC bind IP
        local rpc_bind=$(grep "^rpcbind=" "$CONFIG_DIR/dogecoin.conf" 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$rpc_bind" ]]; then
            RPC_BIND_IP="$rpc_bind"
        fi
        
        # Get data directory
        local data_dir=$(grep "^datadir=" "$CONFIG_DIR/dogecoin.conf" 2>/dev/null | cut -d'=' -f2)
        if [[ -n "$data_dir" ]]; then
            DATA_DIR="$data_dir"
        fi
        
        print_success "Loaded existing configuration"
        echo "  Node Type: ${NODE_TYPE^}"
        echo "  Blockchain: ${BLOCKCHAIN_MODE^}"
        echo "  RPC Bind: ${RPC_BIND_IP}"
    fi
}

#===============================================================================
# SETUP MODE SELECTION
#===============================================================================

select_setup_mode() {
    print_section "SETUP MODE"
    
    if check_existing_installation; then
        echo ""
        echo -e "${GREEN}An existing Dogecoin installation was detected.${NC}"
        echo ""
        echo "What would you like to do?"
        
        local choice=$(prompt_choice "Select an action:" \
            "Update Dogecoin - pull latest code and recompile (keeps config & data)" \
            "Reconfigure - change node settings without reinstalling" \
            "Fresh Install - complete reinstall (preserves blockchain data)" \
            "Manage Wallet - create new wallet or view existing" \
            "Exit - quit without making changes")
        
        case "$choice" in
            1) SETUP_MODE="update" ;;
            2) SETUP_MODE="reconfigure" ;;
            3) SETUP_MODE="fresh" ;;
            4) SETUP_MODE="wallet" ;;
            5) 
                echo ""
                print_info "Exiting setup. No changes made."
                exit 0
                ;;
        esac
    else
        echo ""
        echo -e "${CYAN}No existing installation detected.${NC}"
        echo "This will perform a fresh installation of Dogecoin Core."
        echo ""
        echo -e "${YELLOW}╭─────────────────────────────────────────────────────────────────────╮${NC}"
        echo -e "${YELLOW}│${NC}  ${BOLD}IMPORTANT: Build Time Estimate${NC}                                    ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}                                                                     ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  Building Dogecoin from source takes ${BOLD}15-60 minutes${NC}                ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  depending on your system's CPU and RAM.                            ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}                                                                     ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  The wizard will guide you through configuration first,             ${YELLOW}│${NC}"
        echo -e "${YELLOW}│${NC}  then the build process will begin.                                 ${YELLOW}│${NC}"
        echo -e "${YELLOW}╰─────────────────────────────────────────────────────────────────────╯${NC}"
        
        if ! prompt_yes_no "Continue with fresh installation?" "Y"; then
            echo ""
            print_info "Setup cancelled. Run again when ready."
            exit 0
        fi
        
        SETUP_MODE="fresh"
    fi
    
    echo ""
    print_success "Selected mode: ${SETUP_MODE^}"
}

#===============================================================================
# INTERACTIVE CONFIGURATION
#===============================================================================

show_introduction() {
    print_section "WELCOME"
    
    echo "This wizard will guide you through setting up a Dogecoin node."
    echo ""
    echo "You will be asked to make the following decisions:"
    echo ""
    echo -e "  ${BOLD}1. Node Type${NC}"
    echo "     • Standard Node - For personal use and wallet connections"
    echo "     • Mining Pool Node - Optimized backend for mining pool software"
    echo ""
    echo -e "  ${BOLD}2. Blockchain Mode${NC}"
    echo "     • Full Node (~100GB) - Complete blockchain, maximum security"
    echo "     • Pruned Node (~4GB) - Reduced storage, still validates all blocks"
    echo ""
    echo -e "  ${BOLD}3. Directory Paths${NC}"
    echo "     • Where to install binaries"
    echo "     • Where to store blockchain data"
    echo ""
    echo -e "  ${BOLD}4. Network Configuration${NC}"
    echo "     • RPC access settings"
    echo "     • Firewall rules"
    echo ""
    if [[ "$NODE_TYPE" == "pool" ]] || [[ "$SETUP_MODE" == "fresh" ]]; then
        echo -e "  ${BOLD}5. Pool Wallet (Mining Pool mode only)${NC}"
        echo "     • Create new wallet or use existing address"
        echo ""
    fi
    
    if ! prompt_yes_no "Ready to continue?" "Y"; then
        echo ""
        print_info "Setup cancelled. Run again when ready."
        exit 0
    fi
}

configure_node_type() {
    print_section "STEP 1: NODE TYPE"
    
    echo "What will this node be used for?"
    echo ""
    
    local choice=$(prompt_choice "Which type of node do you want to set up?" \
        "Standard Node - Personal wallet use, remote wallet connections" \
        "Mining Pool Backend - Optimized for pool software, txindex enabled")
    
    if [[ "$choice" == "2" ]]; then
        NODE_TYPE="pool"
        RPC_BIND_IP="127.0.0.1"
        echo ""
        print_success "Selected: Mining Pool Backend"
        echo ""
        echo -e "  ${GREEN}✓${NC} RPC will bind to localhost only (127.0.0.1)"
        echo -e "  ${GREEN}✓${NC} Full RPC access enabled for pool software"
        echo -e "  ${GREEN}✓${NC} ZMQ block notifications on port ${ZMQ_HASHBLOCK_PORT}"
        echo -e "  ${GREEN}✓${NC} Transaction index enabled (txindex=1)"
        echo -e "  ${GREEN}✓${NC} Connection limits increased"
    else
        NODE_TYPE="standard"
        echo ""
        print_success "Selected: Standard Node"
    fi
}

configure_blockchain_mode() {
    print_section "STEP 2: BLOCKCHAIN MODE"
    
    echo "How much blockchain data should be stored?"
    echo ""
    
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "${YELLOW}TIP: For mining pools, pruned mode works perfectly and saves space!${NC}"
        echo ""
    fi
    
    local choice=$(prompt_choice "Which blockchain mode do you want?" \
        "Full Node - Complete blockchain history (~100GB storage required)" \
        "Pruned Node - Recent data only (~4GB) - Still validates ALL blocks")
    
    if [[ "$choice" == "2" ]]; then
        BLOCKCHAIN_MODE="pruned"
        echo ""
        print_success "Selected: Pruned Node (~4GB)"
    else
        BLOCKCHAIN_MODE="full"
        echo ""
        print_success "Selected: Full Node (~100GB)"
    fi
}

configure_directories() {
    print_section "STEP 3: INSTALLATION DIRECTORIES"
    
    echo "Where should Dogecoin be installed?"
    echo ""
    echo "Default paths:"
    echo "  • Binaries:   ${INSTALL_DIR}"
    echo "  • Blockchain: ${DATA_DIR}"
    echo "  • Wallets:    ${WALLET_DIR}"
    echo "  • Config:     ${CONFIG_DIR}"
    echo "  • Logs:       ${LOG_DIR}"
    echo "  • Source:     ${SOURCE_DIR}"
    echo ""
    
    if prompt_yes_no "Use default paths?" "Y"; then
        print_success "Using default paths"
    else
        echo ""
        INSTALL_DIR=$(prompt_input "Binaries directory" "$INSTALL_DIR")
        DATA_DIR=$(prompt_input "Blockchain data directory" "$DATA_DIR")
        WALLET_DIR="${DATA_DIR}/wallets"
        print_success "Custom paths configured"
    fi
}

configure_network() {
    print_section "STEP 4: NETWORK CONFIGURATION"
    
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "${GREEN}Mining pool mode: RPC is configured for localhost access only.${NC}"
        echo ""
        echo "Pool software should connect to:"
        echo "  • RPC:  http://127.0.0.1:${RPC_PORT}"
        echo ""
        echo "If your pool software runs on a different machine,"
        echo "use an SSH tunnel or reverse proxy."
        echo ""
        
        # Block notification options for mining pools
        print_subsection "Block Notifications (Optional)"
        
        echo "Mining pools need to know when new blocks arrive to update miner work."
        echo "Choose a method based on your pool software requirements:"
        echo ""
        
        local notif_choice=$(prompt_choice "How should pool software be notified of new blocks?" \
            "RPC Polling only (RECOMMENDED) - Most compatible, works with all pools" \
            "Enable ZMQ - Instant push notifications (may have issues on some systems)" \
            "Enable blocknotify - Run a custom script when new blocks arrive" \
            "Enable both ZMQ and blocknotify")
        
        case "$notif_choice" in
            1)
                ENABLE_ZMQ="N"
                ENABLE_BLOCKNOTIFY="N"
                echo ""
                print_success "Using RPC polling only (most compatible)"
                echo "  Pool software will poll getblocktemplate for new work."
                ;;
            2)
                ENABLE_ZMQ="Y"
                ENABLE_BLOCKNOTIFY="N"
                echo ""
                print_success "ZMQ notifications enabled"
                echo "  ZMQ hashblock: tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}"
                echo "  ZMQ rawblock:  tcp://127.0.0.1:${ZMQ_RAWBLOCK_PORT}"
                echo ""
                print_warning "If you experience issues, reconfigure with RPC polling."
                ;;
            3)
                ENABLE_ZMQ="N"
                ENABLE_BLOCKNOTIFY="Y"
                echo ""
                echo "Enter the command to run when a new block is found."
                echo "Use %s as placeholder for the block hash."
                echo ""
                echo "Examples:"
                echo "  curl -s http://localhost:8000/newblock/%s"
                echo "  echo %s >> /tmp/newblocks.txt"
                echo ""
                BLOCKNOTIFY_CMD=$(prompt_input "blocknotify command" "echo %s >> /var/log/dogecoin/newblocks.log")
                print_success "blocknotify configured"
                ;;
            4)
                ENABLE_ZMQ="Y"
                ENABLE_BLOCKNOTIFY="Y"
                echo ""
                print_success "Both ZMQ and blocknotify enabled"
                echo "  ZMQ hashblock: tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}"
                echo ""
                BLOCKNOTIFY_CMD=$(prompt_input "blocknotify command" "echo %s >> /var/log/dogecoin/newblocks.log")
                ;;
        esac
        echo ""
        
    else
        print_subsection "RPC Access"
        
        echo "RPC (Remote Procedure Call) allows wallets to connect to your node."
        echo ""
        
        local choice=$(prompt_choice "How should RPC connections be accepted?" \
            "All interfaces (0.0.0.0) - Allows remote wallet connections" \
            "Localhost only (127.0.0.1) - More secure, local access only")
        
        if [[ "$choice" == "2" ]]; then
            RPC_BIND_IP="127.0.0.1"
            echo "  RPC will only accept connections from this machine."
        else
            RPC_BIND_IP="0.0.0.0"
            echo "  RPC will accept connections from any IP address."
            echo "  Make sure to use strong RPC credentials!"
        fi
        
        print_success "RPC will bind to: ${RPC_BIND_IP}"
    fi
    
    # RPC authentication (always required for Dogecoin)
    print_subsection "RPC Authentication"
    
    echo "Dogecoin requires RPC authentication for security."
    echo "You can set a username/password or auto-generate credentials."
    echo ""
    
    echo -ne "${YELLOW}RPC username [dogecoinrpc]:${NC} " >/dev/tty
    read -r RPC_USERNAME </dev/tty
    RPC_USERNAME="${RPC_USERNAME:-dogecoinrpc}"
    
    echo -ne "${YELLOW}RPC password [auto-generate]:${NC} " >/dev/tty
    read -r RPC_PASSWORD </dev/tty
    if [[ -z "$RPC_PASSWORD" ]]; then
        RPC_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
        echo -e "${GREEN}Generated password: ${RPC_PASSWORD}${NC}"
    fi
    print_success "RPC authentication configured"
    
    print_subsection "Firewall Configuration"
    
    echo "UFW (Uncomplicated Firewall) can be configured automatically."
    echo ""
    echo "Ports that will be opened:"
    echo "  • 22/tcp    - SSH (always enabled for safety)"
    echo "  • ${P2P_PORT}/tcp - P2P network connections"
    if [[ "$NODE_TYPE" != "pool" ]] && [[ "$RPC_BIND_IP" == "0.0.0.0" ]]; then
        echo "  • ${RPC_PORT}/tcp - RPC wallet connections"
    fi
    echo ""
    
    if prompt_yes_no "Configure UFW firewall?" "Y"; then
        CONFIGURE_FIREWALL="Y"
        print_success "Firewall will be configured"
    else
        CONFIGURE_FIREWALL="N"
        print_warning "Skipping firewall configuration"
    fi
}

configure_pool_wallet() {
    if [[ "$NODE_TYPE" != "pool" ]]; then
        return
    fi
    
    print_section "STEP 5: POOL WALLET CONFIGURATION"
    
    echo "Mining pools require a wallet address for receiving block rewards."
    echo "This address is used by pool software when calling getblocktemplate."
    echo ""
    
    local choice=$(prompt_choice "How do you want to configure the pool wallet?" \
        "Create new wallet on this server (wallet files stored locally)" \
        "Use existing wallet address (enter address you already own)" \
        "Skip for now (configure wallet later)")
    
    case "$choice" in
        1)
            CREATE_POOL_WALLET="Y"
            echo ""
            print_success "Will create new wallet during setup"
            echo "  The wallet address will be displayed after installation."
            ;;
        2)
            CREATE_POOL_WALLET="N"
            echo ""
            echo -e "${CYAN}Enter your Dogecoin wallet address.${NC}"
            echo ""
            echo "Valid address formats:"
            echo -e "  • ${GREEN}D...${NC}    (Legacy - starts with D)"
            echo ""
            while true; do
                POOL_WALLET_ADDRESS=$(prompt_input_required "Wallet address")
                if [[ "$POOL_WALLET_ADDRESS" == D* ]]; then
                    echo ""
                    print_success "Wallet address saved: ${POOL_WALLET_ADDRESS:0:12}..."
                    break
                else
                    print_warning "Invalid address format!"
                    echo "  Address must start with D"
                fi
            done
            ;;
        3)
            CREATE_POOL_WALLET="N"
            echo ""
            print_warning "Skipping wallet configuration"
            echo "  Remember to configure your pool wallet before starting the pool software."
            echo "  You can run this script again and select 'Manage Wallet' to set it up."
            ;;
    esac
}

show_configuration_summary() {
    print_section "CONFIGURATION SUMMARY"
    
    echo -e "Please review your configuration before proceeding:"
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                      ${BOLD}YOUR CONFIGURATION${NC}                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}                                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Setup Mode:${NC}         ${GREEN}${SETUP_MODE^}${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Node Type:${NC}          ${GREEN}${NODE_TYPE^} Node${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}Blockchain Mode:${NC}    ${GREEN}${BLOCKCHAIN_MODE^}${NC}"
    echo -e "${CYAN}║${NC}                                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}DIRECTORIES${NC}                                                        ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Binaries:         ${GREEN}${INSTALL_DIR}${NC}"
    echo -e "${CYAN}║${NC}  Blockchain:       ${GREEN}${DATA_DIR}${NC}"
    echo -e "${CYAN}║${NC}  Wallets:          ${GREEN}${WALLET_DIR}${NC}"
    echo -e "${CYAN}║${NC}  Config:           ${GREEN}${CONFIG_DIR}${NC}"
    echo -e "${CYAN}║${NC}  Logs:             ${GREEN}${LOG_DIR}${NC}"
    echo -e "${CYAN}║${NC}                                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}NETWORK${NC}                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  P2P Port:         ${GREEN}${P2P_PORT}${NC} (peer connections)"
    echo -e "${CYAN}║${NC}  RPC Endpoint:     ${GREEN}${RPC_BIND_IP}:${RPC_PORT}${NC}"
    echo -e "${CYAN}║${NC}  RPC Username:     ${GREEN}${RPC_USERNAME}${NC}"
    if [[ "$NODE_TYPE" == "pool" ]]; then
        if [[ "$ENABLE_ZMQ" == "Y" ]]; then
            echo -e "${CYAN}║${NC}  ZMQ Hashblock:    ${GREEN}tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}${NC}"
            echo -e "${CYAN}║${NC}  ZMQ Rawblock:     ${GREEN}tcp://127.0.0.1:${ZMQ_RAWBLOCK_PORT}${NC}"
        else
            echo -e "${CYAN}║${NC}  ZMQ:              ${YELLOW}Disabled (using RPC polling)${NC}"
        fi
        if [[ "$ENABLE_BLOCKNOTIFY" == "Y" ]]; then
            echo -e "${CYAN}║${NC}  blocknotify:      ${GREEN}Enabled${NC}"
        fi
    fi
    echo -e "${CYAN}║${NC}  Firewall (UFW):   ${GREEN}${CONFIGURE_FIREWALL}${NC}"
    
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "${CYAN}║${NC}                                                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}  ${BOLD}POOL WALLET${NC}                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
        if [[ "$CREATE_POOL_WALLET" == "Y" ]]; then
            echo -e "${CYAN}║${NC}  Action:           ${GREEN}Create new wallet${NC}"
        elif [[ -n "$POOL_WALLET_ADDRESS" ]]; then
            echo -e "${CYAN}║${NC}  Address:          ${GREEN}${POOL_WALLET_ADDRESS:0:25}...${NC}"
        else
            echo -e "${CYAN}║${NC}  Action:           ${YELLOW}Configure later${NC}"
        fi
    fi
    
    echo -e "${CYAN}║${NC}                                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}BUILD INFO${NC}                                                         ${CYAN}║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Dogecoin Version: ${GREEN}${DOGECOIN_VERSION}${NC}"
    echo -e "${CYAN}║${NC}  Parallel Jobs:    ${GREEN}${BUILD_JOBS}${NC} (based on CPU cores)"
    echo -e "${CYAN}║${NC}                                                                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}╭─────────────────────────────────────────────────────────────────────╮${NC}"
    if [[ "$BLOCKCHAIN_MODE" == "full" ]]; then
        echo -e "${YELLOW}│${NC}  ${BOLD}Disk space required:${NC} ~120GB (100GB chain + 10GB txindex + build)  ${YELLOW}│${NC}"
    else
        echo -e "${YELLOW}│${NC}  ${BOLD}Disk space required:${NC} ~20GB (4GB chain + build files)              ${YELLOW}│${NC}"
    fi
    echo -e "${YELLOW}│${NC}  ${BOLD}Estimated build time:${NC} 15-60 minutes (depends on CPU)              ${YELLOW}│${NC}"
    echo -e "${YELLOW}╰─────────────────────────────────────────────────────────────────────╯${NC}"
    echo ""
    
    if ! prompt_yes_no "Proceed with installation?" "Y"; then
        echo ""
        print_error "Setup aborted by user"
        exit 0
    fi
}

#===============================================================================
# INSTALLATION FUNCTIONS
#===============================================================================

install_dependencies() {
    print_step "1/10" "Installing build dependencies..."
    
    # Update package lists
    print_info "Updating package lists..."
    if ! apt-get update; then
        print_error "Failed to update package lists"
        return 1
    fi
    
    # Upgrade system packages
    print_info "Upgrading system packages..."
    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
        print_warning "System upgrade had issues, continuing anyway..."
    fi
    
    # Install build dependencies for Dogecoin Core
    # These are required for compilation and running a full node / mining pool
    # Install dependencies as per official Dogecoin v1.14.9 documentation
    # https://github.com/dogecoin/dogecoin/blob/v1.14.9/doc/build-unix.md
    
    # Required dependencies (from official docs)
    apt-get install -y -qq \
        build-essential \
        libtool \
        autotools-dev \
        automake \
        pkg-config \
        bsdmainutils \
        libssl-dev \
        libevent-dev \
        libboost-system-dev \
        libboost-filesystem-dev \
        libboost-chrono-dev \
        libboost-program-options-dev \
        libboost-test-dev \
        libboost-thread-dev \
        > /dev/null 2>&1
    
    # Optional dependencies (from official docs)
    apt-get install -y -qq \
        libzmq3-dev \
        libminiupnpc-dev \
        > /dev/null 2>&1 || true
    
    # Utility packages for node management
    apt-get install -y -qq \
        git \
        wget \
        curl \
        ufw \
        jq \
        openssl \
        > /dev/null 2>&1 || {
            # If some packages fail, try core dependencies only
            print_warning "Some packages not available, installing core dependencies..."
            apt-get install -y -qq \
                build-essential \
                libtool \
                autotools-dev \
                automake \
                pkg-config \
                bsdmainutils \
                libssl-dev \
                libevent-dev \
                libboost-system-dev \
                libboost-filesystem-dev \
                libboost-chrono-dev \
                libboost-program-options-dev \
                libboost-test-dev \
                libboost-thread-dev \
                git \
                wget \
                curl \
                > /dev/null
        }
    
    print_success "Build dependencies installed"
    
    # Verify critical libraries are present
    local missing_libs=""
    [[ ! -f /usr/include/event.h ]] && [[ ! -f /usr/include/event2/event.h ]] && missing_libs+=" libevent"
    [[ ! -f /usr/include/boost/version.hpp ]] && missing_libs+=" libboost"
    [[ ! -f /usr/include/zmq.h ]] && missing_libs+=" libzmq"
    
    if [[ -n "$missing_libs" ]]; then
        print_error "Missing critical libraries:$missing_libs"
        print_error "Please install them manually and re-run the script"
        return 1
    fi
    
    return 0
}

install_berkeley_db() {
    print_step "2/10" "Verifying Berkeley DB..."
    
    # Dogecoin v1.14.9 requires BDB 5.3+ (not the old 4.8)
    # We use the system libdb++-dev package which provides BDB 5.3
    
    # Check if system BDB headers exist (from libdb++-dev package)
    if [[ -f "/usr/include/db_cxx.h" ]]; then
        print_info "Found system Berkeley DB at /usr/include"
        
        # Check version
        local bdb_version=$(grep '#define DB_VERSION_STRING' /usr/include/db.h 2>/dev/null | head -1)
        if [[ -n "$bdb_version" ]]; then
            print_info "Version: $bdb_version"
        fi
        
        print_success "Berkeley DB available (system package)"
        return 0
    fi
    
    # If not found, try to install it
    print_warning "System Berkeley DB not found, installing..."
    
    # Try different package names (varies by Debian version)
    # Debian 13 uses libdb5.3++-dev
    if apt-get install -y libdb5.3++-dev libdb5.3-dev 2>/dev/null; then
        print_info "Installed libdb5.3++-dev"
    elif apt-get install -y libdb++-dev libdb-dev 2>/dev/null; then
        print_info "Installed libdb++-dev"
    else
        print_error "Failed to install Berkeley DB development packages"
        echo ""
        echo "Available BDB packages:"
        apt-cache search libdb | grep -E "db.*dev" | head -10
        echo ""
        return 1
    fi
    
    # Verify installation
    if [[ ! -f "/usr/include/db_cxx.h" ]]; then
        print_error "Berkeley DB headers still not found after installation!"
        print_info "Expected: /usr/include/db_cxx.h"
        return 1
    fi
    
    print_success "Berkeley DB installed (system package)"
    return 0
}

create_dogecoin_user() {
    print_step "3/10" "Creating dogecoin system user..."
    
    if id "$DOGECOIN_USER" &>/dev/null; then
        print_info "User '$DOGECOIN_USER' already exists"
    else
        useradd --system --shell /usr/sbin/nologin --home-dir "$DATA_DIR" "$DOGECOIN_USER"
        print_success "User '$DOGECOIN_USER' created"
    fi
}

create_directories() {
    print_step "4/10" "Creating directories..."
    
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$DATA_DIR"
    mkdir -p "$WALLET_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$SOURCE_DIR"
    
    chown -R "$DOGECOIN_USER:$DOGECOIN_USER" "$DATA_DIR"
    chown -R "$DOGECOIN_USER:$DOGECOIN_USER" "$LOG_DIR"
    chmod 700 "$WALLET_DIR"
    
    print_success "Directories created"
}

clone_and_build_dogecoin() {
    print_step "5/10" "Building Dogecoin from source..."
    
    local log_file="/tmp/dogecoin-build.log"
    
    cd /usr/local/src || {
        print_error "Failed to cd to /usr/local/src"
        return 1
    }
    
    if [[ -d "$SOURCE_DIR/.git" ]]; then
        print_info "Updating existing source..."
        cd "$SOURCE_DIR" || return 1
        if ! git fetch --all > "$log_file" 2>&1; then
            print_error "Git fetch failed"
            tail -10 "$log_file"
            return 1
        fi
        if ! git checkout "$DOGECOIN_VERSION" >> "$log_file" 2>&1; then
            print_error "Git checkout failed for $DOGECOIN_VERSION"
            tail -10 "$log_file"
            return 1
        fi
    else
        print_info "Cloning Dogecoin repository..."
        rm -rf "$SOURCE_DIR"
        if ! git clone "$DOGECOIN_REPO" "$SOURCE_DIR" > "$log_file" 2>&1; then
            print_error "Git clone failed"
            tail -20 "$log_file"
            return 1
        fi
        cd "$SOURCE_DIR" || return 1
        if ! git checkout "$DOGECOIN_VERSION" >> "$log_file" 2>&1; then
            print_error "Git checkout failed for $DOGECOIN_VERSION"
            tail -10 "$log_file"
            return 1
        fi
    fi
    
    print_info "Running autogen.sh..."
    if ! ./autogen.sh > "$log_file" 2>&1; then
        print_error "autogen.sh failed"
        echo ""
        echo "Last 20 lines of log:"
        tail -20 "$log_file"
        print_info "Full log: $log_file"
        return 1
    fi
    
    print_info "Configuring build (this may take a minute)..."
    
    # Dogecoin v1.14.9 uses system BDB 5.3+ (from libdb++-dev)
    # No special paths needed - configure will find it in standard locations
    
    if ! ./configure \
        "CXXFLAGS=-O2 -Wno-error" \
        --prefix="$INSTALL_DIR" \
        --disable-tests \
        --disable-bench \
        --disable-gui-tests \
        --with-daemon \
        --with-utils \
        --without-gui \
        --without-miniupnpc \
        --with-incompatible-bdb \
        --enable-zmq \
        > "$log_file" 2>&1; then
        print_error "Configure failed"
        echo ""
        echo "Last 30 lines of log:"
        tail -30 "$log_file"
        echo ""
        echo "Searching config.log for errors..."
        grep -i -B2 -A10 "error:" "${SOURCE_DIR}/config.log" 2>/dev/null | tail -40
        print_info "Full log: $log_file"
        return 1
    fi
    
    print_info "Compiling Dogecoin (this takes 15-60 minutes)..."
    print_info "Using ${BUILD_JOBS} parallel jobs..."
    
    # Build with progress and error capture
    if ! make -j${BUILD_JOBS} > "$log_file" 2>&1; then
        print_error "Compilation failed!"
        echo ""
        echo "Last 30 lines of build log:"
        tail -30 "$log_file"
        print_info "Full log: $log_file"
        return 1
    fi
    print_success "Compilation complete"
    
    print_info "Installing binaries..."
    if ! make install >> "$log_file" 2>&1; then
        print_error "Installation failed!"
        tail -20 "$log_file"
        return 1
    fi
    
    # Verify binaries exist
    if [[ ! -f "$INSTALL_DIR/bin/dogecoind" ]]; then
        print_error "dogecoind binary not found after build!"
        return 1
    fi
    
    rm -f "$log_file"
    print_success "Dogecoin built and installed to $INSTALL_DIR"
    return 0
}

create_symlinks() {
    print_step "6/10" "Creating symlinks..."
    
    local binaries=("dogecoind" "dogecoin-cli" "dogecoin-tx")
    
    for binary in "${binaries[@]}"; do
        if [[ -f "$INSTALL_DIR/bin/$binary" ]]; then
            ln -sf "$INSTALL_DIR/bin/$binary" "/usr/local/bin/$binary"
        fi
    done
    
    print_success "Symlinks created in /usr/local/bin/"
}

create_config_file() {
    print_step "7/10" "Creating configuration file..."
    
    # Build configuration based on selections
    cat > "$CONFIG_DIR/dogecoin.conf" << EOF
#===============================================================================
# DOGECOIN NODE CONFIGURATION
# Generated by setup-dogecoin.sh
# 
# Node Type: ${NODE_TYPE^}
# Blockchain: ${BLOCKCHAIN_MODE^}
# Generated: $(date)
#===============================================================================

#-------------------------------------------------------------------------------
# DATA DIRECTORY
#-------------------------------------------------------------------------------
datadir=${DATA_DIR}

#-------------------------------------------------------------------------------
# NETWORK SETTINGS
#-------------------------------------------------------------------------------
# Enable listening for incoming connections
listen=1

# P2P port
port=${P2P_PORT}

#-------------------------------------------------------------------------------
# RPC SERVER SETTINGS
#-------------------------------------------------------------------------------
# Enable RPC server
server=1

# RPC authentication
rpcuser=${RPC_USERNAME}
rpcpassword=${RPC_PASSWORD}

# RPC binding
rpcbind=${RPC_BIND_IP}
rpcport=${RPC_PORT}

# RPC allowed IPs
EOF

    if [[ "$NODE_TYPE" == "pool" ]]; then
        cat >> "$CONFIG_DIR/dogecoin.conf" << EOF
rpcallowip=127.0.0.1
EOF
    else
        if [[ "$RPC_BIND_IP" == "0.0.0.0" ]]; then
            cat >> "$CONFIG_DIR/dogecoin.conf" << EOF
rpcallowip=0.0.0.0/0
EOF
        else
            cat >> "$CONFIG_DIR/dogecoin.conf" << EOF
rpcallowip=127.0.0.1
EOF
        fi
    fi

    # Mode-specific settings
    if [[ "$NODE_TYPE" == "pool" ]]; then
        cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# MINING POOL MODE SETTINGS
#-------------------------------------------------------------------------------
# Transaction index (required for pool lookups)
txindex=1

# Increased connection limits for pool reliability
maxconnections=256
EOF

        # Add ZMQ if enabled
        if [[ "$ENABLE_ZMQ" == "Y" ]]; then
            cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# ZMQ BLOCK NOTIFICATIONS (ENABLED)
# Pool software can subscribe for instant new block notifications
#-------------------------------------------------------------------------------
zmqpubhashblock=tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}
zmqpubrawblock=tcp://127.0.0.1:${ZMQ_RAWBLOCK_PORT}
EOF
        else
            cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# ZMQ BLOCK NOTIFICATIONS (DISABLED)
# Uncomment to enable - pool software will use RPC polling instead
# If you experience issues with ZMQ, keep these commented out
#-------------------------------------------------------------------------------
# zmqpubhashblock=tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}
# zmqpubrawblock=tcp://127.0.0.1:${ZMQ_RAWBLOCK_PORT}
EOF
        fi

        # Add blocknotify if enabled
        if [[ "$ENABLE_BLOCKNOTIFY" == "Y" ]] && [[ -n "$BLOCKNOTIFY_CMD" ]]; then
            cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# BLOCK NOTIFY SCRIPT
# Runs this command when a new block is found (%s = block hash)
#-------------------------------------------------------------------------------
blocknotify=${BLOCKNOTIFY_CMD}
EOF
        fi

        cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

# Disable wallet (pool typically uses separate wallet server)
# Uncomment if you don't need local wallet functionality
# disablewallet=1
EOF
    else
        cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# STANDARD NODE SETTINGS
#-------------------------------------------------------------------------------
# Maximum connections
maxconnections=125
EOF
    fi

    # Blockchain mode
    cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# BLOCKCHAIN MODE
#-------------------------------------------------------------------------------
EOF
    if [[ "$BLOCKCHAIN_MODE" == "pruned" ]]; then
        cat >> "$CONFIG_DIR/dogecoin.conf" << EOF
# Pruned node - stores only recent blockchain data (~4GB)
prune=${PRUNE_SIZE}
EOF
    else
        cat >> "$CONFIG_DIR/dogecoin.conf" << EOF
# Full node - stores complete blockchain (~100GB)
# No pruning configured
EOF
    fi

    # Common settings
    cat >> "$CONFIG_DIR/dogecoin.conf" << EOF

#-------------------------------------------------------------------------------
# LOGGING
#-------------------------------------------------------------------------------
# Log timestamps
logtimestamps=1

# Debug log file
debuglogfile=${LOG_DIR}/debug.log

#-------------------------------------------------------------------------------
# PERFORMANCE SETTINGS
#-------------------------------------------------------------------------------
# Database cache size (MB)
dbcache=450

# Number of script verification threads
par=${BUILD_JOBS}

#-------------------------------------------------------------------------------
# SECURITY
#-------------------------------------------------------------------------------
# Disable UPnP (recommended for servers)
upnp=0
EOF

    chown "$DOGECOIN_USER:$DOGECOIN_USER" "$CONFIG_DIR/dogecoin.conf"
    chmod 640 "$CONFIG_DIR/dogecoin.conf"
    
    print_success "Configuration file created"
}

create_pool_wallet() {
    if [[ "$NODE_TYPE" != "pool" ]]; then
        return
    fi
    
    print_step "8/10" "Setting up pool wallet..."
    
    if [[ "$CREATE_POOL_WALLET" == "Y" ]]; then
        print_info "Creating new wallet..."
        
        local wallet_name="pool-wallet"
        local max_attempts=30
        local attempt=0
        
        # Start daemon temporarily to create wallet
        print_info "Starting daemon temporarily to create wallet..."
        
        # Ensure any existing daemon is stopped
        "$INSTALL_DIR/bin/dogecoin-cli" -conf="$CONFIG_DIR/dogecoin.conf" stop > /dev/null 2>&1 || true
        sleep 2
        
        # Create a minimal start for wallet creation (no network connections)
        sudo -u "$DOGECOIN_USER" "$INSTALL_DIR/bin/dogecoind" \
            -conf="$CONFIG_DIR/dogecoin.conf" \
            -daemon \
            -connect=0 \
            -listen=0 \
            > /dev/null 2>&1 || true
        
        # Wait for RPC to become available
        print_info "Waiting for daemon to start..."
        while [[ $attempt -lt $max_attempts ]]; do
            if "$INSTALL_DIR/bin/dogecoin-cli" -conf="$CONFIG_DIR/dogecoin.conf" getblockchaininfo > /dev/null 2>&1; then
                print_success "Daemon is ready"
                break
            fi
            attempt=$((attempt + 1))
            sleep 1
            echo -ne "\r${BLUE}[INFO]${NC} Waiting for daemon... ($attempt/$max_attempts)"
        done
        echo ""
        
        if [[ $attempt -ge $max_attempts ]]; then
            print_warning "Daemon took too long to start"
            print_info "You can create the wallet manually later using:"
            echo "  dogecoin-cli -conf=$CONFIG_DIR/dogecoin.conf createwallet pool-wallet"
            return
        fi
        
        # Create wallet (Dogecoin v1.14.x uses simpler syntax)
        print_info "Creating wallet..."
        local wallet_result=$("$INSTALL_DIR/bin/dogecoin-cli" \
            -conf="$CONFIG_DIR/dogecoin.conf" \
            createwallet "$wallet_name" 2>&1)
        
        if echo "$wallet_result" | grep -qi "name\|warning"; then
            # Get a new address
            sleep 1
            POOL_WALLET_ADDRESS=$("$INSTALL_DIR/bin/dogecoin-cli" \
                -conf="$CONFIG_DIR/dogecoin.conf" \
                -rpcwallet="$wallet_name" \
                getnewaddress "pool" 2>/dev/null || echo "")
            
            if [[ -n "$POOL_WALLET_ADDRESS" ]]; then
                # Save wallet info
                cat > "$CONFIG_DIR/pool-wallet.conf" << EOF
# Pool Wallet Configuration
# Generated: $(date)
# 
# IMPORTANT: Back up the wallet files in ${DATA_DIR}/wallets/

WALLET_NAME=${wallet_name}
WALLET_ADDRESS=${POOL_WALLET_ADDRESS}
WALLET_PATH=${DATA_DIR}/wallets/${wallet_name}

# Note: Use dogecoin-cli -rpcwallet=${wallet_name} to interact with this wallet
# Example: dogecoin-cli -rpcwallet=${wallet_name} getbalance
EOF
                
                chmod 600 "$CONFIG_DIR/pool-wallet.conf"
                chown "$DOGECOIN_USER:$DOGECOIN_USER" "$CONFIG_DIR/pool-wallet.conf"
                
                print_success "Pool wallet created"
                echo ""
                echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
                echo -e "${GREEN}  POOL WALLET CREATED                                               ${NC}"
                echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                echo -e "${YELLOW}Wallet Address:${NC}"
                echo "$POOL_WALLET_ADDRESS"
                echo ""
                echo -e "${YELLOW}Wallet Name:${NC} ${wallet_name}"
                echo ""
                echo -e "${RED}IMPORTANT: Back up your wallet!${NC}"
                echo "Wallet files are stored in: ${DATA_DIR}/wallets/${wallet_name}"
                echo ""
                echo "Press Enter to continue..."
                read -r </dev/tty
            fi
        else
            print_warning "Could not create wallet automatically."
            print_info "You can create it manually later using:"
            echo "  dogecoin-cli createwallet pool-wallet"
        fi
        
        # Stop the temporary daemon
        "$INSTALL_DIR/bin/dogecoin-cli" -conf="$CONFIG_DIR/dogecoin.conf" stop > /dev/null 2>&1 || true
        sleep 3
        
    elif [[ -n "$POOL_WALLET_ADDRESS" ]]; then
        # Save existing wallet address
        cat > "$CONFIG_DIR/pool-wallet.conf" << EOF
# Pool Wallet Configuration
# Generated: $(date)

WALLET_ADDRESS=${POOL_WALLET_ADDRESS}

# Note: This is an external wallet address.
# The wallet is managed elsewhere.
EOF
        
        chmod 600 "$CONFIG_DIR/pool-wallet.conf"
        chown "$DOGECOIN_USER:$DOGECOIN_USER" "$CONFIG_DIR/pool-wallet.conf"
        
        print_success "Pool wallet address saved"
    else
        print_info "Skipping wallet configuration"
    fi
}

create_systemd_service() {
    print_step "9/10" "Creating systemd service..."
    
    cat > /etc/systemd/system/dogecoind.service << EOF
[Unit]
Description=Dogecoin Core Daemon
Documentation=https://dogecoin.com/
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=${DOGECOIN_USER}
Group=${DOGECOIN_USER}

ExecStart=${INSTALL_DIR}/bin/dogecoind -daemon -conf=${CONFIG_DIR}/dogecoin.conf -pid=${DATA_DIR}/dogecoind.pid
ExecStop=${INSTALL_DIR}/bin/dogecoin-cli -conf=${CONFIG_DIR}/dogecoin.conf stop

# Wait for the daemon to stop gracefully
TimeoutStopSec=600

Restart=on-failure
RestartSec=30

# Create PID file directory
RuntimeDirectory=dogecoin
RuntimeDirectoryMode=0710

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${DATA_DIR} ${LOG_DIR}

# Resource limits
LimitNOFILE=65535
Nice=10
IOSchedulingClass=2
IOSchedulingPriority=7

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    
    print_success "Systemd service created"
}

configure_firewall() {
    print_step "10/10" "Configuring firewall..."
    
    if [[ "$CONFIGURE_FIREWALL" != "Y" ]]; then
        print_info "Skipping firewall configuration"
        return
    fi
    
    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        ufw --force enable > /dev/null 2>&1
    fi
    
    # Always allow SSH
    ufw allow ssh > /dev/null 2>&1
    
    # Allow P2P port
    ufw allow "$P2P_PORT/tcp" comment 'Dogecoin P2P' > /dev/null 2>&1
    
    # RPC port depends on configuration
    if [[ "$NODE_TYPE" != "pool" ]] && [[ "$RPC_BIND_IP" == "0.0.0.0" ]]; then
        ufw allow "$RPC_PORT/tcp" comment 'Dogecoin RPC' > /dev/null 2>&1
        print_info "RPC port ${RPC_PORT} opened"
    else
        print_info "RPC port NOT exposed (localhost only)"
    fi
    
    ufw reload > /dev/null 2>&1
    
    print_success "Firewall configured"
}

start_service() {
    print_info "Enabling and starting dogecoind service..."
    
    systemctl enable dogecoind > /dev/null 2>&1
    systemctl start dogecoind
    
    sleep 5
    
    if systemctl is-active --quiet dogecoind; then
        print_success "Dogecoin daemon is running!"
    else
        print_warning "Dogecoin daemon may have failed to start"
        print_info "Check logs: sudo journalctl -u dogecoind -n 50"
    fi
}

stop_service() {
    if systemctl is-active --quiet dogecoind 2>/dev/null; then
        print_info "Stopping dogecoind service..."
        systemctl stop dogecoind
        sleep 5
        print_success "Service stopped"
    fi
}

#===============================================================================
# UPDATE MODE
#===============================================================================

perform_update() {
    print_section "UPDATING DOGECOIN"
    
    echo "This will:"
    echo "  • Stop the dogecoind service"
    echo "  • Pull latest source code"
    echo "  • Recompile Dogecoin binaries"
    echo "  • Restart the service"
    echo ""
    echo "Your configuration and blockchain data will be preserved."
    echo ""
    echo -e "${YELLOW}Note: Recompilation takes 15-60 minutes${NC}"
    echo ""
    
    if ! prompt_yes_no "Continue with update?" "Y"; then
        print_info "Update cancelled"
        exit 0
    fi
    
    stop_service
    
    print_step "1/4" "Installing any new dependencies..."
    install_dependencies
    
    print_step "2/4" "Updating and rebuilding Dogecoin..."
    clone_and_build_dogecoin
    
    print_step "3/4" "Updating symlinks..."
    create_symlinks
    
    print_step "4/4" "Starting service..."
    start_service
    
    print_section "UPDATE COMPLETE"
    
    local new_version=$("$INSTALL_DIR/bin/dogecoind" --version 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1 || echo "unknown")
    echo -e "${GREEN}Dogecoin updated to: ${new_version}${NC}"
    echo ""
    echo "Check status: sudo systemctl status dogecoind"
    echo "View logs:    sudo journalctl -u dogecoind -f"
}

#===============================================================================
# RECONFIGURE MODE
#===============================================================================

perform_reconfigure() {
    print_section "RECONFIGURE DOGECOIN NODE"
    
    load_existing_config
    
    echo "Current configuration:"
    echo "  • Node Type: ${NODE_TYPE^}"
    echo "  • Blockchain: ${BLOCKCHAIN_MODE^}"
    echo "  • RPC Bind: ${RPC_BIND_IP}"
    echo ""
    
    if ! prompt_yes_no "Change configuration?" "Y"; then
        print_info "Reconfiguration cancelled"
        exit 0
    fi
    
    # Run configuration steps
    configure_node_type
    configure_blockchain_mode
    configure_network
    
    if [[ "$NODE_TYPE" == "pool" ]]; then
        configure_pool_wallet
    fi
    
    show_configuration_summary
    
    stop_service
    
    print_info "Updating configuration..."
    create_config_file
    
    if [[ "$NODE_TYPE" == "pool" ]]; then
        create_pool_wallet
    fi
    
    configure_firewall
    start_service
    
    print_section "RECONFIGURATION COMPLETE"
    echo "Your node has been reconfigured and restarted."
}

#===============================================================================
# WALLET MANAGEMENT MODE
#===============================================================================

manage_wallet() {
    print_section "WALLET MANAGEMENT"
    
    if [[ -f "$CONFIG_DIR/pool-wallet.conf" ]]; then
        echo "Current pool wallet configuration:"
        echo ""
        source "$CONFIG_DIR/pool-wallet.conf" 2>/dev/null
        if [[ -n "$WALLET_ADDRESS" ]]; then
            echo "  Address: $WALLET_ADDRESS"
        fi
        if [[ -n "$WALLET_NAME" ]]; then
            echo "  Name: $WALLET_NAME"
        fi
        if [[ -n "$WALLET_PATH" ]]; then
            echo "  Path: $WALLET_PATH"
        fi
        echo ""
    else
        echo "No pool wallet is currently configured."
        echo ""
    fi
    
    local choice=$(prompt_choice "What would you like to do?" \
        "Create new wallet" \
        "Set existing wallet address" \
        "View wallet balance" \
        "Get new receiving address" \
        "Back to main menu")
    
    case "$choice" in
        1)
            NODE_TYPE="pool"
            CREATE_POOL_WALLET="Y"
            create_pool_wallet
            ;;
        2)
            NODE_TYPE="pool"
            CREATE_POOL_WALLET="N"
            echo ""
            while true; do
                POOL_WALLET_ADDRESS=$(prompt_input_required "Wallet address")
                if [[ "$POOL_WALLET_ADDRESS" == D* ]]; then
                    break
                else
                    print_warning "Invalid address format. Please enter a valid Dogecoin address."
                fi
            done
            
            cat > "$CONFIG_DIR/pool-wallet.conf" << EOF
# Pool Wallet Configuration
# Generated: $(date)

WALLET_ADDRESS=${POOL_WALLET_ADDRESS}
EOF
            chmod 600 "$CONFIG_DIR/pool-wallet.conf"
            print_success "Wallet address saved"
            ;;
        3)
            if [[ -f "$CONFIG_DIR/pool-wallet.conf" ]]; then
                source "$CONFIG_DIR/pool-wallet.conf"
                if [[ -n "$WALLET_NAME" ]]; then
                    echo ""
                    local balance=$("$INSTALL_DIR/bin/dogecoin-cli" \
                        -conf="$CONFIG_DIR/dogecoin.conf" \
                        -rpcwallet="$WALLET_NAME" \
                        getbalance 2>/dev/null || echo "Error getting balance")
                    echo "Wallet Balance: $balance DOGE"
                    echo ""
                else
                    print_warning "No local wallet configured"
                fi
            else
                print_warning "No wallet configuration found"
            fi
            echo "Press Enter to continue..."
            read -r </dev/tty
            ;;
        4)
            if [[ -f "$CONFIG_DIR/pool-wallet.conf" ]]; then
                source "$CONFIG_DIR/pool-wallet.conf"
                if [[ -n "$WALLET_NAME" ]]; then
                    echo ""
                    local new_addr=$("$INSTALL_DIR/bin/dogecoin-cli" \
                        -conf="$CONFIG_DIR/dogecoin.conf" \
                        -rpcwallet="$WALLET_NAME" \
                        getnewaddress "" "legacy" 2>/dev/null || echo "Error")
                    echo "New Address: $new_addr"
                    echo ""
                else
                    print_warning "No local wallet configured"
                fi
            else
                print_warning "No wallet configuration found"
            fi
            echo "Press Enter to continue..."
            read -r </dev/tty
            ;;
        5)
            return
            ;;
    esac
}

#===============================================================================
# COMPLETION SCREEN
#===============================================================================

print_completion() {
    print_section "SETUP COMPLETE!"
    
    echo -e "${GREEN}Your Dogecoin node has been successfully set up.${NC}"
    echo ""
    
    # Node-specific information
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}                      MINING POOL BACKEND MODE                         ${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${BOLD}Pool Software Connection Details:${NC}"
        echo ""
        echo "  RPC Endpoint:    http://127.0.0.1:${RPC_PORT}"
        echo "  RPC User:        ${RPC_USERNAME}"
        echo "  RPC Password:    ${RPC_PASSWORD}"
        
        if [[ "$ENABLE_ZMQ" == "Y" ]]; then
            echo "  ZMQ Hashblock:   tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}"
            echo "  ZMQ Rawblock:    tcp://127.0.0.1:${ZMQ_RAWBLOCK_PORT}"
        else
            echo ""
            echo -e "  ${YELLOW}Block Notifications: RPC Polling${NC}"
            echo "  Your pool software should poll getblocktemplate or getbestblockhash"
            echo "  to detect new blocks. This is the most compatible method."
        fi
        
        if [[ "$ENABLE_BLOCKNOTIFY" == "Y" ]]; then
            echo ""
            echo -e "  ${GREEN}blocknotify:${NC} Enabled"
            echo "  Command: ${BLOCKNOTIFY_CMD}"
        fi
        
        if [[ -n "$POOL_WALLET_ADDRESS" ]]; then
            echo ""
            echo -e "${BOLD}Pool Wallet Address:${NC}"
            echo "  $POOL_WALLET_ADDRESS"
        fi
        
        echo ""
        echo -e "${BOLD}Test Commands:${NC}"
        echo ""
        echo "  # Check node info"
        echo "  dogecoin-cli -conf=${CONFIG_DIR}/dogecoin.conf getblockchaininfo"
        echo ""
        echo "  # Get block template (for mining)"
        echo "  dogecoin-cli -conf=${CONFIG_DIR}/dogecoin.conf getblocktemplate"
        echo ""
        echo "  # Check best block hash (for polling)"
        echo "  dogecoin-cli -conf=${CONFIG_DIR}/dogecoin.conf getbestblockhash"
        echo ""
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                         RPC CREDENTIALS                               ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}RPC Credentials (SAVE THESE!):${NC}"
    echo ""
    echo "  Username: ${RPC_USERNAME}"
    echo "  Password: ${RPC_PASSWORD}"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                         USEFUL COMMANDS                                ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  # Check service status"
    echo "  sudo systemctl status dogecoind"
    echo ""
    echo "  # View live logs"
    echo "  sudo journalctl -u dogecoind -f"
    echo ""
    echo "  # Check sync progress"
    echo "  dogecoin-cli -conf=${CONFIG_DIR}/dogecoin.conf getblockchaininfo"
    echo ""
    echo "  # Re-run setup (update/reconfigure)"
    echo "  sudo ./setup-dogecoin.sh"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                         FILE LOCATIONS                                 ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Binaries:       $INSTALL_DIR/bin/"
    echo "  Blockchain:     $DATA_DIR/"
    echo "  Wallets:        $WALLET_DIR/"
    echo "  Config:         $CONFIG_DIR/dogecoin.conf"
    echo "  Logs:           $LOG_DIR/debug.log"
    echo ""
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                         NETWORK PORTS                                  ${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  P2P:   ${P2P_PORT}/tcp (peer-to-peer connections)"
    echo "  RPC:   ${RPC_PORT}/tcp (${RPC_BIND_IP})"
    if [[ "$NODE_TYPE" == "pool" ]] && [[ "$ENABLE_ZMQ" == "Y" ]]; then
        echo "  ZMQ:   ${ZMQ_HASHBLOCK_PORT}/tcp (hashblock notifications, localhost only)"
        echo "  ZMQ:   ${ZMQ_RAWBLOCK_PORT}/tcp (rawblock notifications, localhost only)"
    fi
    echo ""
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}                      PORT FORWARDING GUIDE                            ${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${BOLD}Required for node operation:${NC}"
    echo ""
    echo -e "  ┌─────────┬──────────┬─────────────────────────────────────────────┐"
    echo -e "  │ ${BOLD}Port${NC}    │ ${BOLD}Protocol${NC} │ ${BOLD}Purpose${NC}                                     │"
    echo -e "  ├─────────┼──────────┼─────────────────────────────────────────────┤"
    echo -e "  │ ${GREEN}${P2P_PORT}${NC}   │ TCP      │ P2P network - ${YELLOW}FORWARD THIS PORT${NC}            │"
    if [[ "$NODE_TYPE" != "pool" ]] && [[ "$RPC_BIND_IP" == "0.0.0.0" ]]; then
        echo -e "  │ ${GREEN}${RPC_PORT}${NC}   │ TCP      │ RPC access - ${YELLOW}FORWARD IF REMOTE ACCESS${NC}     │"
    else
        echo -e "  │ ${BLUE}${RPC_PORT}${NC}   │ TCP      │ RPC access - localhost only (no forward)   │"
    fi
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "  │ ${BLUE}${ZMQ_HASHBLOCK_PORT}${NC}   │ TCP      │ ZMQ hashblock - localhost only (no forward)│"
        echo -e "  │ ${BLUE}${ZMQ_RAWBLOCK_PORT}${NC}   │ TCP      │ ZMQ rawblock - localhost only (no forward) │"
    fi
    echo -e "  └─────────┴──────────┴─────────────────────────────────────────────┘"
    echo ""
    echo -e "  ${BOLD}Router/Firewall Configuration:${NC}"
    echo ""
    echo "  1. Forward port ${P2P_PORT}/TCP from your router to this server's IP"
    echo "  2. Ensure UFW allows the port: sudo ufw status"
    if [[ "$NODE_TYPE" != "pool" ]] && [[ "$RPC_BIND_IP" == "0.0.0.0" ]]; then
        echo "  3. For remote wallet access, also forward port ${RPC_PORT}/TCP"
    fi
    echo ""
    echo -e "  ${BOLD}Verify ports are open:${NC}"
    echo "  sudo ss -tlnp | grep dogecoin"
    echo ""
    
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${MAGENTA}                     MINING POOL INTEGRATION                          ${NC}"
        echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  ${BOLD}Your pool software should connect using:${NC}"
        echo ""
        echo "  RPC URL:      http://127.0.0.1:${RPC_PORT}"
        echo "  RPC User:     ${RPC_USERNAME}"
        echo "  RPC Password: ${RPC_PASSWORD}"
        echo ""
        
        if [[ "$ENABLE_ZMQ" == "Y" ]]; then
            echo -e "  ${BOLD}ZMQ Block Notifications (Enabled):${NC}"
            echo "    hashblock:  tcp://127.0.0.1:${ZMQ_HASHBLOCK_PORT}"
            echo "    rawblock:   tcp://127.0.0.1:${ZMQ_RAWBLOCK_PORT}"
        else
            echo -e "  ${BOLD}Block Notifications:${NC}"
            echo "    Method: RPC Polling (most compatible)"
            echo "    Poll getbestblockhash or getblocktemplate every 1-2 seconds"
            echo "    This is the recommended approach for reliability."
        fi
        echo ""
        
        if [[ "$ENABLE_BLOCKNOTIFY" == "Y" ]]; then
            echo -e "  ${BOLD}blocknotify Script:${NC}"
            echo "    ${BLOCKNOTIFY_CMD}"
            echo ""
        fi
        
        if [[ -n "$POOL_WALLET_ADDRESS" ]]; then
            echo -e "  ${BOLD}Pool Wallet (for getblocktemplate):${NC}"
            echo "    ${POOL_WALLET_ADDRESS}"
            echo ""
        fi
        
        echo -e "  ${BOLD}Important RPC Methods for Mining Pools:${NC}"
        echo "    • getblocktemplate - Get work for miners"
        echo "    • submitblock      - Submit found blocks"
        echo "    • getbestblockhash - Check for new blocks (polling)"
        echo "    • getblockchaininfo - Check sync status"
        echo "    • validateaddress  - Validate miner addresses"
        echo ""
    fi
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                          IMPORTANT NOTES                              ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  • Initial blockchain sync takes several hours to days"
    echo "  • Check sync progress: dogecoin-cli getblockchaininfo"
    echo "  • The node must be fully synced before mining pool use"
    echo "  • Save your RPC credentials in a secure location"
    if [[ -n "$POOL_WALLET_ADDRESS" ]]; then
        echo "  • Back up wallet files in: ${WALLET_DIR}/"
    fi
    echo ""
    
    # Final prominent completion banner
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}║   ██████╗ ██████╗ ███╗   ███╗██████╗ ██╗     ███████╗████████╗███████╗║${NC}"
    echo -e "${GREEN}║  ██╔════╝██╔═══██╗████╗ ████║██╔══██╗██║     ██╔════╝╚══██╔══╝██╔════╝║${NC}"
    echo -e "${GREEN}║  ██║     ██║   ██║██╔████╔██║██████╔╝██║     █████╗     ██║   █████╗  ║${NC}"
    echo -e "${GREEN}║  ██║     ██║   ██║██║╚██╔╝██║██╔═══╝ ██║     ██╔══╝     ██║   ██╔══╝  ║${NC}"
    echo -e "${GREEN}║  ╚██████╗╚██████╔╝██║ ╚═╝ ██║██║     ███████╗███████╗   ██║   ███████╗║${NC}"
    echo -e "${GREEN}║   ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝   ╚═╝   ╚══════╝║${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}║            DOGECOIN NODE INSTALLATION COMPLETED!                     ║${NC}"
    echo -e "${GREEN}║                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Quick summary box
    if [[ "$NODE_TYPE" == "pool" ]]; then
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│                        QUICK SUMMARY                                │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}  Node Type:     ${BOLD}Mining Pool Backend${NC}                               ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  RPC URL:       ${BOLD}http://127.0.0.1:${RPC_PORT}${NC}                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  RPC User:      ${BOLD}${RPC_USERNAME}${NC}                                  ${CYAN}│${NC}"
        printf "${CYAN}│${NC}  RPC Pass:      ${BOLD}%-40s${NC}     ${CYAN}│${NC}\n" "$RPC_PASSWORD"
        if [[ -n "$POOL_WALLET_ADDRESS" ]]; then
            printf "${CYAN}│${NC}  Pool Wallet:   ${BOLD}%-40s${NC}     ${CYAN}│${NC}\n" "${POOL_WALLET_ADDRESS:0:40}"
        fi
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
    else
        echo -e "${CYAN}┌─────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${CYAN}│                        QUICK SUMMARY                                │${NC}"
        echo -e "${CYAN}├─────────────────────────────────────────────────────────────────────┤${NC}"
        echo -e "${CYAN}│${NC}  Node Type:     ${BOLD}Standard Full Node${NC}                                ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  P2P Port:      ${BOLD}${P2P_PORT}${NC}                                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  Status:        ${GREEN}Running${NC}                                          ${CYAN}│${NC}"
        echo -e "${CYAN}└─────────────────────────────────────────────────────────────────────┘${NC}"
    fi
    echo ""
    echo -e "${GREEN}Installation complete! Your node is now syncing with the network.${NC}"
    echo ""
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    print_banner
    
    # Check for script updates first
    check_for_script_update
    
    # System checks
    print_section "SYSTEM CHECKS"
    check_root
    check_debian
    check_cpu
    check_memory
    
    # Check for existing installation and select mode
    select_setup_mode
    
    case "$SETUP_MODE" in
        "update")
            perform_update
            ;;
        "reconfigure")
            perform_reconfigure
            ;;
        "wallet")
            manage_wallet
            ;;
        "fresh")
            # Fresh installation
            show_introduction
            configure_node_type
            configure_blockchain_mode
            check_disk_space
            configure_directories
            configure_network
            
            if [[ "$NODE_TYPE" == "pool" ]]; then
                configure_pool_wallet
            fi
            
            show_configuration_summary
            
            # Run installation with error handling
            print_section "INSTALLING"
            
            if ! install_dependencies; then
                print_error "Failed to install dependencies. See errors above."
                exit 1
            fi
            
            if ! install_berkeley_db; then
                print_error "Failed to install Berkeley DB. See errors above."
                exit 1
            fi
            
            if ! create_dogecoin_user; then
                print_error "Failed to create dogecoin user."
                exit 1
            fi
            
            if ! create_directories; then
                print_error "Failed to create directories."
                exit 1
            fi
            
            if ! clone_and_build_dogecoin; then
                print_error "Failed to build Dogecoin. See errors above."
                exit 1
            fi
            
            if ! create_symlinks; then
                print_error "Failed to create symlinks."
                exit 1
            fi
            
            if ! create_config_file; then
                print_error "Failed to create config file."
                exit 1
            fi
            
            if [[ "$NODE_TYPE" == "pool" ]]; then
                # Wallet creation is optional - don't fail if it doesn't work
                create_pool_wallet || print_warning "Wallet creation skipped or failed - you can create it manually later"
            fi
            
            if ! create_systemd_service; then
                print_error "Failed to create systemd service."
                exit 1
            fi
            
            # Firewall is optional
            configure_firewall || print_warning "Firewall configuration skipped"
            
            if ! start_service; then
                print_warning "Service failed to start - check logs with: journalctl -u dogecoind"
            fi
            
            print_completion
            ;;
    esac
}

main "$@"

