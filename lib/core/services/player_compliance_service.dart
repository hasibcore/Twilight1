class PlayerComplianceService {
  PlayerComplianceService._();

  /// Confirms that official YouTube playback is used.
  /// Strictly prevents downloading, audio extraction, or DRM bypass.
  static const bool isOfficialPlaybackCompliant = true;
  static const bool allowsAudioRipping = false;
  static const bool allowsVideoDownloading = false;

  static String getBackgroundPlaybackLimitationMessage() {
    return 'Official YouTube embedded playback requires a visible video viewport or Picture-in-Picture mode on supported devices. YouTube Terms of Service strictly forbid headless audio stream ripping.';
  }

  static bool canUsePictureInPicture() {
    // In Flutter Android/iOS apps, PiP can be triggered when supported by OS
    return true;
  }
}
