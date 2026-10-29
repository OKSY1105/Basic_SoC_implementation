@echo off
"C:\Xilinx\Vitis\2024.2\bin\xsdb.bat" "%~dp0run_jtag.tcl" %*
if errorlevel 1 exit /b 1
pause
