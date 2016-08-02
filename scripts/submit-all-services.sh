#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"

try_submit() {
  local file_path="$1"
  echo "* trying to submit $file_path"
  local lines="$(fleetctl submit "$file_path")"
  local line_count=$(echo "$lines" | wc -l | xargs)
  if [ "$line_count" != "1" ]; then
    echo "* response $lines"
    echo "* trying again"
    sleep 1
    try_submit "$file_path"
  else
    echo '* submitted'
  fi
}

main() {
  local services_path="$PROJECT_DIR/services.d"
  local services=( $(find $services_path -type d -maxdepth 1) )
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
      try_submit "$file_path"
    done
  done
}

main "$@"
