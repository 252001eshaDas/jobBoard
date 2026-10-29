// The root component. For now it only shows the job form.
import JobForm from './features/jobs/JobForm';

export default function App() {
  return (
    <div>
      <h1>Job Portal</h1>
      <JobForm />
    </div>
  );
}
