@echo off
setlocal EnableExtensions
cd /d c:\project\NCM

REM Generate 8-char hex suffix
set "HEX=0123456789abcdef"
set "SUFFIX="
for /L %%i in (1,1,8) do (
  set /a "R=!RANDOM! %% 16"
)
REM Use PowerShell Bypass only for random hex (inline -Command, no .ps1 file)
for /f %%s in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "-join ((1..8) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })"') do set "SUFFIX=%%s"
set "NAME=ncm-%SUFFIX%"

for /f "delims=" %%r in ('git rev-parse --show-toplevel') do set "REPO_ROOT=%%r"
set "WORKTREE_DIR=%USERPROFILE%\.cursor\worktrees\%NAME%"

if exist "%WORKTREE_DIR%" (
  echo ERROR: worktree directory already exists: %WORKTREE_DIR%
  exit /b 1
)

if defined WORKTREE_START_REF (
  set "START_REF=%WORKTREE_START_REF%"
) else (
  set "START_REF=HEAD"
)

git worktree add --detach "%WORKTREE_DIR%" "%START_REF%"
if errorlevel 1 exit /b 1

for /f "delims=" %%h in ('git -C "%WORKTREE_DIR%" rev-parse HEAD') do set "HEAD_COMMIT=%%h"

echo WORKTREE_ID=%NAME%
echo WORKTREE_PATH=%WORKTREE_DIR%
echo REPO_ROOT=%REPO_ROOT%
echo HEAD_COMMIT=%HEAD_COMMIT%
echo WORKTREE_START_REF=%START_REF%
