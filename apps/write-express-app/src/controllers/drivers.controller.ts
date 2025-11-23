import type { Request, Response } from "express";
import type { Ping } from "../schemas/ping.schema";
import mongoConnection from "../lib/mongo-client";

export const handleDriverPing = async (req: Request, res: Response) => {
  const pingData: Ping = req.body;

  console.log(pingData);

  try {
    const mongo = await mongoConnection.getClient();

    await mongo.db("admin").command({ ping: 1 });

    res.status(201).send();
  } catch (error) {
    throw new Error("Failed to ping MongoDB", { cause: error });
  }
};
