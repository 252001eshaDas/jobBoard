// One shared axios instance, so we don't repeat the server address in every file.

import axios from 'axios';

export const api = axios.create({
  // Reads VITE_API_URL from client/.env  ->  http://localhost:5000/api
  // So api.post('/jobs', ...) really calls http://localhost:5000/api/jobs
  baseURL: import.meta.env.VITE_API_URL,

  // Lets the browser send cookies (we will need this later for login)
  withCredentials: true,
});
