#!/bin/bash

fleetctl start \
 vulcand.service \
 octoblu-tentacle-server-etcd-netfw-frontend.service \
 octoblu-tentacle-server-etcd-netfw-backend-blue.service

fleetctl start \
 octoblu-api-octoblu-blue@1.service \
 octoblu-api-octoblu-blue-register@1.service \
 octoblu-api-octoblu-blue-route@1.service \
 octoblu-api-octoblu-blue-healthcheck.service

fleetctl start \
 octoblu-app-octoblu-blue@1.service \
 octoblu-app-octoblu-blue-register@1.service \
 octoblu-app-octoblu-blue-healthcheck.service

fleetctl start \
 octoblu-tentacle-server-blue@1.service \
 octoblu-tentacle-server-blue-register@1.service \
 octoblu-tentacle-server-blue-healthcheck.service

fleetctl start \
 octoblu-triggers-service-blue@1.service \
 octoblu-triggers-service-blue-register@1.service \
 octoblu-triggers-service-blue-healthcheck.service

fleetctl start \
 octoblu-weather-service-blue@1.service \
 octoblu-weather-service-blue-register@1.service \
 octoblu-weather-service-blue-healthcheck.service

fleetctl start \
 octoblu-deployinate-service-blue@1.service \
 octoblu-deployinate-service-blue-register@1.service \
 octoblu-deployinate-service-blue-healthcheck.service

fleetctl start \
 octoblu-stock-service-blue@1.service \
 octoblu-stock-service-blue-register@1.service \
 octoblu-stock-service-blue-healthcheck.service

fleetctl start \
 octoblu-little-bits-cloud-proxy-blue@1.service \
 octoblu-little-bits-cloud-proxy-blue-register@1.service \
 octoblu-little-bits-cloud-proxy-blue-healthcheck.service
