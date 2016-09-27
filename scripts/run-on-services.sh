#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"
SERVICESD="$PROJECT_DIR/services.d"
INSTANCE_COUNT=""

run_commands() {
  local commands_str="$1"
  local service_name="$2"
  local commands=( ${commands_str//,/ } )

  for single_command in "${commands[@]}"; do
    run_command "$single_command" "$service_name"
  done
}

run_command() {
  local command="$1"
  local service="$2"
  case "$command" in
    submit)
      run_submit "$service" || return 1
      ;;
    destroy)
      run_destroy "$service" || return 1
      ;;
    load | cat | unload | status | stop | start)
      run_fleet_cmd "${command}" "${service}" || return 1
      ;;
    *)
      echo "Invalid command $command"
      exit 1
      ;;
  esac
}

run_submit() {
  local service="$1"
  is_first "$service"
  if [ "$?" != "0" ]; then
    return 0
  fi
  local file_path="$(get_file_path "$service")"
  if [ ! -f "$file_path" ]; then
    echo "Error: $file_path is not a file"
    return 1
  fi
  run_fleet_cmd submit "${file_path}"
}

run_destroy() {
  local service="$1"
  local file_name="$(get_file_name "$service")"
  local instance="$(get_instance "$service")"
  local at="$(get_at "$service")"
  local instance_file="${file_name}${at}${instance}.service"
  run_fleet_cmd destroy "$instance_file"
  # local root_file="${file_name}${at}.service"
  # if [ "$root_file" == "$instance_file" ]; then
  #   return 0
  # fi
  # is_first "$service"
  # if [ "$?" == "0" ]; then
  #   run_fleet_cmd destroy "$root_file"
  # fi
}

run_fleet_cmd() {
  local command="$1"
  local service="$2"
  echo "* running fleetctl ${command} ${service/$PROJECT_DIR\/}"
  if [ -z "$DRY_RUN" ]; then
    gtimeout 15s fleetctl "${command}" "${service}"
  fi
  command_sleep
}

command_sleep() {
  if [ ! -z "$COMMAND_SLEEP" ]; then
    echo "* [command] sleeping for $COMMAND_SLEEP"
    sleep "$COMMAND_SLEEP"
  fi
}

get_folder_name() {
  local service="$1"
  local folder_name="${service/octoblu\-}"
  folder_name="${folder_name%\-register*}"
  folder_name="${folder_name%\-sidekick*}"
  folder_name="${folder_name%\@*}"
  echo "$folder_name"
}

get_file_path() {
  local service="$1"
  local folder_name="$(get_folder_name "$service")"
  local file_name="$(get_file_name "$service")"
  local at="$(get_at "$service_name")"
  echo "$SERVICESD/${folder_name}/${file_name}${at}.service"
}

get_instance() {
  local service="$1"
  echo "${service//[^0-9]/}"
}

get_file_name() {
  local service="$1"
  echo "${service%\@*}"
}

get_at() {
  local service="$1"
  if [[ "$service" =~ @ ]]; then
    echo "@"
  fi
}

is_first() {
  local service="$1"
  local instance="$(get_instance "$service")"
  if [ ! -z "$instance" -a "$instance" != "1" ]; then
    return 1
  fi
  return 0
}

get_full_file_name() {
  local file_path="$1"
  local file_name="$(basename $file_path)"
  echo "${file_name/\.service/}"
}

is_instance_file() {
  local file_name="$1"
  if [[ "$file_name" =~ @$ ]]; then
    return 0
  fi
  return 1
}

process_file_instances() {
  local commands="$1"; shift
  local file_name="$1"; shift
  local units="$@"
  local has_instances="false"
  local service_instances=( $(filter_units "$units" | grep "$file_name" ) )
  for instance in "${service_instances[@]}"; do
    local i="${instance/$file_name}"
    echo "* running on an existing instance ${instance}"
    run_commands "$commands" "${file_name}${i}"
    has_instances="true"
  done
  if [ "$has_instances" == "false" ]; then
    return 1
  fi
}

