#!/usr/bin/env bash
###############################################################################
# ARGOS - NETWORK MODULE
# Version: 2.4.1 (Merged Configuration)
# Author: Z3E
###############################################################################

# Strict mode and error handling
set -euo pipefail

# Trap for cleanup and error handling
trap cleanup EXIT
trap 'echo -e "${RED}[-] Error at line $LINENO${RESET}"; cleanup' ERR

# Configuration
initialize_colors() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}[-] Run as root!${RESET}"
        exit 1
    fi
}

# Global Variables
LOOT_DIR="./loot/network/$(date +%Y%m%d)"
REPORTS_DIR="$LOOT_DIR/reports"
SCANS_DIR="$LOOT_DIR/scans"
LOGS_DIR="$LOOT_DIR/logs"
TMP_DIR="/tmp/argos_$(date +%s)"
export NMAPDIR="$TMP_DIR/nmap"

TARGET=${1:-}
INTERFACE=""
NETWORK_RANGE=""

# Initialize environment
init_directories() {
    mkdir -p "$LOOT_DIR" "$REPORTS_DIR" "$SCANS_DIR" "$LOGS_DIR" "$TMP_DIR" "$NMAPDIR"
}

# Cleanup function
cleanup() {
    echo -e "${CYAN}[*] Cleaning up...${RESET}"
    rm -rf "$TMP_CONF" "$TMP_DIR"
    echo -e "${GREEN}[✓] Cleanup complete${RESET}"
    exit
}

# Load additional configurations if needed
load_config() {
    # Example: source additional config files
    # source "$(dirname "$0")/../lib/argos_lib.sh"
    :
}

# Auto-detect network configuration
detect_network() {
    DEFAULT_IFACE=$(ip route | awk '/default/ {print $5}')
    if [ -z "$DEFAULT_IFACE" ]; then
        echo -e "${RED}[-] No network interface found!${RESET}"
        exit 1
    fi

    IP_CIDR=$(ip -o -f inet addr show "$DEFAULT_IFACE" | awk '{print $4}')
    GATEWAY=$(ip route | awk '/default/ {print $3}')
    
    echo -e "${CYAN}[*] Detected Network Configuration:${RESET}"
    echo -e "Interface: ${YELLOW}$DEFAULT_IFACE${RESET}"
    echo -e "IP/CIDR: ${YELLOW}$IP_CIDR${RESET}"
    echo -e "Gateway: ${YELLOW}$GATEWAY${RESET}"
    
    read -rp "Confirm configuration [Y/n]? " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        manual_config
    else
        TARGET="$IP_CIDR"
        INTERFACE="$DEFAULT_IFACE"
    fi
}

