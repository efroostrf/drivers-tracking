import dotenv from "dotenv";

dotenv.config();

export interface EnvironmentVariables {
  NODE_ENV: "development" | "production";
  PORT: number;
  MONGO_URI: string;
  MONGO_DB_NAME: string;
  MONGO_MAX_POOL_SIZE: number;
  MONGO_MIN_POOL_SIZE: number;
  PING_RETENTION_DAYS: number;
}

if (!process.env.NODE_ENV) {
  throw new Error("NODE_ENV is required");
}

if (!process.env.PORT) {
  throw new Error("PORT is required");
}

if (!process.env.MONGO_URI) {
  throw new Error("MONGO_URI is required");
}

const env: Readonly<EnvironmentVariables> = {
  NODE_ENV: process.env.NODE_ENV as EnvironmentVariables["NODE_ENV"],
  PORT: parseInt(process.env.PORT ?? "3000"),
  MONGO_URI: process.env.MONGO_URI ?? "",
  MONGO_DB_NAME: process.env.MONGO_DB_NAME ?? "drivers_tracking",
  MONGO_MAX_POOL_SIZE: parseInt(process.env.MONGO_MAX_POOL_SIZE ?? "100"),
  MONGO_MIN_POOL_SIZE: parseInt(process.env.MONGO_MIN_POOL_SIZE ?? "20"),
  PING_RETENTION_DAYS: parseInt(process.env.PING_RETENTION_DAYS ?? "30"),
};

export default env;
