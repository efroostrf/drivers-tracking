#!/bin/bash

# MongoDB Replica Set Setup Script
# This script automates the complete setup of a MongoDB replica set with user authentication

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# Phase 1: Prerequisites Check
print_header "Phase 1: Prerequisites Check"

print_info "Checking for .env file..."
if [ ! -f "$ENV_FILE" ]; then
    print_error ".env file not found at: $ENV_FILE"
    print_info "Please create a .env file based on .env.example"
    print_info "Example:"
    echo "  cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env"
    echo "  # Then edit .env and set your passwords"
    exit 1
fi

print_info "Loading environment variables from .env..."
source "$ENV_FILE"

# Verify required environment variables
if [ -z "$MONGO_ADMIN_PASSWORD" ]; then
    print_error "MONGO_ADMIN_PASSWORD is not set in .env file"
    exit 1
fi

if [ -z "$MONGO_APP_PASSWORD" ]; then
    print_error "MONGO_APP_PASSWORD is not set in .env file"
    exit 1
fi

if [ -z "$MONGO_PROMETHEUS_PASSWORD" ]; then
    print_error "MONGO_PROMETHEUS_PASSWORD is not set in .env file"
    exit 1
fi

print_success "Environment variables loaded successfully"

# Phase 2: Keyfile & Docker Setup
print_header "Phase 2: Keyfile & Docker Setup"

print_info "Generating keyfile and creating directory structure..."
cd "$SCRIPT_DIR"
bash ./generate-keyfile.sh

if [ $? -ne 0 ]; then
    print_error "Failed to generate keyfile"
    exit 1
fi

print_info "Starting Docker containers..."
docker compose up -d

if [ $? -ne 0 ]; then
    print_error "Failed to start Docker containers"
    exit 1
fi

