
require 'shellwords'

nicRoutePath = "/etc/sysconfig/network-scripts/route-eth1"

ssh_prv_key_path = "#{Dir.home}/.vagrant.d/insecure_private_key"
ssh_prv_key = ""
# Windows user running Vagrant has to have keys available
if File.file?("#{ssh_prv_key_path}")
  ssh_prv_key = File.read("#{ssh_prv_key_path}")
else
  puts "No SSH key found: #{ssh_prv_key_path}"
  puts "You will need to remedy this before running this Vagrantfile."
  exit 1
end

# Called from this.configureHost
# Each host calls this for each member of the cluster
$network_config_linux = <<-ADD_NETWORK_CONFIG_LINUX_HEREDOC
#!/bin/bash -eu
debug=${1:-0}

echo "######################################################"
echo "[Vagrantfile.network_config_linux]  $(whoami)@$(hostname)"

if [[ ! "${debug}" == "0" ]]; then
set -x
fi

currentVmIp=$2
targetHostName=$3
targetNatIp=$4
targetNatNetCidr=$5
targetNatNetIp=$6
targetNatNetMask=$7
targetVmIp=$8
ldapRealm=$9


if [[ $# -ne 9 ]]; then
  echo "[ERROR] Invalid number of parameters for network_config_linux: $#"
  exit 1
fi

# Populate /etc/hosts with other servers in vagrant project
if ! grep -q "${targetHostName}" /etc/hosts; then
  echo "# HOST ADDED: ${targetNatIp} ${targetHostName}"
  echo "${targetNatIp} ${targetHostName}.${ldapRealm} ${targetHostName}" >> /etc/hosts
fi

# Create non-persistent route for current boot
if ! ip route | grep -q "${targetNatNetCidr}.*via ${targetVmIp}"; then
  echo "# IP ROUTE ADDED [TEMPORARY]: ${targetNatNetCidr} via ${targetVmIp} dev eth1"
  ip route add ${targetNatNetCidr} via ${targetVmIp} dev eth1
fi

# Create persistent route for future boots
touch #{nicRoutePath}
if ! grep -q "^ADDRESS[0-9]\+=${targetNatNetIp}" #{nicRoutePath}; then
  routeCount=$(grep "^ADDRESS.*" #{nicRoutePath} | wc -l )
  echo "# IP ROUTE ADDED [PERSISTENT]: ADDRESS${routeCount}=${targetNatNetIp} NETMASK${routeCount}=${targetNatNetMask} GATEWAY${routeCount}=${targetVmIp}"
  cat >> #{nicRoutePath} <<INNER_HEREDOC
    ADDRESS${routeCount}=${targetNatNetIp}
    NETMASK${routeCount}=${targetNatNetMask}
    GATEWAY${routeCount}=${targetVmIp}
INNER_HEREDOC
fi

ADD_NETWORK_CONFIG_LINUX_HEREDOC


# Called from this.configureHost
# Each host calls this for each member of the cluster
$network_config_win10 = <<-ADD_NETWORK_CONFIG_WIN10_HEREDOC
# powershell

$debug=$args[0]
$currentVmIp=$args[1]
$targetHostName=$args[2]
$targetNatIp=$args[3]
$targetNatNetCidr=$args[4]
$targetNatNetIp_NOT_USED_FOR_WIN10=$args[5]
$targetNatNetMask_NOT_USED_FOR_WIN10=$args[6]
$targetVmIp=$args[7]
$ldapRealm=$args[8]

if (-NOT ($args.count -eq 9)) {
  echo "[ERROR] Invalid paramter count for network_config_win10: $($args.count)"
  exit 1
}

function Add-NetRouteByDestination {
  param (
    [Parameter(Mandatory=$true)][String]$destinationCidr,
    [Parameter(Mandatory=$true)][String]$interfaceIpString,
    [Parameter(Mandatory=$true)][String]$gatewayIpString
  )
  echo "Check route for: destinationCidr=$destinationCidr interfaceIpString=$interfaceIpString gatewayIpString=$gatewayIpString"
  $interfaceIp=get-netipaddress $interfaceIpString
  $interfaceIdx=$interfaceIp.InterfaceIndex
  try {
    New-NetRoute -DestinationPrefix $destinationCidr -InterfaceIndex $interfaceIdx -NextHop $gatewayIpString -ea stop | out-null
    echo "    Route added for $destinationCidr"
  }
  catch [Microsoft.Management.Infrastructure.CimException] {
    echo "    Route already exists for $destinationCidr"
  }
}

function Add-ResolveHost {
  param (
    [Parameter(Mandatory=$true)][String]$ipAddress,
    [Parameter(Mandatory=$true)][String]$hostname
  )
  echo "Check /etc/hosts for: ipAddress=$ipAddress hostname=$hostname"
  $lineToInsert = $ipAddress + '    ' + $hostname + '.' + $ldapRealm + ' ' + $hostname
  $filename = "$env:windir\\System32\\drivers\\etc\\hosts"
  $content = Get-Content $filename
  $foundLine=$false

  foreach ($line in $content) {
    if ($line -match ${ipAddress} + '\s+' + ${hostname}) {
      $foundLine=$true
    }
  }
  if (-not $foundLine) {
    echo "    Inserted"
    $lineToInsert | Out-File -encoding ASCII -append $filename
  } else {
    echo "    Already exists"
  }
  
}

# ROUTING RULES: Add routes to NAT interfaces.
Add-NetRouteByDestination $targetNatNetCidr $currentVmIp $targetVmIp
# FAKE DNS: Allow other hosts to be resolved
Add-ResolveHost $targetNatIp $targetHostName

# IP routing/forwarding: Allows network packets to be routed across interfaces
reg add HKLM\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters /v IPEnableRouter /D 1 /f | out-null
sc.exe config RemoteAccess start= auto | out-null
sc.exe start RemoteAccess | out-null

# FIREWALL: Allow pings from each NAT interface; also see HOST_CONFIG_WIN10_HEREDOC
New-NetFirewallRule -DisplayName "Allow inbound ICMPv4" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress ${targetNatNetCidr} -Action Allow | out-null
New-NetFirewallRule -DisplayName "Allow inbound ICMPv6" -Direction Inbound -Protocol ICMPv6 -IcmpType 8 -RemoteAddress ${targetNatNetCidr} -Action Allow | out-null

ADD_NETWORK_CONFIG_WIN10_HEREDOC

$ssh_fingerprint_config_linux = <<-SSH_FINGERPRINT_CONFIG_LINUX_HEREDOC
#!/bin/bash -eu
debug=${1:-0}

echo "######################################################"
echo "## [Vagrantfile.ssh_fingerprint_config_linux]  $(whoami)@$(hostname)"
if [[ ! "${debug}" == "0" ]]; then
set -x
fi

ansibleAccount=$2
targetHostname=$3

if [[ $# -ne 3 ]]; then
  echo "[ERROR] Invalid number of parameters for ssh_fingerprint_config_linux: $#"
  exit 1
fi

homeDir="/home/${ansibleAccount}"
knownHostsFile="${homeDir}/.ssh/known_hosts"
# Get IP4 address for targetHostname
targetIpAddress=$(getent ahosts ${targetHostname} | head -n 1 | cut -d' ' -f1)

fingerprint_raw=$( ssh-keyscan -H ${targetHostname} | grep 'ecdsa-sha2' )
fingerprint="${targetHostname},${targetIpAddress} $(echo $fingerprint_raw | cut -d' ' -f2-)"
if [[ ! -e ${knownHostsFile} ]] || ( ! grep -q "${fingerprint}" ${knownHostsFile} ); then
  echo "######################################################"
  echo "## Adding known_hosts fingerprint to ${ansibleAccount}@$(hostname):${knownHostsFile} -> ${fingerprint}"
  echo "${fingerprint}" >> ${knownHostsFile}
  chown ${ansibleAccount}.users ${knownHostsFile}
fi

SSH_FINGERPRINT_CONFIG_LINUX_HEREDOC

# Called from this.configureHost
# Called once per host
# This runs as root so that it can setup the ansible account and it's sudo config.
# Create the ansible user and add them to sudo.
# Copy vagrant ssh keys to ansibleUser
# Enable password login to support kerberos login
$host_config_linux = <<-HOST_CONFIG_LINUX_HEREDOC
#!/bin/bash -eu
debug=${1:-0}

echo "######################################################"
echo "## [Vagrantfile.host_config_linux]  $(whoami)@$(hostname)"
if [[ ! "${debug}" == "0" ]]; then
set -x
fi

ansibleAccount=$2
ansiblePassword=$3
vaultPassword=$4
sshPrivateKeyString="#{ssh_prv_key}"

if [[ $# -ne 4 ]]; then
  echo "[ERROR] Invalid number of parameters for host_config_linux: $#"
  exit 1
fi

homeDir="/home/${ansibleAccount}"

# Create the ansibleAccount if it doesn't exist
if ! id -u ${ansibleAccount} > /dev/null 2>&1; then
  echo "[Vagrantfile.host_config_linux] USER: Create the ansible user '${ansibleAccount}' if it doesnt exist"
  # Allow ansibleAccount to sudo and access to vBox sharedfolders
  useradd -g users -G wheel,vagrant,vboxsf -d ${homeDir} -s /bin/bash -p $(echo ${ansiblePassword} | openssl passwd -1 -stdin) ${ansibleAccount}
fi 
# These are used by ansible build
echo "${ansiblePassword}" > ${homeDir}/.ansible_password_file
echo "${vaultPassword}" > ${homeDir}/.vault_password_file

echo "[Vagrantfile.host_config_linux] SUDO: Allow passwordless sudo for users in wheel group"
# Important to uncomment NOPASSWD line first
# Preserving escape characters through vagrant assignment
sed -i "s/^# \\(\\%wheel.\\+NOPASSWD\\:.*\\)/\\1/"  /etc/sudoers
sed -i "s/^\\(\\%wheel[[:space:]]\\+ALL=(ALL)[[:space:]]\\+ALL\\)/# \\1/"  /etc/sudoers

# Support ansible pipelineing
sed -i 's/[#[:space:]]*Defaults:[[:space:]]\+\!\?requiretty/Defaults: !requiretty/' /etc/sudoers

# Disable the console TMOUT setting if it exists
# Some long running ansible tasks would be aborted otherwise.
# It will be re-applied by ansible-role.github.hardening
sed -i "s/^TMOUT=.*/TMOUT=0/"  /etc/profile

echo "[Vagrantfile.host_config_linux] SSH KEYS: Copy ssh key to allow passwordless login"
sshDir="${homeDir}/.ssh"
tmpPrivateKey=${sshDir}/${ansibleAccount}
rsaPrivateKey=${sshDir}/id_rsa
rsaPublicKey=${sshDir}/id_rsa.pub
authorizedKeys=${sshDir}/authorized_keys

mkdir -p ${sshDir}

# Don't echo the private key to console.
set +x
# Echo the ssh key loaded from windows into target system
# Don't write it directly as it may already exist
echo "${sshPrivateKeyString}" > ${tmpPrivateKey}
if [[ ! "${debug}" == "0" ]]; then
set -x
fi

chmod 600 ${tmpPrivateKey}

# Extract public key from tmp private key
ssh_pub_key=`openssl rsa -in ${tmpPrivateKey} -pubout -outform PEM`
authorized_keys=`ssh-keygen -y -f ${tmpPrivateKey}`

# Has this key been added to authorized_keys already?
if grep -sq "${authorized_keys}" ${authorizedKeys}; then
  echo "[Vagrantfile.host_config_linux] SSH keys already provisioned for: ${ansibleAccount}"
else
  echo "[Vagrantfile.host_config_linux] Creating SSH keys for: ${ansibleAccount}"
  mv -f  ${tmpPrivateKey} ${rsaPrivateKey}
  chmod 600 ${rsaPrivateKey}
  
  echo "${ssh_pub_key}" > ${rsaPublicKey}
  chmod 644 ${rsaPublicKey}

  touch ${authorizedKeys}
  echo "${authorized_keys}" >> ${authorizedKeys}
  chmod 600 ${authorizedKeys}
fi

# Running as root, so switch created files to ${ansibleAccount} user
chown -R ${ansibleAccount}:users ${homeDir}

# Vagrant box has password login disabled; but sssd/ad users expect password login.
# Re-enable password login
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config
systemctl restart sshd
HOST_CONFIG_LINUX_HEREDOC

# Called from this.configureHost
# Called once per host
# This is run as Administrator
# Minimal setup required to support Ansible.
$host_config_win10 = <<-HOST_CONFIG_WIN10_HEREDOC
# powershell

$vmNetCidr=$args[0]

if ($args.count -ne 1) {
  echo "[ERROR] Invalid paramter count: $($args.count)"
  exit 1
}

echo "[FIREWALL] Allow pings from members of VM network"
# also see ADD_NETWORK_CONFIG_WIN10_HEREDOC
New-NetFirewallRule -DisplayName "Allow inbound ICMPv4" -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress ${vmNetCidr} -Action Allow | out-null
New-NetFirewallRule -DisplayName "Allow inbound ICMPv6" -Direction Inbound -Protocol ICMPv6 -IcmpType 8 -RemoteAddress ${vmNetCidr} -Action Allow | out-null

HOST_CONFIG_WIN10_HEREDOC


# Run the ansible-playbook only on the provisioner as the ansible user.
# Cannot run as root because ansible isn't on the path for root.
$run_ansible_playbook = <<-RUN_ANSIBLE_PLAYBOOK_HEREDOC
#!/bin/bash -eu
debug=${1:-0}

echo "######################################################"
echo "[Vagrantfile.run_ansible_playbook] $(whoami)@$(hostname)"
echo "######################################################"
if [[ ! "${debug}" == "0" ]]; then
set -x
fi

env_name=$2
ansibleAccount=$3
targetBaseName=$4
targetOsFamily=$5

if [[ $# -ne 5 ]]; then
  echo "[ERROR] Invalid paramter count: $($args.count)"
  exit 1
fi

# Project directory has been copied to VM
if [[ ! -e /etc/ansible/linux-provisioner ]]; then
  echo "[Vagrantfile.run_ansible_playbook] Calling Makefile target: linux-provisioner"
  sudo su - ${ansibleAccount} -c " ( \
    cd /projects/${targetBaseName} &&\
	make env_name=${env_name} debug=${debug} linux-provisioner
  ) || exit 1 "
  sudo mkdir -p /etc/ansible
  sudo touch /etc/ansible/linux-provisioner
else
  echo "[SKIPPING linux-provisioner] Found $(hostname):/etc/ansible/linux-provisioner"; \
fi

echo "[Vagrantfile.run_ansible_playbook] Calling Makefile target: ${targetOsFamily}-appliance"
sudo su - ${ansibleAccount} -c "( cd /projects/${targetBaseName} && make env_name=${env_name} debug=${debug} ${targetOsFamily}-appliance ) || exit 1"

RUN_ANSIBLE_PLAYBOOK_HEREDOC


# Called from this.createCluster()
# Runs the ansible configuration scripts on the VM
def configureHost(debug, env_name, nodeGroup, machine, clusterDetails, currentHostName, currentVmIp, ansiblePassword, vaultPassword, currentNodeIndex)
  vmNetCidr = "#{clusterDetails['vmNetBaseIp']}.0/24"
  currentOsFamily = nodeGroup['osFamily']
  # Allows all machines to support ssh login from Virtualbox host
  # Builds should run though jumpbox at 2222
  sshPortForwarded = "22#{currentNodeIndex}"
  rdpPortForwarded = "23#{currentNodeIndex}"
  winrmPortForwarded = "24#{currentNodeIndex}"
  
  # Disable the default folder sync
  machine.vm.synced_folder ".", "/vagrant", disabled: true
  
  if currentOsFamily == 'win10'
    # Windows needs special setup to connect over winrm
    machine.vm.guest = :windows
    machine.vm.communicator = "winrm"
    # FIXME: load password from file
    machine.winrm.password = ansiblePassword
    # Windows install can take a long time and can cause the winrm 'keep alive' to panic and quit
    machine.winrm.retry_limit = 30
    machine.winrm.retry_delay = 10
    machine.winrm.username = clusterDetails['localLogin']
    machine.winrm.transport = :plaintext
    machine.winrm.basic_auth_only = true
    machine.vm.boot_timeout = 600
    machine.vm.graceful_halt_timeout = 600
    machine.vm.network :forwarded_port, guest: 3389, host: rdpPortForwarded, id: "RDP"
    machine.vm.network :forwarded_port, guest: 5985, host: winrmPortForwarded, id: "winrm", auto_correct: true
  else
    # Prevent port clashes by moving ssh port to unique port number
    machine.vm.network :forwarded_port, guest: 22, host: sshPortForwarded, id: "ssh"
  end

  # Configure ALL hosts to support ansible connections.
  # Before call to ssh_fingerprint_config_linux
  machine.vm.provision  "shell" do |bash_shell|
    if currentOsFamily == 'linux'
      ansibleUsername = clusterDetails['localLogin']
      # Dollars in passwords cause problems; escape them.
      escapedVaultPassword = Shellwords.escape(vaultPassword)
      escapedAnsiblePassword = Shellwords.escape(ansiblePassword)
      
      bash_shell.inline = $host_config_linux
      bash_shell.args = "'#{debug}' #{ansibleUsername} #{escapedAnsiblePassword} #{escapedVaultPassword}"
    else
      # TODO: Shouldn't assume Windows if not Linux!
      bash_shell.inline = $host_config_win10
      bash_shell.privileged = false
      bash_shell.args = "#{vmNetCidr}"
    end
  end


  targetOsFamily = ''
  appHostnameBase = ''
  # CONFIGURE NETWORK ROUTING FROM THIS VM TO ALL OTHER VM IN CLUSTER
  # Add route and /etc/hosts entries for all other nodes in cluster
  # This is primarily because Vagrant hihacks eth0 for NAT connections.
  clusterDetails['nodeGroups'].each do |targetNodeType|
    (0..targetNodeType['nodeCount']-1).each do |targetNodeIndex|
      
      targetHostName = "#{targetNodeType['images'][1]['imageName']}-#{targetNodeType['addrStart'] + targetNodeIndex}"
      if targetNodeType['hostnameArray'] and ((targetNodeType['hostnameArray']).length == targetNodeType['nodeCount'])
        targetHostName = "#{targetNodeType['hostnameArray'][targetNodeIndex]}"
      end
      targetVmIp = "#{clusterDetails['vmNetBaseIp']}.#{targetNodeType['addrStart'] + targetNodeIndex}"
      targetNatBaseIp = "#{clusterDetails['natNetBaseIp']}.#{targetNodeType['addrStart'] + targetNodeIndex}"
      # Vagrant hard coded address
      targetNatIp = "#{targetNatBaseIp}.15"
      targetNatNetIp = "#{targetNatBaseIp}.0"
      targetNatNetCidr = "#{targetNatNetIp}/#{clusterDetails['natNetCidrMask']}"
      targetNatNetMask = "#{clusterDetails['natNetAddrMask']}"
      ldapRealm = "#{clusterDetails['ldapRealm']}"
      
      if targetHostName != currentHostName
		# Setup the hostnames and network routes to other hosts
        machine.vm.provision  "shell" do |bash_shell|
          if currentOsFamily == 'linux'
            # Call network configuration function for linux (declared above)
            bash_shell.inline = $network_config_linux
          else
            # Call network configuration function for Windows (declared above)
            bash_shell.inline = $network_config_win10
          end
          bash_shell.args = "'#{debug}' #{currentVmIp} #{targetHostName} #{targetNatIp} #{targetNatNetCidr} #{targetNatNetIp} #{targetNatNetMask} #{targetVmIp} #{ldapRealm}"
        end
      end
    end
    if targetNodeType['nodeGroup'] == 'appliance'
      targetOsFamily = targetNodeType['osFamily']
      appHostnameBase = targetNodeType['images'][1]['imageName']
    end
  end

  # Only the provisioner runs ansible
  provisionerHostnameBase = clusterDetails["nodeGroups"].find {|ng| ng['nodeGroup']=='provisioner'}['images'][1]['imageName']
  provisionerAddrStart = clusterDetails["nodeGroups"].find {|ng| ng['nodeGroup']=='provisioner'}['addrStart']
  provisionerHostname = "#{provisionerHostnameBase}-#{provisionerAddrStart}"
  if provisionerHostname == currentHostName
    #Can't request host fingerprint until all other hosts have been created.
    clusterDetails['nodeGroups'].each do |nodeGroup|
      (0..nodeGroup['nodeCount']-1).each do |nodeIndex|
        currentNodeIndex= nodeGroup['addrStart'] + nodeIndex
        currentNodeName = "#{nodeGroup['images'][1]['imageName']}-#{currentNodeIndex}"

        # Loop over all targets for the currentNode
        clusterDetails['nodeGroups'].each do |targetNodeType|
          (0..targetNodeType['nodeCount']-1).each do |targetNodeIndex|
            targetHostName = "#{targetNodeType['images'][1]['imageName']}-#{targetNodeType['addrStart'] + targetNodeIndex}"
            # Update the currentHostName ~/.ssh/known_hosts with fingerprint for targetHostName
            # Must be after call to host_config_linux
            machine.vm.provision  "shell" do |bash_shell|
              if currentOsFamily == 'linux'
                # Call ssh known_hosts configuration function for linux (declared above)
                bash_shell.inline = $ssh_fingerprint_config_linux
              end
              bash_shell.args = "'#{debug}' #{clusterDetails['localLogin']} #{targetHostName}"
            end
          end
        end

      end
    end
    
    # Now run ansible playbook
    machine.vm.synced_folder ".", "/projects/#{appHostnameBase}", automount: true, mount_options: ["dmode=770,fmode=660"]
    machine.vm.provision  "shell" do |bash_shell|
      bash_shell.inline = $run_ansible_playbook
      bash_shell.privileged = false
      bash_shell.args = "'#{debug}' #{env_name} #{clusterDetails['localLogin']} '#{appHostnameBase}' '#{targetOsFamily}'"
    end
    
  end

end

# Vagrant cannot build CentOS 8 guest additions.
# due to missing yum/dnf repositories: C*-base
# This fix is from: https://github.com/dotless-de/vagrant-vbguest/issues/367#issuecomment-602494723
# FIXME: This will probably be fixed someday and this class removed
class Centos8VbGuestInstaller < VagrantVbguest::Installers::CentOS
  def has_rel_repo?
    unless instance_variable_defined?(:@has_rel_repo)
      rel = release_version
      @has_rel_repo = communicate.test("yum repolist")
    end
    @has_rel_repo
  end

  def install_kernel_devel(opts=nil, &block)
    cmd = "yum update kernel -y"
    communicate.sudo(cmd, opts, &block)

    cmd = "yum install -y kernel-devel"
    communicate.sudo(cmd, opts, &block)

    cmd = "shutdown -r now"
    communicate.sudo(cmd, opts, &block)

    begin
      sleep 5
    end until @vm.communicate.ready?
  end
end

# Called from project ../../Vagrantfile
# Create a VM for each node declared by clusterDetails.nodeGroups (normally just a provisioner and an appliance )
# Parameters:
#     clusterDetails: Structure loaded from environment/${env_name}/environment.json
#     debug: Level of debug used by provisioners
#     env_name: The name of the environment to load from environment/${env_name}
#     vagrantCommand: ARGV[0] is used to squash output when running the 'vagrant ssh-config' command
#     rebuild: start from base image to test full build.
def createCluster(clusterDetails, debug=0, env_name='vagrant-virtualbox', vagrantCommand='default', rebuild=false)
  # Vault password encrypts/decrypts the file vault/credentials.yml
  vault_password   = File.read( ENV['HOME'] + "/.vault_password_file"){|f| f.readline}
  # Password for localUser declared in clusterDetails
  ansible_password = File.read( ENV['HOME'] + "/.ansible_password_file"){|f| f.readline}
  
  # Get a list of Vagrant boxes that are available in local cache
  vagrantBoxList = `vagrant box list`
  vagrantProvider = clusterDetails['vmProvider']

  Vagrant.configure("2") do |config|
    # The vagrant ssh-config should use localUser
    if vagrantCommand == 'ssh-config'
      config.ssh.username = clusterDetails['localUser']
    end
    # always use Vagrants insecure key
    config.ssh.insert_key = false
    # forward ssh agent to easily ssh into the different machines
    config.ssh.forward_agent = true
    # Ensure the MAC address is unique
    config.vm.base_mac = nil

    clusterDetails['nodeGroups'].each do |nodeGroup|
      (0..nodeGroup['nodeCount']-1).each do |nodeIndex|
        currentNodeIndex= nodeGroup['addrStart'] + nodeIndex
        currentNodeName = "#{nodeGroup['images'][1]['imageName']}-#{currentNodeIndex}"
        if nodeGroup['hostnameArray'] and ((nodeGroup['hostnameArray']).length == nodeGroup['nodeCount'])
          currentNodeName = "#{nodeGroup['hostnameArray'][nodeIndex]}"
        end

        currentHostCidr = "#{clusterDetails['natNetBaseIp']}.#{nodeGroup['addrStart'] + nodeIndex}.0/#{clusterDetails['natNetCidrMask']}"
        currentVmIp = "#{clusterDetails['vmNetBaseIp']}.#{nodeGroup['addrStart'] + nodeIndex}"
        currentVmNetMask = "255.255.255.0"

        foundMatch = false
        vagrantImageName = ''
        vagrantImageVersion = ''
        nodeGroup['images'].each do |vagrantImage|
          vagrantImageName = vagrantImage['imageName']
          vagrantImageVersion = vagrantImage['imageVersion']
          vagrantBoxRegexp = "^#{vagrantImageName}[ ]+\\(#{vagrantProvider}, #{vagrantImageVersion}\\)"
          # if rebuild, loop to the last image
          if ( ! rebuild ) && vagrantBoxList.match?(/#{vagrantBoxRegexp}/)
            foundMatch = true
            break
          end
        end
        # The vagrant ssh-config captures everything from stdout; ensure it doesn't include this
        if vagrantCommand != 'ssh-config'
          if foundMatch
            puts "[#{nodeGroup['nodeGroup']}] Based on local Vagrant box: '#{vagrantImageName} (#{vagrantProvider}, #{vagrantImageVersion})'"
          else
            puts "[#{nodeGroup['nodeGroup']}] Based on Vagrant box: '#{vagrantImageName} (#{vagrantProvider}, #{vagrantImageVersion})'"
          end
        end


        config.vm.define "#{currentNodeName}" do |machine|
          machine.vm.box = vagrantImageName
          machine.vm.box_version = vagrantImageVersion
          
          # Fix for building VirtualBox Guest Additions for CentOS8
          # FIXME: This will probably be fixed someday and this line removed
          #machine.vbguest.installer = Centos8VbGuestInstaller

          machine.vm.hostname = currentNodeName
          # eth1: Create a nic to talk to other VMs
          machine.vm.network "private_network", ip: currentVmIp, :netmask => currentVmNetMask

          # Virtualbox specific stuff
          if vagrantProvider == 'virtualbox'
            machine.vm.provider 'virtualbox' do |provider_vm|
              provider_vm.name = currentNodeName
              provider_vm.memory = nodeGroup['memory']
              provider_vm.cpus = nodeGroup['cpu']
              # eth0: Modify network address for default NAT nic created by vagrant.
              #       Otherwise vagrant would make all nodes 10.0.2.15, which confuses kubeadm
              provider_vm.customize ['modifyvm',:id, '--natnet1', "#{currentHostCidr}"]
            end
          end

          # hyper-v specific stuff
          if vagrantProvider == 'hyperv'
            machine.vm.provider "hyperv" do |provider_vm|
              provider_vm.vmname = currentNodeName
              provider_vm.memory = nodeGroup['memory']
              provider_vm.cpus = nodeGroup['cpu']
              # eth0: Modify network address for default NAT nic created by vagrant.
              #       Otherwise vagrant would make all nodes 10.0.2.15, which confuses kubeadm
              # provider_vm.customize ['modifyvm',:id, '--natnet1', "#{currentHostCidr}"]
            end
          end

          # Clean VM has been created, now configuration it. 
          # Last host to be created should always the provisioner, which runs the ansible playbook
          configureHost(debug, env_name, nodeGroup, machine, clusterDetails, currentNodeName, currentVmIp, ansible_password, vault_password, currentNodeIndex)
        end
      end
    end


  end
end