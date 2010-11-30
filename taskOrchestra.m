classdef taskOrchestra < handle
    
    properties
        input = struct('function_name', [], 'nargout', [], 'argsin', [])
        output = struct('argsout', [], 'success', false, 'error', [])
        seen = false
        State
        Error
    end
    
    methods
        
        function self = taskOrchestra(function_name, nargout, argsin)
            self.input.function_name = function_name;
            self.input.nargout = nargout;
            self.input.argsin = argsin;
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
        
    end

end
