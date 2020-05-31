
define help_text
= Creating an ansible playbook project
Running 'scripts/project-init.sh' in a GIT BASH (MINGW64) console to create 
a new ansible project.

Default env_name = vagrant-virtualbox
Create default environment VMs with debug enabled at level 1: 
    make debug=1 vagrant-up

Reload changes to the Vagrantfile in default environment VMs:
    make vagrant-reload

Deploy ansible playbook to vagrant VM's using ssh connection:
    make vagrant-deploy

endef

# 2.8 has some useful windows tasks e.g. win_user_profile
ansible_version := 2.8.1

# Make parameters
debug ?= 0
env_name ?= vagrant-virtualbox
# Used by vagrant-box-* targets to determine which node_group to use
# [APPLIANCE, provisioner]
vagrant_node_group ?= appliance
# These variables can be used to build from a specific Vagrant image.
# e.g. from the previous production build to test for upgrade issues.
app_image_name ?= 
app_image_version ?=

# A profile can define a particular setup e.g. ansible tags, updates etc.
profile ?=

# Location to keep the log files
log_dir ?= target

gitRemoteBranch ?= origin/master

# Store ssh config details (generated during vagarnt-up) used by vagrant-reload to speed up connections
ssh_config_file = target/ssh.config

quiet := @
ansible_debug :=
VAGRANT_LOG :=
ifneq ($(debug),0)
ifneq ($(debug),)
$(info Debug output enabled at level $(debug))
# create the verbose flag for the ansible command
ansible_debug = -$(shell printf "%0.sv" {1..$(debug)} )
quiet =
ifeq ($(debug),1)
  VAGRANT_LOG=error
endif
ifeq ($(debug),2)
  VAGRANT_LOG=warn
endif
ifeq ($(debug),3)
  VAGRANT_LOG=info
endif
ifeq ($(debug),4)
  VAGRANT_LOG=info
endif
ifeq ($(debug),5)
  VAGRANT_LOG=debug
endif
endif
endif

# Only used with project-init to identify the project directory name.
project_name ?=
_project_name = $(shell basename $$(pwd))
ifneq ($(project_name),)
_project_name = $(project_name)
endif
$(info project_name=$(_project_name) )

environments_file ?= environments/$(env_name)/environment.json
ifneq ($(shell test -e environments/$(env_name)/environment.json && echo -n yes),yes)
environments_file ?= environments/environment.json
endif
$(info environments_file=$(environments_file))

inventory_file ?= environments/$(env_name)/inventory.ini
$(info Ansible inventory_file=$(inventory_file))

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
$(info vagrant_node_group=$(vagrant_node_group))

.DEFAULT_GOAL := list

# List the makefile targets
.PHONY: list
list:
	$(quiet)make -pRrq | \
	grep '^[a-zA-Z0-9_-]\+:.*' | \
	grep -v '^makefile:.*' | \
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
local_login          := $(shell jq '.localLogin' $(environments_file) | sed 's/\"//g')
vm_provider          := $(shell jq '.vmProvider' $(environments_file) | sed 's/\"//g')
# PROVISIONER CONFIG
pro_hostname_base   := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .images[1].imageName?' $(environments_file) | sed 's/\"//g' )
pro_addr_start      := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .addrStart?' $(environments_file) | sed 's/\"//g' )
pro_hostname        := $(pro_hostname_base)-$(pro_addr_start)
pro_image_name      := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .images[1].imageName?' $(environments_file) | sed 's/\"//g' )
pro_image_version   := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .images[1].imageVersion?' $(environments_file) | sed 's/\"//g' )
#pro_build_version := $(shell jq '.nodeGroups[] | select(.nodeGroup == "provisioner") | .buildVersion?' $(environments_file) | sed 's/\"//g' )
# APPLIANCE CONFIG
app_hostname_base    := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .images[1].imageName?' $(environments_file) | sed 's/\"//g' )
app_addr_start       := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .addrStart?'    $(environments_file) | sed 's/\"//g' )
app_node_count       := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .nodeCount?'    $(environments_file) | sed 's/\"//g' )
app_hostname        := $(app_hostname_base)-$(app_addr_start)
ifndef app_image_name
# image hasn't been set on command line; extract from file
app_image_name := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .images[1].imageName?' $(environments_file) | sed 's/\"//g' )
endif
ifndef app_image_version
# version hasn't been set on command line; extract from file
app_image_version := $(shell jq '.nodeGroups[] | select(.nodeGroup == "appliance") | .images[1].imageVersion?' $(environments_file) | sed 's/\"//g' )
endif
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

