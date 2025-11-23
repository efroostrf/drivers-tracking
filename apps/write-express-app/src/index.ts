import express from "express";
import env from "./lib/env";
// import mongo from "./lib/mongo-client";

// schemas
import { pingSchema } from "./schemas/ping.schema";

const app = express();

app.use(express.json());

app.get("/", (_, res) => {
  res.send("Hello World!");
});

app.post("/v1/drivers/ping", (req, res) => {
  try {
    const { success, error } = pingSchema.safeParse(req.body);

    if (!success) {
      res.status(400).json({
        error: error.message,
      });
      return;
    }

    res.status(201).send();
  } catch (error: unknown) {
    console.error(error);
    res.status(500).json({
      error: "Internal server error",
    });
  }
});

const server = app.listen(env.PORT, () => {
  console.log(`Example app listening on port ${env.PORT}`);
});

server.on("error", (error: NodeJS.ErrnoException) => {
  if (error.code === "EADDRINUSE") {
    console.error(`Port ${env.PORT} is already in use`);
  } else {
    console.error("Server error:", error);
  }
  process.exit(1);
});

process.on("SIGTERM", () => {
  console.log("SIGTERM signal received: closing HTTP server");
  server.close(() => {
    console.log("HTTP server closed");
  });
});

process.on("SIGINT", () => {
  console.log("\nSIGINT signal received: closing HTTP server");
  server.close(() => {
    console.log("HTTP server closed");
    process.exit(0);
  });
});
