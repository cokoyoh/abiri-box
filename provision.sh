#!/usr/bin/env bash
set -e

IP="$1"

echo "📦 Updating package lists..."
sudo apt-get update -y

echo "🛠 Installing base packages..."
sudo apt-get install -y \
    curl unzip git build-essential ruby

echo "📦 Installing Node.js (LTS) + TypeScript..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g typescript

echo "👤 Setting vagrant password..."
echo "vagrant:secret" | sudo chpasswd

echo "🛠 Installing services from abiri.yaml..."
ruby -ryaml -e "
require 'yaml'
YAML.load_file('abiri.yaml')['services'].each do |svc|
  puts svc['name']
end
" | while read -r SERVICE; do
    echo "📦 Installing service: $SERVICE"
    sudo apt-get install -y "$SERVICE"
done

echo "🌐 Configuring sites from abiri.yaml..."
ruby -ryaml -e "
require 'yaml'
sites = YAML.load_file('abiri.yaml')['sites']
sites.each do |s|
  puts \"#{s['map']} #{s['to']}\"
end
" | while read -r domain path; do
    sudo mkdir -p "$path"
    sudo chown -R vagrant:vagrant "$path"

    sudo tee /etc/nginx/sites-available/$domain > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    root $path;

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/$domain

    if ! grep -q "$IP $domain" /etc/hosts; then
        echo "$IP $domain" | sudo tee -a /etc/hosts > /dev/null
    fi
done

echo "🗄 Creating PostgreSQL databases (if not exists) from abiri.yaml..."
ruby -ryaml -e "
require 'yaml'
YAML.load_file('abiri.yaml')['databases'].each do |db|
  puts \"#{db['name']} #{db['user']} #{db['password']}\"
end
" | while read -r DB USER PASS; do
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB}'" | grep -q 1; then
        echo "📀 Creating database: $DB"
        sudo -u postgres createdb "$DB"
        sudo -u postgres psql -c "ALTER USER ${USER} WITH PASSWORD '${PASS}';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB} TO ${USER};"
    else
        echo "✅ Database already exists: $DB"
    fi
done

echo "🔄 Restarting services from abiri.yaml..."
ruby -ryaml -e "
require 'yaml'
YAML.load_file('abiri.yaml')['services'].each do |svc|
  puts svc['name']
end
" | while read -r SERVICE; do
    echo "🔄 Restarting $SERVICE"
    sudo systemctl restart "$SERVICE"
done

echo "✅ Provision complete!"
