// CONTROLLER = the waiter. Takes the order (request), hands it to the kitchen (service),
// and brings back the dish (response). It does not cook (no business logic) and does not store anything.

// asyncHandler is already in your project (src/utils/asyncHandler.ts).
// It catches any error from async code and passes it to our errorHandler, so we don't need try/catch here.
import { asyncHandler } from '../../utils/asyncHandler';
import { createJobSchema } from './job.validation';
import { createJob } from './job.service';

export const createJobController = asyncHandler(async (req, res) => {
  // req.body = the JSON the frontend sent.
  // .parse() checks it against our rules.
  //   - If it is valid   -> returns clean data (and fills defaults like skills = []).
  //   - If it is invalid -> throws an error. Our errorHandler turns that into a 400 response automatically.
  const data = createJobSchema.parse(req.body);

  // Ask the service to save it
  const job = await createJob(data);

  // 201 = "Created" (the correct status code when something new is saved).
  // Send the saved job back as JSON so the frontend can show it.
  res.status(201).json(job);
});
