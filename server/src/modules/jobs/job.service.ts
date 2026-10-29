// SERVICE = the business logic. This is the only file that talks to the database.
// Later, rules like "free recruiters can post only 3 jobs" will go here, not in the controller.

import { Job } from './job.model';
import type { CreateJobInput } from './job.validation';

// Takes clean, already-checked data and saves it as a new job in MongoDB.
export async function createJob(data: CreateJobInput) {
  // Job.create(...) = build a new document and save it, in one step.
  // "await" = wait here until MongoDB confirms it is saved.
  const job = await Job.create(data);

  // Return the saved job (it now also has an _id, createdAt and updatedAt)
  return job;
}
