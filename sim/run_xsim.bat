@echo off
setlocal

set VIVADO_BIN=E:\AMDDesignTools\2025.2\Vivado\bin
set PATH=%VIVADO_BIN%;%PATH%

cd /d "%~dp0"

xvlog --sv ^
  ..\tb\tb.sv ^
  ..\rtl\top.sv ^
  ..\rtl\riscvmulti.sv ^
  ..\rtl\mem.sv ^
  ..\rtl\controller.sv ^
  ..\rtl\datapath.sv ^
  ..\rtl\ImmSrc.sv ^
  ..\rtl\aludec.sv ^
  ..\rtl\mainfsm.sv ^
  ..\rtl\flopenr.sv ^
  ..\rtl\mux2.sv ^
  ..\rtl\flopr.sv ^
  ..\rtl\regfile.sv ^
  ..\rtl\extend.sv ^
  ..\rtl\flopr2.sv ^
  ..\rtl\mux3.sv ^
  ..\rtl\alu.sv
if errorlevel 1 goto :error

xelab -debug typical testbench -s sim_snapshot
if errorlevel 1 goto :error

xsim sim_snapshot --runall
goto :done

:error
echo.
echo *** Simulation failed ***
exit /b 1

:done
endlocal
