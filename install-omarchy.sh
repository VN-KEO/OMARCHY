cat > ~/install-omarchy.sh << 'INSTALL_EOF'
#!/bin/bash

# OMARCHY Installation Script
# GitHub: https://github.com/VN-KEO/OMARCHY

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
show_banner() {
    clear
    echo -e "${MAGENTA}"
    cat << "BANNER"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║  ██████╗ ███╗   ███╗ █████╗ ██████╗ ██████╗██╗  ██╗██╗  ║
║ ██╔═══██╗████╗ ████║██╔══██╗██╔══██╗██╔════╝██║  ██║╚██╗ ║
║ ██║   ██║██╔████╔██║███████║██████╔╝██║     ███████║ ╚██╗║
║ ██║   ██║██║╚██╔╝██║██╔══██║██╔══██╗██║     ██╔══██║  ██║║
║ ╚██████╔╝██║ ╚═╝ ██║██║  ██║██║  ██║╚██████╗██║  ██║  ██║║
║  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝  ╚═╝║
║                                                          ║
║                INSTALLATION WIZARD                       ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}${BOLD}Version: 2.1.0 | Author: VN-KEO | GitHub: https://github.com/VN-KEO/OMARCHY${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}"
}

# Print functions
print_info() { echo -e "${BLUE}[ℹ]${NC} $*"; }
print_success() { echo -e "${GREEN}[✓]${NC} $*"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $*"; }
print_error() { echo -e "${RED}[✗]${NC} $*"; }

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    local missing=()
    
    # Check Python
    if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
        missing+=("python3")
    fi
    
    # Check curl
    if ! command -v curl &>/dev/null; then
        missing+=("curl")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "Missing dependencies: ${missing[*]}"
        
        # Try to install automatically
        if command -v apt &>/dev/null; then
            print_info "Detected apt (Debian/Ubuntu)"
            sudo apt update
            sudo apt install -y "${missing[@]}"
        elif command -v yum &>/dev/null; then
            print_info "Detected yum (RHEL/CentOS)"
            sudo yum install -y "${missing[@]}"
        elif command -v pacman &>/dev/null; then
            print_info "Detected pacman (Arch)"
            sudo pacman -S --noconfirm "${missing[@]}"
        elif command -v dnf &>/dev/null; then
            print_info "Detected dnf (Fedora)"
            sudo dnf install -y "${missing[@]}"
        else
            print_error "Cannot auto-install dependencies"
            print_info "Please install manually:"
            for dep in "${missing[@]}"; do
                echo "  - $dep"
            done
            return 1
        fi
    fi
    
    print_success "All dependencies satisfied"
    return 0
}

