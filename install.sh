#!/usr/bin/env bash
###############################################################################
# ARGOS - Install Script (Enhanced)
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

function banner_install() {
  cat << "EOF"

     ___   ______  _________   ____  ____  ______
    /   | / ____/ / ____/   | / __ \/ __ \/ ____/
   / /| |/ /     / /   / /| |/ /_/ / / / / __/
  / ___ / /___  / /___/ ___ / _, _/ /_/ / /___
 /_/  |_\____/  \____/_/  |_/_/ |_|\____/_____/
     A R G O S   I N S T A L L E R

EOF
}

banner_install

echo -e "${CYAN}[+] Updating system packages...${RESET}"
sudo apt-get update -y && sudo apt-get upgrade -y

declare -A tools=(
  ["whois"]="whois"
  ["dig"]="dnsutils"
  ["nslookup"]="dnsutils"
  ["subfinder"]="subfinder"
  ["amass"]="amass"
  ["nmap"]="nmap"
  ["masscan"]="masscan"
  ["httpx"]="httpx"
  ["dirsearch"]="dirsearch"
  ["sqlmap"]="sqlmap"
  ["gau"]="gau"
  ["hakrawler"]="hakrawler"
  ["gf"]="gf"
  ["enum4linux"]="enum4linux"
  ["sslscan"]="sslscan"
  ["nuclei"]="nuclei"
  ["metasploit"]="metasploit-framework"
  ["mailspoof"]="mailutils"   # Example
)

for t in "${!tools[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then
    echo -e "${GREEN}[i] $t is already installed.${RESET}"
  else
    echo -e "${CYAN}[+] Installing $t (${tools[$t]})...${RESET}"
    sudo apt-get install -y "${tools[$t]}"
    git clone https://github.com/hahwul/dalfox
    cd dalfox
    go install
    go build
    cp /root/go/bin/dalfox /usr/local/go/bin
    echo dalfox is installed correctly !!!!
  fi
done

# Optional GitHub clones
echo -ne "${CYAN}[?] Install extra GitHub-based tools? (SecretFinder, Corsy, GitDorker, etc.) y/N: ${RESET}"
read -r EXTRA
if [[ "$EXTRA" =~ ^[Yy]$ ]]; then
  mkdir -p ~/tools
  # SecretFinder
  if [ ! -d ~/tools/SecretFinder ]; then
    echo -e "${GREEN}[+] Cloning SecretFinder...${RESET}"
    git clone https://github.com/m4ll0k/SecretFinder.git ~/tools/SecretFinder
  fi
  # Corsy
  if [ ! -d ~/tools/Corsy ]; then
    echo -e "${GREEN}[+] Cloning Corsy...${RESET}"
    git clone https://github.com/s0md3v/Corsy.git ~/tools/Corsy
  fi
  # GitDorker
  if [ ! -d ~/tools/GitDorker ]; then
    echo -e "${GREEN}[+] Cloning GitDorker...${RESET}"
    git clone https://github.com/obheda12/GitDorker.git ~/tools/GitDorker
  fi
  # 403bypass
  if [ ! -f ~/tools/403bypass/4xx.py ]; then
    mkdir -p ~/tools/403bypass
    echo -e "${GREEN}[+] Downloading 4xx.py...${RESET}"
    wget -q -O ~/tools/403bypass/4xx.py https://raw.githubusercontent.com/Ekultek/404bypass/master/4xx.py
  fi
fi

echo -e "${GREEN}[+] Installation complete!${RESET}"
exit 0
