% Compatibility launcher for Webots R2025a with recent MATLAB releases.
% Patch Webots' launcher locally so loadlibrary receives the generated
% MATLAB prototype as a function handle instead of treating it as a header.
webotsHome = getenv('WEBOTS_HOME');
if isempty(webotsHome)
    error('WEBOTS_HOME is not set. Start this controller from Webots.');
end
if ismac
    webotsHome = fullfile(webotsHome, 'Contents');
end
officialLauncher = fullfile(webotsHome, 'lib', 'controller', 'matlab', 'launcher.m');
launcherText = fileread(officialLauncher);
oldCall = "loadlibrary(libname,protofile,'alias','libController');";
newCall = "loadlibrary(libname,str2func(protofile),'alias','libController');";
if ~contains(launcherText, oldCall)
    error('The Webots MATLAB launcher format is not recognized.');
end
launcherText = replace(launcherText, oldCall, newCall);
compatLauncher = [tempname '.m'];
fileId = fopen(compatLauncher, 'w');
if fileId == -1
    error('Unable to create the compatible Webots MATLAB launcher.');
end
cleanupFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s', launcherText);
clear cleanupFile;
cleanupLauncher = onCleanup(@() delete(compatLauncher));
run(compatLauncher);
clear cleanupLauncher;