# Install OMARCHY
install_omarchy() {
    local install_dir="/usr/local/bin"
    local script_path="${install_dir}/omarchy"
    
    print_info "Installing OMARCHY..."
    
    # Check if already installed
    if [[ -f "${script_path}" ]]; then
        print_warning "OMARCHY already installed at ${script_path}"
        read -p "Overwrite? (y/N): " choice
        if [[ ! "${choice}" =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled"
            return 0
        fi
    fi
    
    # Download or copy script
    if [[ -f "./omarchy.sh" ]]; then
        print_info "Using local omarchy.sh"
        sudo cp "./omarchy.sh" "${script_path}"
    else
        print_info "Downloading from GitHub..."
        if command -v curl &>/dev/null; then
            sudo curl -s -o "${script_path}" \
                "https://raw.githubusercontent.com/VN-KEO/OMARCHY/main/omarchy.sh"
        elif command -v wget &>/dev/null; then
            sudo wget -q -O "${script_path}" \
                "https://raw.githubusercontent.com/VN-KEO/OMARCHY/main/omarchy.sh"
        else
            print_error "Cannot download (curl/wget not found)"
            return 1
        fi
    fi
    
    # Make executable
    sudo chmod +x "${script_path}"
    print_success "Installed to ${script_path}"
    
    # Create alias for convenience
    if ! grep -q "alias omarchy=" ~/.bashrc 2>/dev/null; then
        echo "alias omarchy='${script_path}'" >> ~/.bashrc
        print_success "Created alias in ~/.bashrc"
    fi
    
    return 0
}

# Create systemd service (optional)
create_service() {
    print_info "Setting up system service..."
    
    local service_file="/etc/systemd/system/omarchy.service"
    
    # Check if service already exists
    if [[ -f "${service_file}" ]]; then
        print_warning "Service already exists"
        read -p "Recreate? (y/N): " choice
        if [[ ! "${choice}" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    # Create service file
    sudo tee "${service_file}" >/dev/null << EOF
[Unit]
Description=OMARCHY Port Rotation System
After=network.target
Wants=network.target

[Service]
Type=simple
User=${USER}
ExecStart=${script_path:-/usr/local/bin/omarchy} start
ExecStop=${script_path:-/usr/local/bin/omarchy} stop
Restart=on-failure
RestartSec=10
Environment="HOME=${HOME}"

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    sudo systemctl daemon-reload
    print_success "Systemd service created"
    
    # Enable auto-start
    read -p "Enable auto-start on boot? (Y/n): " choice
    if [[ ! "${choice}" =~ ^[Nn]$ ]]; then
        sudo systemctl enable omarchy.service
        print_success "Auto-start enabled"
    fi
    
    return 0
}

# Run first-time setup
first_time_setup() {
    print_info "Running first-time setup..."
    
    # Run OMARCHY install
    if command -v omarchy &>/dev/null; then
        omarchy install
    elif [[ -f "/usr/local/bin/omarchy" ]]; then
        /usr/local/bin/omarchy install
    else
        print_error "OMARCHY command not found"
        return 1
    fi
    
    return 0
}

# Main installation
main() {
    show_banner
    
    echo -e "${CYAN}Welcome to OMARCHY Installation Wizard${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}This will install OMARCHY v2.1.0 on your system.${NC}"
    echo -e "${YELLOW}GitHub: https://github.com/VN-KEO/OMARCHY${NC}\n"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root is not recommended"
        read -p "Continue anyway? (y/N): " choice
        if [[ ! "${choice}" =~ ^[Yy]$ ]]; then
            print_info "Please run as a regular user"
            exit 1
        fi
    fi
    
    # Step 1: Check dependencies
    if ! check_dependencies; then
        print_error "Dependency check failed"
        exit 1
    fi
    
    # Step 2: Install script
    if ! install_omarchy; then
        print_error "Installation failed"
        exit 1
    fi
    
    # Step 3: Create service (optional)
    read -p "Create systemd service? (Y/n): " service_choice
    if [[ ! "${service_choice}" =~ ^[Nn]$ ]]; then
        create_service
    fi
    
    # Step 4: First-time setup
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════${NC}"
    print_info "Starting OMARCHY first-time setup..."
    
    if ! first_time_setup; then
        print_error "First-time setup failed"
        print_info "You can run manually: omarchy install"
    fi
    
    # Completion
    echo -e "\n${GREEN}══════════════════════════════════════════════════════════${NC}"
    print_success "OMARCHY INSTALLATION COMPLETE!"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "${BOLD}📋 Available Commands:${NC}"
    echo -e "  ${CYAN}omarchy status${NC}    - Check system status"
    echo -e "  ${CYAN}omarchy rotate${NC}    - Manual port rotation"
    echo -e "  ${CYAN}omarchy monitor${NC}   - Real-time monitoring"
    echo -e "  ${CYAN}omarchy test${NC}      - Test web interface"
    echo -e "  ${CYAN}omarchy config${NC}    - View configuration"
    echo -e "  ${CYAN}omarchy uninstall${NC} - Remove OMARCHY"
    
    echo -e "\n${BOLD}🚀 Quick Start:${NC}"
    echo -e "  1. Check status: ${CYAN}omarchy status${NC}"
    echo -e "  2. Monitor: ${CYAN}omarchy monitor${NC}"
    echo -e "  3. Test: ${CYAN}omarchy test${NC}"
    
    echo -e "\n${BOLD}🔗 GitHub Repository:${NC}"
    echo -e "  ${BLUE}https://github.com/VN-KEO/OMARCHY${NC}"
    echo -e "  ${GRAY}└── ⭐ Star | 🍴 Fork | 📝 Issues | 📚 Wiki${NC}"
    
    echo -e "\n${YELLOW}Need help? Run: omarchy help${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Source bashrc for alias
    if [[ -f ~/.bashrc ]]; then
        source ~/.bashrc 2>/dev/null || true
    fi
}

# Run main
main "$@"
INSTALL_EOF
