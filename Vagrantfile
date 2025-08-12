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

  # Update host's /etc/hosts
  config.vm.provision "shell", privileged: false, run: "always" do |s|
    hosts_entries = settings["sites"].map do |site|
      "#{settings["ip"]} #{site["map"]}"
    end.join("\n")

    s.inline = <<-SHELL
      echo "Updating host /etc/hosts..."
      TEMP_FILE=$(mktemp)
      cp /etc/hosts $TEMP_FILE
      for entry in "#{hosts_entries}"; do
        if ! grep -q "$entry" /etc/hosts; then
          echo "$entry" | sudo tee -a /etc/hosts > /dev/null
        fi
      done
    SHELL
  end
end
