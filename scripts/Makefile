
define help_text
= Creating an ansible playbook project
Running 'scripts/project-init.sh' in a GIT BASH (MINGW64) console to create 
a new ansible project.
endef

# 2.8 has some useful windows tasks e.g. win_user_profile
ansible_version := 2.8.1

# Make parameters
debug ?= false
env_name ?= vagrant
profile ?=
project_name ?=
log_dir ?= target
ssh_config_file = target/ssh.config

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

$(info env_name=$(env_name))

cluster_details_file ?= environments/$(env_name)/environment.json
ifneq ($(shell test -e environments/$(env_name)/environment.json && echo -n yes),yes)
cluster_details_file ?= environments/environment.json
endif
$(info cluster_details_file=$(cluster_details_file))
inventory_file ?= environments/$(env_name)/inventory.ini

# Use password files in home before target
# If target/.vault_password_file is part if a mounted folder 
# from windows it has a problematic executable bit set.
ifeq ($(shell test -e ~/.vault_password_file && echo -n yes),yes)
vault_password_file := ~/.vault_password_file
else
vault_password_file = target/.vault_password_file
endif
$(info vault_password_file=$(vault_password_file))

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

# List the makefile targets
.PHONY: list
list:
	$(quiet)make -pRrq | \
	grep '^\([a-zA-Z0-9_-]\+\):.*' | \
	sed 's/^\([a-zA-Z0-9_-]\+\):.*/   \1/' | \
	sort

.PHONY: help
help:
	@: $(info $(help_text))

.PHONY: mkdir_target
mkdir_target:
	$(quiet)mkdir -p target

.PHONY: load-node-data
load-node-data:
# The jq app may not have been installed yet
ifneq (,$(shell which jq))
local_login          := $(shell jq '.localLogin' $(cluster_details_file) | sed 's/\"//g')
# PROVISIONER CONFIG
prov_hostname_base   := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .hostnameBase?' $(cluster_details_file) | sed 's/\"//g' )
prov_addr_start      := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .addrStart?' $(cluster_details_file) | sed 's/\"//g' )
provisioner_hostname := $(prov_hostname_base)-$(prov_addr_start)
# APPLIANCE CONFIG
app_hostname_base    := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .hostnameBase?' $(cluster_details_file) | sed 's/\"//g' )
app_addr_start       := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .addrStart?'    $(cluster_details_file) | sed 's/\"//g' )
app_node_count       := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .nodeCount?'    $(cluster_details_file) | sed 's/\"//g' )
endif

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
vagrant-up: load-node-data
	$(quiet) time ( \
	if ! (vagrant plugin list | grep -q vagrant-vbguest); then \
	  echo "#################################################" &&\
	  echo "## INSTALL VAGRANT PLUGIN: VirtualBox Guest installer" &&\
	  echo "#################################################" &&\
	  vagrant plugin install vagrant-vbguest; \
	fi &&\
	echo "#################################################" &&\
	echo "## RUNNING VAGRANT UP" &&\
	echo "#################################################" &&\
	vagrant up &&\
	echo "#################################################" &&\
	echo "## Extracting SSH config to file: $(ssh_config_file)" &&\
	echo "#################################################" &&\
	mkdir -p target &&\
	vagrant ssh-config $(provisioner_hostname) > $(ssh_config_file) \
	) || exit 1

