sudo dnf install valkey
sudo systemctl start valkey
sudo systemctl enable valkey
valkey-cli info server
valkey-cli ping