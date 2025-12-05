cat > ~/omarchy.sh << 'OMARCHY_EOF'
#!/usr/bin/env bash

# ===================================================================
# 🏰 OMARCHY - The Sovereign Port Rotation System
# Author: VN-KEO
# GitHub: https://github.com/VN-KEO/OMARCHY
# Version: 2.1.0
# License: MIT
# ===================================================================

set -euo pipefail

# Configuration
readonly OMARCHY_VERSION="2.1.0"
readonly OMARCHY_AUTHOR="VN-KEO"
readonly OMARCHY_GITHUB="https://github.com/VN-KEO/OMARCHY"
readonly OMARCHY_ISSUES="https://github.com/VN-KEO/OMARCHY/issues"
readonly OMARCHY_WIKI="https://github.com/VN-KEO/OMARCHY/wiki"

# Paths
readonly OMARCHY_DIR="${HOME}/.omarchy"
readonly PORTS_DIR="${OMARCHY_DIR}/ports"
readonly LOGS_DIR="${OMARCHY_DIR}/logs"
readonly WEB_DIR="${OMARCHY_DIR}/web"
readonly CONFIG_FILE="${OMARCHY_DIR}/config"
readonly PID_DIR="${OMARCHY_DIR}/pids"

# Default settings
readonly DEFAULT_MIN_PORT=10000
readonly DEFAULT_MAX_PORT=65535
readonly DEFAULT_INTERVAL=60
readonly DEFAULT_BIND_IP="127.0.0.1"

# Colors
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly MAGENTA='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly GRAY='\033[0;90m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE='' GRAY='' BOLD='' NC=''
fi

# ===================================================================
# LOGGING FUNCTIONS
# ===================================================================

log_info() { echo -e "${BLUE}[ℹ]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}[⚠]${NC} $*" >&2; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${GRAY}[🐛]${NC} $*" >&2; }

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

die() {
    log_error "$@"
    exit 1
}

check_deps() {
    local missing=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with:"
        if command -v apt &>/dev/null; then
            echo "  sudo apt install ${missing[*]}"
        elif command -v yum &>/dev/null; then
            echo "  sudo yum install ${missing[*]}"
        elif command -v pacman &>/dev/null; then
            echo "  sudo pacman -S ${missing[*]}"
        fi
        return 1
    fi
    return 0
}

is_root() {
    [[ "$EUID" -eq 0 ]]
}

# ===================================================================
# BANNER & DISPLAY
# ===================================================================

show_banner() {
    clear
    echo -e "${BOLD}${MAGENTA}"
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
║       THE SOVEREIGN PORT ROTATION SYSTEM                 ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}${BOLD}Version: ${GREEN}${OMARCHY_VERSION}${NC} | ${CYAN}GitHub: ${OMARCHY_GITHUB}${NC}"
    echo -e "${BOLD}Author: ${YELLOW}${OMARCHY_AUTHOR}${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
}

show_github() {
    echo -e "\n${CYAN}${BOLD}🔗 GitHub Repository:${NC}"
    echo -e "  ${BLUE}📦 ${OMARCHY_GITHUB}${NC}"
    echo -e "  ${WHITE}└── ⭐ Star | 🍴 Fork | 📝 Issues | 📚 Wiki${NC}"
    echo -e "      ${GRAY}Issues: ${OMARCHY_ISSUES}${NC}"
    echo -e "      ${GRAY}Wiki: ${OMARCHY_WIKI}${NC}"
}

# ===================================================================
# CONFIGURATION MANAGEMENT
# ===================================================================

load_config() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        source "${CONFIG_FILE}"
    else
        # Default values
        MIN_PORT="${DEFAULT_MIN_PORT}"
        MAX_PORT="${DEFAULT_MAX_PORT}"
        INTERVAL="${DEFAULT_INTERVAL}"
        BIND_IP="${DEFAULT_BIND_IP}"
        ENABLE_LOGGING="true"
        WEB_TITLE="🏰 OMARCHY Royal System"
        SHOW_GITHUB="true"
    fi
}

save_config() {
    cat > "${CONFIG_FILE}" << EOF
# OMARCHY Configuration
# Generated: $(date)
# GitHub: ${OMARCHY_GITHUB}

MIN_PORT="${MIN_PORT}"
MAX_PORT="${MAX_PORT}"
INTERVAL="${INTERVAL}"
BIND_IP="${BIND_IP}"
ENABLE_LOGGING="${ENABLE_LOGGING}"
WEB_TITLE="${WEB_TITLE}"
SHOW_GITHUB="${SHOW_GITHUB}"
EOF
}

# ===================================================================
# PORT MANAGEMENT
# ===================================================================

