@echo off
REM Pin the Node runtime for the Codex MCP shim.
REM
REM WHY THIS FILE EXISTS
REM   Exactly the same reason as hermes-council-launch.cmd, one runtime over.
REM
REM   The Hermes supervisor substitutes its own runtime when an MCP entry names one
REM   directly. For Python that produced
REM       ModuleNotFoundError: No module named 'mcp.server.fastmcp'
REM   which reads as a missing dependency and is not one. config.yaml names
REM   `atomicmemory` (npx) and `hermes-skills` (node) as carrying the identical
REM   exposure: a substituted Node fails the same way and just as misleadingly.
REM
REM   This shim would have been the third. A launcher is indirection the supervisor
REM   cannot reach through -- it sees one opaque command, and whatever this file runs
REM   internally is not its business.
REM
REM   Set HERMES_CODEX_NODE to the node.exe you want. Find it with:
REM       (Get-Command node).Source
REM
REM   FAILS LOUDLY rather than falling back to whatever `node` resolves to. A silent
REM   fallback is the entire bug class this exists to prevent, and "it worked on my
REM   machine" is what that bug looks like from the outside.

setlocal

if defined HERMES_CODEX_NODE (
    set "NODE=%HERMES_CODEX_NODE%"
) else (
    echo codex-mcp: HERMES_CODEX_NODE is not set. 1>&2
    echo   Set it to the Node runtime this shim should use, for example: 1>&2
    echo     [Environment]::SetEnvironmentVariable('HERMES_CODEX_NODE',(Get-Command node).Source,'User') 1>&2
    echo   Refusing to guess -- guessing a runtime is what broke hermes-council. 1>&2
    exit /b 9
)

if not exist "%NODE%" (
    echo codex-mcp: node not found at "%NODE%" 1>&2
    echo   HERMES_CODEX_NODE points at a path that does not exist. 1>&2
    exit /b 9
)

REM %~dp0 is this file's own directory, so the server is located relative to the
REM launcher rather than to whatever working directory the supervisor happens to use.
"%NODE%" "%~dp0codex-mcp\server.js" %*
