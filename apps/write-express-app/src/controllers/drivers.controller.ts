import type { Request, Response } from "express";
import type { Ping } from "../schemas/ping.schema";
import { getPingCollection } from "../lib/mongo/collections/ping.collection";

export const handleDriverPing = async (req: Request, res: Response) => {
  const pingData: Ping = req.body;

  try {
    const pingCollection = getPingCollection();

    // Convert Unix timestamp (seconds) to Date object for Time Series Collection
    await pingCollection.insertOne({
      driverId: pingData.driverId,
      latitude: pingData.latitude,
      longitude: pingData.longitude,
      timestamp: new Date(pingData.timestamp * 1000), // Unix seconds -> milliseconds -> Date
    });

    res.status(201).send();
  } catch (error) {
    throw new Error("Failed to save driver ping", { cause: error });
  }
};
