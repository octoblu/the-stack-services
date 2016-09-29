#!/bin/bash

SERVICES_DIR="$HOME/Projects/Octoblu/the-stack-services/services.d"
DEBUG_KEY='restart-services'
CYAN='\033[0;36m'
NOCOLOR='\033[0m'

debug() {
  if [ -z "$DEBUG" ]; then
    return 0
  fi
  local message="$@"
  echo -e "[${CYAN}${DEBUG_KEY}${NOCOLOR}]: $message"
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

handle_fleetctl() {
  local cmd="$@"
  local result="$(gtimeout 10s $cmd 2>&1)"
  if [[ "$result" =~ 'code 500' ]]; then
    return 1
  fi
  return 0
}

try_cmd() {
  local count=1
  until handle_fleetctl "$@"; do
    if [ $count > 5 ]; then
      echo "exceeded trys"
      return 1
    fi
    echo "trying again..."
    count+=1
    sleep 3
  done
}

run_on_fleet() {
  local dry_run="$1"
  local cmd="$2"
  local unit="$3"
  if [ "$dry_run" == "true" ]; then
    echo "fleetctl ${cmd} ${unit}"
  else
    debug "fleetctl ${cmd} ${unit}"
    try_cmd 'fleetctl' "${cmd}" "${unit}" > /dev/null
  fi
  if [ "$cmd" == "destroy" ]; then
    debug 'destroyed - sleeping for 3 seconds'
    if [ "$dry_run" == "false" ]; then
      sleep 3
    fi
  fi
}

get_units() {
  local filter="$1"
  if [ -n "$filter" ]; then
    fleetctl list-units | grep 'service' | grep "$filter" | awk '{print $1}' | uniq || fatal 'unable to get units'
  else
    fleetctl list-units | grep 'service' | awk '{print $1}' | uniq || fatal 'unable to get units'
  fi
}

check_instance() {
  local unit="$1"
  if [[ "$unit" =~ @ ]]; then
    echo "true"
    return 0
  fi
  echo "false"
}

usage(){
  echo 'USAGE: restart-services.sh <filter>'
  echo ''
  echo 'Arguments:'
  echo '  -dry-run           print the execution of the fleetctl, instead of running it'
  echo '  -h, --help         print this help text'
  echo '  -v, --version      print the version'
  echo ''
}

version(){
  echo "1.0.0"
}

main() {
  local filter="$1";
  local dry_run="false"
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
      --dry-run)
        dry_run="true"
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

  local units=( $(get_units "$filter") )
  debug "found ${#units[@]} units"

  local destroyed_units=()

  if [ "$?" != "0" ]; then
    fatal 'unable to list units'
  fi
  debug "dry_run $dry_run"

  for unit in "${units[@]}"; do
    echo "Processing unit: $unit"
    local is_instance="$(check_instance "$unit")"
    local unit_file_name="${unit%\@*}"
    if [ "$is_instance" == "true" ]; then
      unit_file_name="$(echo "${unit_file_name}@.service")"
    fi
    debug "unit_file_name $unit_file_name"
    local unit_file="$(find "$SERVICES_DIR" -type f -name "$unit_file_name" | head -n 1)"
    unit_file="${unit_file/$PWD\//./}"
    debug "unit_file $unit_file"
    if [ ! -f "$unit_file" ]; then
      echo "Service file for $unit does not exist"
      echo "SKIPPING..."
      continue;
    fi
    local should_destroy_global="true"
    for destroyed_unit in "${destroyed_units[@]}"; do
      if [ "$destroyed_unit" == "$unit_file_name" ]; then
        should_destroy_global="false"
        break;
      fi
    done
    if [ "$should_destroy_global" == "true" ]; then
      debug "destroying global $unit_file_name"
      run_on_fleet "$dry_run" 'destroy' "$unit_file_name" || echo "Failed to destroy global"
      debug "submitting $unit_file"
      run_on_fleet "$dry_run" 'submit' "$unit_file" || echo "Failed to submit"
      destroyed_units+=("$unit_file_name")
    fi
    if [ "$is_instance" == "true" ]; then
      debug "destroying instance $unit"
      run_on_fleet "$dry_run" 'destroy' "$unit" || echo "Failed to destroy instance"
    fi
    debug "starting $unit"
    run_on_fleet "$dry_run" 'start' "$unit" || echo "Failed to start"
    debug "done with $unit - sleeping for 3 seconds"
    if [ "$dry_run" == "false" ]; then
      sleep 3
    fi
  done
}

main "$@"