print_info "Waiting for containers to be healthy..."
MAX_WAIT=60
WAIT_COUNT=0
while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    MONGO1_HEALTH=$(docker inspect mongo-1 --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    MONGO2_HEALTH=$(docker inspect mongo-2 --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    MONGO3_HEALTH=$(docker inspect mongo-3 --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    
    if [ "$MONGO1_HEALTH" = "healthy" ] && [ "$MONGO2_HEALTH" = "healthy" ] && [ "$MONGO3_HEALTH" = "healthy" ]; then
        print_success "All containers are healthy"
        break
    fi
    
    echo -n "."
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    print_error "Containers did not become healthy in time"
    print_info "Container health status:"
    echo "  mongo-1: $MONGO1_HEALTH"
    echo "  mongo-2: $MONGO2_HEALTH"
    echo "  mongo-3: $MONGO3_HEALTH"
    exit 1
fi

# Phase 3: IP Address Selection
print_header "Phase 3: IP Address Selection"

print_info "Detecting available network interfaces..."

# Detect IP addresses (filtering out loopback and docker interfaces)
IPS=()
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    while IFS= read -r line; do
        IPS+=("$line")
    done < <(ifconfig | grep "inet " | grep -v "127.0.0.1" | grep -v "inet 172\." | awk '{print $2}')
else
    # Linux
    while IFS= read -r line; do
        IPS+=("$line")
    done < <(hostname -I | tr ' ' '\n' | grep -v "^127\." | grep -v "^172\.")
fi

if [ ${#IPS[@]} -eq 0 ]; then
    print_error "No suitable IP addresses found"
    print_info "Please ensure you have a network connection"
    exit 1
fi

echo "Available IP addresses:"
for i in "${!IPS[@]}"; do
    echo "  $((i+1)). ${IPS[$i]}"
done

echo ""
read -p "Select IP address number (1-${#IPS[@]}): " IP_SELECTION

if ! [[ "$IP_SELECTION" =~ ^[0-9]+$ ]] || [ "$IP_SELECTION" -lt 1 ] || [ "$IP_SELECTION" -gt ${#IPS[@]} ]; then
    print_error "Invalid selection"
    exit 1
fi

SELECTED_IP="${IPS[$((IP_SELECTION-1))]}"
print_success "Selected IP: $SELECTED_IP"

# Phase 4: Replica Set Initialization
print_header "Phase 4: Replica Set Initialization"

print_info "Initializing replica set..."

INIT_COMMAND="rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: '${SELECTED_IP}:27017' },
    { _id: 1, host: '${SELECTED_IP}:27018' },
    { _id: 2, host: '${SELECTED_IP}:27019' }
  ]
})"

docker exec mongo-1 mongosh --quiet --eval "$INIT_COMMAND"

if [ $? -ne 0 ]; then
    print_error "Failed to initialize replica set"
    exit 1
fi

print_success "Replica set initialization command sent"

print_info "Waiting for replica set to stabilize..."
MAX_WAIT=60
WAIT_COUNT=0
PRIMARY_FOUND=false

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    RS_STATUS=$(docker exec mongo-1 mongosh --quiet --eval "rs.status().members.find(m => m.state === 1)" 2>/dev/null || echo "")
    
    if [ -n "$RS_STATUS" ] && [ "$RS_STATUS" != "null" ]; then
        print_success "Primary node established"
        PRIMARY_FOUND=true
        break
    fi
    
    echo -n "."
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
done

if [ "$PRIMARY_FOUND" = false ]; then
    print_error "Replica set did not stabilize in time"
    print_info "Checking replica set status:"
    docker exec mongo-1 mongosh --eval "rs.status()"
    exit 1
fi

# Additional wait for full stabilization
print_info "Waiting for full replica synchronization..."
sleep 5

# Identify the actual PRIMARY node
print_info "Identifying PRIMARY node..."
PRIMARY_HOST=$(docker exec mongo-1 mongosh --quiet --eval "
  const status = rs.status();
  const primary = status.members.find(m => m.state === 1);
  if (primary) {
    print(primary.name);
  } else {
    print('none');
  }
" 2>/dev/null | tail -1)

if [ "$PRIMARY_HOST" = "none" ] || [ -z "$PRIMARY_HOST" ]; then
    print_error "Could not identify PRIMARY node"
    docker exec mongo-1 mongosh --eval "rs.status()"
    exit 1
fi

print_success "PRIMARY node identified: $PRIMARY_HOST"

# Determine which container to use based on the port
PRIMARY_PORT=$(echo "$PRIMARY_HOST" | awk -F: '{print $2}')
if [ "$PRIMARY_PORT" = "27017" ]; then
    PRIMARY_CONTAINER="mongo-1"
elif [ "$PRIMARY_PORT" = "27018" ]; then
    PRIMARY_CONTAINER="mongo-2"
elif [ "$PRIMARY_PORT" = "27019" ]; then
    PRIMARY_CONTAINER="mongo-3"
else
    print_error "Unknown PRIMARY port: $PRIMARY_PORT"
    exit 1
fi

print_info "Using container: $PRIMARY_CONTAINER"

# Phase 5: User Creation on Primary Node
print_header "Phase 5: User Creation on Primary Node"

print_info "Creating admin user on PRIMARY node ($PRIMARY_CONTAINER)..."

ADMIN_USER_COMMAND="db.getSiblingDB('admin').createUser({
  user: 'admin',
  pwd: '${MONGO_ADMIN_PASSWORD}',
  roles: [
    { role: 'userAdminAnyDatabase', db: 'admin' },
    { role: 'clusterAdmin', db: 'admin' }
  ]
})"

docker exec "$PRIMARY_CONTAINER" mongosh --quiet --eval "$ADMIN_USER_COMMAND"

if [ $? -ne 0 ]; then
    print_error "Failed to create admin user"
    exit 1
fi

print_success "Admin user created successfully"

print_info "Creating application user on PRIMARY node (authenticated as admin)..."

APP_USER_COMMAND="db.getSiblingDB('admin').createUser({
  user: 'application',
  pwd: '${MONGO_APP_PASSWORD}',
  roles: [{ role: 'dbOwner', db: 'drivers_tracking' }]
})"

docker exec "$PRIMARY_CONTAINER" mongosh --quiet \
    -u admin \
    -p "$MONGO_ADMIN_PASSWORD" \
    --authenticationDatabase admin \
    --eval "$APP_USER_COMMAND"

if [ $? -ne 0 ]; then
    print_error "Failed to create application user"
    exit 1
fi

print_success "Application user created successfully"

print_info "Creating prometheus monitoring user on PRIMARY node..."

PROMETHEUS_USER_COMMAND="db.getSiblingDB('admin').createUser({
  user: 'prometheus',
  pwd: '${MONGO_PROMETHEUS_PASSWORD}',
  roles: [
    { role: 'clusterMonitor', db: 'admin' },
    { role: 'read', db: 'local' }
  ]
})"

