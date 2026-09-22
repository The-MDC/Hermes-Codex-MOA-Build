@echo off
REM Pin the interpreter for hermes_council.server.
REM
REM WHY THIS FILE EXISTS
REM   The Hermes supervisor substitutes its own bundled Python when an MCP entry
REM   names an interpreter directly. The symptom was
REM       ModuleNotFoundError: No module named 'mcp.server.fastmcp'
REM   which reads as a missing dependency and is not one -- hermes_council imports
REM   fine under the interpreter it was installed into. The supervisor was running
REM   a different Python than the one that had the packages.
REM
REM   A launcher is indirection the supervisor cannot reach through. It sees one
REM   opaque command; whatever this file executes internally is not its business.
REM
REM   Set HERMES_COUNCIL_PYTHON to the interpreter that can import hermes_council.
REM   Find it with:  (Get-Command python).Source
REM
REM   This script FAILS LOUDLY rather than falling back to some other python.
REM   A silent fallback is the entire bug class it exists to prevent.

setlocal

if defined HERMES_COUNCIL_PYTHON (
    set "PY=%HERMES_COUNCIL_PYTHON%"
) else (
    echo hermes-council: HERMES_COUNCIL_PYTHON is not set. 1>&2
    echo   Set it to the interpreter that can import hermes_council, for example: 1>&2
    echo     [Environment]::SetEnvironmentVariable('HERMES_COUNCIL_PYTHON','C:\Python314\python.exe','User') 1>&2
    echo   Refusing to guess -- guessing an interpreter is what broke this before. 1>&2
    exit /b 9
)

if not exist "%PY%" (
    echo hermes-council: interpreter not found at "%PY%" 1>&2
    echo   HERMES_COUNCIL_PYTHON points at a path that does not exist. 1>&2
    exit /b 9
)

"%PY%" -m hermes_council.server %*
