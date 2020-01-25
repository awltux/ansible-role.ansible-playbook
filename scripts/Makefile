

debug ?= false

quiet := @
ifneq ($(debug),false)
  $(info Debug output enabled)
  quiet :=
endif

.DEFAULT_GOAL := help
SHELL = bash

define help_text
Create a git project:
  mkdir -p ansible-playbook.playbook_name/roles
  cd ansible-playbook.playbook_name
  git init
  git submodule add https://github.com/awltux/ansible-role.ansible-playbook.git roles/ansible-role.ansible-playbook
  cd roles/ansible-role.ansible-playbook
  make project-init
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

# Copy the template/init files to the root of the project.
.PHONY: project-init
project-init:
	$(quiet) \
	if [[ ! -e ../../../Makefile ]]; then \
	  echo "Initialising project with template files" &&\
	  cp ../templates/init/* ../../..; \
	else \
	  echo "Project already initialised with template files"; \
	fi \
	for initDir in vars defaults tasks group_vars environments/vagrant 
	if [[ ! -e ../../../var ]]; then \

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
