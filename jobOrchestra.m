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
            task_command = ['env MCR_CACHE_ROOT=/tmp/\$USER.\$LSB_JOBID.\$LSB_JOBINDEX ' ...
                            './run_' self.tasks(1).input.function_name '.sh ' ...
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

            % Track the tasks we have observed
            update_seen = false(size(self.tasks));

            % First we look for output data files from finished tasks
            for i = 1:length(self.tasks)
                self.populate_task_output(i, false);
                if self.tasks(i).output.success
                    self.tasks(i).State = 'finished';
                    update_seen(i) = true;
                end
            end

            % Next, call "bjobs" and parse its output to report on unfinished jobs
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
                % Loop over lines (one per task), parsing and updating task state
                % (after last line is tokenized buffer contains a single newline, thus the >1)
                while length(buffer) > 1
                    [out_line, buffer] = strtok(buffer, 10);
                    lsf_state = strtok(out_line(17:22));
                    tokens = regexp(out_line(58:67), '\[(\d+)\]', 'tokens');
                    task_index = sscanf(tokens{1}{1}, '%d');
                    % skip this if task already observed via output data file
                    if ~update_seen(task_index)
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
                        self.tasks(task_index).seen = true;
                        update_seen(task_index) = true;
                    end
                end
            catch e
                disp('caught exception in bjobs output parsing');
                disp('stdout:');
                fprintf('====\n%s====\n', stdout);
                rethrow(e);
            end

            % Check for tasks not seen in this update, which we *have* seen before
            % but *haven't* marked finished already.
            missing = ~update_seen & cell2mat({self.tasks.seen});
            if any(missing)
                num_unfinished = nnz(~strcmp({self.tasks(missing).State}, 'finished'));
                if num_unfinished > 0
                    error(sprintf('bjobs command failed to report on %d jobs still pending or running for job %d.', ... 
                                  num_unfinished, self.job_id));
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
            task_inputs = [self.tasks.input];
            max_nargout = max([task_inputs.nargout]);
            args = cell(length(self.tasks), max_nargout);
            for i = 1:length(self.tasks)
                self.populate_task_output(i);
                [args{i,1:self.tasks(i).input.nargout}] = self.tasks(i).output.argsout{:};
            end
        end

        function success = populate_task_output(self, task_index, varargin)
            dir = self.task_dir_index(task_index);
            track_error = true;
            if nargin == 3
                track_error = varargin{1};
            end

            try
                self.tasks(task_index).read_output([dir 'out.mat']);
            catch e
                % TODO: This will always be "no such file or directory" from load(),
                % not the actual task's exception, but at least it's a start.
                if track_error
                    self.tasks(task_index).Error = e;
                end
                self.tasks(task_index).output.argsout = {};
            end
            success = self.tasks(task_index).output.success;
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
