@echo off
echo Starting CORE-5300 Smart Security UART Repeater GUI...
python "%~dp0UART1_Repeater_GUI.py"
if %ERRORLEVEL% neq 0 (
    echo.
    echo An error occurred while running the GUI.
    pause
)
