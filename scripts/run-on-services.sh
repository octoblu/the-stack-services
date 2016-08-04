#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"

run_it() {
  local service_name="$1"
  local command="$2"
  echo "${command}ing $service_name..."
  gtimeout 15s fleetctl "${command}" "${service_name}"
}

usage() {
  echo './run-on-services.sh <command> [query]'
  echo ''
  echo 'args: '
  echo '  command: must be one of start, stop, or destroy'
  echo '  query: (optional) will only run on services that match the query. Defaults to *'
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
    echo "Missing fleetctl command"
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
        run_it "${file_name}1" "$command"
        run_it "${file_name}2" "$command"
      else
        run_it "$file_name" "$command"
      fi
    done
  done
}

main "$@"
