# Get JWT token
TOKEN=$(curl -s -X POST http://localhost:8081/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"changeme"}' | jq -r '.token')

# Commands to create proxy hosts via Nginx Proxy Manager API

# Vaultwarden proxy
curl -X POST http://localhost:8081/api/nginx/proxy-hosts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domain_names":["vaultwarden.persephone"],"forward_scheme":"http","forward_host":"host.docker.internal","forward_port":8082}'

# Uptime Kuma proxy
curl -X POST http://localhost:8081/api/nginx/proxy-hosts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domain_names":["uptime.persephone"],"forward_scheme":"http","forward_host":"host.docker.internal","forward_port":3001}'

# Technitium DNS proxy
curl -X POST http://localhost:8081/api/nginx/proxy-hosts \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"domain_names":["persephone"],"forward_scheme":"http","forward_host":"host.docker.internal","forward_port":5381}'