#!/bin/bash
###############################################################################
# ARGOS - Enhanced Install Script
# Go, PATH ayarları ve bağımlılıklar düzeltildi
###############################################################################

source ./utils.sh

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
 /_/  |_|\____/  \____/_/  |_/_/ |_|\____/_____/
     A R G O S   I N S T A L L E R

EOF
}

banner_install

echo -e "${CYAN}[+] Updating system packages...${RESET}"
run_command "sudo apt-get update -y && sudo apt-get upgrade -y"

# Go kurulumu ve PATH ayarı
if ! command -v go >/dev/null; then
  echo -e "${CYAN}[+] Installing Go...${RESET}"
  run_command "wget https://go.dev/dl/go1.20.linux-amd64.tar.gz -O /tmp/go.tar.gz"
  run_command "sudo tar -C /usr/local -xzf /tmp/go.tar.gz"
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
  source ~/.bashrc
fi

# Araç listesi ve kurulum
declare -A tools=(
  ["nmap"]="nmap"
  ["dalfox"]="github.com/hahwul/dalfox/v2@latest"
  ["whois"]="whois"
  ["dig"]="dnsutils"
  ["nslookup"]="dnsutils"
  ["subfinder"]="subfinder"
  ["amass"]="amass"
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
  ["mailspoof"]="mailutils"
)

for t in "${!tools[@]}"; do
  if ! command -v "$t" >/dev/null; then
    echo -e "${CYAN}[+] Installing $t...${RESET}"
    if [[ ${tools[$t]} == github.com/* ]]; then
      run_command "go install ${tools[$t]}"
      tool_name=$(basename "${tools[$t]}")
      run_command "sudo cp $HOME/go/bin/${tool_name} /usr/local/bin/"
    else
      run_command "sudo apt-get install -y ${tools[$t]}"
    fi
  else
    echo -e "${GREEN}[i] $t is already installed.${RESET}"
  fi
done

# Optional GitHub tabanlı araçların kurulumu
echo -ne "${CYAN}[?] Install extra GitHub-based tools? (SecretFinder, Corsy, GitDorker, etc.) y/N: ${RESET}"
read -r EXTRA
if [[ "$EXTRA" =~ ^[Yy]$ ]]; then
  mkdir -p ~/tools
  # SecretFinder
  if [ ! -d ~/tools/SecretFinder ]; then
    echo -e "${GREEN}[+] Cloning SecretFinder...${RESET}"
    run_command "git clone https://github.com/m4ll0k/SecretFinder.git ~/tools/SecretFinder"
  fi
  # Corsy
  if [ ! -d ~/tools/Corsy ]; then
    echo -e "${GREEN}[+] Cloning Corsy...${RESET}"
    run_command "git clone https://github.com/s0md3v/Corsy.git ~/tools/Corsy"
  fi
  # GitDorker
  if [ ! -d ~/tools/GitDorker ]; then
    echo -e "${GREEN}[+] Cloning GitDorker...${RESET}"
    run_command "git clone https://github.com/obheda12/GitDorker.git ~/tools/GitDorker"
  fi
  # 403bypass
  if [ ! -f ~/tools/403bypass/4xx.py ]; then
    mkdir -p ~/tools/403bypass
    echo -e "${GREEN}[+] Downloading 4xx.py...${RESET}"
    run_command "wget -q -O ~/tools/403bypass/4xx.py https://raw.githubusercontent.com/Ekultek/404bypass/master/4xx.py"
  fi
fi

echo -e "${CYAN}[+] Cleaning up old dependencies...${RESET}"
run_command "sudo apt autoremove -y"

echo -e "${GREEN}[+] Installation complete!${RESET}"
exit 0
