

# Make parameters
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
= Creating an ansible playbook project
Running 'scripts/project-init.sh' in a GIT BASH (MINGW64) console to create 
a new ansible project.
endef

.PHONY: help
help:
	@: $(info $(help_text))

# List the makefile targets
.PHONY: list
list:
	$(quiet) \
	make -pRrq | \
	grep '^\([a-zA-Z0-9_-]\+\):.*' | \
	sed 's/^\([a-zA-Z0-9_-]\+\):.*/   \1/'

# Validate that the env_name property is defined and points to a valid environment file.
.PHONY: validate-env-name
validate-env-name:
	$(quiet) \
	if [[ "$(env_name)" == "" ]]; then \
	  echo "Parameter 'env_name' is empty: make env_name=vagrant ..." &&\
	  exit 1; \
	else \
	  inventoryFile=environments/${env_name}/inventory.ini; \
	  if [[ ! -e $${inventoryFile} ]]; then \
	    echo "Parameter 'env_name' has no file: $${inventoryFile}" &&\
	    exit 1; \
	  fi \
	fi

# Validate that the env_name property is defined and points to a valid environment file.
.PHONY: validate-profile
validate-profile:
	$(quiet) \
	if [[ "$(profile)" == "" ]]; then \
	  echo "Parameter 'profile' is empty: make profile=default ..." &&\
	  exit 1; \
	else \
	  profileFile=profiles/${profile}/main.yml; \
	  if [[ ! -e $${profileFile} ]]; then \
	    echo "Parameter 'profile' has no file: $${profileFile}" &&\
	    exit 1; \
	  fi \
	fi

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