// A plain form (no styling) that sends a new job to our backend.

import { useState, type FormEvent } from 'react';
import axios from 'axios';
import { api } from '../../lib/api';

export default function JobForm() {
  // useState = the form's memory. Each line is: [current value, function to change it] = useState(starting value)
  // Everything starts as an empty string because inputs always give us text.
  const [title, setTitle] = useState('');
  const [company, setCompany] = useState('');
  const [location, setLocation] = useState('');
  const [salary, setSalary] = useState('');
  const [skills, setSkills] = useState(''); // typed like: React, Node, MongoDB
  const [description, setDescription] = useState('');

  // message = text shown under the form (success or error)
  const [message, setMessage] = useState('');
  // loading = true while we wait for the server, so the button can be disabled
  const [loading, setLoading] = useState(false);

  // Runs when the user clicks "Post job"
  async function handleSubmit(e: FormEvent) {
    // A normal form reloads the whole page on submit. This stops that.
    e.preventDefault();

    setLoading(true);
    setMessage('');

    try {
      // Send a POST request to http://localhost:5000/api/jobs with this JSON body.
      // "await" = pause here until the server replies.
      const res = await api.post('/jobs', {
        title,
        company,
        location,
        // Inputs give text, but the server expects a number. Empty salary -> undefined (not sent).
        salary: salary ? Number(salary) : undefined,
        // "React, Node , MongoDB" -> ["React", "Node", "MongoDB"]
        // split(',') cuts at commas, trim() removes spaces, filter(Boolean) removes empty pieces.
        skills: skills
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean),
        description,
      });

      // Success: the server sent back the saved job. _id is MongoDB's unique id for it.
      setMessage(`Job posted! ID: ${res.data._id}`);

      // Clear the form for the next job
      setTitle('');
      setCompany('');
      setLocation('');
      setSalary('');
      setSkills('');
      setDescription('');
    } catch (err) {
      // axios.isAxiosError = "did this fail because of the server/network?"
      if (axios.isAxiosError(err)) {
        // If the server replied with an error (like 400), show its message and which fields failed.
        // If there was no reply at all, the server is probably not running.
        const data = err.response?.data;
        setMessage(
          data
            ? `Error: ${data.message} ${JSON.stringify(data.details?.fieldErrors ?? '')}`
            : 'Cannot reach the server. Is it running on port 5000?',
        );
      } else {
        setMessage('Something went wrong');
      }
    } finally {
      // finally = runs whether it worked or failed
      setLoading(false);
    }
  }

  return (
    // onSubmit = call handleSubmit when the form is submitted (button click or Enter key)
    <form onSubmit={handleSubmit}>
      <h2>Post a job</h2>

      {/* Controlled input: it shows the state value, and onChange updates the state on every keystroke */}
      <div>
        <input
          placeholder="Job title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
        />
      </div>

      <div>
        <input
          placeholder="Company"
          value={company}
          onChange={(e) => setCompany(e.target.value)}
        />
      </div>

      <div>
        <input
          placeholder="Location"
          value={location}
          onChange={(e) => setLocation(e.target.value)}
        />
      </div>

      <div>
        <input
          type="number"
          placeholder="Monthly salary (optional)"
          value={salary}
          onChange={(e) => setSalary(e.target.value)}
        />
      </div>

      <div>
        <input
          placeholder="Skills, comma separated (React, Node)"
          value={skills}
          onChange={(e) => setSkills(e.target.value)}
        />
      </div>

      <div>
        <textarea
          placeholder="Job description"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
        />
      </div>

      {/* disabled while loading so the user can't click twice and post the job two times */}
      <button type="submit" disabled={loading}>
        {loading ? 'Posting...' : 'Post job'}
      </button>

      {/* Only show the message line if there is a message */}
      {message && <p>{message}</p>}
    </form>
  );
}
