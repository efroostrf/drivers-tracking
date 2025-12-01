import type { Collection, Document } from "mongodb";
import mongoConnection from "../index";
import env from "../../env";

export interface PingDocument extends Document {
  driverId: string;
  latitude: number;
  longitude: number;
  timestamp: Date; // Stored as Date in MongoDB Time Series Collection
}

const COLLECTION_NAME = "pings";

let pingCollection: Collection<PingDocument> | null = null;

export async function initializePingCollection(): Promise<void> {
  try {
    const client = await mongoConnection.getClient();
    const db = client.db(env.MONGO_DB_NAME);

    const collections = await db
      .listCollections({ name: COLLECTION_NAME })
      .toArray();

    if (collections.length === 0) {
      console.log(`Creating Time Series collection: ${COLLECTION_NAME}`);

      const ttlSeconds = env.PING_RETENTION_DAYS * 24 * 60 * 60;

      // Create Time Series Collection
      // - Provides storage savings through columnar compression
      // - Automatically optimizes queries by driverId and timestamp
      // - No manual index management needed
      await db.createCollection(COLLECTION_NAME, {
        timeseries: {
          timeField: "timestamp", // Required: field containing Date objects
          metaField: "driverId", // Groups data by driver for efficient queries
          granularity: "seconds", // Optimized for 1-30 second ping intervals
        },
        expireAfterSeconds: ttlSeconds, // Automatic data expiration
      });

      console.log(
        `Time Series collection created with ${env.PING_RETENTION_DAYS} days retention`
      );
    } else {
      console.log(`Using existing collection: ${COLLECTION_NAME}`);
    }

    pingCollection = db.collection<PingDocument>(COLLECTION_NAME);

    console.log(`Ping collection initialized successfully`);
  } catch (error) {
    console.error("Failed to initialize ping collection:", error);
    throw error;
  }
}

/**
 * Get the pings collection instance
 * Must call initializePingCollection() first during app startup
 */
export function getPingCollection(): Collection<PingDocument> {
  if (!pingCollection) {
    throw new Error(
      "Ping collection not initialized. Call initializePingCollection() first."
    );
  }
  return pingCollection;
}
