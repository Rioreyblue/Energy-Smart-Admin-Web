@echo off
echo Deploying Firestore security rules...
echo.

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: Firebase CLI is not installed or not in PATH
    echo Please install Firebase CLI first: https://firebase.google.com/docs/cli
    pause
    exit /b 1
)

REM Deploy the rules
echo Deploying rules to Firebase...
firebase deploy --only firestore:rules

if %errorlevel% equ 0 (
    echo.
    echo ✅ Firestore rules deployed successfully!
    echo You can now try logging in again.
) else (
    echo.
    echo ❌ Failed to deploy Firestore rules
    echo Please check your Firebase project configuration
)

echo.
pause









