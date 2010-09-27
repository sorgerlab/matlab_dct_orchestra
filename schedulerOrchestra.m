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

end