# Run just the ansible provisioning on the jumpbox VM
# If provisioner hasnt been previously bootstrapped, add the host key to .ssh/known_hosts 
.PHONY: vagrant-reload
vagrant-reload: load-node-data
	$(quiet) time ( \
	( if [[ ! -e $(ssh_config_file) ]]; then echo "Run 'make vagrant-up' to generate ssh connection file: $(ssh_config_file)" && exit 1; fi ) &&\
	ssh -F $(ssh_config_file) $(provisioner_hostname) \
	"if [[ ! -e /etc/ansible/linux-provisioner ]]; then \
		sudo -u $(local_login) bash -c \
			'ssh-keyscan $(provisioner_hostname) | grep ecdsa-sha2 > ~$(local_login)/.ssh/known_hosts && chmod 600 ~$(local_login)/.ssh/known_hosts' &&\
		if [[ $(app_node_count) -gt 0 ]]; then \
			app_node_max=$$(( $(app_node_count) - 1 )) &&\
			app_node_seq=\$$(seq 0 \$${app_node_max}); \
			for app_index in \$${app_node_seq}; do \
				app_node_index=\$$(( $(app_addr_start) + \$${app_index} )) &&\
				app_hostname=\"$(app_hostname_base)-\$${app_node_index}\" &&\
				sudo -u $(local_login) bash -c \
				  \"ssh-keyscan \$${app_hostname} | grep ecdsa-sha2 >> ~$(local_login)/.ssh/known_hosts && chmod 600 ~$(local_login)/.ssh/known_hosts\"; \
			done \
		fi \
	fi" &&\
	echo "#################################################" &&\
	echo "## Running 'vagrant reload --provision $(provisioner_hostname)" &&\
	echo "#################################################" &&\
	vagrant reload --provision $(provisioner_hostname) \
	) || exit 1

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
	$(quiet)( \
	flag_dir=/etc/ansible &&\
	flag_file=$${flag_dir}/$@ &&\
	if [[ ! -e $${flag_file} ]]; then \
	  sudo yum install -y epel-release &&\
	  sudo yum -y update &&\
	  sudo yum install -y libselinux-python python3 python3-pip jq sshpass &&\
	  sudo su - root -c "pip3 install --upgrade pip" &&\
	  sudo su - root -c "pip3 install ansible==$(ansible_version) dnspython requests pywinrm netaddr jmespath selinux" &&\
	  sudo mkdir -p $${flag_dir} &&\
	  sudo touch $${flag_file}; \
	else \
	  echo "[SKIPPING linux-bootstrap] Found $(hostname):$${flag_file}"; \
	fi \
	) || exit 1

# The provisioner provides Docker and GECK so ansible must be run native on linux.
.PHONY: linux-provisioner
linux-provisioner: linux-bootstrap
	$(quiet)( echo "[Makefile.$@] Apply ansible playbook for provisioner: $${USER}" && \
	export ANSIBLE_FORCE_COLOR=true && \
	ansible-playbook \
	--inventory $(inventory_file) \
	--vault-id=$(vault_password_file) \
	-e env_name="$(env_name)" \
	provisioner.playbook 2>&1 | tee $(log_dir)/$@.log ) || ( export RETURN_CODE=$$? && echo "$@ RC: $$RETURN_CODE"; exit $$RETURN_CODE )

  
# Initialises a host before it has docker and geck installed
.PHONY: linux-appliance
linux-appliance:
	$(quiet)( echo "[Makefile.$@] Apply ansible playbook for appliance " && \
	export ANSIBLE_FORCE_COLOR=true && \
	ansible-playbook \
	--inventory $(inventory_file) \
	--vault-id=$(vault_password_file) \
	-e env_name="$(env_name)" \
	appliance.playbook 2>&1 | tee $(log_dir)/$@.log ) || ( export RETURN_CODE=$$? && echo "$@ RC: $$RETURN_CODE"; exit $$RETURN_CODE )

check-vault-password-file:
	$(quiet)if [[ ! -e $(vault_password_file) ]]; then \
	  echo "[ERROR] Missing file: $(vault_password_file)" && \
	  exit 1; \
	fi

# LINUX ONLY: This command will only work on a Linux host i.e. provisioner
# Passwords used by the scripts are stored in an encrypted vault file called vault/credentials.yml
# If you dont know the devops password to this file, you will need to create a new one.
# This target will try to extract all yml files under the vault directory and stores them 
# in an unencrypted file target/credentials.yml. 
# The file ansible.cfg declares the location of the vault password file e.g. 
#    ${HOME}/.vault_password_file. 
# If this password doesn't unlock the vault files, a template file will be copied to target/credentials.yml.
# Once extracted, modify target/credentials.yml and then call "make vault-encrypt" to update the encrypted vault file.
vault-decrypt: check-vault-password-file
	$(quiet)if ! ( ansible-vault --vault-password-file=$(vault_password_file) view vault/*.yml > target/credentials.yml ); then \
	  echo "[TO FIX THIS] Modify target/credentials.yml then use 'make vault_encrypt'" && \
	  cp roles/ansible-role.ansible-playbook/templates/credentials.yml target/credentials.yml; \
	fi;

# LINUX ONLY: This command will only work on a Linux host i.e. provisioner
# Encrypts the contents of target/credentials.yml to replace vault/credentials.yml
# The file ansible.cfg declares the location of the vault password file e.g. 
#    ${HOME}/.vault_password_file. 
vault-encrypt: check-vault-password-file
	$(quiet)( ansible-vault --vault-password-file=$(vault_password_file) encrypt --output target/credentials-encrypted.yml target/credentials.yml ) && \
	cp target/credentials-encrypted.yml vault/credentials.yml && \
	rm -f target/credentials-encrypted.yml target/credentials.yml