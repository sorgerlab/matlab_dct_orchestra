QUEUE_NAME = 'sysbio_15m';
WORKER_FUNC = @cpu_stress;
NARGOUT = 1;
ARGSIN = {10};


jm = schedulerOrchestra;

set(jm, 'ClusterMatlabRoot', '/opt/matlab');
set(jm, 'SubmitArguments', ['-q ' QUEUE_NAME]); 

job = createJob(jm);

for i = 1:100
    createTask(job, WORKER_FUNC, NARGOUT, ARGSIN);
end

submit(job);
fprintf('LSF job id = %d\n', job.job_id);
while ~waitForState(job, 'finished', 10)
   disp(datestr(now, 31));
   for i=1:length(job.tasks)
       fprintf(1, '%3d', i);
   end
   fprintf(1, '\n');
   for i=1:length(job.tasks)
       fprintf(1, '%3s', upper(job.tasks(i).State(1)));
   end
   fprintf(1, '\n\n');
end
results = getAllOutputArguments(job);

destroy(job);

disp(cell2mat(results));
