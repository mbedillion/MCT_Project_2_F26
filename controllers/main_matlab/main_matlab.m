function main_matlab
    % MATLAB translation of the Webots Project 2 controller.
    % This keeps the original state-feedback and throttle workflow while using
    % the generic Webots MATLAB API for GPS, gyro, compass, and wheel motors.

    % Webots' MATLAB launcher initializes the robot before calling this
    % function. Calling wb_robot_init a second time breaks the controller
    % connection on some Webots releases.
    wb_console_print('MATLAB controller starting...', WB_STDOUT);

    controllerPath = fileparts(mfilename('fullpath'));
    trajectoryPath = fullfile(controllerPath, 'buggyTrace.csv');
    proofPath = fullfile(controllerPath, 'simulation_proof.log');
    proofFile = fopen(proofPath, 'w');
    if proofFile ~= -1
        fprintf(proofFile, 'MATLAB controller started\n');
        fclose(proofFile);
    end
    trajectory = getTrajectory(trajectoryPath);
    timestep = wb_robot_get_basic_time_step();

    initializeDriver();
    calllib('libDriver', 'wbu_driver_set_dipped_beams', true);
    calllib('libDriver', 'wbu_driver_set_gear', 1);

    customController = your_controller(trajectory);
    customController.startSensors(timestep);

    % Set up the in-world console and speedometer displays.
    tuningMode = strcmp(getenv('MATLAB_TUNING'), '1');
    console = 0;
    speedometer = 0;
    speedometerGraphic = 0;
    if ~tuningMode
        console = wb_robot_get_device('console');
        speedometer = wb_robot_get_device('speedometer');
        wb_display_set_font(console, 'Arial Black', 14, true);
        speedometerPath = fullfile(controllerPath, 'speedometer.png');
        speedometerGraphic = wb_display_image_load(speedometer, speedometerPath);
        wb_display_image_paste(speedometer, speedometerGraphic, 0, 0, true);
    end

    XVec = [];
    YVec = [];
    deltaVec = [];
    xdotVec = [];
    ydotVec = [];
    psiVec = [];
    psidotVec = [];
    FVec = [];
    minDist = [];
    passMiddlePoint = false;
    finish = false;
    middleMessageShown = false;
    stepCount = 0;

    while calllib('libDriver', 'wbu_driver_step') ~= -1
        stepCount = stepCount + 1;
        [X, Y, xdot, ydot, psi, psidot, F, delta] = customController.update(timestep);
        setVehicleControls(F, delta);

        [disError, nearIdx] = closestNode(X, Y, trajectory);
        if mod(stepCount, 250) == 0
            progress = sprintf('Step %d: waypoint %d/%d, speed %.2f m/s, cross-track error %.2f m', ...
                stepCount, nearIdx - 1, size(trajectory, 1) - 1, xdot, disError);
            wb_console_print(progress, WB_STDOUT);
            appendProof(proofPath, progress);
        end
        if ~tuningMode
            updateConsole(console, disError, nearIdx, size(trajectory, 1));
            updateSpeedometer(speedometer, speedometerGraphic, xdot * 3.6);
        end

        stepToMiddle = nearIdx - size(trajectory, 1) / 2.0;
        if abs(stepToMiddle) < 100.0 && ~passMiddlePoint
            passMiddlePoint = true;
        end

        if passMiddlePoint && ~middleMessageShown
            wb_console_print('Middle point passed.', WB_STDOUT);
            middleMessageShown = true;
        end
        if passMiddlePoint && ~tuningMode
            wb_display_draw_text(console, 'Middle point passed.', 5, 60);
        end

        nearGoal = nearIdx >= size(trajectory, 1) - 50;
        if nearGoal && passMiddlePoint
            if ~tuningMode
                wb_display_draw_text(console, sprintf('Middle point passed.\n\nDestination reached! :)'), 5, 60);
            end
            wb_console_print('Destination reached! :)', WB_STDOUT);
            appendProof(proofPath, 'Destination reached!');
            finish = true;
            break;
        end

        XVec(end + 1, 1) = X;
        YVec(end + 1, 1) = Y;
        deltaVec(end + 1, 1) = delta;
        xdotVec(end + 1, 1) = xdot;
        ydotVec(end + 1, 1) = ydot;
        psiVec(end + 1, 1) = psi;
        psidotVec(end + 1, 1) = psidot;
        FVec(end + 1, 1) = F;
        minDist(end + 1, 1) = disError;
    end

    calllib('libDriver', 'wbu_driver_set_cruising_speed', 0);
    calllib('libDriver', 'wbu_driver_set_steering_angle', 0);
    if ~tuningMode
        wb_display_image_delete(speedometer, speedometerGraphic);
    end

    if finish
        [grade, scores] = evaluation(minDist, trajectory, XVec, YVec);
        proofSummary = sprintf(['Grade: %.2f/100.0; time: %.3f s; ' ...
            'average error: %.4f m; maximum error: %.4f m'], ...
            grade, length(XVec) * timestep * 0.001, mean(minDist), max(minDist));
        appendProof(proofPath, proofSummary);
        showResult(trajectory, timestep, XVec, YVec, deltaVec, xdotVec, ...
            ydotVec, FVec, psiVec, psidotVec, minDist, grade, scores);
    end
    calllib('libDriver', 'wbu_driver_cleanup');
    unloadlibrary('libDriver');
