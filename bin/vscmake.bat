@if not defined _echo echo off

for /f "usebackq tokens=*" %%i in (`vswhere.exe -latest -products * -requires Microsoft.VisualStudio.Component.VC.CMake.Project -property installationPath`) do (
    if exist "%%i\VC\Auxiliary\Build\vcvarsall.bat" (
        "%%i\VC\Auxiliary\Build\vcvarsall.bat" %1
        cd /D %2
        cmake --preset=%3
        cmake --build --preset=%3
    )
)
