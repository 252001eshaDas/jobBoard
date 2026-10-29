import { NextFunction, Request, Response } from 'express';
import { ZodSchema } from 'zod';

// Usage: router.post('/', validate(createJobSchema), controller)
export const validate =
  (schema: ZodSchema) => (req: Request, _res: Response, next: NextFunction) => {
    req.body = schema.parse(req.body);
    next();
  };