run_count_on_instances() {
  local commands="$1"
  local file_name="$2"
  echo "* running ${INSTANCE_COUNT} instances..."
  for i in $(seq 1 $INSTANCE_COUNT); do
    run_commands "$commands" "${file_name}${i}"
  done
}

prompt_for_count() {
  local file_name="$1"
  read -t 30 -s -p  "how many instances of $file_name? [enter] to skip:"$' ' -n 1 INSTANCE_COUNT
  echo ''
}

process_file() {
  local commands="$1"; shift
  local file_path="$1"; shift
  local units="$@"
  local file_name="$(get_full_file_name "$file_path")"
  echo "* processing file $file_name"
  is_instance_file "$file_name"
  local is_instance="$?"
  if [ "$is_instance" != "0" ]; then
    echo "* running on global $file_name"
    run_commands "$commands" "$file_name"
    return "$?"
  fi
  process_file_instances "$commands" "$file_name" "$units"
  local has_instances="$?"
  if [ "$has_instances" == "0" ]; then
    return 0
  fi
  if [ ! -z "$INSTANCE_COUNT" ] && [ "$INSTANCE_COUNT" != "0" ]; then
    run_count_on_instances "$commands" "$file_name"
    return 0
  fi
  if [[ "$commands" =~ start ]] && [ "$has_instances" == "1" ]; then
    prompt_for_count "$file_name"
    if [ "$INSTANCE_COUNT" != "" ] && [[  "$INSTANCE_COUNT" =~ [0-9]* ]]; then
      run_count_on_instances "$commands" "$file_name"
      return 0
    fi
    INSTANCE_COUNT="0"
    echo "incorrect input, skipping"
  fi
}

process_service() {
  local commands="$1"; shift
  local service_name="$1"; shift
  local service_path="$1"; shift
  local units="$@"
  INSTANCE_COUNT=""
  echo "* processing $service_name"
  local files=( $(find $service_path -type f -maxdepth 1 -iname '*.service') )
  for file_path in "${files[@]}"; do
    if [ "$file_path" == "$service_path" ]; then
      continue
    fi
    process_file "$commands" "$file_path" "$units"
  done
}

filter_units() {
  local units=( $@ )
  for unit in "${units[@]}"; do
    echo "$unit"
  done
}

list_units() {
  local units="$(fleetctl list-units | tail -n +2 | awk '{print $1}' | grep 'octoblu' | grep '@')"
  echo "${units[@]}"
}

usage() {
  echo './run-on-services.sh <command[,command]> [query]'
  echo ''
  echo 'args: '
  echo '  command(s): must be one, or multiple, of start, stop, or destroy. Make sure they are comma separated, no spaces.'
  echo '  query: (optional) will only run on services that match the query. Defaults to *'
  echo ''
  echo 'env:'
  echo '  COMMAND_SLEEP: the sleep duration after running each command'
  echo '  DRY_RUN: if set this will not run any commands'
  echo ''
  echo "example: ./run-on-services.sh start '*meshblu*'"
  echo ''
}

fatal() {
  local message="$1"
  echo "$message"
  exit 1
}

main() {
  local commands="$1"
  if [ "$commands" == "--help" -o "$commands" == "-h"  ]; then
    usage
    exit 0
  fi
  if [ -z "$commands" ]; then
    usage
    echo "Missing fleetctl command(s)"
    exit 1
  fi

  trap 'echo "Exiting!"; exit;' SIGINT

  local query="$2"
  if [ -z "$query" ]; then
    query='*'
  fi

  local services_path="$PROJECT_DIR/services.d"
  local services=( $(find $services_path -type d -maxdepth 1 -iname "$query") )

  local units="$(list_units)"
  if [ "$?" != "0" ]; then
    fatal 'unable to list units'
  fi

  local service_instances=( $(filter_units "$units") )
  for service_path in "${services[@]}"; do
    if [ "$service_path" == "$services_path" ]; then
      continue
    fi
    local service_name="${service_path/$services_path\//}"
    process_service "$commands" "$service_name" "$service_path" "$units"
  done
}

main "$@"
