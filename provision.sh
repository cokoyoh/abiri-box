#!/usr/bin/env bash
set -e

# ----------------------------
# Ensure core utilities are found
# ----------------------------
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IP="${1:-127.0.0.1}"

# ----------------------------
# Update and install base packages
# ----------------------------
echo "📦 Updating package lists..."
/usr/bin/apt-get update -y

echo "🛠 Installing base packages..."
/usr/bin/apt-get install -y curl unzip git build-essential ruby sudo

echo "📦 Installing Node.js + TypeScript..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | /usr/bin/sudo -E bash -
/usr/bin/apt-get install -y nodejs
/usr/bin/npm install -g typescript

# ----------------------------
# Install services from abiri.yaml
# ----------------------------
echo "🛠 Installing services..."
mapfile -t SERVICES < <(ruby -ryaml -e "
require 'yaml'
YAML.load_file('/vagrant/abiri.yaml')['services'].each { |s| puts s['name'] }
")
for SERVICE in "${SERVICES[@]}"; do
    echo "📦 Installing service: $SERVICE"
/usr/bin/apt-get install -y "$SERVICE"
done

# ----------------------------
# Configure sites
# ----------------------------
echo "🌐 Configuring sites..."
mapfile -t SITES < <(ruby -ryaml -e "
require 'yaml'
YAML.load_file('/vagrant/abiri.yaml')['sites'].each { |s| puts \"#{s['map']} #{s['to']}\" }
")
for SITE in "${SITES[@]}"; do
    DOMAIN=$(echo "$SITE" | awk '{print $1}')
    PATH_DIR=$(echo "$SITE" | awk '{print $2}')

    /bin/mkdir -p "$PATH_DIR"
/bin/chown -R vagrant:vagrant "$PATH_DIR"

/usr/bin/tee /etc/nginx/sites-available/$DOMAIN > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $PATH_DIR;

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

/bin/ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

grep -q "$IP $DOMAIN" /etc/hosts || echo "$IP $DOMAIN" >> /etc/hosts
done

/bin/systemctl reload nginx

# ----------------------------
# PostgreSQL setup
# ----------------------------
echo "🗄 Installing PostgreSQL..."
/usr/bin/apt-get install -y postgresql postgresql-contrib
/bin/systemctl enable postgresql
/bin/systemctl start postgresql

# Switch peer -> md5 auth for local connections
/bin/sed -i "s/^local\s\+all\s\+all\s\+peer/local all all md5/" /etc/postgresql/*/main/pg_hba.conf
/bin/systemctl restart postgresql
/bin/sleep 5

# Ensure 'vagrant' role exists
/usr/bin/sudo -u postgres /usr/bin/psql -tc "SELECT 1 FROM pg_roles WHERE rolname='vagrant'" | /bin/grep -q 1 || \
    /usr/bin/sudo -u postgres /usr/bin/psql -c "CREATE ROLE vagrant WITH LOGIN PASSWORD 'secret';"

# Create databases and users from abiri.yaml
ruby -ryaml -e "
require 'yaml'
dbs = YAML.load_file('/vagrant/abiri.yaml')['databases']
dbs.each do |d|
  name = d['name']
  user = d['user']
  pass = d['password']

  # Create role if missing
  system(\"/usr/bin/sudo -u postgres /usr/bin/psql -tc \\\"SELECT 1 FROM pg_roles WHERE rolname='#{user}'\\\" | /bin/grep -q 1 || /usr/bin/sudo -u postgres /usr/bin/psql -c \\\"CREATE ROLE #{user} WITH LOGIN PASSWORD '#{pass}';\\\"\")

  # Create database if missing
  system(\"/usr/bin/sudo -u postgres /usr/bin/psql -tc \\\"SELECT 1 FROM pg_database WHERE datname='#{name}'\\\" | /bin/grep -q 1 || /usr/bin/sudo -u postgres /usr/bin/createdb #{name} -O #{user}\")

  # Grant privileges
  system(\"/usr/bin/sudo -u postgres /usr/bin/psql -c \\\"GRANT ALL PRIVILEGES ON DATABASE #{name} TO #{user};\\\"\")
end
"

# ----------------------------
# Restart services
# ----------------------------
echo "🔄 Restarting services..."
for SERVICE in "${SERVICES[@]}"; do
    /bin/systemctl restart "$SERVICE"
done

echo "✅ Provisioning complete!"
echo "ℹ️ Connect using: psql -U vagrant -d <database> -W"
