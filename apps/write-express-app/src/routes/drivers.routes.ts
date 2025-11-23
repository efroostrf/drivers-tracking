import type { AnyZodObject } from "zod/v3";
import { Router } from "express";

// controllers
import { handleDriverPing } from "../controllers/drivers.controller";

// middleware
import { validate } from "../middleware/validate.middleware";

// schemas
import { pingSchema } from "../schemas/ping.schema";

const router = Router();

router.post(
  "/ping",
  validate(pingSchema as unknown as AnyZodObject),
  handleDriverPing
);

export default router;
