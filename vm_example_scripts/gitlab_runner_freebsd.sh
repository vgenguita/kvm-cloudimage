#!/usr/bin/env sh
#SOURCE: https://docs.gitlab.com/runner/install/

# Exit on error, undefined vars, and pipe failures
set -euo pipefail

#Creating gitlab user
sudo pw group add -n gitlab-runner
sudo pw user add -n gitlab-runner -g gitlab-runner -s /bin/sh
sudo mkdir /home/gitlab-runner
sudo chown gitlab-runner:gitlab-runner /home/gitlab-runner

#Downloading binary and giving permissions
sudo fetch -o /usr/local/bin/gitlab-runner https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/binaries/gitlab-runner-freebsd-amd64
sudo chmod +x /usr/local/bin/gitlab-runner

#Creating logfile and giving permissions
sudo touch /var/log/gitlab_runner.log && sudo chown gitlab-runner:gitlab-runner /var/log/gitlab_runner.log

#Creating rc service
mkdir -p /usr/local/etc/rc.d
sudo sh -c 'cat > /usr/local/etc/rc.d/gitlab_runner' << "EOF"
#!/bin/sh
# PROVIDE: gitlab_runner
# REQUIRE: DAEMON NETWORKING
# BEFORE:
# KEYWORD:

. /etc/rc.subr

name="gitlab_runner"
rcvar="gitlab_runner_enable"

user="gitlab-runner"
user_home="/home/gitlab-runner"
command="/usr/local/bin/gitlab-runner"
command_args="run"
pidfile="/var/run/${name}.pid"

start_cmd="gitlab_runner_start"

gitlab_runner_start()
{
   export USER=${user}
   export HOME=${user_home}
   if checkyesno ${rcvar}; then
      cd ${user_home}
      /usr/sbin/daemon -u ${user} -p ${pidfile} ${command} ${command_args} > /var/log/gitlab_runner.log 2>&1
   fi
}

load_rc_config $name
run_rc_command $1
EOF

sudo chmod +x /usr/local/etc/rc.d/gitlab_runner

echo "Now register a runner and then:"
echo "sudo sysrc gitlab_runner_enable=YES"
echo "sudo service gitlab_runner start"