#!/bin/bash

active_services_for_filename(){
  local path="$1"
  local filename="$(basename "${path}")"
  local service_name="$(echo "$filename" | sed -e 's/\.service$//')"

  local exit_code=1
  local units=""

  while [ "${exit_code}" != "0" ]; do
    units="$(fleetctl list-units)"
    exit_code=$?
  done

  echo "${units}" \
  | grep "${service_name}" \
  | awk '{print $1}'
}

destroy_service(){
  local service="$1"
  local exit_code=1

  while [ "$exit_code" != "0" ]; do
    fleetctl destroy "${service}" 2>&1 \
    | grep 'unit does not exist'
    exit_code=$?
  done
}

get_registers(){
  local directory="$1"
  ls ${directory}/*-register@.service
}

get_sidekicks(){
  local directory="$1"
  ls ${directory}/*-sidekick@.service
}

restart_service(){
  local service="$1"

  destroy_service "${service}" \
  && wait_for_death "${service}" \
  && start_service "${service}"
}

resubmit_file(){
  local filename="$1"
  echo "resubmit_file: ${filename}"

  destroy_service "${filename}"
  wait_for_death "${filename}"
  submit_service "${filename}"
}

rolling_restart(){
  local filename="$1"
  local services=( $(active_services_for_filename "$filename") )
  echo "services: ${services[@]}"

  for service in "${services[@]}"; do
    restart_service "${service}"
  done
}

start_service(){
  local service="$1"
  local exit_code=1

  while [ "$exit_code" != "0" ]; do
    fleetctl start "${service}"
    exit_code=$?
  done
}

submit_service(){
  local service="$1"
  local exit_code=1

  while [ "$exit_code" != "0" ]; do
    fleetctl submit "${service}"
    exit_code=$?
  done
}

wait_for_death(){
  local service="$1"
  local exit_code=0

  while [ "$exit_code" == "0" ]; do
    fleetctl cat "${service}"
    exit_code=$?
  done
}


main(){
  local directory="$1"
  local registers=( $(get_registers "${directory}") )
  local sidekicks=( $(get_sidekicks "${directory}") )
  local filenames=( ${registers[@]} ${sidekicks[@]} )

  for filename in "${filenames[@]}"; do
    echo "updating: ${filename}"
    resubmit_file "${filename}"
    rolling_restart "${filename}"
  done
}
main $@
