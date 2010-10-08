QUEUE_NAME = 'sysbio_2h';


jm = schedulerOrchestra;

set(jm, 'ClusterMatlabRoot', '/opt/matlab');
set(jm, 'SubmitArguments', ['-q ' QUEUE_NAME]); 

job = createJob(jm);

x = rand(10);
y = randi([0 1], 10);
createTask(job, @max, 1, {x});
createTask(job, @max, 2, {x});
createTask(job, @max, 1, {x, y});
createTask(job, @max, 2, {x, y}); % error - two matrices to compare and two output arguments is not supported
createTask(job, @max, 1, {x, [], 2});
createTask(job, @max, 2, {x, [], 2});
createTask(job, @max, 1, {x, y, 2}); % error - two matrices to compare and a working dimension is not supported
createTask(job, @max, 2, {x, y, 2}); % error - two matrices to compare and a working dimension is not supported


submit(job);
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

celldisp(results);
