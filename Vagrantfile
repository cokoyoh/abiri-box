# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'fileutils'

config_file = File.expand_path("abiri.yaml", __dir__)
settings = YAML.load_file(config_file)

Vagrant.configure("2") do |config|
  # ARM64 Ubuntu box from Parallels
  config.vm.box = "parallels/ubuntu-16.04"

  # Use Parallels instead of VirtualBox
  config.vm.provider "parallels" do |prl|
    prl.memory = 2048
    prl.cpus = 2
  end

  # Network setup
  config.vm.network "forwarded_port", guest: 80, host: 8080
  config.vm.network "forwarded_port", guest: 5432, host: 5432

  # Provisioning script
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update -y

    # Install PostgreSQL
    sudo apt-get install -y postgresql postgresql-contrib
    sudo systemctl enable postgresql
    sudo systemctl start postgresql

    # Set default password for postgres user
    sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'password';"

    # Install Nginx
    sudo apt-get install -y nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx
  SHELL
end
