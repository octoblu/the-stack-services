#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"

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
  local service_name="$2"
  local service="$service_name"
  if [ "$command" == "submit" -o "$command" == "destroy" ]; then
    local instance_number="${service_name//[^0-9]/}"
    if [ ! -z "$instance_number" -a "$instance_number" != "1" ]; then
      return 0
    fi
    local folder_name="${file_name/octoblu\-}"
    folder_name="${folder_name%\-register*}"
    folder_name="${folder_name%\-sidekick*}"
    local file_extension=".service"
    if [[ "$service_name" =~ @$ ]]; then
      file_extension="@.service"
    fi
    local file_path="$PROJECT_DIR/services.d/${folder_name}/${file_name}${file_extension}"
    service="$file_path" 
    if [ "$command" == "destroy" ]; then
      service="${file_name}{$file_extension}"
    fi
  fi
  echo "* running ${command} on ${service_name}..."
  run_fleet_cmd "${command}" "${service}" || return 1
  if [ ! -z "$COMMAND_SLEEP" ]; then
    echo "* sleeping for $COMMAND_SLEEP"
    sleep "$COMMAND_SLEEP"
  fi
}

run_fleet_cmd() {
  local command="$1"
  local service="$2"
  gtimeout 15s fleetctl "${command}" "${service}"
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
    echo "* processing $service_name"
    local count=""
    local files=( $(find $service_path -type f -maxdepth 1 -iname '*.service') )
    for file_path in "${files[@]}"; do
      if [ "$file_path" == "$service_path" ]; then
        continue
      fi
      local file_name="$(basename $file_path)"
      file_name="${file_name/\.service/}"
      if [[ "$file_name" =~ @$ ]]; then
        local service_instances=( $(filter_units "$units" | grep "$file_name" ) )
        local has_instances="false"
        for instance in "${service_instances[@]}"; do
          local i="${instance/$file_name}" 
          run_commands "$command" "${file_name}${i}" 
          has_instances="true"
        done
        if [ ! -z "$count" ] && [ "$count" != "0" ]; then 
          echo "auto running $count..."
          for i in $(seq 1 $count); do
            run_commands "$command" "${file_name}${i}"
          done   
        else 
          if [[ "$command" =~ start ]] && [ "$has_instances" == "false" ]; then
            read -t 30 -s -p  "how many instances of $file_name? [enter] to skip:"$' ' -n 1 count
            if [ "$count" != "" ] && [[  "$count" =~ [0-9]* ]]; then
              echo "running $count..."
              for i in $(seq 1 $count); do
                run_commands "$command" "${file_name}${i}"
              done   
            else
              count="0"
              echo "incorrect input, skipping"
            fi
          fi
        fi
      else
        run_commands "$command" "${file_name}" 
      fi
    done
  done
}

main "$@"
