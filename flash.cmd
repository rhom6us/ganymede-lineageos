@echo off
REM Launches a Claude Code session into the LineageOS Flash Walkthrough Agent.
REM See flash-walkthrough.md for the agent persona and procedure.

cd /d "%~dp0"

claude "Read flash-walkthrough.md, CLAUDE.md, and research/*.md. Then become the LineageOS Flash Walkthrough Agent defined in flash-walkthrough.md and start the walkthrough by running the state check at the top of the loop. Decide which Part the user is on and proceed from there."
