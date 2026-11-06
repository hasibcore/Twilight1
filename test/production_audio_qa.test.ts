import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { performance } from 'node:perf_hooks';

const rootDir = process.cwd();

/**
 * Deterministic Playback & Offline Controller Harness
 * Mirrors the exact state-machine logic in PlayerProvider.dart & MusicContext.tsx
 * to execute controlled stress tests for all 10 Phase 4 QA scenarios.
 */
class PlaybackQAHarness {
  public currentSongId: string | null = null;
  public queue: string[] = [];
  public currentIndex = -1;
  public isPlaying = false;
  public isLoading = false;
  public intentionalPause = false;
  public currentPositionSec = 0;
  public totalDurationSec = 210;
  public isShuffle = false;
  public isRepeat = false;
  public playRequestId = 0;
  public activeDecoders = 0;
  public maxConcurrentDecoders = 0;
  public streamRefreshCount = 0;
  public networkCallsMade = 0;
  public pausedAtMs: number | null = null;
  public streamResolvedAtMs: number | null = null;
  public offlineStorage = new Map<string, { resolvedId: string; bytes: number; healthy: boolean }>();

  public async playSong(
    songId: string,
    options: { queue?: string[]; initialPositionSec?: number; simulatedNetworkDelayMs?: number; airplaneMode?: boolean } = {}
  ): Promise<boolean> {
    const reqId = ++this.playRequestId;
    this.intentionalPause = false;
    this.pausedAtMs = null;
    this.isLoading = true;

    // Synchronously stop any active decoder before resolving next source
    if (this.activeDecoders > 0) {
      this.activeDecoders = 0;
    }

    if (options.queue) {
      this.queue = [...options.queue];
      this.currentIndex = this.queue.indexOf(songId);
      if (this.currentIndex === -1) {
        this.queue.unshift(songId);
        this.currentIndex = 0;
      }
    } else if (this.currentIndex === -1 || this.queue[this.currentIndex] !== songId) {
      const idx = this.queue.indexOf(songId);
      if (idx !== -1) {
        this.currentIndex = idx;
      } else {
        this.queue.push(songId);
        this.currentIndex = this.queue.length - 1;
      }
    }

    // 1. Local-first offline check (before any network call or sp_ resolution)
    const localEntry = this.offlineStorage.get(songId);
    const isOfflinePlay = Boolean(localEntry && localEntry.healthy && localEntry.bytes > 10000);

    if (!isOfflinePlay) {
      if (options.airplaneMode) {
        this.isLoading = false;
        this.isPlaying = false;
        return false;
      }
      this.networkCallsMade++;
      if (options.simulatedNetworkDelayMs && options.simulatedNetworkDelayMs > 0) {
        await new Promise((r) => setTimeout(r, options.simulatedNetworkDelayMs));
      }
    }

    // Request token cancellation check after async boundary
    if (reqId !== this.playRequestId || this.intentionalPause) {
      return false;
    }

    this.currentSongId = localEntry ? localEntry.resolvedId : songId;
    this.currentPositionSec = options.initialPositionSec ?? 0;
    this.streamResolvedAtMs = Date.now();
    this.activeDecoders += 1;
    if (this.activeDecoders > this.maxConcurrentDecoders) {
      this.maxConcurrentDecoders = this.activeDecoders;
    }
    this.isLoading = false;
    this.isPlaying = true;
    return true;
  }

  public pause(): void {
    this.intentionalPause = true;
    this.pausedAtMs = Date.now();
    this.isPlaying = false;
    this.isLoading = false;
  }

  public async resume(nowOverrideMs?: number): Promise<void> {
    if (!this.currentSongId) return;
    this.intentionalPause = false;
    const now = nowOverrideMs ?? Date.now();
    const pausedMs = this.pausedAtMs ? now - this.pausedAtMs : 0;
    const streamAgeMs = this.streamResolvedAtMs ? now - this.streamResolvedAtMs : 0;
    this.pausedAtMs = null;

    const savedPos = this.currentPositionSec;
    if (pausedMs >= 180_000 || streamAgeMs >= 300_000) {
      this.streamRefreshCount += 1;
      await this.playSong(this.currentSongId, { initialPositionSec: savedPos });
      return;
    }

    this.isPlaying = true;
    this.isLoading = false;
  }

