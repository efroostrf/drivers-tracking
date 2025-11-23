import type { AnyZodObject } from "zod/v3";
import type { NextFunction, Request, Response, RequestHandler } from "express";

/**
 * Validates the request body against the Zod schema
 * @param schema - The Zod schema to validate the request body against
 * @returns A middleware function that validates the request body against the Zod schema
 */
export const validate = (schema: AnyZodObject): RequestHandler => {
  return async (req: Request, res: Response, next: NextFunction) => {
    const { success, error } = schema.safeParse(req.body);

    if (!success) {
      res.status(400).json({
        error: "Invalid request body",
        details: error.errors,
      });

      return;
    }

    next();
  };
};