docker exec "$PRIMARY_CONTAINER" mongosh --quiet \
    -u admin \
    -p "$MONGO_ADMIN_PASSWORD" \
    --authenticationDatabase admin \
    --eval "$PROMETHEUS_USER_COMMAND"

if [ $? -ne 0 ]; then
    print_error "Failed to create prometheus user"
    exit 1
fi

print_success "Prometheus user created successfully"

# Phase 6: Verification & Summary
print_header "Phase 6: Verification & Summary"

print_info "Verifying application user connection on PRIMARY node..."

VERIFY_COMMAND="db.getSiblingDB('drivers_tracking').runCommand({ connectionStatus: 1 })"

VERIFY_RESULT=$(docker exec "$PRIMARY_CONTAINER" mongosh --quiet \
    -u application \
    -p "$MONGO_APP_PASSWORD" \
    --authenticationDatabase admin \
    --eval "$VERIFY_COMMAND" 2>&1)

if [ $? -eq 0 ]; then
    print_success "Application user can connect successfully"
else
    print_warning "Could not verify application user connection"
    print_info "This might be expected if authentication is still propagating"
fi

# Display Summary
print_header "Setup Complete!"

echo -e "${GREEN}MongoDB Replica Set Configuration:${NC}"
echo "  Replica Set Name: rs0"
echo "  Current PRIMARY: ${PRIMARY_HOST} (container: ${PRIMARY_CONTAINER})"
echo "  Node 1: ${SELECTED_IP}:27017 (mongo-1)"
echo "  Node 2: ${SELECTED_IP}:27018 (mongo-2)"
echo "  Node 3: ${SELECTED_IP}:27019 (mongo-3)"
echo ""
echo -e "${GREEN}User Accounts:${NC}"
echo "  Admin User: admin (userAdminAnyDatabase, clusterAdmin)"
echo "  Application User: application (dbOwner on drivers_tracking)"
echo "  Prometheus User: prometheus (clusterMonitor, read on local)"
echo ""
echo -e "${GREEN}Connection Strings:${NC}"
echo ""
echo "  Admin Connection:"
echo "    mongodb://admin:YOUR_ADMIN_PASSWORD@${SELECTED_IP}:27017,${SELECTED_IP}:27018,${SELECTED_IP}:27019/?replicaSet=rs0&authSource=admin"
echo ""
echo "  Application Connection:"
echo "    mongodb://application:YOUR_APP_PASSWORD@${SELECTED_IP}:27017,${SELECTED_IP}:27018,${SELECTED_IP}:27019/drivers_tracking?replicaSet=rs0&authSource=admin"
echo ""
echo "  Prometheus Connection:"
echo "    mongodb://prometheus:YOUR_PROMETHEUS_PASSWORD@${SELECTED_IP}:27017/?authSource=admin"
echo ""
echo -e "${GREEN}Prometheus Metrics Endpoints:${NC}"
echo "  http://localhost:9216/metrics (mongo-1)"
echo "  http://localhost:9217/metrics (mongo-2)"
echo "  http://localhost:9218/metrics (mongo-3)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Update your application's .env file with the connection string"
echo "  2. Replace YOUR_APP_PASSWORD with the actual password from infrastructure/mongo/.env"
echo "  3. Test the connection from your application"
echo ""
print_success "MongoDB replica set is ready for use!"
