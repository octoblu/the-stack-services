#!/bin/bash

PROJECT_DIR="$HOME/Projects/Octoblu/the-stack-services"

main() {
  env COMMAND_SLEEP=5 "$PROJECT_DIR/scripts/run-on-services.sh" 'destroy,start'
}

main "$@"
