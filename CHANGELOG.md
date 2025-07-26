# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).



[3.3.5]

`Active & Working`

## Added

- Added a method `getAudioUrlFlexible` which gives a single result for audiourl based on either `Title/Artist` or `videoId` 

## Fixed

- Minor fixes to `get_audio_url` added code if the selected quality wasn't found the engine will autoselect the best available.

[3.3.4]

`Active & Working`

## Fixed

- Minor fixes to `handleInitialization`, `get_audio_url`.


[3.3.3]

`Active & Working`

## Fixed

- Minor Patches to `handleInitialization`, `handlePythonInitialization`, `handleDispose`
- Fixed the results mixup issues by properly improving cancellations

[3.3.2]

`Active & Working`

## Fixed

- Ensured robust per-search cancellation by tracking and checking the latest active search ID for each stream type.

- Added a final guard in both Kotlin and Python to prevent yielding or emitting results from any previous/cancelled stream.

- Eliminated edge-case race conditions that could allow items from a canceled query to appear in a new search stream.

- Unified cancellation handling across all stream handlers to guarantee only current query results reach the client.[3.3.1]

## Added

- Finalized generator-safe StreamHandlers for:

- SearchStreamHandler

- RelatedSongsStreamHandler

- ArtistSongsStreamHandler

- SongDetailsStreamHandler
- These handlers now integrate global stream cancellation rules, ensuring only the latest active stream is allowed to emit items.

- Active generator identity verification using isLatestOfType(...) and has(...) in SearchManager to prevent late emissions from stale generators.

- Stream-safe coroutine helpers that fully honor onCancel() and avoid generator.__close__ errors during rapid query changes.

## Fixed

- 🛡️ 1% race condition that allowed a stale item ("my strange addiction") from a previous generator after switching to a new stream (e.g. "Dance Monkey"). This was eliminated by protecting both:

- 🔎 Kotlin: Before delivering items to Flutter (events.success(...))

- 🧠 Python: Before yield within generator, via inspector.is_active(...) guards

- ✂️ Removed useless variables like generatorRegistered = true from Kotlin, which were unused and showing linter warnings.

- 🧹 Prevented cancellation log spam:

- Used searchManager.has(searchId) before calling cancelSearch(...) to avoid:

- 🔄 Fixed Python generators still running yield after close attempt:

- Now intercepted precisely before results are sent in Kotlin and Python.

## Improved

- ✅ Flutter cancellation consistency: Only the latest searchId per stream type (search, related, artist, details) is now allowed to run or emit.

- ⚠ Better log annotations in Kotlin and Python, including:

- PythonEngineInspector: Yield guard check

- YTMusicAPI: Skipping stale result from cancelled stream

- Final StopIteration handling and shutdown trace for debugging

- 🚫 Suppressed Generator does not support __close__ warning by properly handling fallback GeneratorExit in Python

## [3.2.1]

`NOT_WORKING-EOM`

### Added

- Added proper streaminghandlers for (search, related songs, artist songs, song details)
- Added support for Lyrics from YTMUSIC request to `YtFlutterMusicapi.fetchLyrics(songName, AristName)` no time synced only.

## Fixed 

- Multiple generators race conditions now engine checks the generators by ID.

- Error Handling: Improved error reporting in python Engine with logs stating with

- PythonEngine: 
- PythonEngineInspector: 
- PythonEngineExceptionsWarning: 
- PythonEngineExceptionsCritical: 

## [3.1.1]

`Active & Working`

### Fixed

- Added proper python generator results inspector for all stream operations (search, related songs, artist songs, song details)

- Coroutine Management: Fixed the race conditions where the plugin mixes up two song details

- Error Handling: Improved error reporting in python and kotlin side 


## [3.1.0]

`NOT_WORKING-EOM`

### Fixed

- Stream Cancellation: Implemented proper cancellation handling for all stream operations (search, related songs, artist songs, song details)

- Coroutine Management: Added isActive checks before processing each stream item

- Resource Cleanup: Enhanced onCancel methods to properly clean up resources

- Error Handling: Improved error reporting for cancelled operations

- Clean up event sinks properly

## [3.0.0]

`Active & Working`

### Added
- Support of fetching Artist Songs `requires artistName="Obviously"`

- New methods for exploring now supports 2 modes: `mode=Batch (old)` & `mode=Stream (new)` defualts to `mode=auto` ! `required to explore the package`

- Enhanced error recovery for interrupted streams

- Stream cancellation support with proper resource cleanup

### Updated
- Python-Kotlin bridge for efficient generator-based streaming

- Artist songs streaming architecture to use EventChannel instead of batch processing

- Example app with streaming visualization

### Fixed
- Memory management during long streaming sessions

- Thumbnail quality consistency across screens

- Race conditions in concurrent stream operations

- Resource leaks in generator-based implementations

### Performance

- Reduced initial latency from 1200ms to 300ms

- Consistent 50ms intervals between streamed items

- Lower memory footprint during streaming (45% reduction)

- Improved backpressure handling for slow clients

### Breaking Changes

- `(New)streamArtistSongs` now requires explicit cancellation handling

- Generator-based APIs may throw StopIteration exceptions

- Stream order is no longer guaranteed to match original API

### Migration Notes

- Clients should implement proper stream cancellation

- Batch processing now requires explicit collection of stream items of this package!

- Error handling should account for mid-stream failures

## [2.1.5]

`Deprecated — EOS`

### Updated
- Updated `README.md` for the package.

## [2.1.4]

`Deprecated — EOS`

### Added
-Introduced `streamSearchResults` functionality for real-time streaming of search results.
This allows incremental delivery of song metadata instead of waiting for the entire batch, significantly improving responsiveness.

## [1.1.4]

`Deprecated — EOS`

### Fixed
- Resolved issues in the Python mock/testing environment used during development.

## [1.1.3]

`Deprecated — EOS`

### Fixed
- Corrected thumbnail quality mappings in the Python layer.
- `LOW`: w60-h60 (60x60 pixels) 
- `MED`: w120-h120 (120x120 pixels)
- `HIGH`: w320-h320 (320x320 pixels)
- `VERY_HIGH`: w544-h544 (544x544 pixels)

## [1.1.2]

`Deprecated — EOS`

### Fixed
- Addressed a memory overflow issue triggered by `searchMusic` and `getRelatedSongs`.

### Added
- Basic support for retrieving additional songs by an artist and discovering related artists. (Feature is still under development.)


## [1.0.2]

`Deprecated — EOS`

### Fixed
- Corrected a Kotlin syntax error near `line 441` that was preventing builds.

## [1.0.1]

`Deprecated — EOS`

### Added
- Updated outdated documentation link in `pubspec.yaml`.

### Updated
- Updated `yt-dlp` to version `2024.06.30`.
- Updated `ytmusicapi` Python backend to version `1.10.3`.

---

## [1.0.0]

`Deprecated — EOS`

### Added
- Initial stable release.
- YouTube Music search functionality using python's `ytmusicapi` and audio using `yt-dlp`.
- Related songs feature based on current track.
- Support for configurable audio and thumbnail quality.
- Cross-platform structure with Android support.
- Integrated Kotlin-Python bridge using Chaquopy for backend communication.
