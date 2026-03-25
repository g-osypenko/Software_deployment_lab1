set -e 

echo ">>> Installing system packages..."
sudo apt update
sudo apt install -y nginx postgresql postgresql-contrib python3-pip python3-venv libpq-dev 

echo ">>> Creating users..."
sudo useradd -m -s /bin/bash student || true
sudo useradd -m -s /bin/bash teacher || true
sudo useradd -m -s /bin/bash operator || true
sudo useradd -r -s /usr/sbin/nologin app || true

echo "teacher:12345678" | sudo chpasswd
echo "operator:12345678" | sudo chpasswd
sudo passwd -e teacher
sudo passwd -e operator

echo ">>> Configuring PostgreSQL..."
sudo -u postgres psql -c "CREATE DATABASE mywebapp_db;" || true
sudo -u postgres psql -c "CREATE USER mywebapp_user WITH PASSWORD 'securepassword';" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE mywebapp_db TO mywebapp_user;" || true

echo ">>> Deploying application files..."
sudo mkdir -p /opt/mywebapp /etc/mywebapp
sudo cp -r ../src/* /opt/mywebapp/
sudo cp config.yaml /etc/mywebapp/config.yaml

cd /opt/mywebapp
sudo python3 -m venv venv
sudo ./venv/bin/pip install -r requirements.txt

echo ">>> Running DB migrations..."
sudo ./venv/bin/python3 -c "from database import TaskDatabase; import yaml; \
config = yaml.safe_load(open('/etc/mywebapp/config.yaml')); \
db = TaskDatabase(config); db.init_db()"

sudo chown -R app:app /opt/mywebapp
sudo chmod 600 /etc/mywebapp/config.yaml
sudo chown app:app /etc/mywebapp/config.yaml

echo ">>> Setting up systemd..."
sudo cp mywebapp.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable mywebapp
sudo systemctl start mywebapp [cite: 76]

echo ">>> Configuring Nginx..."
sudo cp nginx.conf /etc/nginx/sites-available/mywebapp
sudo ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart nginx

echo "operator ALL=(ALL) NOPASSWD: /usr/bin/systemctl start mywebapp, /usr/bin/systemctl stop mywebapp, /usr/bin/systemctl restart mywebapp, /usr/bin/systemctl status mywebapp, /usr/bin/systemctl reload nginx" | sudo tee /etc/sudoers.d/operator

echo ">>> Creating gradebook and locking default user..."
echo "19" | sudo tee /home/student/gradebook
sudo chown student:student /home/student/gradebook

# sudo usermod -L student_glib 

echo "DONE! Your system is deployed at http://localhost"