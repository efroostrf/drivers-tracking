# Write Express App

This service validates and saves driver pings to a database.

## Getting Started

Follow these instructions to get the project up and running on your local machine.

### Prerequisites

- [Node.js](https://nodejs.org/) (v22 or higher recommended)
- [npm](https://www.npmjs.com/)
- [Docker](https://www.docker.com/) (optional, for containerized execution)

### Installation

1. Navigate to the application directory:

   ```bash
   cd apps/write-express-app
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

### Environment Setup

Copy the example environment file to create your local configuration:

```bash
cp .example.env .env
```

Review `.env` and adjust the variables if necessary:

- `NODE_ENV`: Environment (development/production)
- `PORT`: Port to listen on (default: 3000)
- `MONGO_URI`: MongoDB connection string
- `MONGO_DB_NAME`: Database name (default: drivers_tracking)
- `MONGO_MAX_POOL_SIZE`: Max MongoDB connection pool size (default: 100)
- `MONGO_MIN_POOL_SIZE`: Min MongoDB connection pool size (default: 20)
- `PING_RETENTION_DAYS`: Days to retain ping data (default: 30)

### Running Locally

To build and start the application in one command:

```bash
npm start
```

To build the project only:

```bash
npm run build
```

The server will start on `http://localhost:3000` (or the port specified in `.env`).

## Docker

You can also run this application using Docker.

### Build Image

```bash
docker build -t write-express-app .
```

### Run Container

```bash
docker run -p 3000:3000 write-express-app
```

You can also pass environment variables to the container:

```bash
docker run -p 3000:3000 -e PORT=3000 -e NODE_ENV=production write-express-app
```

## API Endpoints

### Health Check

- **URL**: `/health`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "status": "ok",
    "timestamp": 1733529600000
  }
  ```

### Driver Ping

- **URL**: `/v1/drivers/ping`
- **Method**: `POST`
- **Description**: Receives driver location pings.
- **Request Body**:

  ```json
  {
    "driverId": "string (min 1 char)",
    "latitude": "number (-90 to 90)",
    "longitude": "number (-180 to 180)",
    "timestamp": "number (positive integer, unix timestamp in seconds)"
  }
  ```
