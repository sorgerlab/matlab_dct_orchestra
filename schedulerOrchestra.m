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
            func = str2func(func_name);
            output.argsout = cell(1, input.nargout);
            [output.argsout{:}] = func(input.argsin{:});
            output.success = true;
            save([task_dir 'out.mat'], '-struct', 'output');
        end

        function seed_randstream
        % seed random number generator from system RNG
            fid = fopen('/dev/urandom');
            seed = fread(fid, 1, 'uint32');
            s = RandStream.create('mt19937ar', 'seed', seed);
            RandStream.setDefaultStream(s);
        end
    end

end
