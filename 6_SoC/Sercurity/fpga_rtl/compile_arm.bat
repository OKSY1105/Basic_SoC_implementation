@echo off
setlocal
set "SOURCE_DIR=%~dp0"
set "OUTPUT_DIR=%~1"
if not defined OUTPUT_DIR set "OUTPUT_DIR=%SOURCE_DIR%build"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
set "GCC=C:\Xilinx\Vitis\2024.2\gnu\aarch32\nt\gcc-arm-none-eabi\bin\arm-none-eabi-gcc.exe"
"%GCC%" -mcpu=cortex-a9 -c "%SOURCE_DIR%startup.S" -o "%OUTPUT_DIR%\startup.o"
if errorlevel 1 exit /b 1
"%GCC%" -mcpu=cortex-a9 -O2 -c "%SOURCE_DIR%uart_bridge.c" -o "%OUTPUT_DIR%\uart_bridge.o"
if errorlevel 1 exit /b 1
"%GCC%" -mcpu=cortex-a9 -nostdlib -Wl,-T -Wl,"%SOURCE_DIR%lscript_mini.ld" "%OUTPUT_DIR%\startup.o" "%OUTPUT_DIR%\uart_bridge.o" -o "%OUTPUT_DIR%\uart_bridge.elf"
if errorlevel 1 exit /b 1
echo ARM_BRIDGE_BUILD_PASS: %OUTPUT_DIR%\uart_bridge.elf
exit /b 0
