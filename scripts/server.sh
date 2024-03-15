#!/bin/bash

# Install dependencies
apt-get update
apt-get install -y curl unzip ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/trusted.gpg.d/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs

# Download and unzip the application
curl -LO "https://github.com/jcolemorrison/multiplayer-cloud-server/archive/refs/tags/v${APP_VERSION}.zip"
unzip "v${APP_VERSION}.zip"
cd "multiplayer-cloud-server-${APP_VERSION}"

# Install Node.js dependencies and build the application
npm install
npm run build

# Create a systemd unit file
cat > /etc/systemd/system/game.service <<- EOF
[Unit]
Description=Node.js Game App
After=network.target

[Service]
Environment="NODE_ENV=${NODE_ENV}"
Environment="REDIS_HOST=${REDIS_HOST}"
Environment="PORT=${PORT}"
WorkingDirectory=/multiplayer-cloud-server-${APP_VERSION}
ExecStart=/usr/bin/node dist/index.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable game
systemctl start game