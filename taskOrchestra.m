classdef taskOrchestra < handle
    
    properties
        input = struct('function_name', [], 'nargout', [], 'argsin', [], 'index', [])
        output = struct('argsout', [], 'success', false, 'error', [])
        seen = false
        retry_jobs = jobOrchestra.empty
        State
        Error
    end
    
    methods
        
        function self = taskOrchestra(function_name, nargout, argsin, index)
            self.input.function_name = function_name;
            self.input.nargout = nargout;
            self.input.argsin = argsin;
            self.input.index = index;
            self.State = 'pending';
        end

        function write_input(self, filename)
            data = self.input;
            save(filename, '-struct', 'data');
        end
        
        function read_output(self, filename)
            self.output = load(filename);
            self.Error = self.output.error;
        end

        function schedule_retry(self, parent_job)
        % create a single-task job to retry this task
            % uid format looks like "olduid_r7" (r for retry, 7 for task 7)
            uid = [parent_job.uid '_r' num2str(self.input.index)];
            if length(self.retry_jobs) > 0
                % if second or later retry, modify uid to look like
                % "olduid_r7-2" where 2 is retry count
                uid = [uid '-' num2str(length(self.retry_jobs) + 1)];
            end
            job = jobOrchestra(parent_job.scheduler, uid);
            self.retry_jobs(end+1) = job;
            job.createTask(self.input.function_name, self.input.nargout, self.input.argsin, 1);
            job.submit;
        end
        
    end

end
