@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d c:\project\NCM
set "OUT=c:\project\NCM\_git_ops_output.txt"
echo. > "%OUT%"

call :log === START ===
call :log cwd=%CD%

call :log === 1. git rev-parse --is-inside-work-tree ===
git rev-parse --is-inside-work-tree >> "%OUT%" 2>&1
set "IS_REPO=%ERRORLEVEL%"
git rev-parse --is-inside-work-tree 2>&1
echo IS_REPO_EXIT=%ERRORLEVEL%>> "%OUT%"

call :log === 2. git remote -v ===
git remote -v >> "%OUT%" 2>&1
git remote -v 2>&1

set "GIT_INIT_WORKED=false"
if not "%IS_REPO%"=="0" (
  call :log === 3. git init -b main ===
  git init -b main >> "%OUT%" 2>&1
  if errorlevel 1 (
    echo git_init_worked=false>> "%OUT%"
    call :log git_init FAILED
  ) else (
    set "GIT_INIT_WORKED=true"
    echo git_init_worked=true>> "%OUT%"
    call :log git_init OK
  )
) else (
  set "GIT_INIT_WORKED=true"
  echo git_init_worked=already_repo>> "%OUT%"
  call :log already a repo
)

call :log === 4. ensure .gitignore ===
if not exist .gitignore (
  (
    echo node_modules
    echo .next
    echo out
    echo dist
    echo .env
    echo .env.local
    echo *.log
    echo .DS_Store
    echo Thumbs.db
  ) > .gitignore
  call :log created .gitignore
) else (
  findstr /x /c:"node_modules" .gitignore >nul || echo node_modules>> .gitignore
  findstr /x /c:".next" .gitignore >nul || echo .next>> .gitignore
  findstr /x /c:".env" .gitignore >nul || echo .env>> .gitignore
  findstr /x /c:".env.local" .gitignore >nul || echo .env.local>> .gitignore
  call :log .gitignore checked
)

call :log === 5. git status --porcelain ===
git status --porcelain >> "%OUT%" 2>&1
git status --porcelain 2>&1

call :log === 6. commits? ===
git rev-parse HEAD >nul 2>&1
set "HAS_COMMIT=%ERRORLEVEL%"
set "COMMIT_HASH="
if not "%HAS_COMMIT%"=="0" (
  call :log === creating initial commit ===
  git add .gitignore frontend _run_git_and_worktree.cmd 2>nul
  git add -A
  REM unstage secrets if any were added
  git reset HEAD -- .env .env.local frontend\.env frontend\.env.local 2>nul
  git commit -m "Initial commit" -m "NCM frontend login page with mock auth ready for a future API." >> "%OUT%" 2>&1
  if errorlevel 1 (
    echo commit_failed=true>> "%OUT%"
    call :log commit FAILED
  ) else (
    for /f "delims=" %%h in ('git rev-parse HEAD') do set "COMMIT_HASH=%%h"
    echo commit_hash=!COMMIT_HASH!>> "%OUT%"
    call :log commit OK !COMMIT_HASH!
  )
) else (
  for /f "delims=" %%h in ('git rev-parse HEAD') do set "COMMIT_HASH=%%h"
  echo commit_hash=!COMMIT_HASH!>> "%OUT%"
  call :log existing commit !COMMIT_HASH!
)

call :log === 7. gh auth status ===
gh auth status >> "%OUT%" 2>&1
set "GH_AUTH=%ERRORLEVEL%"
gh auth status 2>&1
echo gh_auth_exit=%GH_AUTH%>> "%OUT%"

set "GITHUB_URL="
set "PUSH_SUCCEEDED=false"
for /f "delims=" %%r in ('git remote get-url origin 2^>nul') do set "EXISTING_REMOTE=%%r"

