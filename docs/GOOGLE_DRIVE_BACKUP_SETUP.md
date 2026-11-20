# Google Drive encrypted backup setup

MyVault uploads its existing password-protected `.myvault` backup format as a visible file in **My Drive**. The Drive account cannot read vault records, attachments, the vault master password, or the VEK.

## One-time Google Cloud setup

1. Create or select a project in [Google Cloud Console](https://console.cloud.google.com/).
2. Enable the **Google Drive API**.
3. Configure the OAuth consent screen and add yourself as a test user while the app is unpublished.
4. Create an Android OAuth client for package `com.personalvault.myvault` and register the release signing certificate SHA-1.
5. Create a Web OAuth client. Its client ID is supplied at build time; do not commit it to source control.

Build with the client IDs:

```powershell
flutter run --dart-define=GOOGLE_CLIENT_ID=YOUR_WEB_CLIENT_ID --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

## User flow

1. Unlock the vault and open **Settings → Google Drive Backup**.
2. Choose a separate recovery passphrase and remember it. MyVault keeps a device-protected copy only to make automatic uploads possible.
3. Sign in to Google and approve the limited `drive.file` permission.
4. Every successful vault edit queues one encrypted upload after five seconds. Use **Back Up Now** to upload immediately.

## Recovery and security

- The Drive file is named `myvault_automatic_backup_v1.myvault` and is visible in the normal **My Drive** file list. It is replaced in place on each successful backup.
- A replacement device needs the same Google account and the remembered recovery passphrase. Create and unlock an empty vault, connect Drive, then choose **Restore from Drive**. Restored data is re-encrypted with the new device's vault key.
- **Turn Off Drive Backup** removes local credentials and revokes app access. It does not delete the existing Drive backup.
- This feature is an encrypted backup, not multi-device live synchronization. Keep the local encrypted vault as the active data store.
