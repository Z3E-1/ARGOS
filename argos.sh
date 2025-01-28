#!/usr/bin/env bash
###############################################################################
# ARGOS - Main Orchestrator
# Enhanced with error handling and input validation
###############################################################################

source ./utils.sh

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; CYAN="\033[0;36m"; RESET="\033[0m"

function banner() {
  cat << "EOF"
      ___   ______  _________   ____  ____  ______
     /   | / ____/ / ____/   | / __ \/ __ \/ ____/
    / /| |/ /     / /   / /| |/ /_/ / / / / __/   
   / ___ / /___  / /___/ ___ / _, _/ /_/ / /___   
  /_/  |_\____/  \____/_/  |_/_/ |_|\____/_____/   
         A R G O S   F R A M E W O R K
EOF
}

function usage() {
  echo -e "${CYAN}Usage:${RESET} $0 [module] [args]"
  echo -e "${CYAN}Modules:${RESET} passive, active, web, network, osint, wildcard, vulnerabilities, massive, metasploit, all, report"
  echo
  echo "Examples:"
  echo "  $0 passive example.com"
  echo "  $0 network 192.168.1.0/24"
  echo "  $0 all example.com"
  echo "  $0 report"
  exit 0
}

function error() {
  echo -e "${RED}[!] $*${RESET}"
}

# run_module <module> <args...>
function run_module() {
  local modfile="./modules/$1.sh"
  shift
  if [ -f "$modfile" ]; then
    bash "$modfile" "$@"
  else
    error "Module not found: $modfile"
  fi
}

# CLI mode
if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help)
      usage
      ;;
    passive|active|web|network|osint|wildcard|vulnerabilities|massive|metasploit)
      mod="$1"
      shift
      run_module "$mod" "$@"
      ;;
    all)
      shift
      TARGET="$1"
      if [ -n "$TARGET" ]; then
        # in a real scenario we might ask for domain vs IP, but here we do everything
        run_module "passive" "$TARGET"
        run_module "active" "$TARGET"
        run_module "web" "$TARGET"
        run_module "network" "$TARGET"
        run_module "osint" "$TARGET"
        run_module "wildcard" "$TARGET"
        run_module "vulnerabilities" "$TARGET"
        run_module "massive" "$TARGET"
        # metasploit might require an nmap.xml from network or active
        # run_module "metasploit" --xml loot/network/nmap_scan_...
      else
        error "Usage: $0 all <target>"
      fi
      ;;
    report)
      shift
      if [ -f "./report.sh" ]; then
        bash "./report.sh" "$@"
      else
        error "report.sh not found."
      fi
      ;;
    *)
      error "Unknown option/module: $1"
      usage
      ;;
  esac
  exit 0
fi

# Otherwise interactive menu
while true; do
  banner
  echo -e "${GREEN} 1) Passive Info Gathering${RESET}"
  echo -e "${GREEN} 2) Active Scanning${RESET}"
  echo -e "${GREEN} 3) Web & API Analysis${RESET}"
  echo -e "${GREEN} 4) Network Analysis${RESET}"
  echo -e "${GREEN} 5) OSINT${RESET}"
  echo -e "${GREEN} 6) Wildcard Scanning${RESET}"
  echo -e "${GREEN} 7) Vulnerabilities${RESET}"
  echo -e "${GREEN} 8) Massive Recon${RESET}"
  echo -e "${GREEN} 9) Metasploit Automation${RESET}"
  echo -e "${GREEN}10) ALL Recon${RESET}"
  echo -e "${GREEN}11) Generate Report${RESET}"
  echo -e "${GREEN}12) Exit${RESET}"
  echo -ne "${CYAN}Select an option: ${RESET}"
  read -r CHOICE
  case "$CHOICE" in
    1) run_module "passive" ;;
    2) run_module "active" ;;
    3) run_module "web" ;;
    4) run_module "network" ;;
    5) run_module "osint" ;;
    6) run_module "wildcard" ;;
    7) run_module "vulnerabilities" ;;
    8) run_module "massive" ;;
    9) run_module "metasploit" ;;
    10)
      echo -ne "${CYAN}Enter target domain/IP for ALL scans: ${RESET}"
      read -r TOTARGET
      if [ -z "$TOTARGET" ]; then
        error "No target provided."
      else
        run_module "passive" "$TOTARGET"
        run_module "active" "$TOTARGET"
        run_module "web" "$TOTARGET"
        run_module "network" "$TOTARGET"
        run_module "osint" "$TOTARGET"
        run_module "wildcard" "$TOTARGET"
        run_module "vulnerabilities" "$TOTARGET"
        run_module "massive" "$TOTARGET"
        # run_module "metasploit" ...
      fi
      ;;
    11)
      if [ -f "./report.sh" ]; then
        bash "./report.sh"
      else
        error "report.sh not found."
      fi
      ;;
    12)
      echo -e "${RED}Exiting...${RESET}"
      exit 0
      ;;
    *)
      error "Invalid choice."
      ;;
  esac
  echo -en "${YELLOW}[Press Enter to continue]${RESET}"
  read -r
done
