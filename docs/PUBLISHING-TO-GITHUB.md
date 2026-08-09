# Publishing to GitHub

## Easiest method: GitHub website

1. Sign in to GitHub.
2. Select **New repository**.
3. Use a name such as `soulmask-server-manager`.
4. Add a short description, for example: `Windows GUI manager for local Soulmask dedicated-server world slots.`
5. Choose **Public** or **Private**.
6. Do not ask GitHub to generate another README or `.gitignore`; they are already included.
7. Create the repository.
8. Select **uploading an existing file**.
9. Upload the contents of this package folder, preserving the `manager`, `scripts`, `templates`, and `docs` folders.
10. Commit the uploaded files.

Before making the repository public, confirm that no `World-XX` folder, save database, password-bearing launcher, API key, or SteamCMD log was added.

## Command-line method

Run these commands from the package folder after creating an empty GitHub repository:

```powershell
git init
git add .
git commit -m "Initial release of Soulmask Server Manager v4.6"
git branch -M main
git remote add origin https://github.com/YOUR-ACCOUNT/soulmask-server-manager.git
git push -u origin main
```

Replace `YOUR-ACCOUNT` with the GitHub account or organization name.

## Recommended repository settings

- Enable Issues only if you want to provide user support.
- Add a screenshot of the running manager to the README later if desired.
- The repository already includes the MIT License.
- Create a `v4.6` release and attach the prepared ZIP for users who do not use Git.

## Suggested release text

```text
Soulmask Server Manager v4.6

Initial public package featuring five world slots, safe save and graceful shutdown,
automatic backups, gameplay configuration, Cloud Mist Forest and Shifting Sands
selection, safe test-world reset, and looping tribal-tech manager audio.

Windows PowerShell 5.1 and SteamCMD are required. See README.md for installation.
```

