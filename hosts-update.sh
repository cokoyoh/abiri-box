#!/bin/bash
set -e

IP="$1"
YAML_FILE="$2"

# Extract domains from YAML on the host side
DOMAINS=$(ruby -ryaml -e "puts YAML.load_file('$YAML_FILE')['sites'].map { |s| s['map'] }")

for domain in $DOMAINS; do
    if ! grep -q "$domain" /etc/hosts; then
        echo "$IP $domain" | sudo tee -a /etc/hosts > /dev/null
        echo "➕ Added $domain to /etc/hosts"
    else
        echo "✔ $domain already exists in /etc/hosts"
    fi
done

echo "✅ Host /etc/hosts update complete!"
