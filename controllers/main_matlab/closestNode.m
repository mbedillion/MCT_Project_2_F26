function [distance, index] = closestNode(X, Y, trajectory)
    % Find the closest waypoint to the point [X, Y]
    point = [X, Y];
    diff = point - trajectory;
    distSquared = sum(diff .^ 2, 2);
    [~, index] = min(distSquared);
    distance = sqrt(distSquared(index));
end
