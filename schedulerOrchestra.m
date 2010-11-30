classdef schedulerOrchestra < handle

    properties
        options = struct;
    end

    methods
        
        function set(self, key, value)
            self.options.(key) = value;
        end
        
        function value = get(self, key)
            if isfield(self.options, key)
                value = self.options.(key);
            else
                value = '';
            end
        end
        
        function job = createJob(self)
            job = jobOrchestra(self);
        end
        
    end

    methods(Static)

        function function_wrapper(task_dir, func_name)
            input = load([task_dir 'in.mat']);
            output = struct('argsout', [], 'success', false, 'error', []);
            try
                func = str2func(func_name);
                output.argsout = cell(1, input.nargout);
                [output.argsout{:}] = func(input.argsin{:});
                output.success = true;
            catch e
                output.error = e;
            end
            save([task_dir 'out.mat'], '-struct', 'output');
        end

        function seed_randstream
        % seed random number generator from system RNG
            RandStream.setDefaultStream(schedulerOrchestra.create_randstream);
        end

        function stream = create_randstream
        % create random number generator seeded from system RNG
            fid = fopen('/dev/urandom');
            seed = fread(fid, 1, 'uint32');
            stream = RandStream.create('mt19937ar', 'seed', seed);
        end
    end

end
