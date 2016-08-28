# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Modified from lepidopter https://github.com/TheTorProject/lepidopter

$setup= <<SETUP
echo "nameserver 8.8.8.8" > /etc/resolv.conf
/root/copilot-install/scripts/setup.sh -p bbb
SETUP

Vagrant.configure("2") do |config|

  # Debian wheezy box
  config.vm.box = "debian/contrib-jessie64"

  config.vm.hostname = "copilot"

  config.vm.synced_folder ".", "/root/copilot-install"

  config.vm.provision :shell, :inline => $setup
end
