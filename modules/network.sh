#!/usr/bin/env bash
###############################################################################
# ARGOS - Network 
# Version: 2.1
# Author: Z3E
###############################################################################

# Strict mode and error handling
set -euo pipefail
trap 'echo -e "${RED}[-] Error at line $LINENO${RESET}"; exit 1' ERR

# Configuration
source "$(dirname "$0")/../lib/argos_lib.sh"

initialize_colors
check_root
load_config

# Global Variables
LOOT_DIR="./loot/network/$(date +%Y%m%d)"
REPORTS_DIR="$LOOT_DIR/reports"
SCANS_DIR="$LOOT_DIR/scans"
LOGS_DIR="$LOOT_DIR/logs"
TMP_DIR="/tmp/argos_$(date +%s)"
export NMAPDIR="$TMP_DIR/nmap"

# Initialize environment
init_directories() {
    create_dir "$LOOT_DIR"
    create_dir "$REPORTS_DIR"
    create_dir "$SCANS_DIR"
    create_dir "$LOGS_DIR"
    create_dir "$TMP_DIR"
    create_dir "$NMAPDIR"
}

# Main menu
main_menu() {
    clear
    print_banner
    echo -e "${CYAN}MAIN MENU${RESET}"
    echo -e "1. Full Network Audit"
    echo -e "2. Targeted Vulnerability Scan"
    echo -e "3. Wireless Network Analysis"
    echo -e "4. Post-Exploitation Activities"
    echo -e "5. Generate Reports"
    echo -e "6. Exit"
}

# Network discovery module
network_discovery() {
    local target="$1"
    echo -e "${GREEN}[+] Starting Network Discovery${RESET}"
    
    # Passive discovery
    if command -v netdiscover &>/dev/null; then
        echo -e "${CYAN}[*] Running Netdiscover (passive)...${RESET}"
        sudo netdiscover -p -P -r "$target" -c 10 > "$SCANS_DIR/netdiscover.txt"
    fi
    
    # ARP scan
    echo -e "${CYAN}[*] Running ARP scan...${RESET}"
    sudo arp-scan --localnet --interface=eth0 > "$SCANS_DIR/arp_scan.txt"
    
    # Advanced ping sweep
    echo -e "${CYAN}[*] Conducting ICMP discovery...${RESET}"
    nmap -sn -PE -PP -PM -oX "$SCANS_DIR/icmp_discovery.xml" "$target"
}

# Port scanning module
port_scanning() {
    local target="$1"
    echo -e "${GREEN}[+] Comprehensive Port Scanning${RESET}"
    
    # Quick scan with RustScan
    if command -v rustscan &>/dev/null; then
        echo -e "${CYAN}[*] Initial Fast Scan with RustScan${RESET}"
        rustscan -a "$target" --ulimit 7000 -g | tee "$SCANS_DIR/rustscan.txt"
    fi
    
    # Full TCP scan with Nmap
    echo -e "${CYAN}[*] Deep TCP Port Scan${RESET}"
    nmap -sS -p- -T4 --min-rate 10000 -v -oX "$SCANS_DIR/tcp_full.xml" "$target"
    
    # Service detection
    echo -e "${CYAN}[*] Service and Version Detection${RESET}"
    nmap -sV -sC -O -A -T4 -p$(extract_ports "$SCANS_DIR/tcp_full.xml") \
        -oX "$SCANS_DIR/service_scan.xml" "$target"
    
    # UDP top ports scan
    echo -e "${CYAN}[*] UDP Port Scan${RESET}"
    nmap -sU --top-ports 100 -T4 -oX "$SCANS_DIR/udp_scan.xml" "$target"
}

# Vulnerability assessment module
vulnerability_assessment() {
    local target="$1"
    echo -e "${GREEN}[+] Vulnerability Assessment${RESET}"
    
    # Nmap vulnerability scripts
    echo -e "${CYAN}[*] Running Nmap Vuln Scripts${RESET}"
    nmap --script "vuln and safe" -p$(extract_ports "$SCANS_DIR/tcp_full.xml") \
        -oX "$SCANS_DIR/nmap_vuln.xml" "$target"
    
    # Nuclei scanning
    if command -v nuclei &>/dev/null; then
        echo -e "${CYAN}[*] Running Nuclei Templates${RESET}"
        nuclei -u "http://$target" -t ~/nuclei-templates/ -severity medium,high \
            -o "$SCANS_DIR/nuclei_scan.txt"
    fi
    
    # CMS detection and scanning
    if command -v wpscan &>/dev/null; then
        echo -e "${CYAN}[*] WordPress Vulnerability Scan${RESET}"
        wpscan --url "http://$target" --no-update -o "$SCANS_DIR/wpscan.txt"
    fi
}

