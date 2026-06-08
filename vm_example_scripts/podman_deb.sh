#!/usr/bin/env bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

apt-get update
apt-get -y install podman buildah