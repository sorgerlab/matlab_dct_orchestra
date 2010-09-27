function rand_wrapper(task_dir)

input = load([task_dir 'in.mat']);

%=====
% change this line to call a different function
func = @rand;
s = RandStream.create('mt19937ar','seed',sum(100*clock));
RandStream.setDefaultStream(s);
%=====

output.argsout{1} = func(input.argsin{:});
output.success = true;

save([task_dir 'out.mat'], '-struct', 'output');
