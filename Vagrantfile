# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

config_file = File.expand_path("abiri.yaml", __dir__)
settings = YAML.load_file(config_file)

Vagrant.configure("2") do |config|
  config.vm.box = "gadelkareem/ubuntu-20.04-parallels"

  config.vm.provider "parallels" do |prl|
    prl.memory = 2048
    prl.cpus = 2
  end

  config.vm.network "forwarded_port", guest: 5432, host: 5432
  config.vm.network "private_network", ip: "192.168.56.56"

  config.ssh.password = "vagrant"
  config.ssh.username = "vagrant"
  config.ssh.insert_key = false
  config.ssh.forward_agent = true


  # Always run provision.sh
  config.vm.provision "shell", path: "provision.sh", run: "always"
end
