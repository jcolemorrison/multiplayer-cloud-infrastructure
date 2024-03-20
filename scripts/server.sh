#!/bin/bash

# Install Google Cloud Logging agent
curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh
bash add-logging-agent-repo.sh
apt-get update
apt-get install -y 'google-fluentd=1.*' google-fluentd-catch-all-config-structured
service google-fluentd start

# Install dependencies
apt-get update
apt-get install -y curl unzip ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor -o /etc/apt/trusted.gpg.d/nodesource.gpg
NODE_MAJOR=20
echo "deb [signed-by=/etc/apt/trusted.gpg.d/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs

# Install rsyslog if it's not already installed
if ! command -v rsyslogd &> /dev/null
then
    apt-get install -y rsyslog
fi

# Configure rsyslog to read from the journal
cat > /etc/rsyslog.d/99-systemd.conf <<- EOF
module(load="imuxsock") # provides support for local system logging
module(load="imjournal" StateFile="imjournal.state") # provides access to the systemd journal

# set the default message size to 64k, which should be large enough for most journal messages
$MaxMessageSize 64k

# Forward logs from the game service to /var/log/syslog
if $programname == 'game' then /var/log/syslog
& stop
EOF

# Start rsyslog
systemctl start rsyslog
systemctl enable rsyslog

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
StandardOutput=journal
StandardError=journal
SyslogIdentifier=game
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
systemctl daemon-reload
systemctl enable game
systemctl start game