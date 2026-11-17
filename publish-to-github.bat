@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title Publish Lotus Bloom to GitHub Pages

set "OWNER=erlixie"
set "NAME=lotus-bloom"
set "PG=C:\Users\Administrator\.workbuddy\binaries\PortableGit\versions\1.3.0\mingw64\bin"
set "CURL=%SystemRoot%\System32\curl.exe"
set "API=https://api.github.com"
set "TMPD=%TEMP%\bloom_deploy"
if not exist "%TMPD%" mkdir "%TMPD%"

echo.
echo ================================================================
echo    Publish  "Lotus Bloom"  to  GitHub Pages
echo ================================================================
echo.
echo   Step 1  sign in to GitHub      (a window opens, once only)
echo   Step 2  create the repository  %OWNER%/%NAME%
echo   Step 3  upload 207 files, about 26 MB
echo   Step 4  switch GitHub Pages on
echo.

if exist "%PG%\git.exe" set "PATH=%PG%;%PATH%"
if not exist "%PG%\git.exe" goto nogit
git --version >nul 2>&1
if errorlevel 1 goto nogit
if not exist "%CURL%" goto nocurl

echo   Press any key to start ...
pause >nul
echo.

rem ========== 1. sign in (standalone, so the window can really open) ==========
echo [1/4]  Checking GitHub sign-in ...
set "TOK="

git-credential-manager github list > "%TMPD%\acc.txt" 2>nul
set "HASACC="
for /f "usebackq delims=" %%a in ("%TMPD%\acc.txt") do if not "%%a"=="" set "HASACC=1"
if defined HASACC goto gettoken

echo        no account stored yet - a sign-in window will open now.
echo        Please finish it: choose "Sign in with your browser".
echo.
git-credential-manager github login
if errorlevel 1 (
    echo        the sign-in step reported an error.
) else (
    echo        sign-in step finished.
)
echo.

:gettoken
rem read the stored credential (no interaction needed at this point)
set "CRED=%TMPD%\cred.txt"
(
 echo protocol=https
 echo host=github.com
 echo.
) | git credential fill > "%CRED%" 2>nul
for /f "tokens=1,* delims==" %%a in ('findstr /b "password=" "%CRED%" 2^>nul') do set "TOK=%%b"
del "%CRED%" >nul 2>&1
if not "%TOK%"=="" goto havecred

echo        could not read a stored credential automatically.
echo.
echo   ------------------------------------------------------------
echo    Alternative: paste a personal access token instead.
echo    In the browser you are already signed in to GitHub, open:
echo        https://github.com/settings/tokens/new
echo    Note: bloom-deploy      Expiration: 7 days
echo    Tick the whole  [v] repo  block, press Generate token,
echo    copy the ghp_... string and paste it below.
echo   ------------------------------------------------------------
echo.
set /p "TOK=Paste token here (or press Enter to quit): "
if "%TOK%"=="" goto nocred
(
 echo protocol=https
 echo host=github.com
 echo username=%OWNER%
 echo password=!TOK!
 echo.
) | git credential approve >nul 2>&1

:havecred
echo        signed in.
echo.

rem ========== 2. create repository if missing ==========
echo [2/4]  Checking repository %OWNER%/%NAME% ...
"%CURL%" -s -o nul -w "%%{http_code}" --max-time 40 -H "Authorization: Bearer %TOK%" -H "Accept: application/vnd.github+json" "%API%/repos/%OWNER%/%NAME%" > "%TMPD%\code.txt" 2>nul
set "CODE="
set /p CODE=<"%TMPD%\code.txt"
echo        current status: !CODE!
if "!CODE!"=="200" goto repok

:mkrep
echo        not found, creating it ...
> "%TMPD%\repo.json" echo {"name":"%NAME%","private":false,"description":"Gesture controlled lotus bloom - static site, no build needed"}
"%CURL%" -s -o "%TMPD%\res.json" -w "%%{http_code}" --max-time 60 -X POST -H "Authorization: Bearer %TOK%" -H "Accept: application/vnd.github+json" --data-binary "@%TMPD%\repo.json" "%API%/user/repos" > "%TMPD%\mcode.txt" 2>nul
set "MCODE="
set /p MCODE=<"%TMPD%\mcode.txt"
echo        create response: !MCODE!
if "!MCODE!"=="201" goto repok
if "!MCODE!"=="422" echo        name already used, will reuse it.
if "!MCODE!"=="422" goto repok
echo        [warn] could not create it automatically.
type "%TMPD%\res.json"
echo.
goto failrepo

:repok
echo        ok.
echo.

rem ========== 3. push the files ==========
echo [3/4]  Uploading 207 files, please wait (about 26 MB) ...
git remote remove origin >nul 2>&1
git remote add origin https://github.com/%OWNER%/%NAME%.git
git push -u origin main --force
if errorlevel 1 goto failpush
echo        done.
echo.

rem ========== 4. switch Pages on ==========
echo [4/4]  Switching GitHub Pages on ...
> "%TMPD%\pages.json" echo {"source":{"branch":"main","path":"/"}}
"%CURL%" -s -o "%TMPD%\pres.json" -w "%%{http_code}" --max-time 60 -X POST -H "Authorization: Bearer %TOK%" -H "Accept: application/vnd.github+json" --data-binary "@%TMPD%\pages.json" "%API%/repos/%OWNER%/%NAME%/pages" > "%TMPD%\pcode.txt" 2>nul
set "PCODE="
set /p PCODE=<"%TMPD%\pcode.txt"
echo        response: !PCODE!    (201 = switched on, 409 = already on)
if "!PCODE!"=="201" goto pagesok
if "!PCODE!"=="409" goto pagesok
echo        [warn] Pages may need one manual click, see below.

:pagesok
echo.
echo ================================================================
echo    ALL DONE
echo.
echo    Your public link, ready in about one minute:
echo        https://%OWNER%.github.io/%NAME%/
echo.
echo    The first visit takes a few seconds: it downloads about
echo    17 MB of model files once, then the browser caches them.
echo ================================================================
echo.
echo    Waiting 60 seconds for GitHub to build the site ...
timeout /t 60 /nobreak >nul
start "" "https://%OWNER%.github.io/%NAME%/"
echo.
echo    If it still shows 404, wait another minute and refresh.
echo    If Pages was not switched on, set it here by hand:
echo      https://github.com/%OWNER%/%NAME%/settings/pages
echo      Source: Deploy from a branch / main / / root  then Save
echo.
pause
exit /b 0

:nocred
echo.
echo [FAILED] No credential could be obtained, nothing was changed.
pause
exit /b 1

:failrepo
echo.
echo [FAILED] The repository could not be created.
echo   Create it by hand, then run this script again:
echo     https://github.com/new    name: %NAME%    Public
echo.
pause
exit /b 1

:failpush
echo.
echo [FAILED] Uploading the files did not work.
echo   - check your network
echo   - run the script again if the sign-in window was closed
echo   Your local files are untouched.
echo.
pause
exit /b 1

:nogit
echo [ERROR] git not found at %PG%
pause
exit /b 1

:nocurl
echo [ERROR] curl.exe not found in System32
pause
exit /b 1
