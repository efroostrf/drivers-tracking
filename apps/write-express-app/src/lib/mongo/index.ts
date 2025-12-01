import { MongoClient, MongoClientOptions } from "mongodb";
import env from "../env";

class MongoConnection {
  private client: MongoClient;
  private isConnected: boolean = false;
  private connectionPromise: Promise<MongoClient> | null = null;

  constructor() {
    const options: MongoClientOptions = {
      maxPoolSize: env.MONGO_MAX_POOL_SIZE,
      minPoolSize: env.MONGO_MIN_POOL_SIZE,
      maxIdleTimeMS: 60000,
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
      writeConcern: {
        w: 1,
        j: false,
      },
    };
    this.client = new MongoClient(env.MONGO_URI, options);
  }

  async connect(): Promise<MongoClient> {
    if (this.isConnected) {
      return this.client;
    }

    // Prevent multiple simultaneous connection attempts
    if (this.connectionPromise) {
      return this.connectionPromise;
    }

    this.connectionPromise = this.client
      .connect()
      .then((client) => {
        console.log("MongoDB connected successfully");
        this.isConnected = true;
        this.connectionPromise = null;

        // Handle connection events
        this.client.on("close", () => {
          console.log("MongoDB connection closed");
          this.isConnected = false;
        });

        this.client.on("error", (error) => {
          console.error("MongoDB connection error:", error);
          this.isConnected = false;
        });

        return client;
      })
      .catch((error) => {
        console.error("MongoDB connection failed:", error);
        this.connectionPromise = null;
        this.isConnected = false;
        throw error;
      });

    return this.connectionPromise;
  }

  async getClient(): Promise<MongoClient> {
    if (!this.isConnected) {
      await this.connect();
    }
    return this.client;
  }

  async disconnect(): Promise<void> {
    if (this.client) {
      await this.client.close();
      this.isConnected = false;
    }
  }
}

export default new MongoConnection();
