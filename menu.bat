@echo off

goto menu

:lua51
start bin/lua51.exe "./menu.lua"
exit

:lua52
start bin/lua52.exe "./menu.lua"
exit

:luajit
start bin/luajit.exe "./menu.lua"
exit

:menu

echo ------------------------------
echo -- Launch with lua version:
echo ------------------------------
echo 1. Lua 5.1
echo 2. Lua 5.2
echo 3. LuaJIT
echo 4. Exit
echo ------------------------------
SET /P M=Make a choice:
IF %M%==1 GOTO lua51
IF %M%==2 GOTO lua52
IF %M%==3 GOTO luajit
IF %M%==4 exit

