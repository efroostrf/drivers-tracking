import app from "./app";
import env from "./lib/env";
import mongoConnection from "./lib/mongo-client";

const server = app.listen(env.PORT, () => {
  console.log(`Server listening on port ${env.PORT}`);
});

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
