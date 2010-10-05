function longtask_wrapper(task_dir)

input = load([task_dir 'in.mat']);

%=====
% change this line to call a different function
func = @longtask;
s = RandStream.create('mt19937ar','seed',sum(100*clock));
RandStream.setDefaultStream(s);
%=====

output.argsout{1} = func(input.argsin{:});
output.success = true;

save([task_dir 'out.mat'], '-struct', 'output');


    function delay_time = longtask()

    if randi(2) == 1
        delay_time = 60*70;  % 70 minutes, longer than LSF's CLEAN_PERIOD
    else
        delay_time = 0;
    end
    fprintf('sleeping for %d seconds\n', delay_time);
    pause(delay_time);
    
    end

end
