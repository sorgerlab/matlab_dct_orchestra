classdef jobOrchestra < handle
    
    properties
        scheduler
        tasks = taskOrchestra.empty
        uid
        job_id
        State
    end
    
    methods
        
        function self = jobOrchestra(scheduler)
            self.scheduler = scheduler;
            self.State = 'pending';
        end
        
        function task = createTask(self, function_name, nargout, argsin)
            if isa(function_name, 'function_handle')
                % If a function handle was passed, append _wrapper to the name and use
                % that as the compiled function name to call.
                function_name = [func2str(function_name) '_wrapper'];
            end
            task = taskOrchestra(function_name, nargout, argsin);
            self.tasks(end+1) = task;
        end
        
        function submit(self)
        % TODO: check that all tasks' function_names are identical,
        % or support different functions per task.
            if length(self.scheduler.options.ClusterMatlabRoot) == 0
                error('You must set the "ClusterMatlabRoot" option on your scheduler object.');
            end

            self.uid = [datestr(now, 30) '_' sprintf('%03d', randi(999))];
            mkdir(self.job_dir);
            for i = 1:length(self.tasks)
                dir = self.task_dir_index(i);
                mkdir(dir);
                self.tasks(i).write_input([dir 'in.mat']);
            end

            job_name = sprintf('%s[1-%d]', self.uid, length(self.tasks));
            bsub_args = ['-J ' job_name ' ' ...
                         '-o ' self.task_dir_bsub_log 'log.txt ' ...
                         self.scheduler.options.SubmitArguments];
            matlab_root = self.scheduler.options.ClusterMatlabRoot;
            % TODO: see function_names issue above. assuming all
            % are identical for now, so we just use the first one.
            task_command = ['./run_' self.tasks(1).input.function_name '.sh ' ...
                            matlab_root ' ' ...
                            self.task_dir_bsub_var];
            bsub_command = ['bsub ' bsub_args ' ' task_command];
            [status, stdout] = system(bsub_command);
            if status ~= 0
                error('bsub command failed.');
                return;
            end
            self.job_id = sscanf(stdout, 'Job <%d>');
            self.State = 'queued';
        end

        function updateState(self)

            try
                [status, stdout] = system(['bjobs ' num2str(self.job_id)]);
                % sample bjobs output:
                % JOBID   USER    STAT  QUEUE      FROM_HOST   EXEC_HOST   JOB_NAME   SUBMIT_TIME
                % 35844   jlm26   RUN   sorger_15m orchestra.m clarinet043 *_75468[1] Sep 23 13:59
                % Split off header line -- 10 is ASCII code for newline
                [out_line, buffer] = strtok(stdout, 10);
                % Look for first header to see if we are getting normal bjobs output
                if ~strcmp(out_line(1:5), 'JOBID')
                    self.State = 'unavailable';
                    return;
                end
                % Track the tasks for which we've parsed a report line
                tasks_seen = false(size(self.tasks));
                % Loop over lines (one per task), parsing and updating task state
                % (after last line is tokenized buffer contains a single newline, thus the >1)
                while length(buffer) > 1
                    [out_line, buffer] = strtok(buffer, 10);
                    lsf_state = strtok(out_line(17:22));
                    tokens = regexp(out_line(58:67), '\[(\d+)\]', 'tokens');
                    task_index = sscanf(tokens{1}{1}, '%d');
                    switch lsf_state
                      case {'PEND', 'PSUSP'}
                        task_state = 'pending';
                      case {'RUN', 'USUSP', 'SSUSP'}
                        task_state = 'running';
                      case {'DONE', 'EXIT'}
                        task_state = 'finished';
                      otherwise; error(sprintf('bjobs command reported unknown task state "%s" for job %d[%d]', ...
                                               lsf_state, self.job_id, task_index));
                    end
                    self.tasks(task_index).State = task_state;
                    tasks_seen(task_index) = true;
                end
            catch e
                disp('caught exception in bjobs output parsing');
                disp('stdout:');
                fprintf('====\n%s====\n', stdout);
                rethrow(e);
            end

            % Check for tasks not seen in the bjobs output, which we haven't marked finished already. (LSF jobs
            % in state 'DONE' get cleaned up, and that's OK as long as we notice them before they get cleaned)
            % TODO: If waitForState is not called within LSF's CLEAN_PERIOD (default 1 hour) then we might miss
            % job exit too. The task wrapper may need to store a status in the out.mat file and check that.
            if any(~tasks_seen)
                num_missing_tasks = nnz(~strcmp({self.tasks(~tasks_seen).State}, 'finished'));
                if num_missing_tasks > 0
                    error(sprintf('bjobs command failed to report on %d jobs still pending or running for job %d.', ... 
                                  num_missing_tasks, self.job_id));
                end
            end
            % Set our state based on state of our tasks
            if any(strcmp({self.tasks.State}, 'running'))
                self.State = 'running';
            elseif strcmp({self.tasks.State}, 'finished')
                self.State = 'finished';
            end
        end
        
        function status = waitForState(self, state, timeout)
            if nargin < 3
                timeout = -1;
                if nargin < 2
                    state = 'finished';
                end
            end
            
            if timeout >= 0
                % We can't really do this with true "timeout semantics", so we just
                % sleep for the full timeout length right away.
                pause(timeout);
                self.updateState;
                status = strcmp(self.State, state);
            else
                while ~strcmp(self.State, state)
                    % We choose an arbitrary period of 60 seconds for our update loop.
                    % LSF will probably never dispatch and complete a job in less
                    % than 60 seconds anyway, so this seems sane.
                    %pause(60); FIXME restore this line
                    pause(1);
                    self.updateState;
                end
                status = true;
            end
        end
        
        function wait(self)
        % TODO: add support for state and timeout args
            waitForState(self);
        end
        
        function args = getAllOutputArguments(self)
            for i = 1:length(self.tasks)
                dir = self.task_dir_index(i);
                self.tasks(i).read_output([dir 'out.mat']);
                % TODO: check task.success
                % TODO: support > 1 output argument
                args{i,1} = self.tasks(i).output.argsout{1};
            end
        end
        
        function destroy(self)
            rmdir(self.job_dir, 's');
        end
        
        function dir = job_dir(self)
            dir = ['Job_' self.uid '/'];
        end
        
        function dir = task_dir(self, task)
            dir = [self.job_dir 'Task_' task '/'];
        end
        
        function dir = task_dir_index(self, task_index)
            dir = self.task_dir(int2str(task_index));
        end
        
        function dir = task_dir_bsub_log(self)
            dir = self.task_dir('%I');
        end
        
        function dir = task_dir_bsub_var(self)
            dir = self.task_dir('\$LSB_JOBINDEX');
        end
        
    end
    
end
