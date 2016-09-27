#!/bin/bash

DEBUG_KEY='check-for-rebooting-machines'

debug() {
  if [ -z "$DEBUG" ]; then
    return 0
  fi
  local message="$1"
  echo "$DEBUG_KEY: $message"
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

get_service_instances() {
  local tag="$1"
  local region="$AWS_REGION"
  if [ -z "$region" ]; then
    region='us-west-2'
  fi
  aws ec2 describe-instances --region="$region" --filters "Name=tag:Name,Values=$tag" | jq --compact-output  '.Reservations[].Instances[]'
}

test_ssh() {
  local public_ip="$1"
  ssh -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q core@$public_ip exit
}

usage(){
  echo 'USAGE: check-for-rebooting-machines.sh <ec2-tag>'
  echo ''
  echo 'Arguments:'
  echo '  -h, --help         print this help text'
  echo '  -v, --version      print the version'
  echo 'Enviroment:'
  echo '  AWS_REGION: defaults to us-west-2'
  echo ''
}

version(){
  echo "1.0.0"
}

main() {
  local tag="$1"
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
      *)
        if [ "${param::1}" == '-' ]; then
          echo "ERROR: unknown parameter \"$param\""
          usage
          exit 1
        fi
        if [ -n "$param" ]; then
          tag="$param"
        fi
        ;;
    esac
    shift
  done

  if [ -z "$tag" ]; then
    echo "Missing EC2 instance tag as first argument"
    usage
    exit 1
  fi

  local service_instances=( $(get_service_instances "$tag") )
  for service_instance in "${service_instances[@]}"; do
    local public_ip="$(echo "$service_instance" | jq -r '.PublicIpAddress')"
    local private_ip="$(echo "$service_instance" | jq -r '.PrivateIpAddress')"
    if [ -z "$public_ip" -o -z "$private_ip" ]; then
      continue;
    fi
    echo "public ip $public_ip"
    echo "private ip $private_ip"
    if [ "$private_ip" == "$private_ip" ]; then
      test_ssh "$public_ip"
      local ssh_exit_code=$?
      if [ "$ssh_exit_code" != "0" ]; then
        echo "OH NO! I can't ssh into $private_ip $public_ip"
      fi
      sleep 1
    fi
  done
}

main "$@"
