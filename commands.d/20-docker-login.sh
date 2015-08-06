#!/bin/bash

docker login \
  --username $(etcdctl get /docker/quay.io/username) \
  --password $(etcdctl get /docker/quay.io/password) \
  --email $(etcdctl get /docker/quay.io/email) \
  quay.io

docker login \
  --username $(etcdctl get /docker/index.docker.io/username) \
  --password $(etcdctl get /docker/index.docker.io/password) \
  --email $(etcdctl get /docker/index.docker.io/email)