end

function appendProof(proofPath, message)
    proofFile = fopen(proofPath, 'a');
    if proofFile ~= -1
        fprintf(proofFile, '%s\n', message);
        fclose(proofFile);
    end
end

function initializeDriver()
    if libisloaded('libDriver')
        unloadlibrary('libDriver');
    end
    webotsHome = getenv('WEBOTS_HOME');
    if isempty(webotsHome)
        error('WEBOTS_HOME is not set. Start this controller from Webots.');
    end
    if ismac
        webotsHome = fullfile(webotsHome, 'Contents');
        driverName = 'libdriver.dylib';
    elseif isunix
        driverName = 'libdriver.so';
    elseif ispc
        driverName = 'driver.dll';
    else
        error('Unsupported operating system for the Webots vehicle driver.');
    end
    driverLibrary = fullfile(webotsHome, 'lib', 'controller', driverName);
    driverHeader = fullfile(webotsHome, 'include', 'controller', 'c', 'webots', 'vehicle', 'driver.h');
    controllerIncludes = fullfile(webotsHome, 'include', 'controller', 'c');
    if ~isfile(driverLibrary), error('Webots vehicle driver library not found: %s', driverLibrary); end
    if ~isfile(driverHeader), error('Webots vehicle driver header not found: %s', driverHeader); end
    loadlibrary(driverLibrary, driverHeader, 'alias', 'libDriver', 'includepath', controllerIncludes);
    calllib('libDriver', 'wbu_driver_init');
end

function refreshDisplay(display)
    width = wb_display_get_width(display);
    height = wb_display_get_height(display);
    wb_display_set_alpha(display, 1.0);
    wb_display_set_color(display, [0, 0, 0]);
    wb_display_fill_rectangle(display, 0, 0, width, height);
    wb_display_set_color(display, [1, 1, 1]);
end

function updateConsole(console, disError, nearIdx, waypointCount)
    refreshDisplay(console);
    % MATLAB indices start at one; show the project's zero-based index.
    pythonIndex = nearIdx - 1;
    percent = 100 * pythonIndex / waypointCount;
    message = sprintf(['Cross-track error: %.5f\n\nNearest waypoint: %d' ...
        '\n\nPercent complete: %.1f%%'], disError, pythonIndex, percent);
    wb_display_draw_text(console, message, 5, 5);
end

function updateSpeedometer(speedometer, graphic, speedKmh)
    refreshDisplay(speedometer);
    wb_display_image_paste(speedometer, graphic, 0, 0, true);
    needleLength = 50;
    alpha = speedKmh / 130.0 * 3.72 - 0.27;
    x = fix(-needleLength * cos(alpha));
    y = fix(-needleLength * sin(alpha));
    wb_display_draw_line(speedometer, 100, 95, 100 + x, 95 + y);
end

function setVehicleControls(F, delta)
    throttleConversion = 5000;
    targetThrottle = clamp(F / throttleConversion, 0, 1);
    steerLimit = pi / 6;
    targetSteer = -clamp(delta, -steerLimit, steerLimit);
    calllib('libDriver', 'wbu_driver_set_throttle', targetThrottle);
    calllib('libDriver', 'wbu_driver_set_steering_angle', targetSteer);
end
