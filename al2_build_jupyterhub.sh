#!/bin/bash

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

# https://jupyterhub.readthedocs.io/en/1.2.1/installation-guide-hard.html
echo "Building jupyterlab service"
rm -rf /opt/jupyterhub
python3 -m venv /opt/jupyterhub

sudo /opt/jupyterhub/bin/python3 -m pip install --upgrade pip
sudo /opt/jupyterhub/bin/python3 -m pip install wheel
sudo /opt/jupyterhub/bin/python3 -m pip install jupyterhub jupyterlab
sudo /opt/jupyterhub/bin/python3 -m pip install ipywidgets

sudo yum install -y nodejs npm
sudo npm install -g configurable-http-proxy

# ssl config
# https://stackoverflow.com/questions/36387654/jupyter-on-ec2-ssl-error
mkdir /opt/jupyterhub/certs
cd /opt/jupyterhub/certs
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -keyout cert.key -out cert.pem -subj "/C=US/ST=Pennsylvnia/L=Philadelphia/O=Company X/OU=Company X Labs/CN=Company X Self-Signed" 

sudo mkdir -p /opt/jupyterhub/etc/jupyterhub/
cd /opt/jupyterhub/etc/jupyterhub/
sudo /opt/jupyterhub/bin/jupyterhub --generate-config

# backup config file
cp /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.bak 

# jupyterhub config (change to your liking)
cat >> /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py <<- EOM
c.Spawner.default_url = ''
c.Authenticator.allow_all = True
c.Authenticator.allowed_users = {'user1', 'user2', 'user3'}
c.Authenticator.delete_invalid_users = True
c.JupyterHub.ssl_cert = '/opt/jupyterhub/certs/cert.pem'
c.JupyterHub.ssl_key = '/opt/jupyterhub/certs/cert.key'
c.JupyterHub.port = 8000
EOM

# systemd service
sudo mkdir -p /opt/jupyterhub/etc/systemd

cat > /opt/jupyterhub/etc/systemd/jupyterhub.service <<- EOM
[Unit]
Description=JupyterHub
After=syslog.target network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/jupyterhub/bin"
ExecStart=/opt/jupyterhub/bin/jupyterhub -f /opt/jupyterhub/etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOM

sudo ln -sf /opt/jupyterhub/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service
sudo systemctl daemon-reload
sudo systemctl enable jupyterhub.service
sudo systemctl start jupyterhub.service
sudo systemctl status jupyterhub.service