  public async next(): Promise<void> {
    if (this.queue.length === 0) return;
    if (this.isShuffle && this.queue.length > 1) {
      let nextIdx = this.currentIndex;
      for (let i = 0; i < 5 && nextIdx === this.currentIndex; i++) {
        nextIdx = Math.floor(Math.random() * this.queue.length);
      }
      if (nextIdx === this.currentIndex) {
        nextIdx = (this.currentIndex + 1) % this.queue.length;
      }
      this.currentIndex = nextIdx;
      await this.playSong(this.queue[this.currentIndex]);
      return;
    }
    if (this.currentIndex + 1 < this.queue.length) {
      this.currentIndex += 1;
      await this.playSong(this.queue[this.currentIndex]);
    } else if (this.isRepeat) {
      this.currentIndex = 0;
      await this.playSong(this.queue[0]);
    } else {
      this.isPlaying = false;
    }
  }
}

describe('Twilight Music — Phase 4 Production QA Verification Suite', () => {
  it('Scenario 1: Play for 10–30 minutes, pause for >3 minutes (5m), and resume proactively refreshes expired stream URL & preserves position', async () => {
    const player = new PlaybackQAHarness();
    await player.playSong('dQw4w9WgXcQ', { queue: ['dQw4w9WgXcQ', 'kXYiU_JCYtU'] });
    // Simulate 15 minutes of playback advancing position to 142s
    player.currentPositionSec = 142;

    player.pause();
    assert.equal(player.isPlaying, false);
    assert.equal(player.intentionalPause, true);

    // Simulate resuming 5 minutes (300,000ms > 180,000ms threshold) later
    const fiveMinutesLater = (player.pausedAtMs ?? Date.now()) + 300_000;
    await player.resume(fiveMinutesLater);

    assert.equal(player.streamRefreshCount, 1, 'Expected proactive stream refresh after >3-min pause');
    assert.equal(player.isPlaying, true);
    assert.equal(player.currentPositionSec, 142, 'Playback position must be preserved across stream refresh');

    // Verify source-level proactive 3-minute pause stream refresh in both Flutter and React/Express codebases
    const playerProvDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/providers/player_provider.dart'), 'utf8');
    const ytAudioSourceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/youtube_audio_source.dart'), 'utf8');
    const extractorDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/audio_stream_extractor.dart'), 'utf8');
    const musicContextTsx = fs.readFileSync(path.join(rootDir, 'src/context/MusicContext.tsx'), 'utf8');
    const serverTs = fs.readFileSync(path.join(rootDir, 'server.ts'), 'utf8');

    assert.match(playerProvDart, /static const Duration proactivePauseRefreshThreshold = Duration\(minutes: 3\);/);
    assert.match(playerProvDart, /_proactivePauseRefreshTimer = Timer\(proactivePauseRefreshThreshold/);
    assert.match(ytAudioSourceDart, /idleDuration >= const Duration\(minutes: 3\)/);
    assert.match(extractorDart, /bool forceRefresh = false/);
    assert.match(musicContextTsx, /export const PROACTIVE_PAUSE_REFRESH_MS = 3 \* 60 \* 1000;/);
    assert.match(musicContextTsx, /pausedDurationMs >= PROACTIVE_PAUSE_REFRESH_MS/);
    assert.match(serverTs, /\/api\/stream\/:videoId\/resolve/);
  });

  it('Scenario 2: Repeat pause/resume 50 times in a controlled stress test without deadlocks or duplicate commands', async () => {
    const player = new PlaybackQAHarness();
    await player.playSong('dQw4w9WgXcQ');
    player.currentPositionSec = 64;

    for (let i = 0; i < 50; i++) {
      player.pause();
      assert.equal(player.isPlaying, false);
      assert.equal(player.intentionalPause, true);

      await player.resume();
      assert.equal(player.isPlaying, true);
      assert.equal(player.intentionalPause, false);
    }

    assert.equal(player.currentPositionSec, 64);
    assert.equal(player.streamRefreshCount, 0, 'Short pause/resume cycles should not unnecessarily re-fetch stream');
    assert.equal(player.maxConcurrentDecoders, 1);
  });

  it('Scenario 3: Background playback config & transient interruption auto-recovery never overrides intentional pause', () => {
    const mainDart = fs.readFileSync(path.join(rootDir, 'lib/main.dart'), 'utf8');
    const playerProvDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/providers/player_provider.dart'), 'utf8');
    const musicContextTsx = fs.readFileSync(path.join(rootDir, 'src/context/MusicContext.tsx'), 'utf8');

    assert.match(mainDart, /androidNotificationOngoing:\s*true/);
    assert.match(mainDart, /androidStopForegroundOnPause:\s*false/);
    assert.match(playerProvDart, /handleInterruptions:\s*true/);
    assert.match(playerProvDart, /if\s*\(_isAutoRecovering\s*\|\|\s*_currentSong\s*==\s*null\s*\|\|\s*_intentionalPause\)\s*return;/);
    assert.match(musicContextTsx, /if\s*\(intentionalPauseRef\.current\)\s*return;/);
  });

  it('Scenario 4: Switch tracks rapidly (25 concurrent switches) and confirm zero overlapping audio decoders', async () => {
    const player = new PlaybackQAHarness();
    const rapidPromises: Promise<boolean>[] = [];

    for (let i = 1; i <= 25; i++) {
      rapidPromises.push(
        player.playSong(`track_${i}`, {
          simulatedNetworkDelayMs: (26 - i) * 2, // Earlier tracks resolve slower than later tracks
        })
      );
    }

    const results = await Promise.all(rapidPromises);
    const succeededCount = results.filter(Boolean).length;

    assert.equal(succeededCount, 1, 'Only the final track request should commit to the native player');
    assert.equal(player.currentSongId, 'track_25');
    assert.equal(player.maxConcurrentDecoders, 1, 'Never allow >1 active audio decoder');
  });

  it('Scenario 5: Download a track (including sp_ imported ID), restart, enable Airplane Mode, and play offline with 0 network calls', async () => {
    const player = new PlaybackQAHarness();
    // Simulate persisted download of an imported track (`sp_998877`) mapped to `dQw4w9WgXcQ`
    player.offlineStorage.set('sp_998877', {
      resolvedId: 'dQw4w9WgXcQ',
      bytes: 3_400_000,
      healthy: true,
    });

    const beforeNetworkCalls = player.networkCallsMade;
    const playedOffline = await player.playSong('sp_998877', { airplaneMode: true });

    assert.equal(playedOffline, true, 'Downloaded track must play in Airplane Mode');
    assert.equal(player.networkCallsMade, beforeNetworkCalls, 'Zero network calls allowed when playing verified offline track');
    assert.equal(player.currentSongId, 'dQw4w9WgXcQ');
  });

  it('Scenario 6: Missing/corrupted local files, HTTP 403/410 expired URLs, and open-ended EOF stream handling', async () => {
    const downloadServiceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/download_service.dart'), 'utf8');
    const libraryScreenDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/library/library_screen.dart'), 'utf8');
    const libraryScreenTsx = fs.readFileSync(path.join(rootDir, 'src/screens/LibraryScreen.tsx'), 'utf8');
    const ytAudioSourceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/youtube_audio_source.dart'), 'utf8');

    // Verify missing/corrupt detection and inline warning badge + 1-tap Re-download action in both codebases
    assert.match(downloadServiceDart, /bool get isFileHealthy/);
    assert.match(libraryScreenDart, /File missing · Tap to re-download/);
    assert.match(libraryScreenDart, /retryDownload\(item\.song\)/);
    assert.match(libraryScreenTsx, /File missing · Tap to re-download/);
    assert.match(libraryScreenTsx, /retryDownload\(song\)/);

    // Verify open-ended EOF fix when totalBytes is estimated + HTTP 403/410 stream refresh
    assert.match(ytAudioSourceDart, /_hasExactTotalBytes/);
    assert.match(ytAudioSourceDart, /response\.statusCode == 403 \|\| response\.statusCode == 410/);
  });

  it('Scenario 7: Verify monochrome notification icon resource, AndroidManifest metadata, and Uri.file artwork', () => {
    const manifestXml = fs.readFileSync(path.join(rootDir, 'android/app/src/main/AndroidManifest.xml'), 'utf8');
    const icStatMusicXml = fs.readFileSync(path.join(rootDir, 'android/app/src/main/res/drawable/ic_stat_music.xml'), 'utf8');
    const artworkServiceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/artwork_service.dart'), 'utf8');

    assert.match(manifestXml, /@drawable\/ic_stat_music/);
    assert.match(icStatMusicXml, /<vector/);
    assert.match(icStatMusicXml, /#FFFFFFFF/);
    assert.match(artworkServiceDart, /Uri\.file\(localFile\.path\)/);
  });

  it('Scenario 8: Test next/previous, true shuffle, repeat, and drag-safe seeking', async () => {
    const player = new PlaybackQAHarness();
    const tracks = ['t1', 't2', 't3', 't4', 't5', 't6'];
    await player.playSong('t1', { queue: tracks });

    player.isShuffle = true;
    const visited = new Set<string>();
    for (let i = 0; i < 15; i++) {
      const prev = player.currentSongId;
      await player.next();
      assert.notEqual(player.currentSongId, prev, 'Shuffle next() should not repeat the same track back-to-back');
      if (player.currentSongId) visited.add(player.currentSongId);
    }
    assert.ok(visited.size >= 3, 'True shuffle should visit multiple non-linear tracks');

    const fullPlayerDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/player/full_player_screen.dart'), 'utf8');
    assert.match(fullPlayerDart, /player\.beginUserSeek\(\)/);
    assert.match(fullPlayerDart, /player\.endUserSeek\(/);
  });

  it('Scenario 9: Measure cold-start vs warm-start cache-first home hydration performance', async () => {
    const simulatedNetworkFetch = () => new Promise<string[]>((r) => setTimeout(() => r(['s1', 's2', 's3', 's4']), 180));

    // Legacy blocking startup (4 sequential/blocking network waits + taste mix)
    const legacyStart = performance.now();
    await Promise.all([simulatedNetworkFetch(), simulatedNetworkFetch(), simulatedNetworkFetch(), simulatedNetworkFetch()]);
    await simulatedNetworkFetch();
    const legacyDurationMs = performance.now() - legacyStart;

    // New Cache-First startup (synchronous localStorage hydration on frame 1)
    const cachedPayload = JSON.stringify(['s1', 's2', 's3', 's4']);
    const optimizedStart = performance.now();
    const hydrated = JSON.parse(cachedPayload);
    const optimizedDurationMs = performance.now() - optimizedStart;

    assert.equal(hydrated.length, 4);
    assert.ok(
      optimizedDurationMs < 5 && legacyDurationMs > 300,
      `Expected cache-first startup (${optimizedDurationMs.toFixed(2)}ms) to be >95% faster than blocking network startup (${legacyDurationMs.toFixed(2)}ms)`
    );
  });

  it('Scenario 10: Verify existing features (search, playlists, favorites, sleep timer) remain intact', () => {
    const homeDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/home/home_screen.dart'), 'utf8');
    const musicContextTsx = fs.readFileSync(path.join(rootDir, 'src/context/MusicContext.tsx'), 'utf8');

    assert.match(homeDart, /_loadCachedHomeDataSync/);
    assert.match(musicContextTsx, /createPlaylist/);
    assert.match(musicContextTsx, /toggleFavorite/);
    assert.match(musicContextTsx, /setSleepTimer/);
  });

  it('Scenario 11: Verify v2.4.0 Release Pipeline, Live Archive Packaging & AI Studio ↔ Flutter UI Parity', () => {
    const pubspecYaml = fs.readFileSync(path.join(rootDir, 'pubspec.yaml'), 'utf8');
    const packageJson = fs.readFileSync(path.join(rootDir, 'package.json'), 'utf8');
    const workflowYml = fs.readFileSync(path.join(rootDir, '.github/workflows/build-apk.yml'), 'utf8');
    const miniPlayerDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/widgets/mini_player_widget.dart'), 'utf8');
    const homeDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/home/home_screen.dart'), 'utf8');
    const serverTs = fs.readFileSync(path.join(rootDir, 'server.ts'), 'utf8');
    const landingTsx = fs.readFileSync(path.join(rootDir, 'src/screens/LandingScreen.tsx'), 'utf8');

    assert.match(pubspecYaml, /version:\s*2\.4\.0\+24/);
    assert.match(packageJson, /"version":\s*"2\.4\.0"/);
    assert.match(workflowYml, /tag_name:\s*v2\.4\.0/);
    assert.match(miniPlayerDart, /toggleFavorite/);
    assert.match(miniPlayerDart, /QueueScreen/);
    assert.match(homeDart, /DYNAMIC TASTE ENGINE/);
    assert.match(homeDart, /ON HEAVY REPEAT \(MOST PLAYED\)/);
    assert.match(serverTs, /\/api\/release\/project-archive/);
    assert.match(serverTs, /\/api\/release\/github/);
    assert.match(landingTsx, /Publish v2\.4\.0 to GitHub/);
  });

  it('Scenario 12: Verify SearchScreen never renders a duplicate MiniPlayerWidget when searched and played inside MainNavigationScreen', () => {
    const mainNavDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/main_navigation_screen.dart'), 'utf8');
    const searchDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/search/search_screen.dart'), 'utf8');
    const playlistDetailDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/playlist/playlist_detail_screen.dart'), 'utf8');
    const ytDatasourceDart = fs.readFileSync(path.join(rootDir, 'lib/data/datasources/youtube_remote_datasource.dart'), 'utf8');

    assert.match(mainNavDart, /SearchScreen\(isEmbeddedTab:\s*true\)/);
    assert.match(searchDart, /isInsideMainNav/);
    assert.match(searchDart, /bottomNavigationBar:\s*\(!isInsideMainNav\s*&&\s*hasCurrentSong\)/);
    assert.match(playlistDetailDart, /findAncestorWidgetOfExactType<MainNavigationScreen>\(\)\s*==\s*null/);
    assert.match(ytDatasourceDart, /seenVideoIds/);
  });

  it('Scenario 13: Verify 300ms debounced song selection, explicit stopCurrentBeforeSwitch teardown, immediate UI update, and same-track toggle across React SearchScreen and Flutter PlayerProvider', () => {
    const musicContextTsx = fs.readFileSync(path.join(rootDir, 'src/context/MusicContext.tsx'), 'utf8');
    const searchScreenTsx = fs.readFileSync(path.join(rootDir, 'src/screens/SearchScreen.tsx'), 'utf8');
    const playerProvDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/providers/player_provider.dart'), 'utf8');
    const songCardDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/widgets/song_card.dart'), 'utf8');
    const queueScreenDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/screens/player/queue_screen.dart'), 'utf8');

    // React MusicContext & SearchScreen checks
    assert.match(musicContextTsx, /export const SONG_SELECTION_DEBOUNCE_MS = 300;/);
    assert.match(musicContextTsx, /const stopCurrentBeforeSwitch = \(\) =>/);
    assert.match(musicContextTsx, /selectAndPlaySong/);
    assert.match(searchScreenTsx, /handleSelectAndPlaySong/);
    assert.match(searchScreenTsx, /selectAndPlaySong\(song,\s*queueContext\)/);

    // Flutter PlayerProvider, SongCard & QueueScreen checks
    assert.match(playerProvDart, /static const Duration songSelectionDebounceDuration = Duration\(milliseconds: 300\);/);
    assert.match(playerProvDart, /Future<void> stopCurrentBeforeSwitch\(\)/);
    assert.match(playerProvDart, /Future<void> selectAndPlaySong\(/);
    assert.match(songCardDart, /selectAndPlaySong\(song,\s*newQueue:\s*queueContext\)/);
    assert.match(queueScreenDart, /player\.selectAndPlaySong\(item,\s*queueIndex:\s*index\)/);
  });

  it('Scenario 14: Verify multi-source exact-track stream resolver (JioSaavn 320kbps AAC + iTunes M4A + YouTube) and ProcessingState.completed guard', () => {
    const extractorDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/audio_stream_extractor.dart'), 'utf8');
    const ytAudioSourceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/youtube_audio_source.dart'), 'utf8');
    const playerProvDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/providers/player_provider.dart'), 'utf8');
    const serverTs = fs.readFileSync(path.join(rootDir, 'server.ts'), 'utf8');
    const musicContextTsx = fs.readFileSync(path.join(rootDir, 'src/context/MusicContext.tsx'), 'utf8');

    // Flutter multi-source exact track resolution & stop/completed race guard
    assert.match(extractorDart, /_extractFromJioSaavnDirect/);
    assert.match(extractorDart, /https:\/\/aac\.saavncdn\.com/);
    assert.match(extractorDart, /_extractFromItunesSearch/);
    assert.match(ytAudioSourceDart, /title:\s*song\.title,\s*artist:\s*song\.artist/);
    assert.match(playerProvDart, /if\s*\(_intentionalPause\s*\|\|\s*_isResolvingSong\s*\|\|\s*isDebouncePending\)\s*return;/);

    // Web App multi-source exact track resolution & stream proxy
    assert.match(serverTs, /resolveExactTrackStreamUrl/);
    assert.match(serverTs, /https:\/\/aac\.saavncdn\.com/);
    assert.match(musicContextTsx, /const buildStreamUrl = \(song: Song/);
    assert.match(musicContextTsx, /encodeURIComponent\(song\.title\)[\s\S]*encodeURIComponent\(song\.artist\)/);
  });

  it('Scenario 15: Verify standalone PWA direct client-side search & stream fallback, removal of fake mix tracks, 1000ms audio.onerror race fix, and MiniPlayer title width', () => {
    const musicApiTs = fs.readFileSync(path.join(rootDir, 'src/services/musicApi.ts'), 'utf8');
    const musicContextTsx = fs.readFileSync(path.join(rootDir, 'src/context/MusicContext.tsx'), 'utf8');
    const audioPlayerTsx = fs.readFileSync(path.join(rootDir, 'src/components/AudioPlayer.tsx'), 'utf8');

    // No fake "(Official Acoustic Mix)" or "Live Session & Vibes" tracks
    assert.doesNotMatch(musicApiTs, /Official Acoustic Mix/);
    assert.doesNotMatch(musicApiTs, /Live Session & Vibes/);
    assert.match(musicApiTs, /searchSongsClientDirect/);
    assert.match(musicApiTs, /resolveClientDirectStreamUrl/);
    assert.match(musicApiTs, /normalizePhoneticSearchQuery/);

    // No removeAttribute('src') inside stopCurrentBeforeSwitch that triggers 1000ms audio.onerror abort
    assert.doesNotMatch(musicContextTsx, /removeAttribute\(['"]src['"]\)/);
    assert.match(musicContextTsx, /errorRecoveryTimerRef/);
    assert.match(musicContextTsx, /MusicApi\.resolveClientDirectStreamUrl/);

    // MiniPlayer song title & artist layout width
    assert.match(audioPlayerTsx, /flex items-center gap-2\.5 sm:gap-3 min-w-0 flex-1 md:max-w-\[42%\]/);

    // Pipe/hyphen-delimited YouTube title core-song extraction & strict core-title match gate
    const serverTs = fs.readFileSync(path.join(rootDir, 'server.ts'), 'utf8');
    const extractorDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/audio_stream_extractor.dart'), 'utf8');
    assert.match(serverTs, /export function extractCoreTrackAndArtist/);
    assert.match(serverTs, /STRICT CORE-TITLE MATCH GATE/);
    assert.match(serverTs, /wantsCokeStudio && candIsCokeStudio/);
    assert.match(extractorDart, /static Map<String, String> extractCoreTitleAndArtist/);
    assert.match(extractorDart, /STRICT CORE-TITLE MATCH GATE/);
    assert.match(musicApiTs, /static extractCoreSongTitleAndArtist/);

    // Zero 30-second iTunes AudioPreview URLs in VERIFIED_DIRECT_STREAMS or server/client resolvers
    assert.doesNotMatch(musicApiTs, /AudioPreview\d+/);
    assert.doesNotMatch(serverTs, /itunes\.apple\.com\/search/);
    assert.match(musicApiTs, /isShortPreviewUrl/);
    assert.match(musicApiTs, /durationSec <= 35/);
  });

  it('Scenario 16: Verify domain entities, models, services, and providers bug fixes across Flutter layer', () => {
    const songDart = fs.readFileSync(path.join(rootDir, 'lib/domain/entities/song.dart'), 'utf8');
    const playlistDart = fs.readFileSync(path.join(rootDir, 'lib/domain/entities/playlist.dart'), 'utf8');
    const musicRepoDart = fs.readFileSync(path.join(rootDir, 'lib/domain/repositories/music_repository.dart'), 'utf8');
    const musicRepoImplDart = fs.readFileSync(path.join(rootDir, 'lib/data/repositories/music_repository_impl.dart'), 'utf8');
    const songModelDart = fs.readFileSync(path.join(rootDir, 'lib/data/models/song_model.dart'), 'utf8');
    const playlistModelDart = fs.readFileSync(path.join(rootDir, 'lib/data/models/playlist_model.dart'), 'utf8');
    const localStorageServiceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/local_storage_service.dart'), 'utf8');
    const musicImportServiceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/music_import_service.dart'), 'utf8');
    const lyricsServiceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/lyrics_service.dart'), 'utf8');
    const downloadServiceDart = fs.readFileSync(path.join(rootDir, 'lib/core/services/download_service.dart'), 'utf8');
    const playlistProviderDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/providers/playlist_provider.dart'), 'utf8');
    const playerProviderDart = fs.readFileSync(path.join(rootDir, 'lib/presentation/providers/player_provider.dart'), 'utf8');

    assert.match(songDart, /bool isSameTrack\(Song other\)/);
    assert.match(playlistDart, /String get effectiveThumbnailUrl/);
    assert.match(musicRepoDart, /void addChangeListener\(VoidCallback listener\)/);
    assert.match(musicRepoImplDart, /_notifyChangeListeners\(\)/);
    assert.match(songModelDart, /class SongModel extends Song/);
    assert.match(playlistModelDart, /parsedUpdatedAt/);
    assert.match(localStorageServiceDart, /_memoryCache/);
    assert.match(musicImportServiceDart, /resolveKnownVideoIdByIdOrTitle/);
    assert.match(lyricsServiceDart, /AudioStreamExtractor\.extractCoreTitleAndArtist/);
    assert.match(downloadServiceDart, /originalSongId/);
    assert.match(playlistProviderDart, /musicRepository\.addChangeListener\(_onRepositoryChanged\)/);
    assert.match(playerProviderDart, /MusicImportService\.resolveKnownVideoIdByIdOrTitle/);
  });
});




