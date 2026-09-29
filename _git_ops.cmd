@echo off
REM Entry point: bypasses PowerShell AllSigned by running pure cmd.
cd /d c:\project\NCM
call "%~dp0_run_git_and_worktree.cmd"
echo.
echo Output also saved to: c:\project\NCM\_git_ops_output.txt
pause