# Wireless attack module
wireless_attacks() {
    echo -e "${GREEN}[+] Wireless Network Analysis${RESET}"
    
    if command -v airodump-ng &>/dev/null; then
        echo -e "${CYAN}[*] Starting WiFi Monitoring${RESET}"
        sudo airodump-ng wlan0 -w "$SCANS_DIR/wifi_capture" --output-format csv
    fi
    
    if command -v reaver &>/dev/null; then
        echo -e "${CYAN}[*] WPS PIN Attack Preparation${RESET}"
        wash -i wlan0 -o "$SCANS_DIR/wps_targets.txt"
    fi
}

# Post-exploitation module
post_exploitation() {
    local target="$1"
    echo -e "${GREEN}[+] Post-Exploitation Actions${RESET}"
    
    # Credential spraying
    if command -v hydra &>/dev/null; then
        echo -e "${CYAN}[*] SSH Credential Spraying${RESET}"
        hydra -L "$WORDLIST_DIR/users.txt" -P "$WORDLIST_DIR/passwords.txt" \
            ssh://"$target" -t 4 -o "$SCANS_DIR/ssh_hydra.txt"
    fi
    
    # Network traffic capture
    echo -e "${CYAN}[*] Starting Packet Capture${RESET}"
    tshark -i eth0 -a duration:300 -w "$LOOT_DIR/network_capture.pcap" &
}

# Reporting module
generate_reports() {
    echo -e "${GREEN}[+] Generating Consolidated Reports${RESET}"
    
    # Convert XML to HTML
    if command -v xsltproc &>/dev/null; then
        xsltproc "$SCANS_DIR/tcp_full.xml" -o "$REPORTS_DIR/nmap_scan.html"
    fi
    
    # Create executive summary
    python3 "$LIB_DIR/report_generator.py" --input "$SCANS_DIR" --output "$REPORTS_DIR"
}

# Full Network Audit
full_network_audit() {
    local target="$1"
    echo -e "${GREEN}[+] Starting Full Network Audit${RESET}"
    
    network_discovery "$target"
    port_scanning "$target"
    vulnerability_assessment "$target"
    
    echo -e "${GREEN}[+] Network Audit Completed${RESET}"
}

# Targeted Vulnerability Scan
targeted_vuln_scan() {
    local target="$1"
    echo -e "${GREEN}[+] Starting Targeted Vulnerability Scan${RESET}"
    
    # Advanced vulnerability scanning with NSE
    echo -e "${CYAN}[*] Running Advanced Vulnerability Scripts${RESET}"
    nmap --script "vuln and safe" -p- -T4 -oX "$SCANS_DIR/targeted_vuln.xml" "$target"
    
    # Web vulnerability scanning
    if command -v nikto &>/dev/null; then
        echo -e "${CYAN}[*] Web Application Scan with Nikto${RESET}"
        nikto -h "http://$target" -output "$SCANS_DIR/nikto_scan.html"
    fi
}

# Get target range from config
get_target_range() {
    echo "$TARGET_NETWORK"
}

# Cleanup and exit
safe_exit() {
    echo -e "${CYAN}[*] Cleaning up temporary files${RESET}"
    rm -rf "$TMP_DIR"
    echo -e "${GREEN}[+] Analysis complete. Results stored in $LOOT_DIR${RESET}"
    exit 0
}

# Main execution flow
main() {
    init_directories
    local target_range=$(get_target_range)
    
    while true; do
        main_menu
        read -p "Select option: " choice
        case $choice in
            1) full_network_audit "$target_range" ;;
            2) targeted_vuln_scan "$target_range" ;;
            3) wireless_attacks ;;
            4) post_exploitation "$target_range" ;;
            5) generate_reports ;;
            6) safe_exit ;;
            *) echo -e "${RED}[!] Invalid option${RESET}";;
        esac
        read -p "Press Enter to continue..."
    done
}

# Entry point
main