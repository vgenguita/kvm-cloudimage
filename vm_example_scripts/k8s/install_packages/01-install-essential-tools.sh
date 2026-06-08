#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

sudo apt-get update
sudo apt-get --quiet --yes dist-upgrade
sudo apt-get --quiet --yes install git vim curl wget htop tmux jq net-tools rsync bird2 cron
##Bird service is needed for callico
sudo systemctl enable bird.service
sudo systemctl start bird.service
cp $PWD/vm_files/.vimrc ~/.vimrc
cp $PWD/vm_files/.tmux.conf ~/.tmux.conf
