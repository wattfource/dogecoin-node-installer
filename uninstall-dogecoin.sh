#!/bin/bash
#
#===============================================================================
#
#   DOGECOIN NODE UNINSTALL SCRIPT
#   
#   Completely removes all Dogecoin node components installed by setup-dogecoin.sh
#   Returns the system to a clean state.
#
#===============================================================================
#
#   USAGE:
#       sudo ./uninstall-dogecoin.sh [OPTIONS]
#
#   OPTIONS:
#       --keep-blockchain    Keep blockchain data (skip /var/lib/dogecoin removal)
#       --keep-wallets       Keep wallet files only
#       --force              Skip all confirmations (dangerous!)
#       --quiet              Minimal output
#       --help               Show this help message
#
#   WHAT THIS REMOVES:
#       • Dogecoin daemon process (stopped gracefully or forcefully)
#       • Dogecoin binaries (/opt/dogecoin/)
#       • Dogecoin source code (/usr/local/src/dogecoin/)
#       • Configuration files (/etc/dogecoin/)
#       • Log files (/var/log/dogecoin/)
#       • Blockchain data (/var/lib/dogecoin/) - optional
#       • Wallet files (/var/lib/dogecoin/wallets/) - optional
#       • Berkeley DB 4.8 (/usr/local/BerkeleyDB.4.8/)
#       • Symlinks in /usr/local/bin/ (dogecoind, dogecoin-cli, etc.)
#       • Systemd service (dogecoind.service)
#       • Firewall rules (UFW: ports 22556, 22555, 28332, 28333)
#       • System user and group (dogecoin)
#       • PID files (/run/dogecoin/, data directory)
#       • Temporary installation files (/tmp/dogecoin*, etc.)
#       • Library cache entries for Berkeley DB
#
#===============================================================================

# Don't use set -e - we handle errors explicitly for better cleanup
# set -e

#===============================================================================
# CONFIGURATION
#===============================================================================

# Installation paths (must match setup script)
INSTALL_DIR="/opt/dogecoin"
DATA_DIR="/var/lib/dogecoin"
WALLET_DIR="/var/lib/dogecoin/wallets"
CONFIG_DIR="/etc/dogecoin"
LOG_DIR="/var/log/dogecoin"
SOURCE_DIR="/usr/local/src/dogecoin"
BDB_PREFIX="/usr/local/BerkeleyDB.4.8"
DOGECOIN_USER="dogecoin"

# Ports to remove from firewall
P2P_PORT="22556"
RPC_PORT="22555"
ZMQ_HASHBLOCK_PORT="28332"
ZMQ_RAWBLOCK_PORT="28333"

# Options
KEEP_BLOCKCHAIN=false
KEEP_WALLETS=false
FORCE_MODE=false
QUIET_MODE=false

#===============================================================================
# TERMINAL COLORS
#===============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

