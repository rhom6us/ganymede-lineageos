@echo off
REM Launches a Claude Code session into the LineageOS Flash Walkthrough Agent.
REM See .claude/agents/flash-walkthrough.md for the agent persona and procedure.
REM
REM Usage:
REM   flash.cmd                       - default opening prompt
REM   flash.cmd "your prompt here"    - pass through your own opening prompt

cd /d "%~dp0"

if "%~1"=="" (
  claude --agent flash-walkthrough "Start the walkthrough by running the state check at the top of the loop. Decide which Part the user is on and proceed from there."
) else (
  claude --agent flash-walkthrough %*
)
