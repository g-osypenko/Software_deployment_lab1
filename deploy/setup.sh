#!/bin/bash
set -e

sudo apt update
sudo apt install -y nginx postgresql postgresql-contrib python3-pip python3-venv libpq-dev

for user in student teacher operator; do
    sudo useradd -m -s /bin/bash $user || true
    echo "$user:12345678" | sudo chpasswd
    sudo passwd -e $user
done
sudo useradd -r -s /usr/sbin/nologin app || true

sudo -u postgres psql -c "CREATE DATABASE mywebapp_db;" || true
sudo -u postgres psql -c "CREATE USER mywebapp_user WITH PASSWORD 'securepassword';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mywebapp_db TO mywebapp_user;"
sudo -u postgres psql -d mywebapp_db -c "GRANT ALL ON SCHEMA public TO mywebapp_user; ALTER SCHEMA public OWNER TO mywebapp_user;"

sudo mkdir -p /opt/mywebapp /etc/mywebapp
sudo cp -r ../src/* /opt/mywebapp/

cat <<EOF | sudo tee /etc/mywebapp/config.yaml
db:
  host: "127.0.0.1"
  database: "mywebapp_db"
  user: "mywebapp_user"
  password: "securepassword"
app:
  port: 5000
EOF

cd /opt/mywebapp
sudo python3 -m venv venv
sudo ./venv/bin/pip install -r requirements.txt
sudo ./venv/bin/python3 -c "from database import TaskDatabase; import yaml; config = yaml.safe_load(open('/etc/mywebapp/config.yaml')); db = TaskDatabase(config); db.init_db()"
sudo chown -R app:app /opt/mywebapp

sudo cp ~/Software_deployment_lab1/deploy/mywebapp.service /etc/systemd/system/
sudo cp ~/Software_deployment_lab1/deploy/nginx.conf /etc/nginx/sites-available/mywebapp
sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

sudo systemctl daemon-reload
sudo systemctl enable mywebapp nginx
sudo systemctl restart mywebapp nginx

echo "operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx" | sudo tee /etc/sudoers.d/operator

echo "19" | sudo tee /home/student/gradebook
sudo chown student:student /home/student/gradebook