# Flutter Web Deployment Guide

Your Flutter web app has been built successfully! The production files are located in:
```
build\web\
```

## Deployment Options

### Option 1: Firebase Hosting (Recommended for Firebase projects)

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase Hosting** (if not already done):
   ```bash
   firebase init hosting
   ```
   - Select your Firebase project
   - Set public directory to: `build/web`
   - Configure as single-page app: **Yes**
   - Set up automatic builds: **No** (or Yes if using CI/CD)

4. **Deploy**:
   ```bash
   firebase deploy --only hosting
   ```

### Option 2: Netlify

1. **Install Netlify CLI**:
   ```bash
   npm install -g netlify-cli
   ```

2. **Login**:
   ```bash
   netlify login
   ```

3. **Deploy**:
   ```bash
   netlify deploy --prod --dir=build/web
   ```

   Or drag and drop the `build/web` folder to [Netlify Drop](https://app.netlify.com/drop)

### Option 3: Vercel

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Deploy**:
   ```bash
   cd build/web
   vercel --prod
   ```

### Option 4: Traditional Web Hosting (FTP/cPanel)

1. **Upload all files** from `build/web` to your web server's public directory (usually `public_html` or `www`)

2. **Important**: Ensure your server supports:
   - Serving `index.html` for all routes (SPA routing)
   - Proper MIME types for `.js`, `.wasm`, `.json` files

3. **Configure `.htaccess`** (for Apache servers):
   ```apache
   RewriteEngine On
   RewriteBase /
   RewriteRule ^index\.html$ - [L]
   RewriteCond %{REQUEST_FILENAME} !-f
   RewriteCond %{REQUEST_FILENAME} !-d
   RewriteRule . /index.html [L]
   ```

### Option 5: GitHub Pages

1. **Install gh-pages**:
   ```bash
   npm install -g gh-pages
   ```

2. **Deploy**:
   ```bash
   gh-pages -d build/web
   ```

## Important Notes

1. **Environment Variables**: If you're using `.env` files, make sure to configure environment variables in your hosting platform's settings.

2. **Firebase Configuration**: Ensure `firebase_options.dart` is properly configured for your production Firebase project.

3. **CORS Settings**: If your app makes API calls, ensure CORS is properly configured on your backend.

4. **OneSignal**: The OneSignal service workers are included. Make sure your OneSignal app ID is configured correctly in production.

5. **HTTPS**: Always use HTTPS in production for security and to enable service workers.

## Quick Deploy Script

You can create a batch file (`deploy.bat`) for Windows:

```batch
@echo off
echo Building Flutter web app...
flutter build web --release --no-tree-shake-icons
echo.
echo Build complete! Files are in build\web
echo.
echo Choose deployment method:
echo 1. Firebase Hosting
echo 2. Netlify
echo 3. Manual upload
pause
```

## Troubleshooting

- **404 errors on routes**: Configure your server to serve `index.html` for all routes (SPA routing)
- **WASM errors**: Ensure your server supports `.wasm` MIME type: `application/wasm`
- **Service worker issues**: Ensure HTTPS is enabled and service worker files are accessible

## Next Steps

After deployment, test your application thoroughly:
- [ ] Login functionality
- [ ] Dashboard loads correctly
- [ ] Chat support works
- [ ] Invoice generation works
- [ ] All Firebase features are accessible
- [ ] OneSignal notifications work (if configured)

