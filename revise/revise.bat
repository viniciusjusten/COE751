@echo off

SET BASEPATH=%~dp0

CALL julia +1.11.7 --project=%BASEPATH% --load=%BASEPATH%\revise.jl
