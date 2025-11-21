#!/bin/bash

# Setup DNS zone for lara-berry using Technitium API
# Run after Technitium is accessible

PI_IP=$(hostname -I | awk '{print $1}')
TECHNIUM_URL="http://127.0.0.1:5381"

echo "Setting up DNS zone for lara-berry with IP: $PI_IP"

# Create primary zone
curl -X POST "$TECHNIUM_URL/api/zones/create" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"lara-berry\", \"type\": \"Primary\"}"

# Add A record for @
curl -X POST "$TECHNIUM_URL/api/zones/records/create" \
  -H "Content-Type: application/json" \
  -d "{\"zone\": \"lara-berry\", \"name\": \"@\", \"type\": \"A\", \"value\": \"$PI_IP\"}"

# Add A record for vaultwarden
curl -X POST "$TECHNIUM_URL/api/zones/records/create" \
  -H "Content-Type: application/json" \
  -d "{\"zone\": \"lara-berry\", \"name\": \"vaultwarden\", \"type\": \"A\", \"value\": \"$PI_IP\"}"

# Add more records as needed...

echo "DNS setup complete. Test with: nslookup lara-berry $PI_IP"