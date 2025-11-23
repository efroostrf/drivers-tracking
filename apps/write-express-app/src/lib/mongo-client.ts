import { MongoClient } from "mongodb";
import env from "./env";

const mongo = new MongoClient(env.MONGO_URI);

mongo.connect();

export default mongo;
