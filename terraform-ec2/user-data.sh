#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log) 2>&1

# Variables (injected by Terraform)
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST}"

# Update and install packages
yum update -y
yum install -y httpd php php-mysqlnd mysql wget unzip || { echo "Package installation failed"; exit 1; }

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Download and configure WordPress
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
cp -r wordpress/* /var/www/html/
rm -rf wordpress latest.tar.gz

# Configure wp-config.php
cd /var/www/html
if [ ! -f wp-config.php ]; then
  cp wp-config-sample.php wp-config.php
fi
sed -i "s/database_name_here/${DB_NAME}/" wp-config.php
sed -i "s/username_here/${DB_USER}/" wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" wp-config.php
sed -i "s/localhost/${DB_HOST}/" wp-config.php

# Generate secure keys and salts
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
printf '%s\n' "g/put your unique phrase here/d" a "$SALT" . w | ed - wp-config.php

# Set correct permissions
chown -R apache:apache /var/www/html/
chmod -R 755 /var/www/html/

# Ensure database exists
mysql -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" || { echo "Database creation failed"; exit 1; }

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Calculate INSTANCE_URL dynamically
INSTANCE_URL=$(curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4)
if [ -z "$INSTANCE_URL" ]; then
  INSTANCE_URL="localhost"
fi

# Perform WordPress installation
wp core install \
  --url="http://${INSTANCE_URL}" \
  --title="My WordPress Site" \
  --admin_user=admin \
  --admin_password=AdminPass123! \
  --admin_email=admin@example.com \
  --allow-root || { echo "WordPress installation failed"; exit 1; }

# Restart Apache to ensure changes are loaded
systemctl restart httpd


# CloudWatch Agent Configuration
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/wordpress/ec2/messages",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/wordpress/ec2/httpd-access",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
