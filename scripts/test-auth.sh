#!/bin/sh
echo "Testing different NPM auth methods..."

echo "1. Testing with identity field:"
curl -s -X POST http://nginx-proxy-manager:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","secret":"changeme"}'

echo -e "\n\n2. Testing with username field:"
curl -s -X POST http://nginx-proxy-manager:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@example.com","password":"changeme"}'

echo -e "\n\n3. Testing with email field:"
curl -s -X POST http://nginx-proxy-manager:81/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"changeme"}'

echo -e "\n\n4. Testing login endpoint:"
curl -s -X POST http://nginx-proxy-manager:81/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@example.com","password":"changeme"}'

echo -e "\n\n5. Testing auth endpoint:"
curl -s -X POST http://nginx-proxy-manager:81/api/auth \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@example.com","password":"changeme"}'