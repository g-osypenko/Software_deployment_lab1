#!/bin/bash
set -e

sudo apt update
sudo apt install -y nginx postgresql postgresql-contrib python3-pip python3-venv libpq-dev [cite: 71]

for user in student teacher operator; do
    sudo useradd -m -s /bin/bash $user || true [cite: 72]
    echo "$user:12345678" | sudo chpasswd 
    sudo passwd -e $user 
done
sudo useradd -r -s /usr/sbin/nologin app || true 

sudo -u postgres psql -c "CREATE DATABASE mywebapp_db;" || true [cite: 73]
sudo -u postgres psql -c "CREATE USER mywebapp_user WITH PASSWORD 'securepassword';" || true [cite: 73]
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mywebapp_db TO mywebapp_user;" [cite: 73]
sudo -u postgres psql -d mywebapp_db -c "GRANT ALL ON SCHEMA public TO mywebapp_user; ALTER SCHEMA public OWNER TO mywebapp_user;"

sudo mkdir -p /opt/mywebapp /etc/mywebapp [cite: 74]
sudo cp -r ../src/* /opt/mywebapp/ [cite: 74]

cat <<EOF | sudo tee /etc/mywebapp/config.yaml
db:
  host: "127.0.0.1"
  database: "mywebapp_db"
  user: "mywebapp_user"
  password: "securepassword"
app:
  port: 5000
EOF [cite: 34, 36]

cd /opt/mywebapp
sudo python3 -m venv venv [cite: 71]
sudo ./venv/bin/pip install -r requirements.txt [cite: 71]
sudo ./venv/bin/python3 -c "from database import TaskDatabase; import yaml; config = yaml.safe_load(open('/etc/mywebapp/config.yaml')); db = TaskDatabase(config); db.init_db()" [cite: 52, 53]
sudo chown -R app:app /opt/mywebapp [cite: 59]

sudo cp ~/Software_deployment_lab1/deploy/mywebapp.service /etc/systemd/system/ [cite: 58]
sudo cp ~/Software_deployment_lab1/deploy/nginx.conf /etc/nginx/sites-available/mywebapp [cite: 77]
sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/ [cite: 77]
sudo rm -f /etc/nginx/sites-enabled/default

sudo systemctl daemon-reload
sudo systemctl enable mywebapp nginx [cite: 75, 76]
sudo systemctl restart mywebapp nginx [cite: 76]

echo "operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx" | sudo tee /etc/sudoers.d/operator 

echo "19" | sudo tee /home/student/gradebook [cite: 78]
sudo chown student:student /home/student/gradebook