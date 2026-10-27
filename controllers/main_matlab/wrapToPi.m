function a_wrapped = wrapToPi(a)
    % Wrap an angle to [-pi, pi)
    a_wrapped = mod(a + pi, 2 * pi) - pi;
end
