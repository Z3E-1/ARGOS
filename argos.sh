#!/usr/bin/env bash
###############################################################################
# ARGOS - Main Menu
###############################################################################

source "./lib/argos_lib.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

function banner_install() {
  clear
  cat << "EOF"

 █████╗ ██████╗  ██████╗  ██████╗ ███████╗
██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗██╔════╝
███████║██████╔╝██║  ███╗██║   ██║███████╗
██╔══██║██╔══██╗██║   ██║██║   ██║╚════██║
██║  ██║██║  ██║╚██████╔╝╚██████╔╝███████║
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚══════╝
   A R G O S   I N S T A L L E R   v2.1
EOF

  echo -e "\n${CYAN}1. Passive Info Gathering"
  echo "2. Active Scanning"
  echo "3. Web & API Analysis"
  echo "4. Network Analysis"
  echo "5. OSINT"
  echo "6. Wildcard Scanning"
  echo "7. Vulnerabilities"
  echo "8. Massive Recon"
  echo "9. Metasploit Automation"
  echo "10. ALL Recon"
  echo "11. Generate Report"
  echo -e "12. Exit${RESET}\n"
}

function run_module() {
  local mod="$1"
  local modfile="./modules/$mod.sh"
  shift
  if [ -f "$modfile" ]; then
    bash "$modfile" "$@"
    if [ $? -ne 0 ]; then
      echo -e "${RED}[!] Module '$mod' encountered an error.${RESET}"
    fi
  else
    echo -e "${RED}[!] Module not found: $modfile${RESET}"
  fi
}

while true; do
  banner_install
  echo -ne "${YELLOW}Select an option: ${RESET}"
  read -r option
  case "$option" in
    1)
      run_module "passive"
      ;;
    2)
      run_module "active"
      ;;
    3)
      run_module "web_api"
      ;;
    4)
      run_module "network"
      ;;
    5)
      run_module "osint"
      ;;
    6)
      run_module "wildcard"
      ;;
    7)
      run_module "vulnerabilities"
      ;;
    8)
      run_module "massive_recon"
      ;;
    9)
      run_module "metasploit"
      ;;
    10)
      run_module "all_recon"
      ;;
    11)
      run_module "generate_report"
      ;;
    12)
      echo -e "${GREEN}[+] Exiting...${RESET}"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}[!] Invalid option. Please select a valid number.${RESET}"
      sleep 1
      ;;
  esac
  echo -e "\n${CYAN}Press Enter to continue...${RESET}"
  read -r
done