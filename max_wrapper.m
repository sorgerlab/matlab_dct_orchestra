function max_wrapper(task_dir)

input = load([task_dir 'in.mat']);

%=====
% change only this line to call a different function
func = @max;
%=====

output.argsout = cell(1, input.nargout);
[output.argsout{:}] = func(input.argsin{:});
output.success = true;

save([task_dir 'out.mat'], '-struct', 'output');
