#!/bin/bash

# Example: Run a simple Nginx container using Podman
# This demonstrates basic Podman usage after setup

echo "Running Nginx container on port 8080..."

# Pull and run Nginx in detached mode
podman run -d --name nginx-example -p 8080:80 nginx

# Check if it's running
if podman ps | grep -q nginx-example; then
    echo "Nginx container is running!"
    echo "Access it at http://localhost:8080 or http://your-pi-ip:8080"
    echo "To stop: podman stop nginx-example && podman rm nginx-example"
else
    echo "Failed to start container. Check Podman setup."
fi