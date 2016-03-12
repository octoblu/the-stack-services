#!/bin/bash

active_services_for_filename(){
  local path="$1"
  local filename="$(basename "${path}")"
  local service_name="$(echo "$filename" | sed -e 's/\.service$//')"

  fleetctl list-units \
  | grep "${service_name}" \
  | awk '{print $1}'
}

get_registers_with_after(){
  grep -lR 'After' **/*-register@.service
}

get_sidekicks_with_after(){
  grep -lR 'After' **/*-sidekick@.service
}

restart_service(){
  local service="$1"

  fleetctl destroy "${service}" \
  && wait_for_death "${service}" \
  && fleetctl start "${service}"
}

resubmit_file(){
  local filename="$1"

  fleetctl destroy "${filename}" \
  && fleetctl submit "${filename}"
}

rolling_restart(){
  local filename="$1"
  local services=( $(active_services_for_filename "$filename") )

  for service in "${services[@]}"; do
    restart_service "${service}"
  done
}

strip_after_this_file(){
  local filename="$1"

  sed -i '' -e 's/After=.*$//g' "$filename"
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
  local registers_with_after=( $(get_registers_with_after) )
  local sidekicks_with_after=( $(get_sidekicks_with_after) )
  local files_with_after=( ${registers_with_after[@]} ${sidekicks_with_after[@]} )

  for filename in "${files_with_after[@]}"; do
    echo "updating: ${filename}"
    strip_after_this_file "${filename}"
    resubmit_file "${filename}"
    rolling_restart "${filename}"
  done
}
main $@
