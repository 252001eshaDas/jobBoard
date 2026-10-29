// VALIDATION = the security guard at the kitchen door.
// Anyone can send anything to our API (not only our React form), so the server checks the data itself.

import { z } from 'zod';

// The rules for a new job. If any rule fails, zod throws an error and the job is NOT saved.
export const createJobSchema = z.object({
  title: z.string().min(3, 'Title must be at least 3 characters'),
  company: z.string().min(2, 'Company name is too short'),
  location: z.string().min(2, 'Location is too short'),

  // .optional() -> salary can be missing. If it is there, it must be a positive number.
  salary: z.number().positive().optional(),

  // A list of text values. If missing, use an empty list.
  skills: z.array(z.string()).default([]),

  description: z.string().min(10, 'Description must be at least 10 characters'),
});

// Automatically builds a TypeScript type from the rules above,
// so we don't write the same fields twice.
export type CreateJobInput = z.infer<typeof createJobSchema>;
