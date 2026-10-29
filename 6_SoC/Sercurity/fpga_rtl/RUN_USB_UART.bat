@echo off
setlocal
set "SOURCE_DIR=%~dp0"
set "OUTPUT_DIR=%~1"
if not defined OUTPUT_DIR set "OUTPUT_DIR=%SOURCE_DIR%build"
echo Building the Zynq PS+PL design for the onboard USB UART...
call "C:\Xilinx\Vivado\2024.2\bin\vivado.bat" -mode batch -notrace -source "%SOURCE_DIR%build_zynq_soc.tcl" -tclargs "%OUTPUT_DIR%"
if errorlevel 1 goto fail
call "%SOURCE_DIR%compile_arm.bat" "%OUTPUT_DIR%"
if errorlevel 1 goto fail
call "C:\Xilinx\Vitis\2024.2\bin\xsdb.bat" "%SOURCE_DIR%run_jtag.tcl" "%OUTPUT_DIR%"
if errorlevel 1 goto fail
echo Onboard USB UART is ready. Connect the UART UI to COM9 at 9600 bps.
pause
exit /b 0
:fail
echo Build or download failed. Read the error above.
pause
exit /b 1
