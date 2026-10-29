// ROUTES = the menu. It says which URL + method goes to which controller.

import { Router } from 'express';
import { createJobController } from './job.controller';

export const jobRouter = Router();

// POST /  (inside this router)  ->  createJobController
// In app.ts we mount this router at /api/jobs, so the full URL becomes: POST /api/jobs
jobRouter.post('/', createJobController);

// Later you will add more lines here, for example:
// jobRouter.get('/', listJobsController);        // GET  /api/jobs      -> list jobs
// jobRouter.get('/:id', getJobController);       // GET  /api/jobs/123  -> one job
