cat > ~/uninstall-omarchy.sh << 'UNINSTALL_EOF'
#!/bin/bash

# OMARCHY Uninstall Script
# GitHub: https://github.com/VN-KEO/OMARCHY

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[ℹ]${NC} $*"; }
print_success() { echo -e "${GREEN}[✓]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $*"; }
print_error() { echo -e "${RED}[✗]${NC} $*"; }

# Show warning
show_warning() {
    clear
    echo -e "${RED}"
    cat << "WARNING"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ██████╗ ███╗   ███╗ █████╗ ██████╗ ██████╗██╗  ██╗██╗  ║
║ ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ║
║ ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚██╗║
║ ██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ██║║
║ ╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║  ██║║
║  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝  ╚═╝║
║                                                          ║
║                 UNINSTALLATION WIZARD                    ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
WARNING
    echo -e "${NC}"
    
    echo -e "${RED}${BOLD}⚠️  CRITICAL WARNING ⚠️${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}This will completely remove OMARCHY from your system.${NC}"
    echo -e "${YELLOW}All data, configurations, and logs will be deleted.${NC}"
    echo -e "${YELLOW}This action cannot be undone!${NC}\n"
    
    echo -e "${BOLD}The following will be removed:${NC}"
    echo "  • OMARCHY binary (/usr/local/bin/omarchy)"
    echo "  • Configuration directory (~/.omarchy/)"
    echo "  • Systemd service (/etc/systemd/system/omarchy.service)"
    echo "  • All rotation history and logs"
    echo "  • Bash aliases"
    
    echo -e "\n${RED}THIS IS A DESTRUCTIVE OPERATION!${NC}\n"
}

# Stop services
stop_services() {
    print_info "Stopping OMARCHY services..."
    
    # Stop via omarchy command if available
    if command -v omarchy &>/dev/null; then
        omarchy stop 2>/dev/null || true
    fi
    
    # Stop systemd service
    if systemctl is-active --quiet omarchy.service 2>/dev/null; then
        sudo systemctl stop omarchy.service
        print_success "Stopped systemd service"
    fi
    
    # Kill any remaining processes
    pkill -f "python.*http.server" 2>/dev/null || true
    pkill -f "omarchy.*daemon" 2>/dev/null || true
    
    sleep 2
}

# Remove files
remove_files() {
    print_info "Removing files..."
    
    # Remove binary
    if [[ -f "/usr/local/bin/omarchy" ]]; then
        sudo rm -f /usr/local/bin/omarchy
        print_success "Removed /usr/local/bin/omarchy"
    fi
    
    # Remove configuration directory
    if [[ -d "${HOME}/.omarchy" ]]; then
        rm -rf "${HOME}/.omarchy"
        print_success "Removed ${HOME}/.omarchy"
    fi
    
    # Remove systemd service
    if [[ -f "/etc/systemd/system/omarchy.service" ]]; then
        sudo systemctl disable omarchy.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/omarchy.service
        sudo systemctl daemon-reload
        print_success "Removed systemd service"
    fi
    
    # Remove bash alias
    if [[ -f "${HOME}/.bashrc" ]]; then
        sed -i '/alias omarchy=/d' "${HOME}/.bashrc"
        print_success "Removed bash alias"
    fi
    
    # Remove zsh alias
    if [[ -f "${HOME}/.zshrc" ]]; then
        sed -i '/alias omarchy=/d' "${HOME}/.zshrc"
        print_success "Removed zsh alias"
    fi
}

# Cleanup temporary files
cleanup_temp() {
    print_info "Cleaning up temporary files..."
    
    # Remove PID files
    find /tmp -name "*omarchy*" -delete 2>/dev/null || true
    find /var/tmp -name "*omarchy*" -delete 2>/dev/null || true
    
    # Remove test files
    rm -f /tmp/omarchy_test.html 2>/dev/null || true
    
    print_success "Temporary files cleaned"
}

# Verify removal
verify_removal() {
    print_info "Verifying removal..."
    
    local errors=0
    
    # Check binary
    if command -v omarchy &>/dev/null; then
        print_error "Binary still exists: $(which omarchy)"
        errors=1
    fi
    
    # Check config directory
    if [[ -d "${HOME}/.omarchy" ]]; then
        print_error "Config directory still exists: ${HOME}/.omarchy"
        errors=1
    fi
    
    # Check systemd service
    if [[ -f "/etc/systemd/system/omarchy.service" ]]; then
        print_error "Systemd service still exists"
        errors=1
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "Verification passed - OMARCHY completely removed"
        return 0
    else
        print_error "Verification failed - some components remain"
        return 1
    fi
}

# Main uninstall
main() {
    show_warning
    
    # Final confirmation
    echo -e "${RED}${BOLD}ARE YOU ABSOLUTELY SURE?${NC}"
    read -p "Type 'DELETE OMARCHY' to confirm: " confirm
    
    if [[ "${confirm}" != "DELETE OMARCHY" ]]; then
        echo -e "${GREEN}Uninstall cancelled. OMARCHY is safe.${NC}"
        exit 0
    fi
    
    echo -e "\n${YELLOW}══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}🚨 STARTING UNINSTALLATION 🚨${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}\n"
    
    # Step 1: Stop services
    stop_services
    
    # Step 2: Remove files
    remove_files
    
    # Step 3: Cleanup
    cleanup_temp
    
    # Step 4: Verify
    if verify_removal; then
        echo -e "\n${GREEN}══════════════════════════════════════════════════════════${NC}"
        print_success "✅ OMARCHY SUCCESSFULLY UNINSTALLED"
        echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
        
        echo -e "\n${YELLOW}Thank you for using OMARCHY!${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}GitHub Repository:${NC} https://github.com/VN-KEO/OMARCHY"
        echo -e "${BOLD}Issues & Feedback:${NC} https://github.com/VN-KEO/OMARCHY/issues"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "\n${RED}══════════════════════════════════════════════════════════${NC}"
        print_error "⚠️  Uninstall incomplete"
        echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
        echo -e "\n${YELLOW}Some components may remain. Manual cleanup may be required.${NC}"
        exit 1
    fi
}

# Run main
main "$@"
UNINSTALL_EOF
