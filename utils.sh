#!/usr/bin/env bash
###############################################################################
# ARGOS - Utility Functions
###############################################################################

RED="\033[0;31m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
RESET="\033[0m"

function validate_ipcidr() {
  [[ $1 =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]] || {
    echo -e "${RED}[!] Invalid IP/CIDR: $1${RESET}"; exit 1
  }
}

function validate_domain() {
  [[ $1 =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]] || {
    echo -e "${RED}[!] Invalid domain: $1${RESET}"; exit 1
  }
}

function run_command() {
  echo -e "${CYAN}[EXEC] $*${RESET}"
  eval "$*"
  [ $? -ne 0 ] && { echo -e "${RED}[!] Command failed: $*${RESET}"; return 1; }
  return 0
}
