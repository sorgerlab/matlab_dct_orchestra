function runtime = cpu_stress(loop_count)

tic;
for i = 1:loop_count
    % takes about 30 seconds on an E5540 (Core i7) @ 2.53GHz with -singleCompThread
    a = rand(3000);
    eig(a);
end
runtime = toc;
