QUEUE_NAME = 'sorger_15m';
WORKER_FUNC = @fail_or_sleep;
NARGOUT = 1;


jm = schedulerOrchestra;

set(jm, 'ClusterMatlabRoot', '/opt/matlab');
set(jm, 'SubmitArguments', ['-q ' QUEUE_NAME]); 

job = createJob(jm);
% set auto_retry since that is what we want to test here
job.auto_retry = 2;  % max 2 retries

num_tasks = 30;
for i = 1:num_tasks
    % set half of the tasks to randomly fail, and half to sleep then succeed
    if i / num_tasks <= 0.5
        arg = 'fail';
    else
        arg = 'sleep';
    end
    createTask(job, WORKER_FUNC, NARGOUT, {arg});
end

submit(job);
fprintf('LSF job id = %d\n', job.job_id);
while ~waitForState(job, 'finished', 10)
   disp(datestr(now, 31));
   for i=1:length(job.tasks)
       fprintf('%3d', i);
   end
   fprintf('\n');
   for i=1:length(job.tasks)
       fprintf('%3s', upper(job.tasks(i).State(1)));
   end
   fprintf('\n');
   for i=1:length(job.tasks)
       num_retries = length(job.retry_jobs{i});
       if num_retries
           fprintf('  %3d: %2d retries - ', i, num_retries);
           if strcmp(job.retry_jobs{i}(end).State, 'finished')
               fprintf('success');
           else
               fprintf('still working');
           end
           fprintf('\n');
       end
   end
   fprintf('\n');
end
results = getAllOutputArguments(job);

%destroy(job);

disp(results);
