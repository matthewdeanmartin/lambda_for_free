sudo dnf install -y postgresql17 postgresql17-server
/usr/bin/postgresql-setup --initdb --unit postgresql
sudo systemctl start postgresql
sudo su postgres