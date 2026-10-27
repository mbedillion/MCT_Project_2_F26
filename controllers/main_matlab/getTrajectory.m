function trajectory = getTrajectory(filename)
    % Read the trajectory CSV file into a Nx2 matrix
    if ~isfile(filename)
        error('Trajectory file not found: %s', filename);
    end
    trajectory = readmatrix(filename);
    trajectory = trajectory(all(isfinite(trajectory(:, 1:2)), 2), 1:2);
    if isempty(trajectory)
        error('Trajectory file contains no valid XY waypoints: %s', filename);
    end
end
