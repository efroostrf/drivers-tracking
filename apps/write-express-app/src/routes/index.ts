import { Router } from "express";

// routes
import driversRoutes from "./drivers.routes";

const router = Router();

// Health check endpoint
router.get("/health", (_req, res) => {
  res.status(200).json({
    status: "ok",
    timestamp: Date.now(),
  });
});

router.use("/v1/drivers", driversRoutes);

export default router;
