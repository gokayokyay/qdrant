#!/bin/bash

set -ex

# Ensure current path script dir
cd "$(dirname "$0")/"

function clear_after_tests()
{
  docker-compose down
}

# Prevent double building in docker-compose
docker build --secret id=REGION --secret id=ACCESS_KEY --secret id=SECRET_KEY --secret id=BUCKET_NAME --secret id=ENDPOINT ../../ --tag=qdrant_consensus
docker-compose up -d --force-recreate
trap clear_after_tests EXIT

# Wait for service to start
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:6433)" != "200" ]]; do
  sleep 1;
done