get_random_port() {
    local used_ports=()
    
    # Read used ports from history
    if [[ -f "${PORTS_DIR}/history.txt" ]]; then
        mapfile -t used_ports < "${PORTS_DIR}/history.txt" 2>/dev/null || true
    fi
    
    local attempts=0
    while [[ $attempts -lt 100 ]]; do
        ((attempts++))
        local port=$((RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT))
        
        # Skip common ports
        [[ ${port} -lt 1024 ]] && continue
        [[ ${port} =~ ^(80|443|22|21|25|53)$ ]] && continue
        [[ ${port} =~ ^(3000|4200|5000|8000|8080|8081|8888|9000)$ ]] && continue
        
        # Skip recently used
        if [[ " ${used_ports[*]} " =~ " ${port} " ]]; then
            continue
        fi
        
        # Check if port is in use
        if command -v ss &>/dev/null; then
            ss -tuln 2>/dev/null | grep -q ":${port} " && continue
        elif command -v netstat &>/dev/null; then
            netstat -tuln 2>/dev/null | grep -q ":${port} " && continue
        fi
        
        echo "${port}"
        return 0
    done
    
    # Fallback: sequential search
    for ((port=MIN_PORT; port<=MAX_PORT; port++)); do
        if ! [[ " ${used_ports[*]} " =~ " ${port} " ]]; then
            echo "${port}"
            return 0
        fi
    done
    
    die "No available ports in range ${MIN_PORT}-${MAX_PORT}"
}

get_current_port() {
    if [[ -f "${PORTS_DIR}/current.txt" ]]; then
        cat "${PORTS_DIR}/current.txt" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# ===================================================================
# WEB SERVER
# ===================================================================

generate_html() {
    local port="$1"
    local next_rotation=$(date -d "+${INTERVAL} seconds" '+%H:%M:%S')
    
    cat > "${WEB_DIR}/index.html" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${WEB_TITLE}</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --royal-gold: #ffd700;
            --royal-purple: #6a0dad;
            --royal-blue: #0a0a23;
            --neon-green: #00ff00;
            --neon-cyan: #00ffff;
            --neon-pink: #ff00ff;
        }
        
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: 'Courier New', monospace;
            background: linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #16213e 100%);
            color: #fff;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
            overflow-x: hidden;
        }
        
        .royal-container {
            background: rgba(0, 0, 0, 0.8);
            backdrop-filter: blur(10px);
            border: 2px solid var(--royal-gold);
            border-radius: 20px;
            padding: 40px;
            max-width: 1000px;
            width: 100%;
            box-shadow: 
                0 0 30px rgba(255, 215, 0, 0.3),
                0 0 60px rgba(106, 13, 173, 0.2),
                inset 0 0 20px rgba(255, 215, 0, 0.1);
            text-align: center;
            position: relative;
            overflow: hidden;
        }
        
        .royal-container::before {
            content: '';
            position: absolute;
            top: -50%;
            left: -50%;
            width: 200%;
            height: 200%;
            background: radial-gradient(circle, rgba(255,215,0,0.1) 0%, transparent 70%);
            animation: pulse 10s infinite linear;
        }
        
        @keyframes pulse {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .crown {
            font-size: 3em;
            color: var(--royal-gold);
            text-shadow: 0 0 20px var(--royal-gold);
            margin-bottom: 10px;
            animation: crownGlow 2s infinite alternate;
        }
        
        @keyframes crownGlow {
            0% { text-shadow: 0 0 10px var(--royal-gold); }
            100% { text-shadow: 0 0 30px var(--royal-gold), 0 0 40px var(--royal-gold); }
        }
        
        .title {
            color: var(--royal-gold);
            font-size: 3.5em;
            font-weight: bold;
            text-shadow: 0 0 20px rgba(255, 215, 0, 0.5);
            margin-bottom: 5px;
            letter-spacing: 2px;
        }
        
        .subtitle {
            color: var(--neon-cyan);
            font-size: 1.2em;
            margin-bottom: 30px;
            text-shadow: 0 0 10px var(--neon-cyan);
        }
        
        .port-display {
            background: linear-gradient(135deg, rgba(0, 255, 255, 0.1), rgba(255, 0, 255, 0.1));
            border: 3px solid var(--neon-cyan);
            border-radius: 15px;
            padding: 40px;
            margin: 40px 0;
            position: relative;
            overflow: hidden;
        }
        
        .port-display::before {
            content: '';
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.1), transparent);
            animation: shine 3s infinite;
        }
        
        @keyframes shine {
            0% { left: -100%; }
            100% { left: 100%; }
        }
        
        .port-label {
            color: var(--neon-cyan);
            font-size: 1.5em;
            margin-bottom: 15px;
            text-transform: uppercase;
            letter-spacing: 3px;
        }
        
        .port-number {
            color: var(--neon-green);
            font-size: 6em;
            font-weight: bold;
            text-shadow: 
                0 0 20px var(--neon-green),
                0 0 40px var(--neon-green);
            margin: 20px 0;
            font-family: 'Monaco', 'Consolas', monospace;
            animation: portGlow 1.5s infinite alternate;
        }
        
        @keyframes portGlow {
            0% { 
                text-shadow: 0 0 20px var(--neon-green), 0 0 40px var(--neon-green);
                transform: scale(1);
            }
            100% { 
                text-shadow: 0 0 30px var(--neon-green), 0 0 60px var(--neon-green), 0 0 90px var(--neon-green);
                transform: scale(1.02);
            }
        }
        
        .timer-container {
            background: rgba(0, 0, 0, 0.5);
            border: 2px solid var(--neon-pink);
            border-radius: 10px;
            padding: 20px;
            margin: 30px 0;
        }
        
        .timer {
            color: var(--neon-pink);
            font-size: 2em;
            font-weight: bold;
            text-shadow: 0 0 10px var(--neon-pink);
        }
        
        .github-section {
            margin: 40px 0;
            padding: 25px;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 15px;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .github-title {
            color: #fff;
            font-size: 1.3em;
            margin-bottom: 15px;
        }
        
        .github-link {
            color: var(--neon-cyan);
            font-size: 1.1em;
            text-decoration: none;
            display: inline-block;
            padding: 10px 20px;
            border: 2px solid var(--neon-cyan);
            border-radius: 50px;
            transition: all 0.3s;
            margin: 10px;
        }
        
        .github-link:hover {
            background: var(--neon-cyan);
            color: #000;
            box-shadow: 0 0 20px var(--neon-cyan);
        }
        
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 40px 0;
        }
        
        .stat {
            background: rgba(255, 255, 255, 0.05);
            padding: 20px;
            border-radius: 10px;
            border: 1px solid rgba(255, 215, 0, 0.2);
        }
        
        .stat i {
            font-size: 2em;
            margin-bottom: 10px;
            color: var(--royal-gold);
        }
        
        .footer {
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid rgba(255, 215, 0, 0.2);
            color: #666;
            font-size: 0.8em;
        }
        
        .author {
            color: var(--royal-gold);
            font-weight: bold;
        }
        
        /* Responsive */
        @media (max-width: 768px) {
            .royal-container { padding: 20px; }
            .title { font-size: 2.5em; }
            .port-number { font-size: 4em; }
            .timer { font-size: 1.5em; }
            .stats { grid-template-columns: 1fr; }
        }
    </style>
