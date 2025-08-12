#!/usr/bin/env bash

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

dnf update
dnf -y install podman buildah