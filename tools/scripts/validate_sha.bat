@echo off
REM validate_sha.bat <sha> [repo_path]
if "%~1"=="" (
  echo Usage: %~nx0 ^<sha^> [repo_path]
  exit /b 1
)
set sha=%~1
set repo=%~2
if "%repo%"=="" set repo=.

powershell -NoProfile -Command ^
  "param($sha,$repo); ^
   if ($sha -notmatch '^[0-9a-fA-F]{7,40}$') { Write-Error 'INVALID_FORMAT'; exit 2 } ; ^
   $proc = & git -C $repo cat-file -e \"$($sha)^{commit}\" 2>$null; ^
   if ($LASTEXITCODE -ne 0) { Write-Error 'NOT_FOUND'; exit 3 } ; ^
   Write-Output 'VALID'; exit 0" -- "%sha%" "%repo%"

exit /b %ERRORLEVEL%
