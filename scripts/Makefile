
define help_text
= Creating an ansible playbook project
Running 'scripts/project-init.sh' in a GIT BASH (MINGW64) console to create 
a new ansible project.
endef

# 2.8 has some useful windows tasks e.g. win_user_profile
ANSIBLE_VERSION := 2.8.1

# Make parameters
debug ?= false
env_name ?= vagrant
profile ?=
project_name ?=

quiet := @
ifneq ($(debug),false)
ifneq ($(debug),)
  $(info Debug output enabled)
  quiet :=
endif
endif

_project_name = $(shell basename $$(pwd))
ifneq ($(project_name),)
_project_name = $(project_name)
endif
$(info project_name = $(_project_name) )

cluster_details_file ?= environments/vagrant/environment.json
inventory_file ?= environments/$(env_name)/inventory.ini

# Use password files in home before target
# If target/.vault_password_file is part if a mounted folder 
# from windows it has a problematic executable bit set.
ifeq ($(shell test -e ~/.vault_password_file && echo -n yes),yes)
VAGRANT_PASSWORD_FILE := ~/.vault_password_file
else
VAGRANT_PASSWORD_FILE = target/.vault_password_file
endif
$(info VAGRANT_PASSWORD_FILE=$(VAGRANT_PASSWORD_FILE))

# Use password files in home before target
# If target/.vault_password_file is part if a mounted folder 
# from windows it has a problematic executable bit set.
ifeq ($(shell test -e ~/.ansible_password_file && echo -n yes),yes)
ANSIBLE_PASSWORD_FILE := ~/.ansible_password_file
else
ANSIBLE_PASSWORD_FILE = target/.ansible_password_file
endif
$(info ANSIBLE_PASSWORD_FILE=$(ANSIBLE_PASSWORD_FILE))


.DEFAULT_GOAL := list

.PHONY: parse_env_details
parse_env_details:
# The jq app may not have been installed yet
ifneq (, $(shell which jq))
provisioner_hostname := $(shell jq '.provisionerHostname' $(cluster_details_file) | sed 's/\"//g' )
local_login := $(shell jq '.localLogin' $(cluster_details_file) | sed 's/\"//g')
# APPLIANCE CONFIG
app_hostname_base := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .hostnameBase?' $(cluster_details_file) | sed 's/\"//g' )
app_addr_start := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .addrStart?' $(cluster_details_file) | sed 's/\"//g' )
endif

# List the makefile targets
.PHONY: list
list:
	$(quiet)make -pRrq | \
	grep '^\([a-zA-Z0-9_-]\+\):.*' | \
	sed 's/^\([a-zA-Z0-9_-]\+\):.*/   \1/'

.PHONY: help
help:
	@: $(info $(help_text))

# Validate that the env_name property is defined and points to a valid environment file.
.PHONY: validate-env-name
validate-env-name:
	$(quiet)if [[ "$(env_name)" == "" ]]; then \
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
	$(quiet)if [[ "$(profile)" == "" ]]; then \
	  echo "Parameter 'profile' is empty: make profile=default ..." &&\
	  exit 1; \
	else \
	  profileFile=profiles/${profile}/main.yml; \
	  if [[ ! -e $${profileFile} ]]; then \
	    echo "Parameter 'profile' has no file: $${profileFile}" &&\
	    exit 1; \
	  fi \
	fi

# Docker Desktop conflicts with Virtualbox; must disable Microsoft VM system
# On Windows install gnuwin32 version of make
# http://gnuwin32.sourceforge.net/packages/make.htm
.PHONY: vagrant-up
vagrant-up: parse_env_details vagrant-ansible-passwords
	$(quiet)( \
	if ! (vagrant plugin list | grep -q vagrant-vbguest); then \
	  echo "#################################################" &&\
	  echo "## INSTALL VAGRANT PLUGIN: VirtualBox Guest installer" &&\
	  echo "#################################################" &&\
	  vagrant plugin install vagrant-vbguest; \
	fi &&\
	echo "#################################################" &&\
	echo "## RUNNING VAGRANT UP" &&\
	echo "#################################################" &&\
	vagrant up \
	) || exit 1

# Run just the ansible provisioning on the jumpbox VM
.PHONY: vagrant-reload
vagrant-reload: parse_env_details vagrant-ansible-passwords
	@( vagrant ssh -c \
	"if [[ ! -e /etc/ansible/.bootstrapped ]]; then \
		sudo -u $(local_login) bash -c 'ssh-keyscan $(app_hostname_base)-$(app_addr_start) | \
		grep ecdsa-sha2 > ~$(local_login)/.ssh/known_hosts &&\
		chmod 600 ~$(local_login)/.ssh/known_hosts'; \
	fi" $(provisioner_hostname) &&\
	vagrant reload --provision $(provisioner_hostname) ) || exit 1


