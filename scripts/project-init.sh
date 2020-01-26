#!/bin/bash
set -e
set -u

# Initialise an ansible-playbook project.

if [[ "" == "${playbook_name}" ]]; then
  echo "Missing environment variable: playbook_name";
  exit 1
fi

projectName=ansible-playbook.${playbook_name} &&\
parentDir=$( basename $(pwd) );
if [[ ! "${projectName}" == "${parentDir}" ]]; then
  if [[ ! -e ${projectName}/roles ]]; then
    echo "Create the project directory"
    mkdir -p ${projectName}/roles;
  fi
  cd ${projectName};
fi

parentDir=$( basename $(pwd) );
if [[ ! "${projectName}" == "${parentDir}" ]]; then
  echo "Parent directory must match: ${projectName}";
  exit 1
fi

echo "Initialise the git repo";
if [[ ! -e .git ]]; then
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

echo "Initialising project with template files"
templatesDir=roles/${helperRoleName}/templates/init
cp --recursive --no-clobber ${templatesDir}/* .; \

