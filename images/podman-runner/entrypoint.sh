#!/bin/bash
if [ -e "/.env" ]; then
  echo "Adding custom environment variables" 1>&2
  source /.env
fi

RUNNER_ASSETS_DIR=${RUNNER_ASSETS_DIR:-/runnertmp}
RUNNER_HOME=${RUNNER_HOME:-/runner}

LIGHTGREEN="\e[0;32m"
LIGHTRED="\e[0;31m"
WHITE="\e[0;97m"
RESET="\e[0m"

log(){
  printf "%s %s %s\n" "$WHITE" "${@}" "$RESET" 1>&2
}

success(){
  printf "%s %s %s\n" "$LIGHTGREEN" "${@}" "$RESET" 1>&2
}

error(){
  printf "%s %s %s\n" "$LIGHTRED" "${@}" "$RESET" 1>&2
}

if [ -n "${STARTUP_DELAY_IN_SECONDS}" ]; then
  log "Delaying startup by ${STARTUP_DELAY_IN_SECONDS} seconds"
