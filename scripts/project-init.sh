#!/bin/bash
set -e
set -u

# Initialise an ansible-playbook project.
which echo
function print_help() {
cat <<HEREDOC
Initialising vagrant project
Run it HOME to create a new project
Run it project directory to populate new project
PARAM #1: The name of the Project Directory
Run directly from git:
  \$(bash <\$(curl -s https://raw.githubusercontent.com/awltux/ansible-role.ansible-playbook/master/scripts/project-init.sh))
HEREDOC
}

if [[ $# -eq 1 ]]; then
  playbook_name=$1
  if [[ -z "${playbook_name}" ]]; then
    echo "Parameter #1 is an empty string: playbook_name"
	print_help
    exit 1
  fi
else
  echo "PARAM #1 is missing: playbook_name"
  print_help
  exit 1
fi

if ! net session 2>/dev/null; then
  echo "[ERROR] This script installs software packages and must therefore be run as Administrator"
  print_help
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
  print_help
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

cat > .gitignore <<HEREDOC
.vagrant
target
HEREDOC
 
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
 
 
 