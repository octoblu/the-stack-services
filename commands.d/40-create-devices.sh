#!/bin/bash

source ${CONFIG_DIR}/env

LITTLE_BITS_PROXY_UUID=`etcdctl get /octoblu/little-bits-cloud-proxy/env/MESHBLU_UUID 2>/dev/null`

if [ -z ${LITTLE_BITS_PROXY_UUID} ]; then
  JSON_FILE=/tmp/little-bits-cloud-proxy.json
  meshblu-util register -s ${MESHBLU_HOST}:${MESHBLU_PORT} -t 'proxy:little-bits-cloud' > ${JSON_FILE}
  meshblu-util keygen ${JSON_FILE}
  etcdctl set /octoblu/little-bits-cloud-proxy/env/MESHBLU_UUID $(jq -r '.uuid' ${JSON_FILE})
  etcdctl set /octoblu/little-bits-cloud-proxy/env/MESHBLU_TOKEN $(jq -r '.token' ${JSON_FILE})
  jq -r '.privateKey' ${JSON_FILE} | tr -d "\\n" | etcdctl set /octoblu/little-bits-cloud-proxy/env/MESHBLU_PRIVATE_KEY
fi