# Validate that the profile property is defined and points to a valid profile definition file.
.PHONY: validate-profile
validate-profile:
	$(quiet)if [[ "$(profile)" == "" ]]; then \
	  echo "Parameter 'profile' is empty: make profile=default ..." &&\
	  exit 1; \
	else \
	  profileFile=profiles/$(profile)/main.yml; \
	  if [[ ! -e $${profileFile} ]]; then \
	    echo "Parameter 'profile' doesn't resolve to valid file: $${profileFile}" &&\
	    exit 1; \
	  fi \
	fi

# Docker Desktop conflicts with Virtualbox; must disable Microsoft VM system
# On Windows install gnuwin32 version of make
# http://gnuwin32.sourceforge.net/packages/make.htm
# Restart the VM's and apply any configuration to support ansible deploy 
.PHONY: vagrant-up
vagrant-up: load-node-data
	$(quiet) time ( \
	if ! (env_name=$(env_name) vagrant plugin list | grep -q vagrant-vbguest); then \
	  echo "#################################################" &&\
	  echo "## INSTALL VAGRANT PLUGIN: VirtualBox Guest installer" &&\
	  env_name=$(env_name) vagrant plugin install vagrant-vbguest; \
	fi &&\
	PROVISION_FLAG='' &&\
	INSTALLED_BOX_COUNT=`vagrant box list | grep "$(pro_image_name)[ ]\+($(vm_provider), 0)" | wc -l` &&\
	if [[ $${INSTALLED_BOX_COUNT} -eq 0 ]]; then \
	  PROVISION_FLAG='--provision'; \
	fi &&\
	echo "#################################################" &&\
	echo "## RUNNING VAGRANT UP" &&\
	debug=$(debug) env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant up $${PROVISION_FLAG}&&\
	echo "#################################################" &&\
	echo "## Extracting vagrant SSH config to file: $(ssh_config_file)" &&\
	mkdir -p target &&\
	env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant ssh-config $(pro_hostname) > $(ssh_config_file) \
	) || exit 1

# Restart the VM's and apply any configuration to support ansible deploy 
.PHONY: vagrant-reload
vagrant-reload: load-node-data
	$(quiet) time ( \
	( \
	if [[ ! -e $(ssh_config_file) ]]; then \
		echo "Run 'make vagrant-up' to generate ssh connection file: $(ssh_config_file)" &&\
		exit 1; \
	fi ) &&\
	echo "#################################################" &&\
	echo "## Running 'debug=$(debug) env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant reload --provision" &&\
	debug=$(debug) env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant reload --provision \
	) || exit 1


.PHONY: vagrant-box-setup
vagrant-box-setup: load-node-data
BUILD_NUMBER ?= 0
# SETUP FOR VAGRANT_UPLOAD
artifactory_base_url := artifactory.local.example.com/artifactory
vagrant_repo_url := $(artifactory_base_url)/vagrant-local
vagrant_api_url := $(artifactory_base_url)/api/vagrant
vagrant_server_url := https://$(vagrant_api_url)/vagrant-local
vagrant_auth_url := $(vagrant_api_url)/auth
# SETUP FOR vagrant-box-upload and vagrant-box-download
ifeq ($(vagrant_node_group),appliance)
  vagrant_upload_url := https://$(vagrant_repo_url)/boxes/$(app_hostname_base)/versions/$(app_build_version)/providers/$(vm_provider).box
  vagrant_download_url := https://$(vagrant_repo_url)/boxes/$(app_image_name)/versions/$(app_image_version)/providers/$(vm_provider).box
  image_name := $(app_image_name)
  hostname_base := $(app_hostname_base)
  vm_hostname := $(app_hostname)
  download_version := $(app_image_version)
  os_family := $(app_os_family)
  ifdef BUILD_NUMBER
    upload_version := $(app_build_version).$(BUILD_NUMBER)
  else
    upload_version := $(app_build_version).0
  endif
