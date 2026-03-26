#!/bin/bash
# Myzr game server — RunPod startup script
# Clones from GitHub and starts the Node.js server

set -e

cd /workspace

# Clone or pull latest
if [ -d "myzr" ]; then
  cd myzr && git pull
else
  apt-get update -qq && apt-get install -y -qq git > /dev/null 2>&1
  git clone https://github.com/oxygn-cloud-ai/claude-skills.git myzr
  cd myzr
fi

# Install dependencies
cd server
npm install --omit=dev
cd ..

# Start the server
echo "Starting Myzr server on port 3000..."
exec node server/server.js
