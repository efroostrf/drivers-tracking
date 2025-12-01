import app from "./app";
import env from "./lib/env";
import mongoConnection from "./lib/mongo";
import { initializePingCollection } from "./lib/mongo/collections/ping.collection";

async function startServer() {
  try {
    // Connect to MongoDB
    await mongoConnection.connect();

    // Initialize collections and indexes
    await initializePingCollection();

    // Start the HTTP server
    const server = app.listen(env.PORT, () => {
      console.log(`Server listening on port ${env.PORT}`);
    });

    setupServerErrorHandlers(server);
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
}

function setupServerErrorHandlers(server: ReturnType<typeof app.listen>) {
  server.on("error", (error: NodeJS.ErrnoException) => {
    if (error.code === "EADDRINUSE") {
      console.error(`Port ${env.PORT} is already in use`);
    } else {
      console.error("Server error:", error);
    }
    process.exit(1);
  });

  const gracefulShutdown = async (signal: string) => {
    console.log(`\n${signal} signal received: closing HTTP server`);

    server.close(async () => {
      console.log("HTTP server closed");

      try {
        await mongoConnection.disconnect();
        console.log("MongoDB connection closed");
        process.exit(0);
      } catch (error) {
        console.error("Error closing MongoDB connection:", error);
        process.exit(1);
      }
    });
  };

  process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
  process.on("SIGINT", () => gracefulShutdown("SIGINT"));
}

startServer();