else
  vagrant_upload_url := https://$(vagrant_repo_url)/boxes/$(pro_hostname_base)/versions/$(pro_build_version)/providers/$(vm_provider).box
  vagrant_download_url := https://$(vagrant_repo_url)/boxes/$(pro_image_name)/versions/$(pro_image_version)/providers/$(vm_provider).box
  image_name := $(pro_image_name)
  hostname_base := $(pro_hostname_base)
  vm_hostname := $(pro_hostname)
  download_version := $(pro_image_version)
  os_family := $(pro_os_family)
  ifdef BUILD_NUMBER
    upload_version := $(pro_build_version).$(BUILD_NUMBER)
  else
    upload_version := $(pro_build_version).0
  endif
endif

.PHONY: vagrant-bootstrap-check
vagrant-bootstrap-check:
ifeq (, $(shell which jq))
	echo "Install missing tool 'jq'" &&\
	echo "  Windows: choco install jq" &&\
	echo "   CentOS: make linux-bootstrap" &&\
	exit 1
endif

# DEVELOPMENT: Package the local VM into a vagrant box file.
# Used by make targets: vagrant-box-cache
.PHONY: vagrant-box-package
vagrant-box-package: vagrant-box-setup vagrant-bootstrap-check
ifndef hostname_base
	$(error vagrant_node_group=$(vagrant_node_group) results in an empty hostname_base)
endif
	$(quiet) VAGRANT_BOX_NAME=$(image_name)-$(vm_provider)-$(download_version).box &&\
	rm -f target/$${VAGRANT_BOX_NAME} &&\
	echo "$(vagrant_node_group): Packaging vagrant box: $(vm_hostname) --> target/$${VAGRANT_BOX_NAME}" &&\
	env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant package --output target/$${VAGRANT_BOX_NAME} $(vm_hostname)
	
# DEVELOPMENT: Add a vagrant box package to the local vagrant cache
# Used by make targets: vagrant-box-cache
.PHONY: vagrant-box-add
vagrant-box-add: vagrant-box-setup vagrant-bootstrap-check
ifndef hostname_base
	$(error vagrant_node_group=$(vagrant_node_group) results in an empty hostname_base)
endif
ifneq (,$(image_name))
	$(quiet) VAGRANT_BOX_NAME=$(image_name)-$(vm_provider)-$(download_version).box &&\
	INSTALLED_BOX_COUNT=`vagrant box list | grep "$(image_name)[ ]\+($(vm_provider), $(download_version))" | wc -l` &&\
	if [[ $${INSTALLED_BOX_COUNT} -eq 0 ]]; then \
		echo "$(vagrant_node_group): Adding the vagrant box image: $(image_name):$(download_version)" &&\
		env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant box add --name $(image_name) target/$${VAGRANT_BOX_NAME} ; \
	else \
		echo "$(vagrant_node_group): Found cached Vagrant box image for the $(vagrant_node_group): $(image_name):$(download_version)" &&\
		echo "$(vagrant_node_group): To remove cached Vagrant box image: vagrant box remove --box-version $(download_version) --provider $(vm_provider) $(image_name)" &&\
		exit 1; \
	fi
endif


# DEVELOPMENT: Package the current VM into a vagrant box package and at it to the local vagrant cache
.PHONY: vagrant-box-cache
vagrant-box-cache: vagrant-box-setup vagrant-bootstrap-check vagrant-box-package vagrant-box-add
	 $(quiet)echo "$(vagrant_node_group): Cached Vagrant box image: $(image_name):$(download_version)"; \

