#!/usr/bin/env bash
#
# Script Setup Git
# Copyright (C) 2022 a Renayura <renayura@proton.me>
#

msg() {
	echo
	echo -e "\e[1;32m$*\e[0m"
	echo
}

msg "Starting configurate git"

##----------------------------------------------------------##
# Git Identity
git config --global core.editor "nano"
git config --global user.name "Renayura"
git config --global user.email "renayura@proton.me"
git config --global credential.helper store

##----------------------------------------------------------##
# Git Alias
git config --global alias.c "commit -s"
git config --global alias.cam "commit --am"
git config --global alias.ca "cherry-pick --abort"
git config --global alias.cr "cherry-pick --signoff"
git config --global alias.p "push -f"
git config --global alias.cc "cherry-pick --continue"
git config --global alias.cs "cherry-pick --skip"
git config --global alias.cp "cherry-pick"

##----------------------------------------------------------##
# Setup Change-id hooks
mkdir -p ~/.git-templates/hooks
git config --global init.templatedir '~/.git-templates'
curl -Lo ~/.git-templates/hooks/commit-msg https://raw.githubusercontent.com/Renayura/Scripts/master/commit-msg
chmod u+x ~/.git-templates/hooks/commit-msg
msg "Git configiration succesfully"
