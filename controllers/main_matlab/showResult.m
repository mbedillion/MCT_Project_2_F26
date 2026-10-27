function showResult(traj, timestep, X, Y, delta, xdot, ydot, F, psi, psidot, minDist, grade, scores) %#ok<INUSD>
    % Plot the complete driving profile
    sampleCount = length(X);
    totalTime = (0:sampleCount - 1)' * timestep * 0.001;
    fprintf('total steps: %d\n', sampleCount);

    if sampleCount == 0
        warning('No samples were recorded; no result plot was created.');
        return;
    end

    firstSample = min(3, sampleCount);
    plotSamples = firstSample:sampleCount;

    resultFigure = figure('Position', [100, 100, 1200, 800], 'Color', 'w');

    subplot(4, 2, 1);
    xlabel('X (m)');
    ylabel('Y (m)');
    hold on;
    plot(traj(:, 1), traj(:, 2), 'Color', [0.5 0.5 0.5], 'LineWidth', 6);
    plot(X, Y, 'r');
    hold off;

    subplot(4, 2, 2);
    plot(totalTime(plotSamples), delta(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('delta (rad)');

    subplot(4, 2, 3);
    plot(totalTime(plotSamples), xdot(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('xdot (m/s)');

    subplot(4, 2, 4);
    plot(totalTime(plotSamples), ydot(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('ydot (m/s)');

    subplot(4, 2, 5);
    plot(totalTime(plotSamples), psi(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('psi (rad)');

    subplot(4, 2, 6);
    plot(totalTime(plotSamples), psidot(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('psidot (rad/s)');

    subplot(4, 2, 7);
    plot(totalTime(plotSamples), minDist(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('minDist (m)');

    subplot(4, 2, 8);
    plot(totalTime(plotSamples), F(plotSamples), 'r');
    xlabel('Time (s)');
    ylabel('F (N)');

    % Preserve the original layout and labels, but force readable axes even
    % when MATLAB or the operating system uses a dark theme.
    plotAxes = findall(resultFigure, 'Type', 'axes');
    set(plotAxes, 'Color', 'w', 'XColor', 'k', 'YColor', 'k', ...
        'FontSize', 10, 'LineWidth', 1, 'Box', 'on');
    for axisHandle = reshape(plotAxes, 1, [])
        axisHandle.XLabel.Color = 'k';
        axisHandle.YLabel.Color = 'k';
        axisHandle.XLabel.FontWeight = 'bold';
        axisHandle.YLabel.FontWeight = 'bold';
        grid(axisHandle, 'on');
    end

    sgtitle(sprintf('Vehicle trajectory and control history - Grade: %.2f/100', grade), ...
        'Color', 'k', 'FontWeight', 'bold');
    drawnow;

    resultPath = fullfile(fileparts(mfilename('fullpath')), 'controller_results.png');
    exportgraphics(resultFigure, resultPath, 'Resolution', 150);
    fprintf('Saved result image: %s\n', resultPath);

    avgDist = mean(minDist);
    fprintf('maxMinDist: %.4f\n', max(minDist));
    fprintf('avgMinDist: %.4f\n', avgDist);

    % Webots launches this controller with MATLAB's -batch option, which
    % would otherwise close MATLAB (and this figure) as soon as grading ends.
    if strcmp(getenv('MATLAB_TUNING'), '1')
        fprintf('Noninteractive verification mode: closing results window.\n');
        close(resultFigure);
    else
        fprintf('Results ready. Close the results window to exit MATLAB.\n');
        waitfor(resultFigure);
    end
end