manual_config() {
    echo -e "\n${CYAN}[*] Available Network Interfaces:${RESET}"
    mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}')
    for i in "${!interfaces[@]}"; do 
        echo "  $((i+1)). ${interfaces[$i]}"
    done
    
    while true; do
        read -rp "${YELLOW}Select interface (1-${#interfaces[@]}): ${RESET}" choice
        if [[ $choice =~ ^[1-9][0-9]*$ ]] && ((choice >= 1 && choice <= ${#interfaces[@]})); then
            INTERFACE="${interfaces[$((choice-1))]}"
            break
        else
            echo -e "${RED}[-] Invalid selection!${RESET}"
        fi
    done
    
    read -rp "${YELLOW}Enter target IP/CIDR or hostname: ${RESET}" TARGET
    if [[ -z "$TARGET" ]]; then
        echo -e "${RED}[-] Target is required!${RESET}"
        exit 1
    fi
}

# Temporary configuration setup
setup_temp_config() {
    TMP_CONF="$TMP_DIR/argos.conf"
    cat > "$TMP_CONF" << EOF
# ARGOS TEMP CONFIG
target=$TARGET
interface=$INTERFACE
nmap_timing=T4
EOF
    export CONFIG_FILE="$TMP_CONF"
}

# Network Scan Function
network_scan() {
    echo -e "${GREEN}[+] Starting network scan on ${CYAN}$INTERFACE${GREEN} targeting ${CYAN}$TARGET${RESET}"
    nmap -e "$INTERFACE" -sn "$TARGET" -oN "$SCANS_DIR/scan_results.txt"
    cat "$SCANS_DIR/scan_results.txt"
}

# Vulnerability Check Function
vulnerability_check() {
    echo -e "${GREEN}[+] Running vulnerability checks${RESET}"
    nmap -e "$INTERFACE" --script vuln "$TARGET" -oN "$SCANS_DIR/vuln_scan.txt"
    cat "$SCANS_DIR/vuln_scan.txt"
}

# Generate Report Function
generate_report() {
    echo -e "${GREEN}[+] Generating final report${RESET}"
    tar czf "$LOOT_DIR/network_scan_$(date +%s).tar.gz" -C "$SCANS_DIR" .
    echo -e "${GREEN}[✓] Report generated at $LOOT_DIR/network_scan_$(date +%s).tar.gz${RESET}"
}

# Dynamic target selection
get_target() {
    if [ -n "$TARGET" ]; then
        echo -e "${YELLOW}[!] Using target from command line: $TARGET${RESET}"
        return
    fi
    
    # Placeholder for loading target from config
    # if [ -n "${target:-}" ]; then
    #     TARGET=$target
    #     echo -e "${YELLOW}[!] Using target from config: $TARGET${RESET}"
    #     return
    # fi
    
    echo -e "${RED}[!] Target not specified${RESET}"
    read -rp "${CYAN}Enter target (IP/CIDR or hostname): ${RESET}" TARGET
    if [[ -z "$TARGET" ]]; then
        echo -e "${RED}[-] Target is required!${RESET}"
        exit 1
    fi
}

# Interface selection menu
select_interface() {
    mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}')
    
    echo -e "\n${CYAN}[*] Available Network Interfaces:${RESET}"
    for i in "${!interfaces[@]}"; do 
        echo "  $((i+1)). ${interfaces[$i]}"
    done
    
    while true; do
        read -rp "${YELLOW}Select interface (1-${#interfaces[@]}): ${RESET}" choice
        if [[ $choice =~ ^[1-9][0-9]*$ ]] && ((choice >= 1 && choice <= ${#interfaces[@]})); then
            INTERFACE="${interfaces[$((choice-1))]}"
            echo -e "${GREEN}[+] Selected interface: $INTERFACE${RESET}"
            break
        else
            echo -e "${RED}[-] Invalid selection!${RESET}"
        fi
    done
}

# Validate target format
validate_target() {
    # IP/CIDR validation
    if [[ "$TARGET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]]; then
        NETWORK_RANGE="$TARGET"
        return
    fi
    
    # Domain validation
    if [[ "$TARGET" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
        NETWORK_RANGE=$(dig +short "$TARGET" | head -n1)
        if [[ -z "$NETWORK_RANGE" ]]; then
            echo -e "${RED}[-] Cannot resolve domain: $TARGET${RESET}"
            exit 1
        fi
        return
    fi
    
    echo -e "${RED}[-] Invalid target format: $TARGET${RESET}"
    exit 1
}

# Network discovery module
network_discovery() {
    echo -e "${GREEN}[+] Starting Network Discovery on $INTERFACE${RESET}"
    
    # Get network range from interface if not specified
    if [[ -z "$NETWORK_RANGE" ]]; then
        NETWORK_RANGE=$(ip -o -f inet addr show "$INTERFACE" | awk '{print $4}')
        if [[ -z "$NETWORK_RANGE" ]]; then
            echo -e "${RED}[-] Network information not found for interface $INTERFACE!${RESET}"
            exit 1
        fi
    fi

    # Passive discovery with netdiscover
    if command -v netdiscover &>/dev/null; then
        echo -e "${CYAN}[*] Running Netdiscover (passive)...${RESET}"
        netdiscover -p -P -r "$NETWORK_RANGE" -i "$INTERFACE" | tee "$SCANS_DIR/netdiscover.txt"
    else
        echo -e "${YELLOW}[!] Netdiscover not installed, skipping passive discovery.${RESET}"
    fi
    
    # ARP scan
    echo -e "${CYAN}[*] Running ARP scan...${RESET}"
    arp-scan --localnet --interface="$INTERFACE" | tee "$SCANS_DIR/arp_scan.txt"
    
    # Enhanced ping sweep
    echo -e "${CYAN}[*] Conducting ICMP discovery...${RESET}"
    nmap -e "$INTERFACE" -sn -PE -PP -PM -oX "$SCANS_DIR/icmp_discovery.xml" "$NETWORK_RANGE" | tee "$LOGS_DIR/icmp_discovery.log"
}

# Port scanning module
port_scanning() {
    echo -e "${GREEN}[+] Comprehensive Port Scanning for $TARGET${RESET}"
    
    # Quick scan with RustScan
    if command -v rustscan &>/dev/null; then
        echo -e "${CYAN}[*] Initial Fast Scan with RustScan${RESET}"
        rustscan -a "$TARGET" -i "$INTERFACE" --ulimit 7000 -g | tee "$SCANS_DIR/rustscan.txt"
    else
        echo -e "${YELLOW}[!] RustScan not installed, skipping fast scan.${RESET}"
    fi
    
    # Full TCP scan with Nmap
    echo -e "${CYAN}[*] Deep TCP Port Scan${RESET}"
    nmap -e "$INTERFACE" -sS -p- -T4 --min-rate 10000 -v -oX "$SCANS_DIR/tcp_full.xml" "$TARGET" | tee "$LOGS_DIR/tcp_scan.log"
    
    # Service detection
    echo -e "${CYAN}[*] Service and Version Detection${RESET}"
    PORTS=$(extract_ports "$SCANS_DIR/tcp_full.xml")
    if [[ -n "$PORTS" ]]; then
        nmap -e "$INTERFACE" -sV -sC -O -A -T4 -p"$PORTS" -oX "$SCANS_DIR/service_scan.xml" "$TARGET" | tee "$LOGS_DIR/service_scan.log"
    else
        echo -e "${YELLOW}[!] No open ports found for service detection.${RESET}"
    fi
    
    # UDP top ports scan
    echo -e "${CYAN}[*] UDP Port Scan${RESET}"
    nmap -e "$INTERFACE" -sU --top-ports 100 -T4 -oX "$SCANS_DIR/udp_scan.xml" "$TARGET" | tee "$LOGS_DIR/udp_scan.log"
}

# Function to extract open ports from Nmap XML
extract_ports() {
    local xml_file="$1"
    grep -oP '(?<=portid=")\d+(?=")' "$xml_file" | paste -sd "," -
}

# Vulnerability assessment module
vulnerability_assessment() {
    echo -e "${GREEN}[+] Vulnerability Assessment for $TARGET${RESET}"
    
    # Nmap vulnerability scripts
    echo -e "${CYAN}[*] Running Nmap Vuln Scripts${RESET}"
    nmap -e "$INTERFACE" --script 'vuln and safe' -p"$(extract_ports "$SCANS_DIR/tcp_full.xml")" -oX "$SCANS_DIR/nmap_vuln.xml" "$TARGET" | tee "$LOGS_DIR/nmap_vuln.log"
    
    # Nuclei scanning
    if command -v nuclei &>/dev/null; then
        echo -e "${CYAN}[*] Running Nuclei Templates${RESET}"
        nuclei -u "http://$TARGET" -t ~/nuclei-templates/ -severity medium,high | tee "$SCANS_DIR/nuclei_scan.txt"
    else
        echo -e "${YELLOW}[!] Nuclei not installed, skipping nuclei scans.${RESET}"
    fi
}

# Wireless attack module
wireless_attacks() {
    echo -e "${GREEN}[+] Wireless Network Analysis on $INTERFACE${RESET}"
    
    # Check monitor mode
    if ! iwconfig "$INTERFACE" | grep -q "Mode:Monitor"; then
        echo -e "${YELLOW}[*] Enabling monitor mode on $INTERFACE${RESET}"
        airmon-ng check kill | tee "$LOGS_DIR/airmon.log"
        airmon-ng start "$INTERFACE" | tee -a "$LOGS_DIR/airmon.log"
        INTERFACE="${INTERFACE}mon"
    fi
    
    # Start monitoring
    echo -e "${CYAN}[*] Starting airodump-ng on $INTERFACE${RESET}"
    airodump-ng "$INTERFACE" -w "$SCANS_DIR/wifi_capture" | tee "$LOGS_DIR/wifi_monitor.log" &
    echo -e "${YELLOW}[!] airodump-ng running in background (PID: $!)${RESET}"
}

# Post-exploitation module
post_exploitation() {
    echo -e "${GREEN}[+] Post-Exploitation Actions${RESET}"
    
    # Credential spraying with Hydra
    if command -v hydra &>/dev/null && [ -d "$WORDLIST_DIR" ]; then
        echo -e "${CYAN}[*] SSH Credential Spraying${RESET}"
        hydra -L "$WORDLIST_DIR/users.txt" -P "$WORDLIST_DIR/passwords.txt" ssh://"$TARGET" -t 4 | tee "$SCANS_DIR/ssh_hydra.txt"
    else
        echo -e "${YELLOW}[!] Hydra not installed or WORDLIST_DIR not set, skipping credential spraying.${RESET}"
    fi
    
    # Network traffic capture
    echo -e "${CYAN}[*] Starting Packet Capture on $INTERFACE${RESET}"
    tshark -i "$INTERFACE" -a duration:300 -w "$LOOT_DIR/network_capture.pcap" 2>&1 | tee "$LOGS_DIR/packet_capture.log" &
    echo -e "${YELLOW}[!] Packet capture running in background (PID: $!)${RESET}"
}

# Reporting module
generate_reports() {
    echo -e "${GREEN}[+] Generating Consolidated Reports${RESET}"
    
    # Convert XML to HTML using xsltproc
    if command -v xsltproc &>/dev/null && [ -f "$SCANS_DIR/tcp_full.xml" ]; then
        xsltproc "$SCANS_DIR/tcp_full.xml" -o "$REPORTS_DIR/nmap_scan.html" | tee "$LOGS_DIR/report_gen.log"
    else
        echo -e "${YELLOW}[!] xsltproc not installed or tcp_full.xml not found, skipping XML to HTML conversion.${RESET}"
    fi
    
    # Generate summary report (assuming report_generator.py exists)
    if command -v python3 &>/dev/null && [ -f "$LIB_DIR/report_generator.py" ]; then
        python3 "$LIB_DIR/report_generator.py" --input "$SCANS_DIR" --output "$REPORTS_DIR" | tee -a "$LOGS_DIR/report_gen.log"
    else
        echo -e "${YELLOW}[!] Python3 or report_generator.py not found, skipping summary report generation.${RESET}"
    fi
}

# Full Network Audit
full_network_audit() {
    network_discovery
    port_scanning
    vulnerability_assessment
    echo -e "${GREEN}[✓] Network Audit Completed${RESET}"
}

# Targeted Vulnerability Scan
targeted_vuln_scan() {
    vulnerability_assessment
}

# Generate Reports
report_generation() {
    generate_reports
}

# Main menu
main_menu() {
    clear
    echo -e "${GREEN}=== ARGOS - NETWORK MODULE ===${RESET}"
    echo -e "Target: ${CYAN}$TARGET${RESET}"
    echo -e "Interface: ${CYAN}$INTERFACE${RESET}"
    echo -e "${CYAN}1. Full Network Audit"
    echo "2. Targeted Vulnerability Scan"
    echo "3. Wireless Attacks"
    echo "4. Post-Exploitation"
    echo "5. Generate Reports"
    echo "6. Exit"
    echo -e "${RESET}"
}

# Safe exit
safe_exit() {
    echo -e "${CYAN}[*] Cleaning up temporary files${RESET}"
    rm -rf "$TMP_DIR"
    echo -e "${GREEN}[✓] Analysis complete. Results stored in $LOOT_DIR${RESET}"
    exit 0
}

# Main execution flow
main() {
    initialize_colors
    check_root
    load_config
    init_directories
    detect_network
    setup_temp_config
    
    while true; do
        main_menu
        read -rp "Select option: " choice
        case "$choice" in
            1) full_network_audit ;;
            2) targeted_vuln_scan ;;
            3) wireless_attacks ;;
            4) post_exploitation ;;
            5) report_generation ;;
            6) safe_exit ;;
            *) echo -e "${RED}[-] Invalid option${RESET}";;
        esac
        read -rp "Press Enter to continue..."
    done
}

# Entry point
main
