function result = fail_or_sleep(arg)

disp(['arg = ' arg]);
if strcmp(arg, 'fail')
    r = rand;
    if r < 0.5
        disp('failure triggered');
        error('failure');
    else
        disp('success');
        result = 'success';
    end
else
    disp('sleeping...');
    pause(60*2);
    disp('done');
    result = 'sleep';
end