# Download parent vagrant box from the artifactory vagrant repo
.PHONY: vagrant-box-download
vagrant-box-download: vagrant-box-setup vagrant-bootstrap-check
ifneq (,$(app_image_name))
	$(info APPLIANCE: Attempt to download VM image from: $(vagrant_app_download_url))
	$(quiet) INSTALLED_BOX_COUNT=`vagrant box list | grep "$(app_image_name).*$(vm_provider).*$(app_image_version)" | wc -l` &&\
	if [[ $${INSTALLED_BOX_COUNT} -eq 0 ]]; then \
		echo "APPLIANCE: Downloading the vagrant box image: $(app_image_name):$(app_image_version)" &&\
		PASSWORD_FILE="target/.ansible_password_file" &&\
		USER_LOGIN=devopssa &&\
		USER_PASSWORD=`cat $${PASSWORD_FILE}` &&\
		VAGRANT_BOX_URL="$(vagrant_server_url)/$(app_image_name)" &&\
		VAGRANT_SERVER_URL=$(vagrant_server_url) \
		ATLAS_TOKEN=`curl -s https://$${USER_LOGIN}:$${USER_PASSWORD}@$(vagrant_auth_url)` \
		env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant box add --name $(app_image_name) --box-version $(app_image_version) $${VAGRANT_BOX_URL}; \
	else \
		echo "APPLIANCE: Found cached Vagrant box image for the $(vagrant_node_group): $(app_image_name):$(app_image_version)"; \
	fi
endif
ifneq (,$(pro_image_name))
	$(info PROVISIONER: Attempt to download VM image from: $(vagrant_pro_download_url))
	$(quiet) INSTALLED_BOX_COUNT=`vagrant box list | grep "$(pro_image_name).*$(vm_provider).*$(pro_image_version)" | wc -l` &&\
	if [[ $${INSTALLED_BOX_COUNT} -eq 0 ]]; then \
		echo "PROVISIONER: Downloading the vagrant box image: $(pro_image_name):$(pro_image_version)" &&\
		PASSWORD_FILE="target/.ansible_password_file" &&\
		USER_LOGIN=devopssa &&\
		USER_PASSWORD=`cat $${PASSWORD_FILE}` &&\
		VAGRANT_BOX_URL="$(vagrant_server_url)/$(pro_image_name)" &&\
		VAGRANT_SERVER_URL=$(vagrant_server_url) \
		ATLAS_TOKEN=`curl -s https://$${USER_LOGIN}:$${USER_PASSWORD}@$(vagrant_auth_url)` \
		env_name=$(env_name) VAGRANT_LOG=$(VAGRANT_LOG) vagrant box add --name $(pro_image_name) --box-version $(pro_image_version) $${VAGRANT_BOX_URL}; \
	else \
		echo "PROVISIONER: Found cached Vagrant box image for the $(vagrant_node_group): $(pro_image_name):$(pro_image_version)"; \
	fi
endif
	
# Setup ssh certs and ansible on the provisioner
.PHONY: ansible-setup
ansible-setup:
	$(quiet)# Install python3 \
	# Install ansible if on provisioner

# [ONLY WORKS WHEN RUN ON PROVISIONER] Run ansible on the provisioner
.PHONY: ansible-deploy
ansible-deploy: linux-appliance
	$(quiet):


# Run ansible on the provisioner using ssh and the ssh.config created by vagrant-up
.PHONY: vagrant-deploy
vagrant-deploy: load-node-data
	$(quiet) ( \
	ssh_command="sudo su - $(local_login) -c \"cd /projects/$(app_hostname_base) && pwd && make env_name=${env_name} debug=${debug} ansible-deploy\"" &&\
	echo "#################################################" &&\
	echo "## Running ansible_deploy on vagrant host over ssh" &&\
	echo "#################################################" &&\
	echo "$${ssh_command}" | ssh -F $(ssh_config_file) $(pro_hostname) \
	) || exit 1

.PHONY: molecule-test
molecule-test:
	$(quiet)# Run molecule unit tests on provisioner using docker

# Pull parent project and preserve submodule versions set in parent.
# submodule sync: ensures changes to .gitmodule are synced with local .git/config
# submodule update: ensures submodules are reset to their correct version
.PHONY: git-pull
git-pull:
	$(info WARNING: Pulling the latest change-sets, including reset of submodules)
	git pull --recurse-submodules &&\
	git submodule sync &&\
	git submodule update --init --recursive

