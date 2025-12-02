# MongoDB Replica Set Infrastructure

This directory contains the infrastructure configuration and automation scripts for setting up a MongoDB replica set with authentication.

## Overview

The MongoDB deployment consists of three instances configured as a replica set named `rs0`. The setup includes automated initialization, user creation, and authentication configuration.

## Prerequisites

- Docker and Docker Compose
- bash shell
- openssl (for keyfile generation)
- Network connectivity on the host machine

## Quick Start

1. Create environment configuration:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and set secure passwords:

   ```
   MONGO_ADMIN_PASSWORD=<your-secure-admin-password>
   MONGO_APP_PASSWORD=<your-secure-application-password>
   MONGO_PROMETHEUS_PASSWORD=<your-secure-prometheus-password>
   ```

3. Run the setup script:

   ```bash
   ./setup-replica.sh
   ```

4. Select your network IP address from the presented list.

5. Wait for the setup to complete.

## Directory Structure

```
mongo/
├── .env.example              # Environment variables template
├── .gitignore               # Git ignore rules (excludes .env and data)
├── docker-compose.yml       # Docker Compose configuration
├── generate-keyfile.sh      # Keyfile generation script
├── setup-replica.sh         # Automated setup script
└── mongo/                   # MongoDB data directory (created during setup)
    ├── keyfile              # Replica set authentication keyfile
    ├── node1/               # mongo-1 node data
    ├── node2/               # mongo-2 node data
    └── node3/               # mongo-3 node data
```

## Architecture

### MongoDB Instances

Three MongoDB 8.0 instances are deployed as Docker containers:

| Container Name   | Port  | Role                        |
| ---------------- | ----- | --------------------------- |
| mongo-1          | 27017 | Replica set member          |
| mongo-2          | 27018 | Replica set member          |
| mongo-3          | 27019 | Replica set member          |
| mongo-exporter-1 | 9216  | Metrics exporter for mongo-1 |
| mongo-exporter-2 | 9217  | Metrics exporter for mongo-2 |
| mongo-exporter-3 | 9218  | Metrics exporter for mongo-3 |

**Note:** The PRIMARY role is elected dynamically by the replica set. Any container can become the PRIMARY node.

### Replica Set Configuration

- **Replica Set Name:** `rs0`
- **Authentication:** Keyfile-based authentication between replica members
- **Network Binding:** All interfaces (`--bind_ip_all`)

## Setup Process

The `setup-replica.sh` script automates the complete setup process through six phases:

### Phase 1: Prerequisites Check

Validates the environment configuration:

- Verifies `.env` file exists
- Loads environment variables
- Confirms `MONGO_ADMIN_PASSWORD` is set
- Confirms `MONGO_APP_PASSWORD` is set
- Confirms `MONGO_PROMETHEUS_PASSWORD` is set

If validation fails, the script exits with an error message.

### Phase 2: Keyfile & Docker Setup

Prepares the infrastructure:

1. Executes `generate-keyfile.sh` to:
   - Create `mongo/` directory structure if it doesn't exist
   - Generate a 756-byte base64-encoded keyfile
   - Set file permissions to 400 (read-only for owner)
2. Starts Docker containers via `docker compose up -d`
3. Polls container health status until all three instances report healthy (timeout: 60 seconds)

### Phase 3: IP Address Selection

Detects and presents available network interfaces:

- On macOS: Uses `ifconfig` to detect IP addresses
- On Linux: Uses `hostname -I` to detect IP addresses
- Filters out loopback (`127.0.0.1`) and Docker bridge (`172.x.x.x`) interfaces
- Presents numbered list of available IPs
- Prompts user to select the IP address for replica set configuration

The selected IP is used to configure the replica set member hostnames.

### Phase 4: Replica Set Initialization

Initializes the replica set:

1. Executes `rs.initiate()` command with three members:
   - Member 0: `<selected-ip>:27017`
   - Member 1: `<selected-ip>:27018`
   - Member 2: `<selected-ip>:27019`
2. Waits for PRIMARY node to be elected (timeout: 60 seconds)
3. Waits additional 5 seconds for full replica synchronization
4. Queries `rs.status()` to identify which node was elected as PRIMARY
5. Determines the corresponding Docker container name based on the PRIMARY port

### Phase 5: User Creation on Primary Node

Creates user accounts on the elected PRIMARY node:

1. **Admin User Creation:**

   - Username: `admin`
   - Password: From `MONGO_ADMIN_PASSWORD`
   - Database: `admin`
   - Roles:
     - `userAdminAnyDatabase` - Manage users across all databases
     - `clusterAdmin` - Administer the replica set cluster
   - Authentication: Unauthenticated (first user creation)

2. **Application User Creation:**
   - Username: `application`
   - Password: From `MONGO_APP_PASSWORD`
   - Database: `admin`
   - Roles:
     - `dbOwner` on `drivers_tracking` database
   - Authentication: Authenticated as `admin` user

3. **Prometheus User Creation:**
   - Username: `prometheus`
   - Password: From `MONGO_PROMETHEUS_PASSWORD`
   - Database: `admin`
   - Roles:
     - `clusterMonitor` on `admin` database - Read-only access to cluster monitoring
     - `read` on `local` database - Read access to replication oplog
   - Authentication: Authenticated as `admin` user

All user creation commands are executed on the actual PRIMARY node, not assumed on a specific container.

### Phase 6: Verification & Summary

Validates the setup and displays configuration:

