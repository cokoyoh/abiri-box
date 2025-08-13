#!/usr/bin/env bash
set -e

IP="${1:-127.0.0.1}"  # fallback IP

echo "📦 Updating package lists..."
sudo apt-get update -y

echo "🛠 Installing base packages..."
sudo apt-get install -y curl unzip git build-essential ruby

echo "📦 Installing Node.js (LTS) + TypeScript..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
sudo npm install -g typescript

# ----------------------------
# Install services from abiri.yaml
# ----------------------------
echo "🛠 Installing services..."
mapfile -t SERVICES < <(ruby -ryaml -e "
require 'yaml'
YAML.load_file('abiri.yaml')['services'].each { |s| puts s['name'] }
")
for SERVICE in "${SERVICES[@]}"; do
    echo "📦 Installing service: $SERVICE"
    sudo apt-get install -y "$SERVICE"
done

# ----------------------------
# Configure sites
# ----------------------------
echo "🌐 Configuring sites..."
mapfile -t SITES < <(ruby -ryaml -e "
require 'yaml'
YAML.load_file('abiri.yaml')['sites'].each { |s| puts \"#{s['map']} #{s['to']}\" }
")
for SITE in "${SITES[@]}"; do
    DOMAIN=$(echo "$SITE" | awk '{print $1}')
    PATH=$(echo "$SITE" | awk '{print $2}')

    sudo mkdir -p "$PATH"
    sudo chown -R vagrant:vagrant "$PATH"

    sudo tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $PATH;

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

    sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

    if ! grep -q "$IP $DOMAIN" /etc/hosts; then
        echo "$IP $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
    fi
done

# ----------------------------
# PostgreSQL setup
# ----------------------------
echo "🗄 Ensuring PostgreSQL roles and databases..."
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Ensure 'vagrant' role exists with LOGIN
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='vagrant'" | grep -q 1; then
    sudo -u postgres psql -c "CREATE ROLE vagrant WITH LOGIN PASSWORD 'secret';"
fi

# Set md5 auth for local connections
sudo sed -i "s/^local\s\+all\s\+all\s\+peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf
sudo systemctl restart postgresql

# Create databases and users from abiri.yaml
mapfile -t DB_ENTRIES < <(ruby -ryaml -e "
require 'yaml'
YAML.load_file('abiri.yaml')['databases'].each { |db| puts \"#{db['name']} #{db['user']} #{db['password']}\" }
")

for ENTRY in "${DB_ENTRIES[@]}"; do
    DB=$(echo "$ENTRY" | awk '{print $1}')
    USER=$(echo "$ENTRY" | awk '{print $2}')
    PASS=$(echo "$ENTRY" | awk '{print $3}')

    # Create user if missing
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${USER}'" | grep -q 1; then
        echo "👤 Creating user $USER"
        sudo -u postgres psql -c "CREATE ROLE ${USER} WITH LOGIN PASSWORD '${PASS}';"
    fi

    # Create database if missing
    if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB}'" | grep -q 1; then
        echo "📀 Creating database $DB owned by $USER"
        sudo -u postgres createdb "$DB" -O "$USER"
    fi

    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB} TO ${USER};"
done

# ----------------------------
# Restart services
# ----------------------------
echo "🔄 Restarting services..."
for SERVICE in "${SERVICES[@]}"; do
    sudo systemctl restart "$SERVICE"
done

echo "✅ Provisioning complete!"
echo "ℹ️ You can now connect using: psql -U vagrant -d <database> -W"
