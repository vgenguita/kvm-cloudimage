#!/usr/bin/env bash
#SOURCE: https://docs.gitlab.com/runner/install/

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh" | sudo bash
sudo dnf -Y install gitlab-runner