1. Tests connection using application user credentials
2. Displays replica set configuration:
   - Replica set name
   - Current PRIMARY node
   - All member nodes
3. Lists created user accounts with their roles
4. Provides connection strings for:
   - Admin user (for administrative tasks)
   - Application user (for application connectivity)

## User Accounts

### Admin User

- **Username:** `admin`
- **Authentication Database:** `admin`
- **Roles:**
  - `userAdminAnyDatabase` - Create and modify users and roles
  - `clusterAdmin` - Manage replica set operations
- **Use Case:** Administrative tasks, user management, cluster operations

### Application User

- **Username:** `application`
- **Authentication Database:** `admin`
- **Roles:**
  - `dbOwner` on `drivers_tracking` - Full access to drivers_tracking database
- **Use Case:** Application-level database operations

### Prometheus User

- **Username:** `prometheus`
- **Authentication Database:** `admin`
- **Roles:**
  - `clusterMonitor` on `admin` - Read-only access to cluster monitoring data
  - `read` on `local` - Read access to replication oplog
- **Use Case:** MongoDB metrics collection for Prometheus monitoring

## Connection Strings

### Admin Connection

```
mongodb://admin:<password>@<ip>:27017,<ip>:27018,<ip>:27019/?replicaSet=rs0&authSource=admin
```

### Application Connection

```
mongodb://application:<password>@<ip>:27017,<ip>:27018,<ip>:27019/drivers_tracking?replicaSet=rs0&authSource=admin
```

### Prometheus Connection

```
mongodb://prometheus:<password>@<ip>:27017/?authSource=admin
```

Replace `<password>` with the respective password from `.env` and `<ip>` with the selected IP address.

## Prometheus Metrics

### MongoDB Exporters

Three Percona MongoDB Exporter instances are deployed, one for each MongoDB node:

| Exporter         | Target Node | Metrics Endpoint              |
| ---------------- | ----------- | ----------------------------- |
| mongo-exporter-1 | mongo-1     | http://localhost:9216/metrics |
| mongo-exporter-2 | mongo-2     | http://localhost:9217/metrics |
| mongo-exporter-3 | mongo-3     | http://localhost:9218/metrics |

Each exporter uses the `--collect-all` flag to collect all available metrics.

### Prometheus Configuration Example

Add the following scrape configuration to your Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'mongodb'
    static_configs:
      - targets:
          - 'localhost:9216'
          - 'localhost:9217'
          - 'localhost:9218'
```

## Security Considerations

1. **Passwords:** Store passwords securely in `.env` file. Never commit `.env` to version control.
2. **Keyfile:** The keyfile is automatically generated with secure random content and proper permissions.
3. **Network Access:** The replica set binds to all interfaces. Use firewall rules to restrict access.
4. **Authentication:** All replica set members authenticate with each other using the keyfile.
5. **User Isolation:** Application user has limited permissions (dbOwner only on drivers_tracking).

## Maintenance

### Starting the Replica Set

```bash
docker compose up -d
```

### Stopping the Replica Set

```bash
docker compose down
```

### Viewing Logs

```bash
# All containers
docker compose logs -f

# Specific container
docker logs -f mongo-1
docker logs -f mongo-2
docker logs -f mongo-3
```

### Checking Replica Set Status

```bash
docker exec mongo-1 mongosh -u admin -p <password> --authenticationDatabase admin --eval "rs.status()"
```

### Data Persistence

MongoDB data is persisted in the `mongo/` directory:

- `mongo/node1/data` - mongo-1 node data
- `mongo/node2/data` - mongo-2 node data
- `mongo/node3/data` - mongo-3 node data

To completely reset the replica set, stop the containers and remove the `mongo/` directory, then run `setup-replica.sh` again.

## Troubleshooting

### Containers Not Healthy

If containers fail to become healthy:

- Check Docker logs: `docker compose logs`
- Verify keyfile permissions: `ls -l mongo/keyfile` (should be 400)
- Ensure ports 27017-27019 are not in use

### Replica Set Initialization Fails

If replica set initialization fails:

- Verify network connectivity between containers
- Check that the selected IP address is accessible
- Review MongoDB logs for specific errors

### User Creation Fails

If user creation fails with "not primary" error:

- The script automatically detects the PRIMARY node
- Verify the replica set has elected a PRIMARY: `rs.status()`
- Ensure sufficient time for replica stabilization

### Authentication Errors

If connection fails with authentication errors:

- Verify passwords in `.env` match those used during setup
- Confirm `authSource=admin` is specified in connection string
- Check user exists: `db.getUsers()` in admin database

### MongoDB Exporter Issues

If exporters fail to start or show authentication errors:

- Verify `MONGO_PROMETHEUS_PASSWORD` in `.env` matches the password used during setup
- Check exporter logs: `docker logs mongo-exporter-1`
- Ensure the prometheus user was created successfully
- Verify the exporter can reach the MongoDB node: `docker exec mongo-exporter-1 wget -qO- http://localhost:9216/metrics`

If exporters show "connection refused":

- Ensure the corresponding MongoDB container is healthy
- Check that the exporter's `depends_on` condition is satisfied
- Verify network connectivity between containers

## References

- [MongoDB Replica Set Documentation](https://docs.mongodb.com/manual/replication/)
- [MongoDB Security Checklist](https://docs.mongodb.com/manual/administration/security-checklist/)
- [MongoDB Connection String URI Format](https://docs.mongodb.com/manual/reference/connection-string/)
