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
createTask(job, @max, 2, {x, y}); % error - MATLAB:max:TwoInTwoOutCaseNotSupported
createTask(job, @max, 1, {x, [], 2});
createTask(job, @max, 2, {x, [], 2});
createTask(job, @max, 1, {x, y, 2}); % error - MATLAB:max:caseNotSupported
createTask(job, @max, 2, {x, y, 2}); % error - MATLAB:max:caseNotSupported

expected_errors = {[], [], [], 'MATLAB:max:TwoInTwoOutCaseNotSupported', ...
                   [], [], 'MATLAB:max:caseNotSupported', 'MATLAB:max:caseNotSupported'};

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

celldisp(results);

for i = 1:length(job.tasks)
    task = job.tasks(i);
    fprintf('task %d: ');
    if isempty(task.Error) && isempty(expected_errors{i})
        fprintf('success - no error expected, no error reported');
    elseif ~isempty(task.Error) && strcmp(task.Error.identifier, expected_errors{i})
        fprintf('success - error expected, same error reported');
    elseif isempty(task.Error) && ~isempty(expected_errors{i})
        fprintf('FAILURE - error expected, but no error reported');
    elseif ~isempty(task.Error) && isempty(expected_errors{i})
        fprintf('FAILURE - no error expected, but an error was reported:\n-----%s-----', task.Error.getReport);
    elseif ~isempty(task.Error) && ~strcmp(task.Error.identifier, expected_errors{i})
        fprintf('FAILURE - error expected, but a different error was reported:\n-----%s-----', task.Error.getReport);
    else
        fprintf('UNKNOWN - unexpected condition!\n-----');
        disp('task.Error:');
        disp(task.Error);
        disp('expected_error');
        disp(expected_errors{i});
        disp('-----');
    end
    fprintf('\n');
end

destroy(job);
