#!/usr/bin/env bash
###############################################################################
# ARGOS - Main Menu
###############################################################################

source "./utils.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

cat << "EOF"

     ___            
    /   | 
   / /| |  
  / ___ / 
 /_/  |_\  
        R G O S   
1) Passive Info Gathering
2) Active Scanning
3) Web & API Analysis
4) Network Analysis
5) OSINT
6) Wildcard Scanning
7) Vulnerabilities
8) Massive Recon
9) Metasploit Automation
10) ALL Recon
11) Generate Report
12) Exit
EOF

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
  echo -ne "Select an option: "
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
      ;;
  esac
done