# BEWARE: This is to allow developers to make changes to the submodules.
# BIG ASSUMPTION THAT ALL SUBMODULES ARE ON ORIGIN MASTER BRANCH
.PHONY: git-pull-hard
git-pull-hard:
	$(info DEV_ONLY: Ignoring current submodule versions and pulling HEAD of ORIGIN MASTER )
	$(HIDE_CMD) \
	if [[ ! $$( git status -s | wc -l ) -eq 0 ]]; then \
	  echo "[ERROR] There are local changes in git repo" &&\
		exit 1; \
	fi &&\
	gitRemote=$$(echo $(gitRemoteBranch) | sed -e "s#^\([^/]\+\)/.*#\1#g" ) &&\
	gitBranch=$$(echo $(gitRemoteBranch) | sed -e "s#^[^/]\+/##g" ) &&\
	if git branch | grep -q $${gitBranch}; then \
		git fetch $${gitRemote} $${gitBranch}; \
	else \
		git fetch $${gitRemote} $${gitBranch}:$${gitBranch}; \
	fi &&\
	git rebase HEAD $${gitBranch} &&\
	git pull --rebase $${gitRemote} $${gitBranch} &&\
	git submodule foreach --recursive " \
		if git branch | grep -q $${gitBranch}; then \
			git fetch $${gitRemote} $${gitBranch}; \
		else \
			git fetch $${gitRemote} $${gitBranch}:$${gitBranch}; \
		fi &&\
		git rebase HEAD $${gitBranch} &&\
		git pull --rebase $${gitRemote} $${gitBranch}"


# FIXME: Can only push if HEAD is at the tip of a branch
# Push the project and any submodules is has
#.PHONY: git-push-origin-master
#git-push-origin-master:
#	$(quiet)git push origin master

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
	
# If the inventory file is missing for the requested environment, 
# create a simple one from the clusterDetails.json
.PHONY: create-inventory
create-inventory: linux-bootstrap
	@echo "[Makefile.$@] Create an Ansible inventory file" && \
	source $(create_inventory_script) "$(environments_file)" "$(env_name)" "$(inventory_file)"

# [ONLY WORKS WHEN RUN ON PROVISIONER] 
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
	flag_file=$${flag_dir}/$(_project_name) &&\
	if [[ ! -e $${flag_file} ]]; then \
	  sudo yum install -y epel-release &&\
	  sudo yum install -y python3-pip jq sshpass &&\
	  sudo su - root -c "pip3 install --upgrade pip" &&\
	  sudo su - root -c "pip3 install ansible==$(ansible_version) dnspython requests pywinrm netaddr jmespath selinux" &&\
	  sudo mkdir -p $${flag_dir} &&\
	  sudo touch $${flag_file}; \
	fi \
	) || exit 1

# [ONLY WORKS WHEN RUN ON PROVISIONER]
# Deploys provisioner specific changes using ansible
.PHONY: linux-provisioner
linux-provisioner: linux-bootstrap
	$(quiet)( echo "[Makefile.$@] Apply ansible playbook for provisioner: $${USER}" && \
	mkdir -p $(log_dir) && \
	export ANSIBLE_FORCE_COLOR=true && \
	ansible-playbook $(ansible_debug) \
	--inventory $(inventory_file) \
	--vault-id=$(vault_password_file) \
	-e env_name="$(env_name)" \
	provisioner.playbook 2>&1 | tee $(log_dir)/$@.log ) || ( export RETURN_CODE=$$? && echo "$@ RC: $$RETURN_CODE"; exit $$RETURN_CODE )

  
# [ONLY WORKS WHEN RUN ON PROVISIONER]
# Deploys appliance specific changes using ansible
.PHONY: linux-appliance
linux-appliance:
	$(quiet)( echo "[Makefile.$@] Apply ansible playbook for appliance " && \
	mkdir -p $(log_dir) && \
	export ANSIBLE_FORCE_COLOR=true && \
	ansible-playbook $(ansible_debug) \
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