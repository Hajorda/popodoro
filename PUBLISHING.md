# Publishing a New Release

This document explains the steps to release a new version of Popodoro. The project is configured with a fully automated CI/CD pipeline using GitHub Actions. When you follow these steps, it will automatically build the executables, create a GitHub Release, and deploy the new version marker to GitHub Pages so that users get the update prompt inside the app.

## Step-by-Step Guide

### 1. Bump the Version
Open `pubspec.yaml` and update the `version` field. 
Flutter versions follow the format `major.minor.patch+build_number`.

```yaml
# pubspec.yaml
version: 1.0.2+3 # <-- Update this line
```
*Tip: Always increment the build number (`+3`) when you make a new release.*

### 2. Commit the Version Change
Commit the updated `pubspec.yaml` to your main branch.

```bash
git add pubspec.yaml
git commit -m "Bump version to 1.0.2"
```

### 3. Create a Git Tag
Create a tag that perfectly matches the version you just set in `pubspec.yaml` (prefix it with a `v`).

```bash
git tag v1.0.2
```

### 4. Push to GitHub
Push your commit and the new tag to GitHub.

```bash
git push origin main
git push origin v1.0.2
```

---

## What Happens Next? (Automated)

Once you push the `v1.0.2` tag, GitHub Actions automatically handles the rest:

1. **Build Jobs (`build-macos` & `build-windows`)**: It spins up Mac and Windows server environments to build `popodoro-macos.zip` and the Windows Inno Setup `.exe` installer.
2. **Release Job**: It creates a new release on the GitHub Releases page and attaches the `.zip` and `.exe` files as assets.
3. **Appcast Deployment (`deploy-pages`)**: It generates an `appcast.xml` file containing the download links for `v1.0.2` and pushes it strictly to the `gh-pages` branch. 
4. **App Update Dialog**: Existing users running `v1.0.1` will open their app, check the `appcast.xml` hosted on GitHub Pages, notice `1.0.2` is available, and an "Update Now" dialog will appear automatically.
