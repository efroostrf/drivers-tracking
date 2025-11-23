import express from "express";
import helmet from "helmet";

// routes
import routes from "./routes";

// middleware
import { errorHandler } from "./middleware/error-handler.middleware";

const app = express();

app.use(express.json());
app.use(helmet());
app.disable("x-powered-by");
app.use(routes);
app.use(errorHandler);
app.use((_req, res) => {
  res.status(404).send();
});

export default app;
