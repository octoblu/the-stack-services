#!/bin/bash
echo 'starting octoblu-alexa-service-register@1'
fleetctl start octoblu-alexa-service-register@1

echo 'starting octoblu-alexa-service-register@2'
fleetctl start octoblu-alexa-service-register@2

echo 'starting octoblu-alexa-service-sidekick@1'
fleetctl start octoblu-alexa-service-sidekick@1

echo 'starting octoblu-alexa-service-sidekick@2'
fleetctl start octoblu-alexa-service-sidekick@2

echo 'starting octoblu-alexa-service@1'
fleetctl start octoblu-alexa-service@1

echo 'starting octoblu-alexa-service@2'
fleetctl start octoblu-alexa-service@2

