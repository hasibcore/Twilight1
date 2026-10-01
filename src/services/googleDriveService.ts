import { getDriveAccessToken, auth, googleProvider, setDriveAccessToken } from './firebase';
import { signInWithPopup, GoogleAuthProvider } from 'firebase/auth';

export interface DriveUploadResult {
  success: boolean;
  fileId?: string;
  fileName?: string;
  webViewLink?: string;
  error?: string;
}

export class GoogleDriveService {
  /**
   * Ensures a valid in-memory access token is available.
   * If not cached, initiates a Google Sign-In popup with the required drive.file scope.
   */
  static async ensureAccessToken(): Promise<string> {
    const existingToken = getDriveAccessToken();
    if (existingToken) {
      return existingToken;
    }

    // Request token via popup
    const result = await signInWithPopup(auth, googleProvider);
    const credential = GoogleAuthProvider.credentialFromResult(result);
    if (!credential?.accessToken) {
      throw new Error('Could not obtain Google Drive access token from sign-in.');
    }

    setDriveAccessToken(credential.accessToken);
    return credential.accessToken;
  }

  /**
   * Finds or creates a dedicated 'Twilight Music Releases' folder in the user's Drive.
   */
  static async getOrCreateTwilightFolder(accessToken: string): Promise<string> {
    const folderName = 'Twilight Music Releases';
    const query = encodeURIComponent(
      `name = '${folderName}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false`
    );

    try {
      const searchRes = await fetch(
        `https://www.googleapis.com/drive/v3/files?q=${query}&fields=files(id,name)`,
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );

      if (searchRes.ok) {
        const data = await searchRes.json();
        if (data.files && data.files.length > 0) {
          return data.files[0].id;
        }
      }

      // Create new folder
      const createRes = await fetch('https://www.googleapis.com/drive/v3/files', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          name: folderName,
          mimeType: 'application/vnd.google-apps.folder',
          description: 'Official release builds and packages for Twilight Music',
        }),
      });

      if (createRes.ok) {
        const createdFolder = await createRes.json();
        return createdFolder.id;
      }
    } catch (err) {
      console.warn('Folder check failed, uploading to root:', err);
    }

    return 'root';
  }

  /**
   * Uploads the Twilight Music full project release archive to the user's Google Drive.
   */
  static async uploadReleaseArchive(
    onProgress?: (percent: number, message: string) => void
  ): Promise<DriveUploadResult> {
    try {
      if (onProgress) onProgress(10, 'Authenticating Google Drive...');
      const accessToken = await this.ensureAccessToken();

      if (onProgress) onProgress(25, 'Connecting to Twilight Music Releases folder...');
      const folderId = await this.getOrCreateTwilightFolder(accessToken);

      if (onProgress) onProgress(45, 'Fetching release archive package...');
      // Fetch latest built tarball from local endpoint
      const archiveResponse = await fetch('/landing/downloads/twilight-music-full-project.tar.gz');
      if (!archiveResponse.ok) {
        throw new Error('Could not read release archive from local server.');
      }

      const blob = await archiveResponse.blob();
      const fileName = `Twilight-Music-v1.0.1-Release-${new Date().toISOString().slice(0, 10)}.tar.gz`;

      if (onProgress) onProgress(65, 'Uploading archive to Google Drive...');

      // Multipart upload
      const metadata = {
        name: fileName,
        mimeType: 'application/gzip',
        parents: folderId !== 'root' ? [folderId] : undefined,
        description: 'Complete Twilight Music project release package with background playback and clean UI.',
      };

      const formData = new FormData();
      formData.append(
        'metadata',
        new Blob([JSON.stringify(metadata)], { type: 'application/json' })
      );
      formData.append('file', blob);

      const uploadResponse = await fetch(
        'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
          body: formData,
        }
      );

      if (!uploadResponse.ok) {
        const errJson = await uploadResponse.json().catch(() => null);
        throw new Error(errJson?.error?.message || `Google Drive API error (${uploadResponse.status})`);
      }

      const uploadedFile = await uploadResponse.json();

      if (onProgress) onProgress(100, 'Upload complete!');

      return {
        success: true,
        fileId: uploadedFile.id,
        fileName: uploadedFile.name,
        webViewLink: uploadedFile.webViewLink,
      };
    } catch (err: any) {
      console.error('Google Drive upload error:', err);
      return {
        success: false,
        error: err?.message || 'Failed to upload archive to Google Drive.',
      };
    }
  }
}
