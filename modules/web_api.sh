#!/usr/bin/env bash
###############################################################################
# ARGOS - Web & API Analysis (Enhanced Version)
###############################################################################

set -e
set -o pipefail

source "$(dirname "$0")/../lib/argos_lib.sh"
# Renkler
RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# ASCII Art
cat << "EOF"

 █████╗ ██████╗  ██████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝
███████║██████╔╝██║  ███╗██║   ██║███████╗
██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
   W E B  &  A P I   (Enhanced)
EOF

# Config
THREADS=100
HTTPX_PORTS="80,443,8080,8443,3000"
NMAP_PORTS="1-65535"
NMAP_TOP_PORTS=1000
LOOT_DIR_BASE="$(pwd)/loot"
SCAN_PROFILE="quick" # quick|full

# Hedefler
TARGETS=()
if [ "$#" -ge 1 ]; then
  TARGETS=("$@")
else
  echo -ne "${CYAN}Hedef domain(ler) girin (örn: example.com test.com): ${RESET}"
  read -r -a TARGETS
fi

[ "${#TARGETS[@]}" -eq 0 ] && { echo -e "${RED}[!] Domain belirtilmedi.${RESET}"; exit 1; }

# Bağımlılıklar
declare -A tools=(
  ["subfinder"]="Subdomain Discovery"
  ["amass"]="Subdomain Enumeration"
  ["httpx"]="HTTP Probe"
  ["nuclei"]="Vulnerability Scanner"
  ["subjack"]="Subdomain Takeover"
  ["dalfox"]="XSS Scanner"
  ["gau"]="URL Collector"
  ["gf"]="Pattern Filter"
  ["sqlmap"]="SQL Injection"
  ["nmap"]="Port Scanner"
  ["nikto"]="Web Server Scanner"
  ["wafw00f"]="WAF Detector"
  ["jsxss"]="JS XSS Scanner"
  
)

for tool in "${!tools[@]}"; do
  command -v "$tool" >/dev/null || { 
    echo -e "${RED}[!] Eksik araç: ${YELLOW}$tool${RED} - ${tools[$tool]}${RESET}"
    exit 1
  }
done

# WAF Bypass fonksiyonu
waf_bypass() {
  local target=$1
  echo -e "\n${CYAN}[*] WAF Bypass Denemeleri: ${target}${RESET}"
  
  # DNS History Check
  if command -v bypass-firewalls-by-DNS-history >/dev/null; then
    bypass-firewalls-by-DNS-history -d "$target" | tee "$LOOT_DIR/waf_bypass_dns.txt"
  fi
  
  # Nmap WAF Bypass Scriptleri
  nmap --script "http-waf-detect,http-waf-fingerprint" "$target" -oN "$LOOT_DIR/waf_nmap.txt"
}

# JS Analizi
js_analysis() {
  local JS_FILES="$LOOT_DIR/js_files.txt"
  [ ! -s "$JS_FILES" ] && return
  
  echo -e "\n${CYAN}=== JS DOSYASI ANALİZİ ===${RESET}"
  
  # LinkFinder ile Endpoint Bulma
  echo -e "${YELLOW}[*] JS Endpoint Taraması${RESET}"
  while read -r js_url; do
    python3 -m linkfinder -i "$js_url" -o cli >> "$LOOT_DIR/js_endpoints.txt"
  done < "$JS_FILES"
  
  # Retire.js ile olmadı başka bişey buluruz
  
  # JSXSS ile XSS Taraması
  echo -e "\n${YELLOW}[*] JS İçi XSS Taraması${RESET}"
  while read -r js_url; do
    jsxss -u "$js_url" >> "$LOOT_DIR/js_xss.txt"
  done < "$JS_FILES"
}

# Nmap Tarama Profilleri
nmap_scan() {
  local target=$1
  echo -e "\n${CYAN}[*] Nmap Taraması: ${target}${RESET}"
  
  case $SCAN_PROFILE in
    "quick")
      nmap -p 80,443,8080,8443 -sV --script "default,vuln" -T4 "$target" -oN "$LOOT_DIR/nmap_quick.txt"
      ;;
    "full")
      nmap -p- -sV --script "default,vuln,discovery,exploit" -T4 "$target" -oN "$LOOT_DIR/nmap_full.txt"
      ;;
  esac
}

# SQLMap Gelişmiş Tarama
advanced_sqli() {
  local SQLI_PARAMS=$1
  [ ! -s "$SQLI_PARAMS" ] && return
  
  echo -e "\n${CYAN}[*] Gelişmiş SQLi Taraması${RESET}"
  sqlmap -m "$SQLI_PARAMS" --batch --random-agent --level=3 --risk=3 \
    --crawl=5 --forms --threads=10 --output-dir="$LOOT_DIR/sqlmap_results" \
    --tamper="between,randomcase,space2comment" --technique=BEUST
}

# Nikto Gelişmiş Tarama
nikto_scan() {
  local target=$1
  echo -e "\n${CYAN}[*] Nikto Taraması: ${target}${RESET}"
  nikto -h "$target" -Format xml -output "$LOOT_DIR/nikto_${target//[^a-zA-Z0-9]/_}.xml"
  xsltproc "$LOOT_DIR/nikto_${target//[^a-zA-Z0-9]/_}.xml" -o "$LOOT_DIR/nikto_${target//[^a-zA-Z0-9]/_}.html"
}

# Ana İşlem
for TARGET in "${TARGETS[@]}"; do
  echo -e "\n${GREEN}[+] WEB & API analizi başlatılıyor: ${YELLOW}$TARGET${RESET}"
  
  TS=$(date +%Y%m%d_%H%M%S)
  LOOT_DIR="${LOOT_DIR_BASE}/web_${TARGET}_${TS}"
  mkdir -p "$LOOT_DIR"/{js_files,sqlmap_results}
  
  # Subdomain Discovery
  echo -e "\n${CYAN}=== SUBDOMAIN KEŞFİ ===${RESET}"
  subfinder -d "$TARGET" -silent | tee "$LOOT_DIR/subdomains.txt"
  amass enum -passive -d "$TARGET" -silent | tee -a "$LOOT_DIR/subdomains.txt"
  sort -u "$LOOT_DIR/subdomains.txt" -o "$LOOT_DIR/subdomains.txt"
  
  # Live Hosts
  echo -e "\n${CYAN}=== AKTİF HOSTLAR ===${RESET}"
  httpx -l "$LOOT_DIR/subdomains.txt" -ports "$HTTPX_PORTS" -silent -o "$LOOT_DIR/live.txt"
  
  # WAF Detection & Bypass
  wafw00f -i "$LOOT_DIR/live.txt" -o "$LOOT_DIR/waf.txt"
  grep 'Cloudflare' "$LOOT_DIR/waf.txt" && waf_bypass "$TARGET"
  
  # Nmap Scanning
  nmap_scan "$TARGET"
  
  # JS Analysis
  grep -Eo 'https?://[^ ]+\.js' "$LOOT_DIR/live.txt" | sort -u > "$LOOT_DIR/js_files.txt"
  js_analysis
  
  # SQLi Scanning
  gau -subs "$TARGET" | gf sqli > "$LOOT_DIR/sqli_params.txt"
  advanced_sqli "$LOOT_DIR/sqli_params.txt"
  
  # Nikto Scanning
  while read -r host; do nikto_scan "$host"; done < "$LOOT_DIR/live.txt"
  
  # Sonuçlar
  echo -e "\n${GREEN}=== TARAMA TAMAMLANDI ===${RESET}"
  tree "$LOOT_DIR"
done

exit 0