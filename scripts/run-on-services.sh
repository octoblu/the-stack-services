#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"

run_commands() {
  local service_name="$1"
  local commands_str="$2"
  local commands=( ${commands_str//,/ } )

  for single_command in "${commands[@]}"; do
    run_command "$service_name" "$single_command"
  done
}

run_command() {
  local service_name="$1"
  local command="$2"
  echo "${command}ing $service_name..."
  gtimeout 15s fleetctl "${command}" "${service_name}"
  if [ ! -z "$COMMAND_SLEEP" ]; then
    sleep "$COMMAND_SLEEP"
  fi
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
  echo ''
  echo "example: ./run-fleetctl-command.sh start '*meshblu*'"
  echo ''
}

main() {
  local command="$1"
  if [ "$command" == "--help" ]; then
    usage
    exit 0
  fi
  if [ "$command" == "-h" ]; then
    usage
    exit 0
  fi
  if [ -z "$command" ]; then
    usage
    echo "Missing fleetctl command(s)"
    exit 1
  fi
  local query="$2"
  if [ -z "$query" ]; then 
    query='*'
  fi
  local services_path="$PROJECT_DIR/services.d"
  local services=( $(find $services_path -type d -maxdepth 1 -iname "$query") )

  for service_path in "${services[@]}"; do
    if [ "$service_path" == "$services_path" ]; then
      continue
    fi
    local service_name="${service_path/$services_path\//}"
    echo "* processing $service_name"
    local files=( $(find $service_path -type f -maxdepth 1 -iname '*.service') )
    for file_path in "${files[@]}"; do
      if [ "$file_path" == "$service_path" ]; then
        continue
      fi
      local file_name="$(basename $file_path)"
      file_name="${file_name/\.service/}"
      if [[ "$file_name" =~ @$ ]]; then
        run_commands "${file_name}1" "$command"
        run_commands "${file_name}2" "$command"
      else
        run_commands "${file_name}" "$command"
      fi
    done
  done
}

main "$@"
