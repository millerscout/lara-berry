# Complete setup script for Lara Berry Docker Compose with Vaultwarden and Technitium DNS
# This script starts the services, waits for them to be ready, and configures Nginx Proxy Manager proxies

Write-Host "Starting Podman Compose services..."
podman-compose up -d

Write-Host "Waiting 30 seconds for services to start..."
Start-Sleep -Seconds 30

Write-Host "Getting NPM JWT token..."
$token = (Invoke-WebRequest -Uri "http://localhost:8081/api/tokens" -Method POST -ContentType "application/json" -Body '{"identity":"admin@example.com","secret":"changeme"}' | ConvertFrom-Json).token

Write-Host "Creating proxy hosts..."

# Vaultwarden proxy
Write-Host "Creating Vaultwarden proxy..."
Invoke-WebRequest -Uri "http://localhost:8081/api/nginx/proxy-hosts" -Method POST -Headers @{"Authorization"="Bearer $token"; "Content-Type"="application/json"} -Body '{"domain_names":["vaultwarden.persephone"],"forward_scheme":"http","forward_host":"host.docker.internal","forward_port":8082}' | Out-Null

# Uptime Kuma proxy
Write-Host "Creating Uptime Kuma proxy..."
Invoke-WebRequest -Uri "http://localhost:8081/api/nginx/proxy-hosts" -Method POST -Headers @{"Authorization"="Bearer $token"; "Content-Type"="application/json"} -Body '{"domain_names":["uptime.persephone"],"forward_scheme":"http","forward_host":"host.docker.internal","forward_port":3001}' | Out-Null

# Technitium DNS proxy
Write-Host "Creating Technitium DNS proxy..."
Invoke-WebRequest -Uri "http://localhost:8081/api/nginx/proxy-hosts" -Method POST -Headers @{"Authorization"="Bearer $token"; "Content-Type"="application/json"} -Body '{"domain_names":["persephone"],"forward_scheme":"http","forward_host":"host.docker.internal","forward_port":5381}' | Out-Null

Write-Host "Setup complete! Services are running and proxies are configured."
Write-Host "Access:"
Write-Host "  Vaultwarden: http://vaultwarden.persephone"
Write-Host "  Uptime Kuma: http://uptime.persephone"
Write-Host "  Technitium DNS: http://persephone"
Write-Host ""
Write-Host "Don't forget to add these domains to your hosts file:"
Write-Host "127.0.0.1 vaultwarden.persephone"
Write-Host "127.0.0.1 uptime.persephone"
Write-Host "127.0.0.1 persephone"