if defined EXISTING_REMOTE (
  call :log existing remote: !EXISTING_REMOTE!
  echo github_url_existing=!EXISTING_REMOTE!>> "%OUT%"
  set "GITHUB_URL=!EXISTING_REMOTE!"
  echo push_succeeded=skipped_remote_exists>> "%OUT%"
) else if "%GH_AUTH%"=="0" (
  call :log === 8. gh repo create NCM ===
  gh repo create NCM --public --source=. --remote=origin --push >> "%OUT%" 2>&1
  if errorlevel 1 (
    call :log NCM name failed, trying NCM-portal
    gh repo create NCM-portal --public --source=. --remote=origin --push >> "%OUT%" 2>&1
    if errorlevel 1 (
      echo push_succeeded=false>> "%OUT%"
      call :log gh repo create FAILED
    ) else (
      set "PUSH_SUCCEEDED=true"
      echo push_succeeded=true>> "%OUT%"
      for /f "delims=" %%u in ('git remote get-url origin') do set "GITHUB_URL=%%u"
      echo github_url=!GITHUB_URL!>> "%OUT%"
      call :log push OK !GITHUB_URL!
    )
  ) else (
    set "PUSH_SUCCEEDED=true"
    echo push_succeeded=true>> "%OUT%"
    for /f "delims=" %%u in ('git remote get-url origin') do set "GITHUB_URL=%%u"
    echo github_url=!GITHUB_URL!>> "%OUT%"
    call :log push OK !GITHUB_URL!
  )
) else (
  echo push_succeeded=false_gh_not_auth>> "%OUT%"
  call :log gh not authenticated, skip create/push
)

REM === worktree create (Windows block) ===
call :log === 9. create worktree ===
for /f %%s in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "-join ((1..8) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })"') do set "SUFFIX=%%s"
set "NAME=ncm-!SUFFIX!"
for /f "delims=" %%r in ('git rev-parse --show-toplevel') do set "REPO_ROOT=%%r"
set "WORKTREE_DIR=%USERPROFILE%\.cursor\worktrees\!NAME!"
if exist "!WORKTREE_DIR!" (
  echo ERROR: worktree directory already exists: !WORKTREE_DIR!>> "%OUT%"
  call :log worktree dir exists
) else (
  if defined WORKTREE_START_REF (
    set "START_REF=!WORKTREE_START_REF!"
  ) else (
    set "START_REF=HEAD"
  )
  git worktree add --detach "!WORKTREE_DIR!" "!START_REF!" >> "%OUT%" 2>&1
  if errorlevel 1 (
    call :log worktree add FAILED
  ) else (
    for /f "delims=" %%h in ('git -C "!WORKTREE_DIR!" rev-parse HEAD') do set "WT_HEAD=%%h"
    echo WORKTREE_ID=!NAME!>> "%OUT%"
    echo WORKTREE_PATH=!WORKTREE_DIR!>> "%OUT%"
    echo REPO_ROOT=!REPO_ROOT!>> "%OUT%"
    echo HEAD_COMMIT=!WT_HEAD!>> "%OUT%"
    echo WORKTREE_START_REF=!START_REF!>> "%OUT%"
    call :log WORKTREE_ID=!NAME!
    call :log WORKTREE_PATH=!WORKTREE_DIR!
    call :log HEAD_COMMIT=!WT_HEAD!

    REM setup discovery
    set "SETUP_RAN=skipped"
    if exist "!WORKTREE_DIR!\.cursor\worktrees.json" (
      echo found worktrees.json in WORKTREE_PATH>> "%OUT%"
    ) else if exist "!REPO_ROOT!\.cursor\worktrees.json" (
      echo found worktrees.json in REPO_ROOT>> "%OUT%"
    ) else (
      echo worktree_setup=skipped_no_config>> "%OUT%"
      set "SETUP_RAN=skipped_after_check"
      call :log setup skipped - no worktrees.json
    )
  )
)

call :log === SUMMARY ===
echo git_init_worked=!GIT_INIT_WORKED!
echo commit_hash=!COMMIT_HASH!
echo github_url=!GITHUB_URL!
echo push_succeeded=!PUSH_SUCCEEDED!
echo git_init_worked=!GIT_INIT_WORKED!>> "%OUT%"
echo commit_hash=!COMMIT_HASH!>> "%OUT%"
echo github_url=!GITHUB_URL!>> "%OUT%"
echo push_succeeded=!PUSH_SUCCEEDED!>> "%OUT%"
call :log === END ===
echo Full log written to %OUT%
exit /b 0

:log
echo %*
echo %*>> "%OUT%"
goto :eof