</head>
<body>
    <div class="royal-container">
        <div class="crown">👑</div>
        <h1 class="title">OMARCHY</h1>
        <p class="subtitle">The Sovereign Port Rotation System</p>
        
        <div class="port-display">
            <div class="port-label">Current Royal Port</div>
            <div class="port-number" id="port">${port}</div>
            <p style="color: #aaa;">Auto-rotates every ${INTERVAL} seconds</p>
        </div>
        
        <div class="timer-container">
            <div class="timer">
                ⏰ Next rotation in: <span id="countdown">${INTERVAL}</span> seconds
            </div>
        </div>
        
        <div class="stats">
            <div class="stat">
                <i class="fas fa-shield-alt"></i>
                <h3>Security</h3>
                <p>Zero pattern detection</p>
            </div>
            <div class="stat">
                <i class="fas fa-bolt"></i>
                <h3>Speed</h3>
                <p>Instant port rotation</p>
            </div>
            <div class="stat">
                <i class="fas fa-user-secret"></i>
                <h3>Stealth</h3>
                <p>Complete anonymity</p>
            </div>
            <div class="stat">
                <i class="fas fa-crown"></i>
                <h3>Sovereignty</h3>
                <p>Full network control</p>
            </div>
        </div>
        
        <div class="github-section">
            <div class="github-title">
                <i class="fab fa-github"></i> GitHub Repository
            </div>
            <a href="${OMARCHY_GITHUB}" target="_blank" class="github-link">
                ${OMARCHY_GITHUB}
            </a>
            <div style="margin-top: 15px; color: #aaa;">
                <i class="fas fa-star"></i> Star • 
                <i class="fas fa-code-branch"></i> Fork • 
                <i class="fas fa-exclamation-circle"></i> Issues • 
                <i class="fas fa-book"></i> Wiki
            </div>
        </div>
        
        <div class="footer">
            <p>© $(date +%Y) OMARCHY v${OMARCHY_VERSION} | Created by <span class="author">${OMARCHY_AUTHOR}</span></p>
            <p>GitHub: <a href="${OMARCHY_GITHUB}" style="color: #666;">${OMARCHY_GITHUB}</a></p>
        </div>
    </div>
    
    <script>
        // Countdown timer
        let timeLeft = ${INTERVAL};
        const countdownEl = document.getElementById('countdown');
        const portEl = document.getElementById('port');
        
        const timer = setInterval(() => {
            timeLeft--;
            if (timeLeft <= 0) {
                timeLeft = ${INTERVAL};
                // Auto-refresh when rotation happens
                setTimeout(() => {
                    location.reload();
                }, 1000);
            }
            countdownEl.textContent = timeLeft;
        }, 1000);
        
        // Port number animation
        let glowState = 0;
        setInterval(() => {
            glowState = (glowState + 1) % 3;
            const colors = ['#00ff00', '#00ffff', '#ff00ff'];
            const glows = [
                '0 0 20px #00ff00, 0 0 40px #00ff00',
                '0 0 20px #00ffff, 0 0 40px #00ffff',
                '0 0 20px #ff00ff, 0 0 40px #ff00ff'
            ];
            portEl.style.color = colors[glowState];
            portEl.style.textShadow = glows[glowState];
        }, 2000);
        
        // GitHub link enhancement
        document.querySelectorAll('.github-link').forEach(link => {
            link.addEventListener('mouseenter', () => {
                link.innerHTML = '<i class="fab fa-github"></i> ' + link.innerHTML;
            });
            link.addEventListener('mouseleave', () => {
                link.innerHTML = link.innerHTML.replace('<i class="fab fa-github"></i> ', '');
            });
        });
        
        // Real-time clock
        function updateClock() {
            const now = new Date();
            document.querySelectorAll('.timer').forEach(el => {
                if (el.id !== 'countdown') {
                    el.innerHTML = '🕐 ' + now.toLocaleTimeString();
                }
            });
        }
        setInterval(updateClock, 1000);
        updateClock();
    </script>