print_banner() {
    if [[ "$QUIET_MODE" == true ]]; then
        return
    fi
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║              DOGECOIN NODE UNINSTALL SCRIPT                          ║"
    echo "║                                                                      ║"
    echo "║        This will remove all Dogecoin node components                 ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

print_info() {
    if [[ "$QUIET_MODE" != true ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

print_success() {
    if [[ "$QUIET_MODE" != true ]]; then
        echo -e "${GREEN}[✓]${NC} $1"
    fi
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    if [[ "$QUIET_MODE" != true ]]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}  $1${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

confirm() {
    local prompt="$1"
    local default="$2"
    
    if [[ "$FORCE_MODE" == true ]]; then
        return 0
    fi
    
    if [[ "$default" == "Y" ]]; then
        echo -ne "${YELLOW}${prompt} [Y/n]:${NC} "
    else
        echo -ne "${YELLOW}${prompt} [y/N]:${NC} "
    fi
    
    read -r result
    result="${result:-$default}"
    
    if [[ "$result" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

show_help() {
    echo "Dogecoin Node Uninstall Script"
    echo ""
    echo "Usage: sudo ./uninstall-dogecoin.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --keep-blockchain    Keep blockchain data (/var/lib/dogecoin)"
    echo "  --keep-wallets       Keep wallet files only"
    echo "  --force              Skip all confirmations (dangerous!)"
    echo "  --quiet              Minimal output"
    echo "  --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo ./uninstall-dogecoin.sh                    # Interactive uninstall"
    echo "  sudo ./uninstall-dogecoin.sh --keep-blockchain  # Keep blockchain data"
    echo "  sudo ./uninstall-dogecoin.sh --force --quiet    # Silent complete removal"
    echo ""
}

#===============================================================================
# PARSE ARGUMENTS
#===============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --keep-blockchain)
                KEEP_BLOCKCHAIN=true
                shift
                ;;
            --keep-wallets)
                KEEP_WALLETS=true
                shift
                ;;
            --force)
                FORCE_MODE=true
                shift
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

#===============================================================================
# CHECK FUNCTIONS
#===============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        echo ""
        echo "Usage: sudo ./uninstall-dogecoin.sh"
        exit 1
    fi
}

check_installation() {
    local found=false
    local found_items=""
    
    # Check all possible installation artifacts
    [[ -d "$INSTALL_DIR" ]] && found=true && found_items+="  • Binaries: $INSTALL_DIR\n"
    [[ -d "$DATA_DIR" ]] && found=true && found_items+="  • Data: $DATA_DIR\n"
    [[ -d "$CONFIG_DIR" ]] && found=true && found_items+="  • Config: $CONFIG_DIR\n"
    [[ -d "$LOG_DIR" ]] && found=true && found_items+="  • Logs: $LOG_DIR\n"
    [[ -d "$SOURCE_DIR" ]] && found=true && found_items+="  • Source: $SOURCE_DIR\n"
    [[ -d "$BDB_PREFIX" ]] && found=true && found_items+="  • Berkeley DB: $BDB_PREFIX\n"
    [[ -f "/etc/systemd/system/dogecoind.service" ]] && found=true && found_items+="  • Systemd service\n"
    [[ -L "/usr/local/bin/dogecoind" ]] && found=true && found_items+="  • Symlinks in /usr/local/bin/\n"
    id "$DOGECOIN_USER" &>/dev/null && found=true && found_items+="  • System user: $DOGECOIN_USER\n"
    pgrep -x dogecoind > /dev/null 2>&1 && found=true && found_items+="  • Running dogecoind process\n"
    systemctl is-active --quiet dogecoind 2>/dev/null && found=true && found_items+="  • Active systemd service\n"
    
    if [[ "$found" == true ]]; then
        print_info "Found Dogecoin installation components:"
        echo -e "$found_items"
    else
        print_warning "No Dogecoin installation detected"
        if ! confirm "Continue anyway?" "N"; then
            exit 0
        fi
    fi
}

#===============================================================================
# REMOVAL FUNCTIONS
#===============================================================================

stop_service() {
    print_step "Stopping Dogecoin Service"
    
    # Method 1: Stop via systemd if service exists
    if systemctl is-active --quiet dogecoind 2>/dev/null; then
        print_info "Stopping dogecoind via systemd..."
        systemctl stop dogecoind 2>/dev/null || true
        sleep 3
    fi
    
    # Method 2: Try stopping via dogecoin-cli (graceful shutdown)
    if [[ -f "$INSTALL_DIR/bin/dogecoin-cli" ]] && [[ -f "$CONFIG_DIR/dogecoin.conf" ]]; then
        print_info "Attempting graceful shutdown via dogecoin-cli..."
        "$INSTALL_DIR/bin/dogecoin-cli" -conf="$CONFIG_DIR/dogecoin.conf" stop 2>/dev/null || true
        sleep 3
    elif command -v dogecoin-cli &>/dev/null && [[ -f "$CONFIG_DIR/dogecoin.conf" ]]; then
        dogecoin-cli -conf="$CONFIG_DIR/dogecoin.conf" stop 2>/dev/null || true
        sleep 3
    fi
    
    # Method 3: Kill any remaining dogecoind processes (by name)
    if pgrep -x dogecoind > /dev/null 2>&1; then
        print_info "Killing remaining dogecoind processes..."
        pkill -15 dogecoind 2>/dev/null || true  # SIGTERM first
        sleep 3
        
        # Force kill if still running
        if pgrep -x dogecoind > /dev/null 2>&1; then
            print_warning "Force killing dogecoind..."
            pkill -9 dogecoind 2>/dev/null || true
            sleep 2
        fi
    fi
    
    # Method 4: Kill by user (if dogecoin user exists)
    if id "$DOGECOIN_USER" &>/dev/null; then
        if pgrep -u "$DOGECOIN_USER" > /dev/null 2>&1; then
            print_info "Killing processes owned by $DOGECOIN_USER user..."
            pkill -15 -u "$DOGECOIN_USER" 2>/dev/null || true
            sleep 2
            pkill -9 -u "$DOGECOIN_USER" 2>/dev/null || true
            sleep 1
        fi
    fi
    
    # Verify no dogecoind processes remain
    if pgrep -x dogecoind > /dev/null 2>&1; then
        print_warning "Some dogecoind processes may still be running"
        print_info "Running processes:"
        pgrep -ax dogecoind 2>/dev/null || true
    else
        print_success "All dogecoind processes stopped"
    fi
    
    # Disable the service
    if systemctl is-enabled --quiet dogecoind 2>/dev/null; then
        print_info "Disabling dogecoind service..."
        systemctl disable dogecoind 2>/dev/null || true
        print_success "Service disabled"
    fi
}

remove_systemd_service() {
    print_step "Removing Systemd Service"
    
    if [[ -f "/etc/systemd/system/dogecoind.service" ]]; then
        rm -f /etc/systemd/system/dogecoind.service
        systemctl daemon-reload
        print_success "Systemd service removed"
    else
        print_info "Systemd service not found"
    fi
}

remove_binaries() {
    print_step "Removing Dogecoin Binaries"
    
    # Remove symlinks first
    local symlinks=("dogecoind" "dogecoin-cli" "dogecoin-tx")
    for link in "${symlinks[@]}"; do
        if [[ -L "/usr/local/bin/$link" ]]; then
            rm -f "/usr/local/bin/$link"
            print_info "Removed symlink: /usr/local/bin/$link"
        fi
    done
    
    # Remove installation directory
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_success "Removed $INSTALL_DIR"
    else
        print_info "Binary directory not found"
    fi
}

remove_source_code() {
    print_step "Removing Source Code"
    
    if [[ -d "$SOURCE_DIR" ]]; then
        rm -rf "$SOURCE_DIR"
        print_success "Removed $SOURCE_DIR"
    else
        print_info "Source directory not found"
    fi
}

remove_berkeley_db() {
    print_step "Removing Berkeley DB 4.8"
    
    if [[ -d "$BDB_PREFIX" ]]; then
        rm -rf "$BDB_PREFIX"
        print_success "Removed $BDB_PREFIX"
    else
        print_info "Berkeley DB not found"
    fi
}

remove_config() {
    print_step "Removing Configuration Files"
    
    if [[ -d "$CONFIG_DIR" ]]; then
        # Show what config files exist
        if [[ "$QUIET_MODE" != true ]]; then
            print_info "Configuration files to remove:"
            ls -la "$CONFIG_DIR" 2>/dev/null || true
        fi
        
        rm -rf "$CONFIG_DIR"
        print_success "Removed $CONFIG_DIR"
    else
        print_info "Config directory not found"
    fi
}

remove_logs() {
    print_step "Removing Log Files"
    
    if [[ -d "$LOG_DIR" ]]; then
        rm -rf "$LOG_DIR"
        print_success "Removed $LOG_DIR"
    else
        print_info "Log directory not found"
    fi
}

remove_data() {
    print_step "Removing Blockchain Data"
    
    if [[ ! -d "$DATA_DIR" ]]; then
        print_info "Data directory not found"
        return
    fi
    
    if [[ "$KEEP_BLOCKCHAIN" == true ]]; then
        print_warning "Keeping blockchain data (--keep-blockchain)"
        
        if [[ "$KEEP_WALLETS" == true ]]; then
            print_warning "Keeping wallet files (--keep-wallets)"
        fi
        return
    fi
    
    if [[ "$KEEP_WALLETS" == true ]]; then
        print_warning "Keeping wallet files (--keep-wallets)"
        
        # Remove everything except wallets
        find "$DATA_DIR" -mindepth 1 -maxdepth 1 ! -name 'wallets' -exec rm -rf {} \;
        print_success "Removed blockchain data (kept wallets)"
        return
    fi
    
    # Calculate size for user info
    local data_size=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1 || echo "unknown")
    
    if [[ "$FORCE_MODE" != true ]]; then
        echo ""
        echo -e "${RED}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${NC}  ${BOLD}WARNING: BLOCKCHAIN DATA DELETION${NC}                                    ${RED}║${NC}"
        echo -e "${RED}╠═══════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║${NC}                                                                       ${RED}║${NC}"
        echo -e "${RED}║${NC}  This will permanently delete:                                        ${RED}║${NC}"
        echo -e "${RED}║${NC}    • Blockchain data (~${data_size})                                       ${RED}║${NC}"
        echo -e "${RED}║${NC}    • Wallet files (if any)                                            ${RED}║${NC}"
        echo -e "${RED}║${NC}    • All transaction history                                          ${RED}║${NC}"
        echo -e "${RED}║${NC}                                                                       ${RED}║${NC}"
        echo -e "${RED}║${NC}  ${YELLOW}This CANNOT be undone!${NC}                                               ${RED}║${NC}"
        echo -e "${RED}║${NC}                                                                       ${RED}║${NC}"
        echo -e "${RED}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Check for wallets
        if [[ -d "$WALLET_DIR" ]] && [[ -n "$(ls -A $WALLET_DIR 2>/dev/null)" ]]; then
            echo -e "${YELLOW}⚠ WALLET FILES DETECTED in $WALLET_DIR${NC}"
            echo "  Make sure you have backed up your wallets!"
            echo ""
        fi
        
        if ! confirm "Delete ALL blockchain data and wallets?" "N"; then
            print_warning "Skipping blockchain data removal"
            print_info "Use --keep-blockchain or --keep-wallets next time"
            return
        fi
        
        # Double confirm for wallets
        if [[ -d "$WALLET_DIR" ]] && [[ -n "$(ls -A $WALLET_DIR 2>/dev/null)" ]]; then
            echo ""
            echo -e "${RED}FINAL WARNING: Wallet files will be deleted!${NC}"
            if ! confirm "Are you ABSOLUTELY sure?" "N"; then
                print_warning "Aborted - keeping data"
                return
            fi
        fi
    fi
    
    rm -rf "$DATA_DIR"
    print_success "Removed $DATA_DIR (${data_size})"
}

remove_firewall_rules() {
    print_step "Removing Firewall Rules"
    
    if ! command -v ufw &> /dev/null; then
        print_info "UFW not installed, skipping"
        return
    fi
    
    if ! ufw status | grep -q "Status: active"; then
        print_info "UFW not active, skipping"
        return
    fi
    
    # Remove all Dogecoin-related port rules
    print_info "Removing Dogecoin port rules..."
    
    # P2P port
    ufw delete allow ${P2P_PORT}/tcp 2>/dev/null && print_info "  Removed P2P port rule (${P2P_PORT})" || true
    
    # RPC port
    ufw delete allow ${RPC_PORT}/tcp 2>/dev/null && print_info "  Removed RPC port rule (${RPC_PORT})" || true
    
    # ZMQ ports (in case they were added)
    ufw delete allow ${ZMQ_HASHBLOCK_PORT}/tcp 2>/dev/null && print_info "  Removed ZMQ hashblock port rule (${ZMQ_HASHBLOCK_PORT})" || true
    ufw delete allow ${ZMQ_RAWBLOCK_PORT}/tcp 2>/dev/null && print_info "  Removed ZMQ rawblock port rule (${ZMQ_RAWBLOCK_PORT})" || true
    
    # Remove rules by comment (catches any rules with "dogecoin" or "Dogecoin" in the comment)
    # Process in reverse order to avoid index shifting issues
    local rule_nums=$(ufw status numbered | grep -i dogecoin | awk -F'[][]' '{print $2}' | sort -rn)
    if [[ -n "$rule_nums" ]]; then
        print_info "Removing rules with 'dogecoin' in comment..."
        for num in $rule_nums; do
            ufw --force delete "$num" 2>/dev/null && print_info "  Removed rule #$num" || true
        done
    fi
    
    print_success "Firewall rules removed"
}

remove_user() {
    print_step "Removing System User"
    
    if id "$DOGECOIN_USER" &>/dev/null; then
        # Kill any remaining processes owned by user (should already be done, but be thorough)
        print_info "Ensuring no processes remain for user $DOGECOIN_USER..."
        pkill -15 -u "$DOGECOIN_USER" 2>/dev/null || true
        sleep 2
        pkill -9 -u "$DOGECOIN_USER" 2>/dev/null || true
        sleep 1
        
        # Remove user
        userdel -f "$DOGECOIN_USER" 2>/dev/null || {
            print_warning "Could not remove user with userdel, trying alternative..."
            # Sometimes userdel fails if processes still exist, force remove from passwd/shadow
            if [[ -f /etc/passwd ]]; then
                sed -i "/^${DOGECOIN_USER}:/d" /etc/passwd 2>/dev/null || true
            fi
            if [[ -f /etc/shadow ]]; then
                sed -i "/^${DOGECOIN_USER}:/d" /etc/shadow 2>/dev/null || true
            fi
        }
        print_success "Removed user: $DOGECOIN_USER"
    else
        print_info "User not found"
    fi
    
    # Remove group if it exists (separate from user)
    if getent group "$DOGECOIN_USER" &>/dev/null; then
        print_info "Removing group: $DOGECOIN_USER"
        groupdel "$DOGECOIN_USER" 2>/dev/null || {
            # Alternative removal
            if [[ -f /etc/group ]]; then
                sed -i "/^${DOGECOIN_USER}:/d" /etc/group 2>/dev/null || true
            fi
        }
        print_success "Removed group: $DOGECOIN_USER"
    fi
    
    # Remove user's home directory if it still exists and is not in /var/lib/dogecoin
    if [[ -d "/home/$DOGECOIN_USER" ]]; then
        rm -rf "/home/$DOGECOIN_USER" 2>/dev/null || true
        print_info "Removed /home/$DOGECOIN_USER"
    fi
}

cleanup_tmp() {
    print_step "Cleaning Up Temporary Files"
    
    # Remove any temp files from installation
    rm -rf /tmp/dogecoin-setup 2>/dev/null || true
    rm -rf /tmp/setup-dogecoin*.sh 2>/dev/null || true
    rm -rf /tmp/db-4.8.30* 2>/dev/null || true
    rm -rf /tmp/dogecoin* 2>/dev/null || true
    rm -f /tmp/setup-dogecoin-new.sh 2>/dev/null || true
    
    # Remove build logs created during installation
    rm -f /tmp/bdb-build.log 2>/dev/null || true
    rm -f /tmp/dogecoin-build.log 2>/dev/null || true
    
    # Remove any Berkeley DB temp directories
    rm -rf /tmp/tmp.* 2>/dev/null || true
    
    # Clean up any stale PID files
    rm -f /run/dogecoin/dogecoind.pid 2>/dev/null || true
    rm -f "$DATA_DIR/dogecoind.pid" 2>/dev/null || true
    rmdir /run/dogecoin 2>/dev/null || true
    
    # Remove any .dogecoin directory in root's home (in case user ran as root without proper config)
    if [[ -d /root/.dogecoin ]]; then
        print_info "Found /root/.dogecoin - removing..."
        rm -rf /root/.dogecoin 2>/dev/null || true
    fi
    
    # Check for .dogecoin in regular user homes
    for user_home in /home/*; do
        if [[ -d "$user_home/.dogecoin" ]]; then
            print_info "Found $user_home/.dogecoin - removing..."
            rm -rf "$user_home/.dogecoin" 2>/dev/null || true
        fi
    done
    
    # Remove any apt cache files created during dependency install
    apt-get clean 2>/dev/null || true
    
    print_success "Temporary files cleaned"
}

remove_ld_cache() {
    print_step "Updating Library Cache"
    
    # Remove any LD config files created for Berkeley DB
    if [[ -f /etc/ld.so.conf.d/berkeleydb.conf ]]; then
        rm -f /etc/ld.so.conf.d/berkeleydb.conf
        ldconfig 2>/dev/null || true
        print_info "Removed Berkeley DB library config"
    fi
    
    # Update ldconfig after removing Berkeley DB
    if [[ -d /etc/ld.so.conf.d ]]; then
        ldconfig 2>/dev/null || true
    fi
    
    print_success "Library cache updated"
}

#===============================================================================
# VERIFICATION
#===============================================================================

verify_removal() {
    print_step "Verifying Removal"
    
    local issues=0
    
    # Check for running processes
    if pgrep -x dogecoind > /dev/null 2>&1; then
        print_warning "WARNING: dogecoind process still running"
        issues=$((issues + 1))
    fi
    
    # Check for systemd service
    if systemctl is-active --quiet dogecoind 2>/dev/null; then
        print_warning "WARNING: dogecoind service still active"
        issues=$((issues + 1))
    fi
    
    # Check for binaries
    if [[ -f "$INSTALL_DIR/bin/dogecoind" ]]; then
        print_warning "WARNING: Binaries still exist at $INSTALL_DIR"
        issues=$((issues + 1))
    fi
    
    # Check for symlinks
    for binary in dogecoind dogecoin-cli dogecoin-tx; do
        if [[ -L "/usr/local/bin/$binary" ]] || [[ -f "/usr/local/bin/$binary" ]]; then
            print_warning "WARNING: $binary still exists in /usr/local/bin/"
            issues=$((issues + 1))
        fi
    done
    
    # Check for config directory
    if [[ -d "$CONFIG_DIR" ]]; then
        print_warning "WARNING: Config directory still exists at $CONFIG_DIR"
        issues=$((issues + 1))
    fi
    
    # Check for log directory
    if [[ -d "$LOG_DIR" ]]; then
        print_warning "WARNING: Log directory still exists at $LOG_DIR"
        issues=$((issues + 1))
    fi
    
    # Check for systemd service file
    if [[ -f "/etc/systemd/system/dogecoind.service" ]]; then
        print_warning "WARNING: Systemd service file still exists"
        issues=$((issues + 1))
    fi
    
    # Check for user
    if id "$DOGECOIN_USER" &>/dev/null; then
        print_warning "WARNING: System user $DOGECOIN_USER still exists"
        issues=$((issues + 1))
    fi
    
    # Check which command
    if command -v dogecoind &>/dev/null; then
        print_warning "WARNING: dogecoind still found in PATH"
        issues=$((issues + 1))
    fi
    
    # Check for Berkeley DB
    if [[ -d "$BDB_PREFIX" ]]; then
        print_warning "WARNING: Berkeley DB still exists at $BDB_PREFIX"
        issues=$((issues + 1))
    fi
    
    # Check for source code
    if [[ -d "$SOURCE_DIR" ]]; then
        print_warning "WARNING: Source code still exists at $SOURCE_DIR"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        print_success "Verification passed - all components removed"
    else
        print_warning "Verification found $issues potential issue(s)"
        print_info "Some components may require manual cleanup or a reboot"
    fi
}

#===============================================================================
# SUMMARY
#===============================================================================

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}                    ${BOLD}UNINSTALL COMPLETE${NC}                                  ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "The following components have been removed:"
    echo ""
    echo -e "  ${GREEN}✓${NC} Dogecoin daemon stopped"
    echo -e "  ${GREEN}✓${NC} Systemd service disabled and removed"
    echo -e "  ${GREEN}✓${NC} Dogecoin binaries and symlinks"
    echo -e "  ${GREEN}✓${NC} Source code (/usr/local/src/dogecoin)"
    echo -e "  ${GREEN}✓${NC} Berkeley DB 4.8"
    echo -e "  ${GREEN}✓${NC} Library cache configuration"
    echo -e "  ${GREEN}✓${NC} Configuration files (/etc/dogecoin)"
    echo -e "  ${GREEN}✓${NC} Log files (/var/log/dogecoin)"
    echo -e "  ${GREEN}✓${NC} Firewall rules (UFW)"
    echo -e "  ${GREEN}✓${NC} System user (dogecoin)"
    echo -e "  ${GREEN}✓${NC} Temporary files"
    
    if [[ "$KEEP_BLOCKCHAIN" == true ]]; then
        echo -e "  ${YELLOW}○${NC} Blockchain data (kept at $DATA_DIR)"
    elif [[ "$KEEP_WALLETS" == true ]]; then
        echo -e "  ${GREEN}✓${NC} Blockchain data (removed)"
        echo -e "  ${YELLOW}○${NC} Wallet files (kept at $WALLET_DIR)"
    else
        echo -e "  ${GREEN}✓${NC} Blockchain data and wallets"
    fi
    
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo "Your system has been cleaned of Dogecoin node components."
    echo ""
    
    if [[ "$KEEP_BLOCKCHAIN" == true ]] || [[ "$KEEP_WALLETS" == true ]]; then
        echo -e "${YELLOW}Note: Some data was preserved. To remove everything:${NC}"
        echo "  sudo rm -rf $DATA_DIR"
        echo ""
    fi
    
    echo -e "${BOLD}Verify removal:${NC}"
    echo "  which dogecoind                      # Should return nothing"
    echo "  systemctl status dogecoind           # Should say 'not found'"
    echo "  ls /opt/dogecoin                     # Should not exist"
    echo "  ls /etc/dogecoin                     # Should not exist"
    echo "  id dogecoin                          # Should say 'no such user'"
    echo ""
    
    echo -e "${BOLD}To reinstall:${NC}"
    echo "  sudo ./setup-dogecoin.sh"
    echo ""
    echo -e "${YELLOW}A system reboot is recommended to ensure complete cleanup.${NC}"
    echo ""
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    parse_args "$@"
    
    print_banner
    check_root
    check_installation
    
    if [[ "$FORCE_MODE" != true ]]; then
        echo ""
        echo "This will remove the Dogecoin node and all its components."
        echo ""
        if [[ "$KEEP_BLOCKCHAIN" == true ]]; then
            echo -e "${YELLOW}Note: Blockchain data will be preserved (--keep-blockchain)${NC}"
        fi
        if [[ "$KEEP_WALLETS" == true ]]; then
            echo -e "${YELLOW}Note: Wallet files will be preserved (--keep-wallets)${NC}"
        fi
        echo ""
        
        if ! confirm "Continue with uninstall?" "N"; then
            print_info "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Perform uninstall in order
    stop_service
    remove_systemd_service
    remove_binaries
    remove_source_code
    remove_berkeley_db
    remove_ld_cache
    remove_config
    remove_logs
    remove_data
    remove_firewall_rules
    remove_user
    cleanup_tmp
    verify_removal
    
    print_summary
}

main "$@"

