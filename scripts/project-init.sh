#!/bin/bash -eux

# Initialise an ansible-playbook project.
playbook_name=$1
if [[ "" == "${playbook_name}" ]]; then
  echo "Set parameter #1: playbook_name";
  exit 1
fi

if ! net session >/dev/null; then
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
  git submodule init roles/${helperRoleName};
fi

templatesDir=roles/${helperRoleName}/templates/init
echo "Copy the project files from: ${templatesDir}"
cp --recursive --no-clobber ${templatesDir}/* ./;

if ! [ -x "$(command -v choco)" ]; then
  echo "Install choco using powershell"
  "$(which powershell)" -NoProfile -InputFormat None -ExecutionPolicy Bypass \
                          -Command "[Net.ServicePointManager]::SecurityProtocol = \"tls12, tls11, tls\"; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
fi

PATH="${PATH};${ALLUSERSPROFILE}\\chocolatey\\bin"
echo "Use Choco to install tools required by this script"
if ! [ -x "$(command -v vagrant)" ]; then
  echo "Install vagrant using powershell"
  choco install -y vagrant
fi
if ! [ -x "$(command -v virtualbox)" ]; then
  echo "Install virtualbox using powershell"
  choco install -y  virtualbox  
fi
if ! [ -x "$(command -v jq)" ]; then
  echo "Install jq using powershell"
  choco install -y   jq 
fi
if ! [ -x "$(command -v make)" ]; then
  echo "Install make using powershell"
  choco install -y    make
fi
