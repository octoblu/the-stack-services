#!/bin/bash

SERVICES_DIR="$HOME/Projects/Octoblu/the-stack-services/services.d"

DEBUG_KEY='restart-services'

debug() {
  if [ -z "$DEBUG" ]; then
    return 0
  fi
  local message="$1"
  echo "$DEBUG_KEY: $message"
}

fatal() {
  local message="$1"
  echo "Error: $message"
  exit 1
}

script_directory(){
  local source="${BASH_SOURCE[0]}"
  local dir=""

  while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  dir="$( cd -P "$( dirname "$source" )" && pwd )"

  echo "$dir"
}

run_on_fleet() {
  local command="$1"
  local unit="$2"
  try gtimeout 15s fleetctl "${command}" "${unit}" > /dev/null
}

filter_units() {
  local units=( $@ )
  for unit in "${units[@]}"; do
    echo "$unit"
  done
}

get_units() {
  local filter="$1"
  local units="$(fleetctl list-units | grep 'service' | awk '{print $1}' | uniq)"
  if [ -n "$filter" ]; then
    filter_units "${units[@]}" | grep "$filter"
  else
    filter_units "${units[@]}"
  fi
}

is_instance() {
  local unit="$1"
  if [[ "$unit" =~ @ ]]; then
    return 0
  fi
  return 1
}

usage(){
  echo 'USAGE: restart-services.sh <filter>'
  echo ''
  echo 'Arguments:'
  echo '  -h, --help         print this help text'
  echo '  -v, --version      print the version'
}

version(){
  echo "1.0.0"
}

main() {
  local filter="$1";
  while [ "$1" != "" ]; do
    local param="$1"
    local value="$2"
    case "$param" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        if [ "${param::1}" == '-' ]; then
          echo "ERROR: unknown parameter \"$param\""
          usage
          exit 1
        fi
        if [ -n "$param" ]; then
          filter="$param"
        fi
        ;;
    esac
    shift
  done

  trap 'echo "Exiting!"; exit;' SIGINT

  local units=( $(get_units "$filter") )

  if [ "$?" != "0" ]; then
    fatal 'unable to list units'
  fi

  for unit in "${units[@]}"; do
    echo "Processing unit: $unit"
    run_on_fleet 'stop' "$unit" || echo "Failed to stop"
    run_on_fleet 'start' "$unit" || echo "Failed to start"
    sleep 10
  done
}

main "$@"
