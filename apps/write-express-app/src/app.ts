import express from "express";

// routes
import routes from "./routes";

// middleware
import { errorHandler } from "./middleware/error-handler.middleware";

const app = express();

app.use(express.json());
app.use(routes);
app.use(errorHandler);

export default app;
