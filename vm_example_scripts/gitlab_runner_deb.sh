#!/usr/bin/env bash
#SOURCE: https://about.gitlab.com/install/#debian

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive 
# cat <<EOF | tee /etc/apt/preferences.d/pin-gitlab-runner.pref
# Explanation: Prefer GitLab provided packages over the Debian native ones
# Package: gitlab-runner
# Pin: origin packages.gitlab.com
# Pin-Priority: 1001
# EOF
apt-get update
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | bash
apt-get -y install gitlab-runner