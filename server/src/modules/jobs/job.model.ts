// MODEL = the shape of a job document in MongoDB.
// Think of it as the column headings of an Excel sheet, so every job has the same fields.

// Schema = describes the fields. model = turns that description into something we can save/find with.
import { Schema, model } from 'mongoose';

// Describe what one job looks like
const jobSchema = new Schema(
  {
    // required: true  -> MongoDB refuses to save a job without this field
    // trim: true      -> "  React Dev  " is saved as "React Dev" (removes extra spaces)
    title: { type: String, required: true, trim: true },
    company: { type: String, required: true, trim: true },
    location: { type: String, required: true, trim: true },

    // Optional field (no "required"). Monthly salary in rupees.
    salary: { type: Number },

    // [String] = a list of text values, e.g. ["React", "Node", "MongoDB"]
    // default: []  -> if nobody sends skills, save an empty list
    skills: { type: [String], default: [] },

    description: { type: String, required: true },
  },
  {
    // timestamps: true -> MongoDB automatically adds createdAt and updatedAt for us
    timestamps: true,
  },
);

// 'Job' is the model name. MongoDB will create a collection called "jobs" (lowercase + plural).
// A collection is like a table; each job is one row (called a "document").
export const Job = model('Job', jobSchema);
