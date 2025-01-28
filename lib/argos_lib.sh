#!/usr/bin/env bash
###############################################################################
# ARGOS - Utility Library
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

function initialize_colors() {
  export RED GREEN YELLOW CYAN RESET
}

function check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Bu komut root yetkisi gerektirir${RESET}"
    exit 1
  fi
}

function load_config() {
  CONFIG_FILE="./argos.conf"
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    echo -e "${YELLOW}[!] Config dosyası bulunamadı${RESET}"
  fi
}

function create_dir() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
    echo -e "${GREEN}[+] Dizin oluşturuldu: $1${RESET}"
  fi
}

function print_banner() {
  clear
  cat << "EOF"
  
 █████╗ ██████╗  ██████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝
███████║██████╔╝██║  ███╗██║   ██║███████╗
██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
EOF
}

function validate_ipcidr() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]] || {
    echo -e "${RED}[!] Geçersiz IP/CIDR: $1${RESET}"
    exit 1
  }
}

function validate_domain() {
  [[ $1 =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]] || {
    echo -e "${RED}[!] Geçersiz domain: $1${RESET}"
    exit 1
  }
}

function run_command() {
  echo -e "${CYAN}[EXEC] $*${RESET}"
  eval "$*"
  if [ $? -ne 0 ]; then
    echo -e "${RED}[!] Komut başarısız: $*${RESET}"
    exit 1
  fi
}