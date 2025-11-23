import type { Request, Response } from "express";
import type { Ping } from "../schemas/ping.schema";
// import mongo from "../lib/mongo-client";

export const handleDriverPing = async (req: Request, res: Response) => {
  const pingData: Ping = req.body;

  console.log(pingData);

  res.status(201).send();
};
