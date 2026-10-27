function value = clamp(v, minValue, maxValue)
    % Clamp a value to a given range
    value = max(min(maxValue, v), minValue);
end
