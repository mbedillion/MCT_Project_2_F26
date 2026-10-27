function [grade, scores] = evaluation(minDistList, traj_, X, Y)
    % Evaluate controller performance using the supplied grading rules.
    fprintf('Evaluating...\n');

    % Fall 2026 assignment thresholds (MCT_Project_2_2026.pdf).
    timeBaseline = 350;
    dt = 0.032;
    Cmax_cl = 12.0;
    Cavg = 4.0;
    Cmax_md = 8.0;
    fs = 30.0;

    traj = traj_(2:end-60, :);
    comGrad = clGrader(traj, X, Y, fs, Cmax_cl);
    beatBaselineScore = 0.0;

    fprintf('Score for completing the loop: %.2f/%.2f\n', comGrad, fs);
    avgGrad = adGrader(minDistList, fs, Cavg);
    fprintf('Score for average distance: %.2f/%.2f\n', avgGrad, fs);
    maxGrad = mdGrader(minDistList, fs, Cmax_md);
    fprintf('Score for maximum distance: %.2f/%.2f\n', maxGrad, fs);

    if comGrad < fs
        fprintf('Your vehicle did not finish the loop.\nYou cannot enter the competition.\n');
    else
        timeCurrent = length(X) * dt;
        beatBaselineScore = beatBaselineGrader(timeCurrent, timeBaseline);
        fprintf('Your time is %.4f\n', timeCurrent);
    end

    grade = avgGrad + maxGrad + comGrad + beatBaselineScore;
    scores = [comGrad, avgGrad, maxGrad, beatBaselineScore];
    fprintf('Your total score is : %.2f/100.0\n', grade);
end

function score = clGrader(traj, X, Y, fs, Cmax_cl)
    ng = 0.0;
    ntrack = size(traj, 1);
    XY = [X(:), Y(:)];
    % Process trajectory points in chunks to avoid the very slow nested
    % nearest-point loop while keeping memory bounded.
    chunkSize = 256;
    for first = 1:chunkSize:ntrack
        last = min(first + chunkSize - 1, ntrack);
        dx = traj(first:last, 1) - XY(:, 1)';
        dy = traj(first:last, 2) - XY(:, 2)';
        nearest = sqrt(min(dx .^ 2 + dy .^ 2, [], 2));
        ng = ng + sum(nearest <= Cmax_cl);
    end
    score = fs * (ng / ntrack);
end

function score = adGrader(minDistList, fs, Cavg)
    avg = mean(minDistList);
    if avg <= Cavg
        score = fs;
    elseif avg <= Cavg * 2
        score = (-20 / Cavg) * avg + 40;
    else
        score = 0;
    end
end

function score = mdGrader(minDistList, fs, Cmax_md)
    ng = 0;
    for i = 1:length(minDistList)
        if minDistList(i) <= Cmax_md
            ng = ng + 1;
        end
    end
    score = fs * (ng / length(minDistList));
end

function score = beatBaselineGrader(timeCurrent, timeBaseline)
    if timeCurrent <= timeBaseline
        score = 10;
    elseif timeCurrent <= 2.0 * timeBaseline
        score = 20 - 10 * timeCurrent / timeBaseline;
    else
        score = 0;
    end
end
