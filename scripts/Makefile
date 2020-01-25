

debug ?= false
env_name ?= vagrant
profile ?=

quiet := @
ifneq ($(debug),false)
  $(info Debug output enabled)
  quiet :=
endif

.DEFAULT_GOAL := help
SHELL = bash

define help_text
Run this in a git BASH console to create a new ansible project:
  if [[ "" == "${playbook_name}" ]]; then \
    echo "Missing environment variable: playbook_name"; \
  else \
    # Create the project directory \
    projectName=ansible-playbook.${playbook_name} &&\
    parentDir=$( basename $(pwd) ) &&\
    if [[ ! "${projectName}" == "${parentDir}" ]]; then \
      if [[ ! -e ${projectName}/roles ]]; then \
        mkdir -p ${projectName}/roles; \
      fi &&\
      cd ${projectName}; \
    fi &&\
    # Initialise the git repo \
    if [[ ! -e .git ]]; then \
      git init; \
    fi &&\
    # Add the helper sub module \
    helperPlaybookName=ansible-role.ansible-playbook; \
    if [[ ! -e roles/${helperPlaybookName} ]]; then \
      git submodule add https://github.com/awltux/${helperPlaybookName}.git roles/${helperPlaybookName}; \
    else \
      git pull roles/${helperPlaybookName}; \
    fi &&\
    # Initialise the project with template files. \
    make -C roles/${helperPlaybookName}/scripts project-init &&\
  fi
endef

.PHONY: help
help:
	@: $(info $(help_text))

.PHONY: list
list:
	$(quiet) \
	make -pRrq | \
	grep '^\([a-zA-Z0-9_-]\+\):.*' | \
	sed 's/^\([a-zA-Z0-9_-]\+\):.*/   \1/'

validate-env-name:
	$(quiet) \
	if [[ "$(env_name)" == "" ]]; then \
	  echo "Makefile parameter is empty: make env_name=vagrant target_name" &&\
	  exit 1; \
	else \
	  if [[ ! -e environments/${env_name}/inventory.ini ]]; then \
	    echo "Makefile parameter env_name need to reference an inventoryfile: environments/${env_name}/inventory.ini" &&\
	    exit 1; \
	  fi \
	fi

# Setup the project uisng default config.
.PHONY: project-init
project-init:
	$(quiet) \
	parentDir=$( basename $(pwd) ) &&\
	roleName=ansible-playbook.${playbook_name} &&\
	if [[ ! "${roleName}" == "${parentDir}" ]]; then \
	  echo "The project-init target must be launched from within the role" &&\
	  exit 1
	fi &&\
	if [[ ! -e ../../../Makefile ]]; then \
	  echo "Initialising project with template files" &&\
	  cp ../templates/init/* ../../..; \
	else \
	  echo "Project already initialised with template files"; \
	fi &&\
	for initDir in "vars" "defaults" "tasks" "group_vars" "environments/$(env_name)"; do \
	  mkdir -p ../../../${initDir}; \
	done

vagrant-up:
	$(quiet) \
	vagrant up

# Setup ssh certs and ansible on the provisioner
ansible-setup:
	$(quiet) \
	# Install python3 \
	# Install ansible if on provisioner

# Run ansible on the provisioner
ansible-deploy:
	$(quiet) \
	
molecule-test:
	$(quiet) \
	# Run molecule unit tests on provisioner using docker

git-pull-origin-master:
	$(quiet) \
	git pull origin master
	
git-push-origin-master:
	$(quiet) \
	git push origin master