# Setup ssh certs and ansible on the provisioner
.PHONY: ansible-setup
ansible-setup:
	$(quiet)# Install python3 \
	# Install ansible if on provisioner

# Run ansible on the provisioner
.PHONY: ansible-deploy
ansible-deploy:
	$(quiet):

.PHONY: molecule-test
molecule-test:
	$(quiet)# Run molecule unit tests on provisioner using docker

# Pull the project and any submodules is has
.PHONY: git-pull-origin-master
git-pull-origin-master:
	$(quiet)git pull origin master

# Push the project and any submodules is has
.PHONY: git-push-origin-master
git-push-origin-master:
	$(quiet)git push origin master

# Copy the password files from the windows home directory to the projects target dir
.PHONY: vagrant-ansible-passwords
vagrant-ansible-passwords:
	$(quiet)vault_file=~/.vault_password_file &&\
	vault_target_file="target/.vault_password_file" &&\
	if [[ -e $${vault_file} ]]; then \
		if [[ ! -e $${vault_target_file} ]]; then \
			echo "[Makefile.$@] Copying password file: $${vault_file}" &&\
			mkdir -p target &&\
			cp $${vault_file} target/; \
		fi; \
	else \
		echo "[ERROR] Missing password file: `hostname`:$${vault_file}" &&\
		exit 1; \
	fi &&\
	ansible_file=~/.ansible_password_file &&\
	ansible_target_file="target/.ansible_password_file" &&\
	if [[ -e $${ansible_file} ]]; then \
		if [[ ! -e $${ansible_target_file} ]]; then \
			echo "[Makefile.$@] Copying password file: $${ansible_file}" &&\
			mkdir -p target &&\
			cp $${ansible_file} target/; \
		fi; \
	else \
		echo "[ERROR] Missing password file: `hostname`:$${ansible_file}" &&\
		exit 1; \
	fi

.PHONY: windows-needs-admin
windows-needs-admin:
	$(quiet)if net session  1>NUL 2>NUL; then \
	  echo "Have Admin rights"; \
	else \
	  echo "Need admin rights" &&\
	  exit 1; \
	fi

.PHONY: project-init
project-init:
	$(quiet)bash ./roles/ansible-role.ansible-playbook/scripts/project-init.sh "$(_project_name)"
	
# If the inventory file is missing for the requested environment, create 
# a simple one from the clusterDetails.json
.PHONY: create-inventory
create-inventory: linux-bootstrap
	@echo "[Makefile.$@] Create an Ansible inventory file" && \
	source $(create_inventory_script) "$(cluster_details_file)" "$(env_name)" "$(inventory_file)"

# Install:
#   jq: to allow 'make' and 'bash' to interpret JSON
#   sshpass: needed by ansible to connect over ssh
#   ansible: from pip becuase yum version has out of date dependencies
#   dnspython: allows hostnames to be resolved by ansible
.PHONY: linux-bootstrap
linux-bootstrap:
	# FIXME: Need to add username=$(ldap_login) and password=$(ANSIBLE_PASSWORD_FILE) to /etc/yum.conf: [main] section
	@( sudo yum install -y epel-release &&\
	sudo yum install -y libselinux-python python3 python3-pip jq sshpass &&\
	sudo su - root -c "pip3 install --upgrade pip" &&\
	sudo su - root -c "pip3 install ansible==$(ANSIBLE_VERSION) dnspython requests pywinrm netaddr jmespath selinux" ) || exit 1

# The provisioner provides Docker and GECK so ansible must be run native on linux.
.PHONY: linux-provisioner
linux-provisioner: linux-bootstrap
	@( echo "[Makefile.$@] Apply provisioner ansible-playbook" && \
	export ANSIBLE_FORCE_COLOR=true && \
	ansible-playbook \
	--inventory $(inventory_file) \
	--vault-id=$(VAGRANT_PASSWORD_FILE) \
	-e env_name='$(env_name)' \
	provisioner.playbook 2>&1 ) || ( export RETURN_CODE=$$? && echo "linux-provisioner RC: $$RETURN_CODE"; exit $$RETURN_CODE )
#	ansible-playbook.provisioner.yml 2>&1 | tee $(log_dir)/$@.log 
  
# Initialises a host before it has docker and geck installed
.PHONY: linux-appliance
linux-appliance: linux-bootstrap
	export ANSIBLE_FORCE_COLOR=true && \
	ansible-playbook \
	--inventory $(inventory_file) \
	--vault-id=$(VAGRANT_PASSWORD_FILE) \
	-e env_name='$(env_name)' \
	appliance.playbook 2>&1 | tee $(log_dir)/$@.log || exit 1

