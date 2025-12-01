import { z } from "zod";

export const pingSchema = z.object({
  driverId: z.string().min(1),
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timestamp: z.number().int().positive(), // Unix timestamp in seconds (will be converted to Date for storage)
});

export type Ping = z.infer<typeof pingSchema>;
