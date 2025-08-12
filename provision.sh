#!/usr/bin/env bash
set -e

IP="$1"

echo "📦 Updating packages..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "🛠 Installing base packages..."
sudo apt-get install -y nginx postgresql postgresql-contrib curl unzip git build-essential

echo "📦 Installing Node.js (LTS)..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "👤 Setting vagrant password..."
echo "vagrant:secret" | sudo chpasswd

echo "🌐 Configuring sites from abiri.yaml..."
SITES=$(ruby -ryaml -e "puts YAML.load_file('abiri.yaml')['sites'].map { |s| \"#{s['map']} #{s['to']}\" }")
while read -r domain path; do
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
done <<< "$SITES"

echo "🔄 Restarting Nginx..."
sudo systemctl restart nginx

echo "✅ Provision complete!"
