import dotenv from "dotenv";

dotenv.config();

export interface EnvironmentVariables {
  NODE_ENV: "development" | "production";
  PORT: number;
  MONGO_URI: string;
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
};

export default env;
