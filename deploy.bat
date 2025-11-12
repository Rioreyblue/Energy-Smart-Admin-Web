@echo off
echo ========================================
echo Flutter Web App Deployment Script
echo ========================================
echo.

echo Step 1: Building Flutter web app...
call flutter build web --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo Build failed! Please check the errors above.
    pause
    exit /b 1
)
echo Build completed successfully!
echo.

echo Step 2: Checking Firebase authentication...
firebase projects:list >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo Firebase authentication required!
    echo Please run: firebase login
    echo Then run this script again.
    echo.
    pause
    exit /b 1
)
echo Firebase authentication OK!
echo.

echo Step 3: Setting Firebase project...
firebase use capstonefinal593
echo.

echo Step 4: Deploying to Firebase Hosting...
firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo Deployment failed! Please check the errors above.
    pause
    exit /b 1
)
echo.
echo ========================================
echo Deployment completed successfully!
echo ========================================
echo.
pause