</body>
</html>
HTML
}

start_web_server() {
    local port="$1"
    
    log_info "Starting web server on ${BIND_IP}:${port}"
    
    # Stop existing server
    stop_web_server
    
    # Generate HTML
    generate_html "${port}"
    
    # Try different server methods
    if command -v python3 &>/dev/null; then
        cd "${WEB_DIR}"
        python3 -m http.server "${port}" --bind "${BIND_IP}" >/dev/null 2>&1 &
        echo $! > "${PID_DIR}/web.pid"
        log_success "Python web server started (PID: $!)"
        return 0
    fi
    
    if command -v python &>/dev/null; then
        cd "${WEB_DIR}"
        python -m SimpleHTTPServer "${port}" >/dev/null 2>&1 &
        echo $! > "${PID_DIR}/web.pid"
        log_success "Python 2 web server started (PID: $!)"
        return 0
    fi
    
    log_error "Python not found. Cannot start web server."
    return 1
}

stop_web_server() {
    if [[ -f "${PID_DIR}/web.pid" ]]; then
        local pid
        pid=$(cat "${PID_DIR}/web.pid" 2>/dev/null)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null && log_info "Stopped web server (PID: ${pid})"
        fi
        rm -f "${PID_DIR}/web.pid"
    fi
}

# ===================================================================
# ROTATION ENGINE
# ===================================================================

