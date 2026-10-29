@echo off
rem Python 3.9 on this PC has tkinter and pyserial installed.
py -3.9 "%~dp0UART1_Repeater_GUI.py"
if errorlevel 1 pause
