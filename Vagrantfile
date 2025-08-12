# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'fileutils'

config_file = File.expand_path("abiri.yaml", __dir__)
settings = YAML.load_file(config_file)

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.network "private_network", ip: settings["ip"]

  # Sync folders
  settings["folders"].each do |folder|
    config.vm.synced_folder folder["map"], folder["to"], type: "virtualbox"
  end

  # Provision inside VM
  config.vm.provision "shell", path: "provision.sh", args: [settings["ip"]]

  # Provision on host to update /etc/hosts
  config.vm.provision "host", type: "shell", run: "always" do |s|
    domains = settings["sites"].map { |site| site["map"] }
    domains.each do |domain|
      s.inline = <<-SHELL
        if ! grep -q "#{settings['ip']} #{domain}" /etc/hosts; then
          echo "Adding #{domain} to host /etc/hosts"
          echo "#{settings['ip']} #{domain}" | sudo tee -a /etc/hosts > /dev/null
        fi
      SHELL
    end
  end
end
