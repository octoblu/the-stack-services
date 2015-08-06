#!/bin/bash

fleetctl list-unit-files -no-legend -fields unit | xargs fleetctl destroy

echo "murdering docker"
for CONTAINER in "$(docker ps --quiet)"; do
  docker kill $CONTAINER > /dev/null
done



etcdctl rm --recursive /octoblu &> /dev/null
etcdctl rm --recursive /docker &> /dev/null
etcdctl rm --recursive /meshblu &> /dev/null
etcdctl rm --recursive /vulcand &> /dev/null
