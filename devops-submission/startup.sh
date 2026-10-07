#!/bin/sh
set -e

echo "Running startup script..."

# Ensure the app directory and its contents are owned by the node user
chown -R node:node /app

# Create the temporary directory that the node user needs
# and ensure it has the right permissions.
mkdir -p /home/node/tmp
chown -R node:node /home/node/tmp

echo "Permissions set. Starting application..."

# Execute the main process (this is passed from CMD)
exec "$@"