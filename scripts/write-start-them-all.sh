#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"
START_THEM_ALL="$PROJECT_DIR/scripts/start-them-all.sh"

write_to_script() {
  local service_name="$1"
  echo "echo 'starting $service_name'" >> "$START_THEM_ALL"
  echo "fleetctl start ${service_name}" >> "$START_THEM_ALL"
  echo "" >> "$START_THEM_ALL"
}

main() {
  local services_path="$PROJECT_DIR/services.d"
  local services=( $(find $services_path -type d -maxdepth 1 -iname '*alexa*') )
  mkdir -p "$(dirname $START_THEM_ALL)"
  echo '#!/bin/bash' > "$START_THEM_ALL"
  chmod +x "$START_THEM_ALL"
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
        write_to_script "${file_name}1"
        write_to_script "${file_name}2"
      else
        write_to_script "$file_name"
      fi
    done
  done
}

main "$@"
