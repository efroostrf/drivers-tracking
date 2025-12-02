#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Monitoring Stack Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# Check for required tools
check_requirements() {
    echo -e "${YELLOW}Checking requirements...${NC}"
    
    if ! command -v nmap &> /dev/null; then
        echo -e "${RED}Error: nmap is not installed.${NC}"
        echo "Please install nmap:"
        echo "  macOS:  brew install nmap"
        echo "  Ubuntu: sudo apt-get install nmap"
        echo "  CentOS: sudo yum install nmap"
        exit 1
    fi
    
    echo -e "${GREEN}✓ nmap is installed${NC}"
    echo
}

# Auto-detect current subnet
detect_subnet() {
    echo -e "${YELLOW}Detecting network subnet...${NC}"
    
    # Get the primary network interface IP
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
    else
        # Linux
        LOCAL_IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$LOCAL_IP" ]; then
        echo -e "${RED}Error: Could not detect local IP address.${NC}"
        exit 1
    fi
    
    # Extract subnet (assuming /24)
    SUBNET=$(echo "$LOCAL_IP" | sed 's/\.[0-9]*$/.0\/24/')
    
    echo -e "${GREEN}✓ Local IP: $LOCAL_IP${NC}"
    echo -e "${GREEN}✓ Subnet: $SUBNET${NC}"
    echo
}

# Scan for MongoDB exporters
scan_exporters() {
    echo -e "${YELLOW}Scanning network for MongoDB exporters...${NC}"
    echo -e "  Scanning ports 9216, 9217, 9218 on $SUBNET"
    echo -e "  This may take a moment..."
    echo
    
    EXPORTER_PORTS="9216,9217,9218"
    DISCOVERED_TARGETS=()
    
    # Run nmap scan and capture results
    SCAN_RESULTS=$(nmap -p $EXPORTER_PORTS --open -oG - "$SUBNET" 2>/dev/null | grep "Ports:")
    
    if [ -z "$SCAN_RESULTS" ]; then
        echo -e "${RED}No MongoDB exporters found on the network.${NC}"
        echo "Make sure the MongoDB replica set with exporters is running."
        exit 1
    fi
    
    # Parse nmap output to extract IPs and open ports
    while IFS= read -r line; do
        IP=$(echo "$line" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}')
        
        # Check each port
        if echo "$line" | grep -q "9216/open"; then
            DISCOVERED_TARGETS+=("$IP:9216")
            echo -e "${GREEN}  ✓ Found exporter at $IP:9216${NC}"
        fi
        if echo "$line" | grep -q "9217/open"; then
            DISCOVERED_TARGETS+=("$IP:9217")
            echo -e "${GREEN}  ✓ Found exporter at $IP:9217${NC}"
        fi
        if echo "$line" | grep -q "9218/open"; then
            DISCOVERED_TARGETS+=("$IP:9218")
            echo -e "${GREEN}  ✓ Found exporter at $IP:9218${NC}"
        fi
    done <<< "$SCAN_RESULTS"
    
    if [ ${#DISCOVERED_TARGETS[@]} -eq 0 ]; then
        echo -e "${RED}No MongoDB exporters found on the network.${NC}"
        exit 1
    fi
    
    echo
    echo -e "${GREEN}Found ${#DISCOVERED_TARGETS[@]} exporter(s)${NC}"
    echo
}

# Prompt for scrape interval
prompt_scrape_interval() {
    echo -e "${YELLOW}Configuration${NC}"
    read -p "Enter Prometheus scrape interval [15s]: " SCRAPE_INTERVAL
    SCRAPE_INTERVAL=${SCRAPE_INTERVAL:-15s}
    echo -e "${GREEN}✓ Scrape interval: $SCRAPE_INTERVAL${NC}"
    echo
}

# Prompt for Grafana password
prompt_grafana_password() {
    while true; do
        read -sp "Enter Grafana admin password: " GRAFANA_PASSWORD
        echo
        
        if [ -z "$GRAFANA_PASSWORD" ]; then
            echo -e "${RED}Password cannot be empty.${NC}"
            continue
        fi
        
        read -sp "Confirm Grafana admin password: " GRAFANA_PASSWORD_CONFIRM
        echo
        
        if [ "$GRAFANA_PASSWORD" != "$GRAFANA_PASSWORD_CONFIRM" ]; then
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
            continue
        fi
        
        break
    done
    
    echo -e "${GREEN}✓ Grafana password set${NC}"
    echo
}

# Generate prometheus.yml
generate_prometheus_config() {
    echo -e "${YELLOW}Generating prometheus.yml...${NC}"
    
    # Build targets list with proper YAML formatting
    TARGETS_YAML=""
    REPLICA_NUM=1
    for target in "${DISCOVERED_TARGETS[@]}"; do
        TARGETS_YAML+="          - '$target'  # MongoDB Exporter - Replica $REPLICA_NUM"$'\n'
        ((REPLICA_NUM++))
    done
    
    # Remove trailing newline (compatible with both BSD and GNU sed)
    TARGETS_YAML="${TARGETS_YAML%$'\n'}"
    
    cat > prometheus.yml << EOF
global:
  scrape_interval: $SCRAPE_INTERVAL

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'mongodb_remote'
    static_configs:
      - targets:
$TARGETS_YAML
        labels:
          cluster: 'production_rs0'
EOF
    
    echo -e "${GREEN}✓ prometheus.yml created${NC}"
}

# Generate .env file
generate_env_file() {
    echo -e "${YELLOW}Generating .env file...${NC}"
    
    cat > .env << EOF
GRAFANA_ADMIN_PASSWORD=$GRAFANA_PASSWORD
EOF
    
    chmod 600 .env
    echo -e "${GREEN}✓ .env created${NC}"
}

# Create data directories
create_data_directories() {
    echo -e "${YELLOW}Creating data directories...${NC}"
    
    mkdir -p data/prometheus
    mkdir -p data/grafana
    
    # Set permissions for Grafana (runs as user 472)
    chmod 777 data/grafana
    
    # Set permissions for Prometheus (runs as nobody)
    chmod 777 data/prometheus
    
    echo -e "${GREEN}✓ Data directories created${NC}"
}

# Start docker compose
start_services() {
    echo -e "${YELLOW}Starting monitoring stack...${NC}"
    
    docker compose up -d
    
    echo -e "${GREEN}✓ Monitoring stack started${NC}"
}

# Main execution
main() {
    check_requirements
    detect_subnet
    scan_exporters
    prompt_scrape_interval
    prompt_grafana_password
    generate_prometheus_config
    generate_env_file
    create_data_directories
    start_services
    
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}  Setup Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo
    echo "Access the services:"
    echo -e "  Prometheus: ${BLUE}http://localhost:9090${NC}"
    echo -e "  Grafana:    ${BLUE}http://localhost:3000${NC}"
    echo -e "              User: admin"
    echo -e "              Password: (from .env file)"
    echo
}

main

