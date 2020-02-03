#!/bin/bash -eu

# Initialise an ansible-playbook project.
playbook_name=$1
if [[ "" == "${playbook_name}" ]]; then
  echo "Set parameter #1: playbook_name";
  exit 1
fi

if ! net session  1>NUL 2>NUL; then
  echo "[ERROR] This script must be run as Administrator"
  exit 1
fi

parentDir="$( basename $(pwd) )";
if [[ ! "${playbook_name}" == "${parentDir}" ]]; then
  if [[ ! -e ${playbook_name}/roles ]]; then
    echo "Create the project directory"
    mkdir -p ${playbook_name}/roles;
  fi
  cd ${playbook_name};
fi

parentDir=$( basename $(pwd) );
if [[ ! "${playbook_name}" == "${parentDir}" ]]; then
  echo "Parent directory must match: ${playbook_name}";
  exit 1
fi

if [[ ! -e .git ]]; then
  echo "Initialise the git repo";
  git init;
fi

helperRoleName=ansible-role.ansible-playbook;
if [[ -e roles/${helperRoleName} ]]; then
  echo "Update the helper submodule role: ${helperRoleName}"
  git pull roles/${helperRoleName};
else
  echo "Add the helper submodule role: ${helperRoleName}"
  git submodule add https://github.com/awltux/${helperRoleName}.git roles/${helperRoleName};
fi

templatesDir=roles/${helperRoleName}/templates/init
cp --recursive --no-clobber ${templatesDir}/* .;

# Install choco
"$(which powershell)" -NoProfile -InputFormat None -ExecutionPolicy Bypass \
                          -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
PATH="${PATH};${ALLUSERSPROFILE}\chocolatey\bin"
# Use Choco to install tools required by this script.
choco install -y vagrant virtualbox jq make
