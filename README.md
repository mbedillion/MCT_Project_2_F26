# MCT-F26 Project 2

MATLAB R2025a backend for the Project 2 state-feedback-control assignment,
migrated from the supplied Webots R2021-era world to Webots R2025a while
retaining its student-facing behavior.
Python is not required by the converted project.

## Requirements

- Webots R2025a
- MATLAB R2025a with Control System Toolbox
- Windows: MATLAB Support for MinGW-w64 C/C++ Compiler
- macOS: Xcode Command Line Tools with a MATLAB-supported Clang compiler
- Ubuntu Linux: a GCC release supported by the installed MATLAB version

The controller selects `driver.dll` on Windows, `libdriver.dylib` on macOS,
and `libdriver.so` on Linux. macOS and Ubuntu support follows the same code path
as Project 1 but remains runtime-unverified. Do not use the Linux Snap package,
whose sandbox does not support MATLAB controllers.

## Clone and run

```text
git clone <repository-url> MCT-F26-Project2
cd MCT-F26-Project2
```

Open `worlds/automotive_new.wbt` in Webots R2025a and press **Run**. The tractor
uses controller `main_matlab`; Webots launches MATLAB and runs
`controllers/main_matlab/main_matlab.m`. Do not run that file directly because
Webots must establish the controller connection first.

If Webots does not detect MATLAB, set its MATLAB command in **Tools >
Preferences > General** to the MATLAB R2025a executable. Preserve the repository
folder structure and reset the simulation after controller edits. If controller
startup fails, confirm `WEBOTS_HOME` is set by Webots, install the MinGW support
package, and remove stale generated Webots/MATLAB cache files before retrying.
Do this only after Webots and MATLAB have exited so no thunk DLL remains locked.

## Assignment work

Read [MCT_Project_2_2026.pdf](MCT_Project_2_2026.pdf)
in full. Edit only:

```text
controllers/main_matlab/your_controller.m
```

Implement the labeled lateral full-state-feedback section and longitudinal
controller section inside `update`. The initial zero-force, zero-steering
placeholders are safe. The supplied runner, grader, trajectory, and helper files
must not be changed for assignment work.

The Fall 2026 assignment targets a loop time of at most 350 s, maximum deviation
of at most 8.0 m, and average deviation of at most 4.0 m. After the destination is
reached, grading prints in the terminal and MATLAB saves
`controllers/main_matlab/controller_results.png`. The results window remains
open until closed by the user.

Instructor solutions, generated plots, scores, logs, caches, and Webots project
UI state are intentionally excluded from Git.

## R2025a compatibility

The migrated world declares its R2025a PROTO dependencies explicitly. Road,
building, forest, playset, and primitive coordinates follow R2025a conventions.
The project-local front and rear wheel PROTOs preserve the original joint frames
while rotating only wheel geometry to the newer primitive-axis convention.