rotate_port() {
    log_info "Executing royal port rotation..."
    
    local old_port
    old_port=$(get_current_port)
    local new_port
    new_port=$(get_random_port)
    
    # Save new port
    echo "${new_port}" > "${PORTS_DIR}/current.txt"
    echo "${new_port}" >> "${PORTS_DIR}/history.txt"
    
    # Keep only last 50 ports
    tail -n 50 "${PORTS_DIR}/history.txt" > "${PORTS_DIR}/history.tmp" 2>/dev/null
    mv "${PORTS_DIR}/history.tmp" "${PORTS_DIR}/history.txt" 2>/dev/null
    
    # Log rotation
    if [[ "${ENABLE_LOGGING}" == "true" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') | ${old_port:-NONE} → ${new_port}" >> "${LOGS_DIR}/rotations.log"
    fi
    
    # Update web server
    start_web_server "${new_port}"
    
    echo "${new_port}"
}

# ===================================================================
# DAEMON MANAGEMENT
# ===================================================================

start_daemon() {
    log_info "Starting rotation daemon (interval: ${INTERVAL}s)"
    
    # Stop existing daemon
    stop_daemon
    
    # Create daemon script
    cat > "${PID_DIR}/daemon.sh" << 'DAEMON_SCRIPT'
#!/bin/bash
# OMARCHY Rotation Daemon

set -euo pipefail

INTERVAL="$1"
LOG_FILE="$2"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Daemon started (interval: ${INTERVAL}s)" >> "${LOG_FILE}"

trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] Daemon stopped" >> "${LOG_FILE}"; exit 0' TERM INT

while true; do
    sleep "${INTERVAL}"
    ~/omarchy.sh rotate --silent >> "${LOG_FILE}" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Rotation completed" >> "${LOG_FILE}"
done
DAEMON_SCRIPT
    
    chmod +x "${PID_DIR}/daemon.sh"
    
    # Start daemon
    nohup "${PID_DIR}/daemon.sh" "${INTERVAL}" "${LOGS_DIR}/daemon.log" >> "${LOGS_DIR}/daemon.log" 2>&1 &
    echo $! > "${PID_DIR}/daemon.pid"
    
    log_success "Daemon started (PID: $!)"
}

stop_daemon() {
    if [[ -f "${PID_DIR}/daemon.pid" ]]; then
        local pid
        pid=$(cat "${PID_DIR}/daemon.pid" 2>/dev/null)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            kill "${pid}" 2>/dev/null && log_info "Stopped daemon (PID: ${pid})"
        fi
        rm -f "${PID_DIR}/daemon.pid" "${PID_DIR}/daemon.sh"
    fi
}

# ===================================================================
# STATUS & MONITORING
# ===================================================================

show_status() {
    show_banner
    
    local current_port
    current_port=$(get_current_port)
    local rotations=0
    local daemon_status="INACTIVE"
    local web_status="STOPPED"
    
    # Get rotation count
    if [[ -f "${LOGS_DIR}/rotations.log" ]]; then
        rotations=$(wc -l < "${LOGS_DIR}/rotations.log" 2>/dev/null || echo 0)
    fi
    
    # Check daemon
    if [[ -f "${PID_DIR}/daemon.pid" ]]; then
        local daemon_pid
        daemon_pid=$(cat "${PID_DIR}/daemon.pid" 2>/dev/null)
        if [[ -n "${daemon_pid}" ]] && kill -0 "${daemon_pid}" 2>/dev/null; then
            daemon_status="ACTIVE (PID: ${daemon_pid})"
        fi
    fi
    
    # Check web server
    if [[ -f "${PID_DIR}/web.pid" ]]; then
        local web_pid
        web_pid=$(cat "${PID_DIR}/web.pid" 2>/dev/null)
        if [[ -n "${web_pid}" ]] && kill -0 "${web_pid}" 2>/dev/null; then
            if timeout 1 bash -c "echo > /dev/tcp/${BIND_IP}/${current_port}" 2>/dev/null; then
                web_status="RUNNING on ${BIND_IP}:${current_port}"
            else
                web_status="DEAD (PID: ${web_pid})"
            fi
        fi
    fi
    
    echo -e "${BOLD}${CYAN}📊 ROYAL STATUS REPORT${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    
    echo -e "  ${BOLD}👑 Current Port:${NC} ${GREEN}${current_port:-Not set}${NC}"
    echo -e "  ${BOLD}🔄 Rotation Daemon:${NC} ${YELLOW}${daemon_status}${NC}"
    echo -e "  ${BOLD}🌐 Web Server:${NC} ${YELLOW}${web_status}${NC}"
    echo -e "  ${BOLD}📊 Total Rotations:${NC} ${CYAN}${rotations}${NC}"
    echo -e "  ${BOLD}⏰ Rotation Interval:${NC} ${MAGENTA}${INTERVAL}s${NC}"
    echo -e "  ${BOLD}🎯 Port Range:${NC} ${WHITE}${MIN_PORT}-${MAX_PORT}${NC}"
    
    # Recent ports
    if [[ -f "${PORTS_DIR}/history.txt" ]]; then
        echo -e "\n  ${BOLD}📜 Recent Ports:${NC}"
        tail -5 "${PORTS_DIR}/history.txt" | while read -r port; do
            echo -e "    → ${port}"
        done
    fi
    
    # Access info
    if [[ -n "${current_port}" ]]; then
        echo -e "\n  ${BOLD}🔗 Access URLs:${NC}"
        echo -e "    ${BLUE}Local:${NC}    http://${BIND_IP}:${current_port}"
        echo -e "    ${BLUE}Network:${NC}  http://$(hostname -I 2>/dev/null | awk '{print $1}'):${current_port}"
        echo -e "    ${BLUE}Test:${NC}     curl -s http://${BIND_IP}:${current_port} | grep -o '[0-9]\\{5,\\}'"
    fi
    
    # Next rotation
    if [[ -f "${PID_DIR}/daemon.pid" ]] && [[ -n "${current_port}" ]]; then
        echo -e "\n  ${BOLD}⏳ Next Rotation:${NC} In $((INTERVAL - ($(date +%s) % INTERVAL)))s"
    fi
    
    show_github
}

# ===================================================================
# COMMAND HANDLERS
# ===================================================================

cmd_install() {
    show_banner
    echo -e "${YELLOW}${BOLD}🚀 Installing OMARCHY v${OMARCHY_VERSION}${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    
    # Check dependencies
    check_deps "python3" "curl" "git" || die "Missing required dependencies"
    
    # Check if already installed
    if [[ -d "${OMARCHY_DIR}" ]]; then
        log_warning "OMARCHY already installed at ${OMARCHY_DIR}"
        read -p "Reinstall? (y/N): " choice
        if [[ ! "${choice}" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 0
        fi
        cmd_stop
        rm -rf "${OMARCHY_DIR}"
    fi
    
    # Create directories
    log_info "Creating directory structure..."
    mkdir -p "${OMARCHY_DIR}" "${PORTS_DIR}" "${LOGS_DIR}" "${WEB_DIR}" "${PID_DIR}"
    
    # Save default config
    load_config
    save_config
    
    # Perform initial rotation
    log_info "Generating initial port..."
    local initial_port
    initial_port=$(rotate_port)
    
    # Start daemon
    start_daemon
    
    # Show success
    echo -e "\n${GREEN}${BOLD}✅ OMARCHY INSTALLATION COMPLETE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    show_status
    
    echo -e "\n${BOLD}📋 Quick Commands:${NC}"
    echo -e "  ${BLUE}./omarchy.sh status${NC}    - Show system status"
    echo -e "  ${BLUE}./omarchy.sh rotate${NC}    - Manual rotation"
    echo -e "  ${BLUE}./omarchy.sh monitor${NC}   - Real-time monitoring"
    echo -e "  ${BLUE}./omarchy.sh test${NC}      - Test web interface"
    echo -e "  ${BLUE}./omarchy.sh uninstall${NC} - Remove OMARCHY"
    
    show_github
}

cmd_start() {
    load_config
    
    # Check if already running
    if [[ -f "${PID_DIR}/daemon.pid" ]]; then
        local pid
        pid=$(cat "${PID_DIR}/daemon.pid" 2>/dev/null)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            log_warning "OMARCHY is already running (PID: ${pid})"
            show_status
            return 0
        fi
    fi
    
    log_info "Starting OMARCHY system..."
    
    # Ensure directories exist
    mkdir -p "${OMARCHY_DIR}" "${PORTS_DIR}" "${LOGS_DIR}" "${WEB_DIR}" "${PID_DIR}"
    
    # Get or create port
    local port
    port=$(get_current_port)
    if [[ -z "${port}" ]]; then
        port=$(rotate_port)
    else
        start_web_server "${port}"
    fi
    
    # Start daemon
    start_daemon
    
    log_success "OMARCHY started successfully"
    show_status
}

cmd_stop() {
    log_info "Stopping OMARCHY system..."
    
    stop_daemon
    stop_web_server
    
    # Clean PID files
    rm -f "${PID_DIR}"/*.pid
    
    log_success "OMARCHY stopped"
}

cmd_restart() {
    cmd_stop
    sleep 2
    cmd_start
}

cmd_rotate() {
    local silent=""
    
    # Check for silent flag
    if [[ "${1:-}" == "--silent" ]]; then
        silent="true"
    fi
    
    load_config
    
    if [[ -z "${silent}" ]]; then
        show_banner
    fi
    
    local new_port
    new_port=$(rotate_port)
    
    if [[ -z "${silent}" ]]; then
        echo -e "${GREEN}✅ New Royal Port: ${new_port}${NC}"
        echo -e "${BLUE}🌐 Access: http://${BIND_IP}:${new_port}${NC}"
    else
        echo "${new_port}"
    fi
}

cmd_test() {
    load_config
    
    local port
    port=$(get_current_port)
    
    if [[ -z "${port}" ]]; then
        log_error "No port configured. Run 'omarchy start' first."
        return 1
    fi
    
    show_banner
    echo -e "${CYAN}🔍 Testing OMARCHY Web Interface${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    echo -e "Port: ${port}"
    echo -e "URL: http://${BIND_IP}:${port}"
    echo ""
    
    # Test connection
    if timeout 3 curl -s "http://${BIND_IP}:${port}" >/tmp/omarchy_test.html 2>&1; then
        echo -e "${GREEN}✅ Web server is responding${NC}"
        
        # Check GitHub link
        if grep -q "${OMARCHY_GITHUB}" /tmp/omarchy_test.html; then
            echo -e "${GREEN}✅ GitHub link found${NC}"
        else
            echo -e "${YELLOW}⚠️  GitHub link not found in HTML${NC}"
        fi
        
        # Extract port
        local html_port
        html_port=$(grep -o 'port-number[^>]*>[0-9]*' /tmp/omarchy_test.html 2>/dev/null | grep -o '[0-9]*$')
        if [[ -n "${html_port}" ]]; then
            echo -e "${GREEN}✅ Port in HTML: ${html_port}${NC}"
            if [[ "${html_port}" == "${port}" ]]; then
                echo -e "${GREEN}✅ Ports match${NC}"
            else
                echo -e "${YELLOW}⚠️  Port mismatch${NC}"
            fi
        fi
        
        # Show preview
        echo -e "\n${BLUE}📄 HTML Preview (first 5 lines):${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        head -5 /tmp/omarchy_test.html | sed 's/</\&lt;/g; s/>/\&gt;/g'
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        return 0
    else
        echo -e "${RED}❌ Web server not responding${NC}"
        
        # Check if server is running
        if [[ -f "${PID_DIR}/web.pid" ]]; then
            local pid
            pid=$(cat "${PID_DIR}/web.pid" 2>/dev/null)
            if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
                echo -e "${YELLOW}⚠️  Server process ${pid} is running but not responding${NC}"
            else
                echo -e "${RED}⚠️  Server process is dead${NC}"
            fi
        else
            echo -e "${RED}⚠️  No server process found${NC}"
        fi
        
        return 1
    fi
}

cmd_monitor() {
    load_config
    
    show_banner
    echo -e "${CYAN}${BOLD}👁️  REAL-TIME MONITOR${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}\n"
    
    trap 'echo -e "\n${GREEN}Monitor stopped.${NC}"; exit 0' INT
    
    local last_port=""
    local rotation_count=0
    
    while true; do
        clear
        show_banner
        echo -e "${CYAN}${BOLD}👁️  REAL-TIME MONITOR${NC}"
        echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
        
        local current_port
        current_port=$(get_current_port)
        
        # Detect rotation
        if [[ -n "${last_port}" ]] && [[ "${current_port}" != "${last_port}" ]]; then
            ((rotation_count++))
            echo -e "${MAGENTA}🔄 ROTATION #${rotation_count}: ${last_port} → ${current_port}${NC}"
            echo ""
        fi
        
        last_port="${current_port}"
        
        # Display info
        echo -e "${BOLD}Current Port:${NC} ${GREEN}${current_port}${NC}"
        echo -e "${BOLD}Rotations:${NC} ${CYAN}${rotation_count}${NC}"
        
        # Calculate next rotation
        local next_in=$((INTERVAL - ($(date +%s) % INTERVAL)))
        echo -e "${BOLD}Next Rotation:${NC} ${YELLOW}In ${next_in}s${NC}"
        
        # Show recent activity
        echo -e "\n${BOLD}Recent Activity:${NC}"
        if [[ -f "${LOGS_DIR}/daemon.log" ]]; then
            tail -5 "${LOGS_DIR}/daemon.log" | sed 's/^/  /'
        else
            echo "  No activity yet"
        fi
        
        echo -e "\n${GRAY}[Refreshing every 5 seconds]${NC}"
        sleep 5
    done
}

cmd_config() {
    load_config
    
    show_banner
    echo -e "${CYAN}${BOLD}⚙️  CONFIGURATION${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    
    echo -e "${BOLD}Current Settings:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    grep -v "^#" "${CONFIG_FILE}" | sed 's/^/  /'
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo -e "\n${YELLOW}To modify configuration:${NC}"
    echo "  1. Edit: ${CONFIG_FILE}"
    echo "  2. Restart: ./omarchy.sh restart"
    
    echo -e "\n${BOLD}Config Path:${NC} ${CONFIG_FILE}"
}

cmd_logs() {
    show_banner
    echo -e "${CYAN}${BOLD}📋 SYSTEM LOGS${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    
    if [[ ! -d "${LOGS_DIR}" ]]; then
        echo "No logs directory found."
        return
    fi
    
    local log_files=(${LOGS_DIR}/*.log)
    
    if [[ ${#log_files[@]} -eq 0 ]]; then
        echo "No log files found."
        return
    fi
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "${log_file}" ]]; then
            echo -e "\n${BOLD}📄 $(basename "${log_file}"):${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            tail -20 "${log_file}" 2>/dev/null || echo "  (empty or unreadable)"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        fi
    done
    
    echo -e "\n${YELLOW}Log Directory:${NC} ${LOGS_DIR}"
}

cmd_uninstall() {
    show_banner
    
    echo -e "${RED}${BOLD}⚠️  UNINSTALL OMARCHY ⚠️${NC}"
    echo -e "${YELLOW}This will permanently remove OMARCHY and all its data.${NC}"
    echo -e "${YELLOW}All configuration, logs, and history will be deleted.${NC}\n"
    
    # Show current status
    if [[ -d "${OMARCHY_DIR}" ]]; then
        echo -e "${BOLD}Data to be removed:${NC}"
        echo "  ${OMARCHY_DIR}/"
        echo "  Total size: $(du -sh "${OMARCHY_DIR}" 2>/dev/null | cut -f1)"
    fi
    
    echo -e "\n${RED}THIS ACTION CANNOT BE UNDONE!${NC}\n"
    
    read -p "Type 'UNINSTALL' to confirm: " confirm
    if [[ "${confirm}" != "UNINSTALL" ]]; then
        echo -e "${GREEN}Uninstall cancelled.${NC}"
        exit 0
    fi
    
    # Stop services
    cmd_stop 2>/dev/null || true
    
    # Remove directory
    if [[ -d "${OMARCHY_DIR}" ]]; then
        rm -rf "${OMARCHY_DIR}"
        echo -e "${GREEN}✓ Removed ${OMARCHY_DIR}${NC}"
    fi
    
    # Remove script from PATH if installed globally
    if [[ -f "/usr/local/bin/omarchy" ]]; then
        sudo rm -f /usr/local/bin/omarchy
        echo -e "${GREEN}✓ Removed global binary${NC}"
    fi
    
    # Remove systemd service if exists
    if [[ -f "/etc/systemd/system/omarchy.service" ]]; then
        sudo systemctl stop omarchy.service 2>/dev/null || true
        sudo systemctl disable omarchy.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/omarchy.service
        sudo systemctl daemon-reload
        echo -e "${GREEN}✓ Removed systemd service${NC}"
    fi
    
    echo -e "\n${GREEN}✅ OMARCHY has been completely uninstalled.${NC}"
    echo -e "${YELLOW}Thank you for using OMARCHY!${NC}"
}

cmd_version() {
    show_banner
    echo -e "${CYAN}${BOLD}📦 OMARCHY v${OMARCHY_VERSION}${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Author:${NC}      ${OMARCHY_AUTHOR}"
    echo -e "${BOLD}GitHub:${NC}      ${OMARCHY_GITHUB}"
    echo -e "${BOLD}Issues:${NC}      ${OMARCHY_ISSUES}"
    echo -e "${BOLD}Wiki:${NC}        ${OMARCHY_WIKI}"
    echo -e "${BOLD}License:${NC}     MIT"
    echo -e "${BOLD}Platform:${NC}    Linux/Unix"
    
    show_github
}

cmd_help() {
    show_banner
    
    echo -e "${CYAN}${BOLD}📖 OMARCHY COMMAND REFERENCE${NC}"
    echo -e "${WHITE}══════════════════════════════════════════════════════════${NC}"
    
    echo -e "\n${BOLD}🚀 Installation:${NC}"
    echo -e "  ${BLUE}install${NC}     - Full installation with daemon"
    echo -e "  ${BLUE}start${NC}       - Start all services"
    echo -e "  ${BLUE}stop${NC}        - Stop all services"
    echo -e "  ${BLUE}restart${NC}     - Restart services"
    echo -e "  ${BLUE}uninstall${NC}   - Remove OMARCHY completely"
    
    echo -e "\n${BOLD}🔄 Port Management:${NC}"
    echo -e "  ${BLUE}rotate${NC}      - Manual port rotation"
    echo -e "  ${BLUE}status${NC}      - Show current status"
    echo -e "  ${BLUE}config${NC}      - Show configuration"
    
    echo -e "\n${BOLD}🔍 Monitoring:${NC}"
    echo -e "  ${BLUE}monitor${NC}     - Real-time monitoring"
    echo -e "  ${BLUE}test${NC}        - Test web interface"
    echo -e "  ${BLUE}logs${NC}        - View system logs"
    
    echo -e "\n${BOLD}📚 Information:${NC}"
    echo -e "  ${BLUE}version${NC}     - Show version info"
    echo -e "  ${BLUE}help${NC}        - Show this help"
    
    show_github
    
    echo -e "\n${BOLD}📝 Examples:${NC}"
    echo -e "  ${WHITE}./omarchy.sh install${NC}    # First-time setup"
    echo -e "  ${WHITE}./omarchy.sh status${NC}     # Check system status"
    echo -e "  ${WHITE}./omarchy.sh monitor${NC}    # Real-time monitoring"
    echo -e "  ${WHITE}./omarchy.sh test${NC}       # Test web server"
    
    echo -e "\n${GRAY}Need help? Visit: ${OMARCHY_WIKI}${NC}"
}

# ===================================================================
# MAIN DISPATCHER
# ===================================================================

main() {
    local command="${1:-help}"
    
    case "${command}" in
        install|setup)
            cmd_install
            ;;
        start)
            cmd_start
            ;;
        stop)
            cmd_stop
            ;;
        restart)
            cmd_restart
            ;;
        rotate)
            cmd_rotate "$2"
            ;;
        status|info)
            show_status
            ;;
        test)
            cmd_test
            ;;
        monitor)
            cmd_monitor
            ;;
        config)
            cmd_config
            ;;
        logs)
            cmd_logs
            ;;
        uninstall|remove)
            cmd_uninstall
            ;;
        version|--version|-v)
            cmd_version
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            echo -e "${RED}Unknown command: ${command}${NC}"
            echo -e "Use ${BLUE}./omarchy.sh help${NC} for available commands."
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
OMARCHY_EOF
