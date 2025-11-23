import { Router } from "express";

// routes
import driversRoutes from "./drivers.routes";

const router = Router();

router.use("/v1/drivers", driversRoutes);

export default router;
