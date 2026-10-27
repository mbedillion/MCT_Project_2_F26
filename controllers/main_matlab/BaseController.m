classdef BaseController < handle
    % Base controller for Webots sensor access and vehicle state estimation
    properties
        trajectory
        previousX
        previousY
        previousZ
        previousPsi
        previousXdotError
        integralXdotError
        gps
        gyro
        compass
    end

    methods
        function obj = BaseController(trajectory)
            obj.trajectory = trajectory;
            obj.previousX = 0;
            obj.previousY = 0;
            obj.previousZ = 0;
            obj.previousPsi = 0;
            obj.previousXdotError = 0;
            obj.integralXdotError = 0;
        end

        function startSensors(obj, timestep)
            obj.gps = wb_robot_get_device('gps');
            wb_gps_enable(obj.gps, timestep);

            obj.gyro = wb_robot_get_device('gyro');
            wb_gyro_enable(obj.gyro, timestep);

            obj.compass = wb_robot_get_device('compass');
            wb_compass_enable(obj.compass, timestep);
        end

        function [delT, X, Y, xdot, ydot, psi, psidot] = getStates(obj, timestep)
            delT = 0.001 * timestep;

            position = wb_gps_get_values(obj.gps);
            X = position(1);
            Y = position(2);

            Xdot = (X - obj.previousX) / (delT + 1e-9);
            obj.previousX = X;
            Ydot = (Y - obj.previousY) / (delT + 1e-9);
            obj.previousY = Y;
            XYdot = [Xdot; Ydot];

            psi = wrapToPi(obj.getBearingInRad());
            angularVelocity = wb_gyro_get_values(obj.gyro);
            psidot = angularVelocity(3);

            rotationMat = [cos(psi), -sin(psi); sin(psi), cos(psi)];
            velocities = rotationMat \ XYdot;
            xdot = velocities(1);
            ydot = velocities(2);
            xdot = clamp(xdot, 1e-5, inf);
        end

        function bearing = getBearingInRad(obj)
            north = wb_compass_get_values(obj.compass);
            rad = atan2(north(2), north(1));
            bearing = pi / 2.0 - rad;
        end
    end
end
