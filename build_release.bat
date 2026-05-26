@echo off
echo Copying Flutter ephemeral cpp_client_wrapper files...
xcopy /E /Y "C:\flutter_windows_3.38.5-stable\flutter\bin\cache\artifacts\engine\windows-x64\cpp_client_wrapper" "windows\flutter\ephemeral\cpp_client_wrapper" >nul 2>&1
echo Building release...
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat" >nul 2>&1
flutter build windows --release
echo.
echo Done! EXE is at: build\windows\x64\runner\Release\billingsoftware.exe
pause
