import type { Request, Response, NextFunction } from "express";

export const errorHandler = (
  error: unknown,
  _req: Request,
  res: Response,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  _: NextFunction
): void => {
  console.error("Error:", error);

  res.status(500).json({
    error: "Internal server error",
  });
};
