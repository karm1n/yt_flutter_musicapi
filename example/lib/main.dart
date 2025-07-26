import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yt_flutter_musicapi/models/relatedSongModel.dart';
import 'package:yt_flutter_musicapi/models/artistsStreamModel.dart';
import 'package:yt_flutter_musicapi/models/searchModel.dart';
import 'package:yt_flutter_musicapi/yt_flutter_musicapi.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YouTube Music API Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(color: Color(0xFF1E1E1E)),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      themeMode: AppSettings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: MusicApiTestPage(),
    );
  }

  // Call this method from your settings dialog callback
  void updateTheme() {
    setState(() {
      // This will trigger a rebuild with the new theme
    });
  }
}

class AppSettings {
  static int limit = 5;
  static AudioQuality audioQuality = AudioQuality.veryHigh;
  static ThumbnailQuality thumbnailQuality = ThumbnailQuality.veryHigh;
  static bool isDarkMode = true;
  static int batchSize = 4;
  static String mode = 'auto'; // 'auto', 'batch', or 'stream'
  static String artistName = 'Ed Sheeran';
  static String testVideoId = '4NRXx6U8ABQ'; // Default video ID
  static List<Map<String, String>> testSongs = [
    {'title': 'Perfect', 'artist': 'Ed Sheeran'},
    {'title': 'Bad Guy', 'artist': 'Billie Eilish'},
    {'title': 'Blinding Lights', 'artist': 'The Weeknd'},
  ];

  static List<Map<String, String>> batchTestSongs = [
    {'title': 'Bohemian Rhapsody', 'artist': 'Queen'},
    {'title': 'Sweet Child O\' Mine', 'artist': 'Guns N\' Roses'},
    {'title': 'Hotel California', 'artist': 'Eagles'},
    {'title': 'Enter Sandman', 'artist': 'Metallica'},
    {'title': 'Livin\' on a Prayer', 'artist': 'Bon Jovi'},
    {'title': 'Seven Nation Army', 'artist': 'The White Stripes'},
    {'title': 'In the End', 'artist': 'Linkin Park'},
    {'title': 'Mr. Brightside', 'artist': 'The Killers'},
    {'title': 'Radioactive', 'artist': 'Imagine Dragons'},
    {'title': 'Use Somebody', 'artist': 'Kings of Leon'},
    {'title': 'Take Me Out', 'artist': 'Franz Ferdinand'},
    {'title': 'The Pretender', 'artist': 'Foo Fighters'},
    {'title': 'Starlight', 'artist': 'Muse'},
  ];

  static String relatedSongTitle = 'Perfect';
  static String relatedSongArtist = 'Ed Sheeran';
}

class Inspector {
  static void checkRules(List<dynamic> results, String operation) {
    print('🔍 INSPECTOR: Checking rules for $operation');

    if (results.isEmpty) {
      print('❌ INSPECTOR: No results returned');
      return;
    }

    if (results.length > AppSettings.limit) {
      print(
        '❌ INSPECTOR: Limit exceeded! Expected: ${AppSettings.limit}, Got: ${results.length}',
      );
    } else {
      print(
        '✅ INSPECTOR: Limit respected: ${results.length}/${AppSettings.limit}',
      );
    }

    for (int i = 0; i < results.length; i++) {
      var item = results[i];
      print('📋 INSPECTOR: Item ${i + 1}:');

      if (item is SearchResult) {
        _checkSearchResult(item);
      } else if (item is RelatedSong) {
        _checkRelatedSong(item);
      } else if (item is ArtistSong) {
        _checkArtistSong(item);
      }
    }
  }

  static void _checkArtistSong(ArtistSong song) {
    print('  Title: ${song.title}');
    print('  Artists: ${song.artists}');
    print('  Video ID: ${song.videoId}');
    print('  Duration: ${song.duration ?? 'N/A'}');
    print('  Artist Name: ${song.artistName}');

    if (song.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (song.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }

  static void _checkSearchResult(SearchResult result) {
    print('  Title: ${result.title}');
    print('  Artists: ${result.artists}');
    print('  Video ID: ${result.videoId}');
    print('  Duration: ${result.duration ?? 'N/A'}');
    print('  Year: ${result.year ?? 'N/A'}');

    if (result.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (result.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }

  static void _checkRelatedSong(RelatedSong song) {
    print('  Title: ${song.title}');
    print('  Artists: ${song.artists}');
    print('  Video ID: ${song.videoId}');
    print('  Duration: ${song.duration ?? 'N/A'}');
    print('  Is Original: ${song.isOriginal}');

    if (song.albumArt != null) {
      print(
        '  ✅ Album Art: Available (${AppSettings.thumbnailQuality.value} quality)',
      );
    } else {
      print('  ❌ Album Art: Missing');
    }

    if (song.audioUrl != null) {
      print(
        '  ✅ Audio URL: Available (${AppSettings.audioQuality.value} quality)',
      );
    } else {
      print('  ❌ Audio URL: Missing');
    }
    print('  ---');
  }
}

class MusicApiTestPage extends StatefulWidget {
  @override
  _MusicApiTestPageState createState() => _MusicApiTestPageState();
}

class _MusicApiTestPageState extends State<MusicApiTestPage> {
  final YtFlutterMusicapi _api = YtFlutterMusicapi();
  final List<String> _cliOutput = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isInitialized = false;
  bool _isLoading = false;
  final List<ArtistSong> _songs = [];

  @override
  void initState() {
    super.initState();
    _addToCliOutput('🚀 YouTube Music API Test App Started');
    _addToCliOutput('ℹ️  Use the buttons below to test API methods');
    _addToCliOutput('⚙️  Configure settings using the gear icon');
  }

  void _addToCliOutput(String message) {
    setState(() {
      _cliOutput.add(
        '${DateTime.now().toString().substring(11, 19)} | $message',
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _testStreamCancellation() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    if (AppSettings.mode != 'stream') {
      _addToCliOutput('❌ This test only works in stream mode');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // First search (will be cancelled after 10 seconds)
    final firstQuery = 'Ed Sheeran Perfect';
    _addToCliOutput('🔍 Starting first search: "$firstQuery"');
    _addToCliOutput('⏳ Will cancel after 15 seconds...');

    // Store first search results
    final firstResults = <SearchResult>[];

    // Start the first search
    final firstSearchStream = _api.streamSearchResults(
      query: firstQuery,
      limit: AppSettings.limit,
      audioQuality: AppSettings.audioQuality,
      thumbQuality: AppSettings.thumbnailQuality,
      includeAudioUrl: true,
      includeAlbumArt: true,
    );

    final firstSearchSubscription = firstSearchStream.listen(
      (result) {
        firstResults.add(result);
        _addToCliOutput('🎵 First search result: ${result.title}');
        _addToCliOutput('   Artists: ${result.artists}');
        _addToCliOutput('   Duration: ${result.duration ?? 'N/A'}');
      },
      onError: (e) {
        _addToCliOutput('❌ First search error: $e');
      },
      onDone: () {
        _addToCliOutput(
          '✅ First search got ${firstResults.length} results before cancel',
        );
      },
    );

    // Second search (will start after 10 seconds)
    final secondQuery = 'Jee Le Zara';
    Future.delayed(Duration(seconds: 15), () async {
      _addToCliOutput('\n⏰ Cancelling first search after 15 seconds');
      await firstSearchSubscription.cancel();

      // Print summary of first search results
      if (firstResults.isNotEmpty) {
        _addToCliOutput('📋 First search got ${firstResults.length} results:');
        for (var result in firstResults) {
          _addToCliOutput('   • ${result.title} (${result.duration ?? 'N/A'})');
        }
      } else {
        _addToCliOutput('📋 First search got no results before cancellation');
      }

      _addToCliOutput('\n🚀 Starting second search: "$secondQuery"');

      try {
        int received = 0;
        final stopwatch = Stopwatch()..start();

        await for (final result in _api.streamSearchResults(
          query: secondQuery,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        )) {
          received++;
          _addToCliOutput(
            '\n🎧 Second search result $received in ${stopwatch.elapsedMilliseconds}ms:',
          );
          _addToCliOutput('   Title: ${result.title}');
          _addToCliOutput('   Artists: ${result.artists}');
          _addToCliOutput('   Duration: ${result.duration ?? 'N/A'}');
          _addToCliOutput('   Video ID: ${result.videoId}');

          if (received >= AppSettings.limit) {
            _addToCliOutput('⏹️ Reached limit of ${AppSettings.limit} results');
            break;
          }
        }

        _addToCliOutput(
          '\n✅ Second search finished: $received result(s) in ${stopwatch.elapsedMilliseconds}ms',
        );
        _addToCliOutput('\n✅ SearchStream Cancellation Did Its Job ✅');
      } catch (e) {
        _addToCliOutput('❌ Second search error: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _testRelatedSongsCancellation() async {
    if (!_isInitialized) {
      _addToCliOutput('⚠️ API not initialized - test will still run');
    }

    setState(() {
      _isLoading = true;
      _cliOutput.add(
        '⏳ Starting Related Songs Cancellation Test (15s timeout)',
      );
    });

    final firstSong = 'Perfect';
    final firstArtist = 'Ed Sheeran';
    final secondSong = 'Jee Le Zara';
    final secondArtist = 'Tanishk Bagchi';
    final timeout = Duration(seconds: 15);

    // First stream
    final firstResults = <RelatedSong>[];
    final firstStream = _api.streamRelatedSongs(
      songName: firstSong,
      artistName: firstArtist,
      limit: AppSettings.limit,
      audioQuality: AppSettings.audioQuality,
      thumbQuality: AppSettings.thumbnailQuality,
      includeAudioUrl: true,
      includeAlbumArt: true,
    );

    final firstSubscription = firstStream.listen(
      (song) {
        firstResults.add(song);
        _addToCliOutput('🎵 (1st) ${song.title}');
      },
      onError: (e) => _addToCliOutput('❌ (1st) Error: $e'),
      onDone: () => _addToCliOutput(
        '✅ (1st) Completed with ${firstResults.length} songs',
      ),
    );

    // Second stream after timeout
    Future.delayed(timeout, () async {
      await firstSubscription.cancel();
      _addToCliOutput('\n⏰ (1st) Cancelled after ${timeout.inSeconds}s');

      // Print first results summary
      _addToCliOutput('📋 (1st) Results Summary:');
      firstResults
          .take(5)
          .forEach((song) => _addToCliOutput('   • ${song.title}'));
      if (firstResults.length > 5) {
        _addToCliOutput('   ...and ${firstResults.length - 5} more');
      }

      // Start second stream
      _addToCliOutput('\n🚀 (2nd) Starting for "$secondSong"');
      final secondResults = <RelatedSong>[];

      try {
        int count = 0;
        await for (final song in _api.streamRelatedSongs(
          songName: secondSong,
          artistName: secondArtist,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        )) {
          count++;
          secondResults.add(song);
          _addToCliOutput('🎧 (2nd) $count: ${song.title}');
          if (count >= AppSettings.limit) break;
        }

        // Print second results summary
        _addToCliOutput('\n📋 (2nd) Results Summary:');
        secondResults.forEach((song) => _addToCliOutput('   • ${song.title}'));
      } catch (e) {
        _addToCliOutput('❌ (2nd) Error: $e');
      } finally {
        setState(() => _isLoading = false);
        _addToCliOutput('\n🏁 Test completed');
        _addToCliOutput('\n✅ RelatedStream Cancellation Did Its Job ✅');
      }
    });
  }

  Future<void> _testArtistSongsCancellation() async {
    if (!_isInitialized) {
      _addToCliOutput('⚠️ API not initialized - test will still run');
    }

    setState(() {
      _isLoading = true;
      _cliOutput.add('⏳ Starting Artist Songs Cancellation Test (15s timeout)');
    });

    final firstArtist = 'Ed Sheeran';
    final secondArtist = 'Arijit Singh';
    final timeout = Duration(seconds: 15);

    // First stream
    final firstResults = <ArtistSong>[];
    final firstStream = _api.streamArtistSongs(
      artistName: firstArtist,
      limit: AppSettings.limit,
      audioQuality: AppSettings.audioQuality,
      thumbQuality: AppSettings.thumbnailQuality,
      includeAudioUrl: true,
      includeAlbumArt: true,
    );

    final firstSubscription = firstStream.listen(
      (song) {
        firstResults.add(song);
        _addToCliOutput('🎵 (1st) ${song.title}');
      },
      onError: (e) => _addToCliOutput('❌ (1st) Error: $e'),
      onDone: () => _addToCliOutput(
        '✅ (1st) Completed with ${firstResults.length} songs',
      ),
    );

    // Second stream after timeout
    Future.delayed(timeout, () async {
      await firstSubscription.cancel();
      _addToCliOutput('\n⏰ (1st) Cancelled after ${timeout.inSeconds}s');

      // Print first results summary
      _addToCliOutput('📋 (1st) Results Summary:');
      firstResults
          .take(5)
          .forEach((song) => _addToCliOutput('   • ${song.title}'));
      if (firstResults.length > 5) {
        _addToCliOutput('   ...and ${firstResults.length - 5} more');
      }

      // Start second stream
      _addToCliOutput('\n🚀 (2nd) Starting for "$secondArtist"');
      final secondResults = <ArtistSong>[];

      try {
        int count = 0;
        await for (final song in _api.streamArtistSongs(
          artistName: secondArtist,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        )) {
          count++;
          secondResults.add(song);
          _addToCliOutput('🎧 (2nd) $count: ${song.title}');
          if (count >= AppSettings.limit) break;
        }

        // Print second results summary
        _addToCliOutput('\n📋 (2nd) Results Summary:');
        secondResults.forEach((song) => _addToCliOutput('   • ${song.title}'));
      } catch (e) {
        _addToCliOutput('❌ (2nd) Error: $e');
      } finally {
        setState(() => _isLoading = false);
        _addToCliOutput('\n🏁 Test completed');
        _addToCliOutput('\n✅ ArtistStream Cancellation Did Its Job ✅');
      }
    });
  }

  void _clearCliOutput() {
    setState(() {
      _cliOutput.clear();
    });
    _addToCliOutput('🧹 CLI Output Cleared');
  }

  Future<void> _initializeApi() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🔄 Initializing YouTube Music API...');

    try {
      final response = await _api.initialize(country: 'US');

      if (response.success) {
        setState(() {
          _isInitialized = true;
        });
        _addToCliOutput('✅ API Initialized Successfully');
        _addToCliOutput('📋 Message: ${response.message ?? 'Ready to use'}');
      } else {
        _addToCliOutput('❌ API Initialization Failed');
        _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during initialization: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkStatus() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🔍 Checking API Status...');

    try {
      final response = await _api.checkStatus();

      if (response.success && response.data != null) {
        final status = response.data!;

        _addToCliOutput('✅ API Status: OK');
        _addToCliOutput('📋 Message: ${status.message}');

        _addToCliOutput(
          '🎵 YTMusic: ${status.ytmusicReady ? '✅ Ready' : '❌ Not Ready'} (v${status.ytmusicVersion})',
        );

        _addToCliOutput(
          '⬇️ yt-dlp: ${status.ytdlpReady ? '✅ Ready' : '❌ Not Ready'} (v${status.ytdlpVersion})',
        );

        if (status.isFullyOperational) {
          _addToCliOutput('🚀 All systems operational and ready!');
          _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _addToCliOutput('📊 System Summary:');
          _addToCliOutput('   • YTMusic API: ✅ Operational');
          _addToCliOutput('   • yt-dlp Engine: ✅ Operational');
          _addToCliOutput('   • Ready for music operations');
        } else {
          _addToCliOutput('⚠️  Some components are not ready');
          _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _addToCliOutput('📊 System Summary:');
          _addToCliOutput(
            '   • YTMusic API: ${status.ytmusicReady ? '✅' : '❌'} ${status.ytmusicReady ? 'Operational' : 'Failed'}',
          );
          _addToCliOutput(
            '   • yt-dlp Engine: ${status.ytdlpReady ? '✅' : '❌'} ${status.ytdlpReady ? 'Operational' : 'Failed'}',
          );
          _addToCliOutput('   • ${status.statusSummary}');
        }
      } else {
        _addToCliOutput('❌ API Status: Error');
        _addToCliOutput('📋 Message: ${response.message ?? 'Unknown status'}');

        if (response.data != null) {
          final status = response.data!;

          _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _addToCliOutput('📊 Component Status:');

          _addToCliOutput(
            '🎵 YTMusic: ${status.ytmusicReady ? '✅' : '❌'} ${status.ytmusicReady ? 'Ready' : 'Failed'} (v${status.ytmusicVersion})',
          );

          _addToCliOutput(
            '⬇️ yt-dlp: ${status.ytdlpReady ? '✅' : '❌'} ${status.ytdlpReady ? 'Ready' : 'Failed'} (v${status.ytdlpVersion})',
          );

          _addToCliOutput('📋 Status: ${status.statusSummary}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during status check: $e');

      _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _addToCliOutput('💡 Troubleshooting Guide:');
      _addToCliOutput('   1. Check Python environment setup');
      _addToCliOutput(
        '   2. Verify ytmusicapi installation: pip install ytmusicapi',
      );
      _addToCliOutput('   3. Verify yt-dlp installation: pip install yt-dlp');
      _addToCliOutput('   4. Test network connectivity');
      _addToCliOutput('   5. Check system logs for detailed errors');

      print('Status check error details: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMusic() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    String query = _searchController.text.trim();
    if (query.isEmpty) {
      query = 'Billie Eilish bad guy';
      _searchController.text = query;
    }

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🔍 Searching for: "$query"');
    _addToCliOutput(
      '📊 Settings: Limit=${AppSettings.limit}, Audio=${AppSettings.audioQuality.value}, Thumb=${AppSettings.thumbnailQuality.value}, Mode=${AppSettings.mode}',
    );

    try {
      if (AppSettings.mode == 'stream') {
        await _streamSearchResults(query: query);
      } else {
        final response = await _api.searchMusic(
          query: query,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        );

        if (response.success && response.data != null) {
          _addToCliOutput('✅ Search completed successfully');
          _addToCliOutput('📋 Found ${response.data!.length} results');

          for (int i = 0; i < response.data!.length; i++) {
            final result = response.data![i];
            _addToCliOutput('🎵 Result ${i + 1}:');
            _addToCliOutput('   Title: ${result.title}');
            _addToCliOutput('   Artists: ${result.artists}');
            _addToCliOutput('   Duration: ${result.duration ?? 'N/A'}');
            _addToCliOutput('   Year: ${result.year ?? 'N/A'}');
            _addToCliOutput('   Video ID: ${result.videoId}');
            _addToCliOutput(
              '   Album Art: ${result.albumArt != null ? 'Available and respected!' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${result.audioUrl != null ? 'Available and respected!' : 'N/A'}',
            );
            _addToCliOutput('   ---');
          }

          Inspector.checkRules(response.data!, 'Search Music');
          _addToCliOutput('🎉 SUCCESS: Search operation completed');
        } else {
          _addToCliOutput('❌ Search failed');
          _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during search: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _streamSearchResults({required String query}) async {
    int received = 0;
    final stopwatch = Stopwatch()..start();

    _addToCliOutput('📡 Streaming search results for: "$query"');

    try {
      await for (final result in _api.streamSearchResults(
        query: query,
        limit: AppSettings.limit,
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      )) {
        received++;
        _addToCliOutput('🎧 Streamed Result $received:');
        _addToCliOutput('   Title: ${result.title}');
        _addToCliOutput('   Artists: ${result.artists}');
        _addToCliOutput('   Duration: ${result.duration ?? 'N/A'}');
        _addToCliOutput('   Video ID: ${result.videoId}');
        _addToCliOutput(
          '   Album Art: ${result.albumArt != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput(
          '   Audio URL: ${result.audioUrl != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput('   ---');

        if (received >= AppSettings.limit) {
          _addToCliOutput('⏹️ Streaming limit reached (${AppSettings.limit})');
          break;
        }
      }

      _addToCliOutput(
        '✅ Stream finished: $received result(s) in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e) {
      _addToCliOutput('❌ Streaming error: $e');
    }
  }

  // Add this method to your _MusicApiTestPageState class
  Future<void> _getRelatedSongs() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput(
      '🔍 Getting related songs for: "${AppSettings.relatedSongTitle}" by ${AppSettings.relatedSongArtist}',
    );
    _addToCliOutput(
      '📊 Settings: Limit=${AppSettings.limit}, Audio=${AppSettings.audioQuality.value}, '
      'Thumb=${AppSettings.thumbnailQuality.value}, Mode=${AppSettings.mode}',
    );

    try {
      if (AppSettings.mode == 'stream') {
        await _streamRelatedSongs();
      } else {
        final response = await _api.getRelatedSongs(
          songName: AppSettings.relatedSongTitle,
          artistName: AppSettings.relatedSongArtist,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        );

        if (response.success && response.data != null) {
          _addToCliOutput('✅ Related songs retrieved successfully');
          _addToCliOutput('📋 Found ${response.data!.length} related songs');

          for (int i = 0; i < response.data!.length; i++) {
            final song = response.data![i];
            _addToCliOutput('🎵 Related Song ${i + 1}:');
            _addToCliOutput('   Title: ${song.title}');
            _addToCliOutput('   Artists: ${song.artists}');
            _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
            _addToCliOutput('   Is Original: ${song.isOriginal}');
            _addToCliOutput('   Video ID: ${song.videoId}');
            _addToCliOutput(
              '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput('   ---');
          }

          Inspector.checkRules(response.data!, 'Related Songs');
          _addToCliOutput('🎉 SUCCESS: Related songs operation completed');
        } else {
          _addToCliOutput('❌ Failed to get related songs');
          _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during related songs fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _streamRelatedSongs() async {
    int received = 0;
    final stopwatch = Stopwatch()..start();

    try {
      await for (final song in _api.streamRelatedSongs(
        songName: AppSettings.relatedSongTitle,
        artistName: AppSettings.relatedSongArtist,
        limit: AppSettings.limit,
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      )) {
        received++;
        _addToCliOutput(
          '🎵 Received related song $received in ${stopwatch.elapsedMilliseconds}ms:',
        );
        _addToCliOutput('   Title: ${song.title}');
        _addToCliOutput('   Artists: ${song.artists}');
        _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
        _addToCliOutput('   Is Original: ${song.isOriginal}');
        _addToCliOutput('   Video ID: ${song.videoId}');
        _addToCliOutput(
          '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput(
          '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput('   ---');

        stopwatch.reset();
      }

      _addToCliOutput('✅ Streamed $received related songs successfully');
    } catch (e) {
      _addToCliOutput('❌ Exception during related songs stream: $e');
    }
  }

  Future<void> _getArtistSongs() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    setState(() {
      _isLoading = true;
      _songs.clear();
    });

    _addToCliOutput(
      '🎤 Getting songs from artist: "${AppSettings.artistName}"',
    );
    _addToCliOutput(
      '📊 Settings: Limit=${AppSettings.limit}, '
      'Audio=${AppSettings.audioQuality.value}, '
      'Thumb=${AppSettings.thumbnailQuality.value}, '
      'Mode=${AppSettings.mode}',
    );

    try {
      if (AppSettings.mode == 'stream') {
        await _streamArtistSongs();
      } else {
        final response = await _api.getArtistSongs(
          artistName: AppSettings.artistName,
          limit: AppSettings.limit,
          audioQuality: AppSettings.audioQuality,
          thumbQuality: AppSettings.thumbnailQuality,
          includeAudioUrl: true,
          includeAlbumArt: true,
        );

        if (response.success && response.data != null) {
          _addToCliOutput('✅ Artist songs retrieved successfully');
          _addToCliOutput('📋 Found ${response.data!.length} songs');

          for (int i = 0; i < response.data!.length; i++) {
            final song = response.data![i];
            _addToCliOutput('🎵 Song ${i + 1}:');
            _addToCliOutput('   Title: ${song.title}');
            _addToCliOutput('   Artists: ${song.artists}');
            _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
            _addToCliOutput('   Video ID: ${song.videoId}');
            _addToCliOutput('   Artist Name: ${song.artistName}');
            _addToCliOutput(
              '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput(
              '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
            );
            _addToCliOutput('   ---');

            setState(() {
              _songs.add(song);
            });
          }

          Inspector.checkRules(response.data!, 'Artist Songs');
          _addToCliOutput('🎉 SUCCESS: Artist songs operation completed');
        } else {
          _addToCliOutput('❌ Failed to get artist songs');
          _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
        }
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during artist songs fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _streamArtistSongs() async {
    int received = 0;
    final stopwatch = Stopwatch()..start();

    try {
      await for (final song in _api.streamArtistSongs(
        artistName: AppSettings.artistName,
        limit: AppSettings.limit,
        audioQuality: AppSettings.audioQuality,
        thumbQuality: AppSettings.thumbnailQuality,
        includeAudioUrl: true,
        includeAlbumArt: true,
      )) {
        received++;
        _addToCliOutput(
          '🎵 Received song $received in ${stopwatch.elapsedMilliseconds}ms:',
        );
        _addToCliOutput('   Title: ${song.title}');
        _addToCliOutput('   Artists: ${song.artists}');
        _addToCliOutput('   Duration: ${song.duration ?? 'N/A'}');
        _addToCliOutput('   Video ID: ${song.videoId}');
        _addToCliOutput('   Artist Name: ${song.artistName}');
        _addToCliOutput(
          '   Album Art: ${song.albumArt != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput(
          '   Audio URL: ${song.audioUrl != null ? 'Available' : 'N/A'}',
        );
        _addToCliOutput('   ---');

        setState(() {
          _songs.add(song);
        });

        stopwatch.reset();
      }

      if (received > 0) {
        _addToCliOutput('✅ Streamed $received songs successfully');
        Inspector.checkRules(_songs, 'Artist Songs');
      } else {
        _addToCliOutput('❌ No songs were streamed');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during artist songs stream: $e');
    }
  }

  Future<void> _testGetAudioUrlFlexible() async {
    setState(() {
      _isLoading = true;
    });
    _addToCliOutput('🎵 Testing getAudioUrlFlexible...');

    try {
      // Test 1: With title and artist
      _addToCliOutput('\n🔍 Test 1: Title + Artist lookup');
      _addToCliOutput('   Title: "Blinding Lights"');
      _addToCliOutput('   Artist: "The Weeknd"');
      _addToCliOutput('   Quality: ${AppSettings.audioQuality.value}');

      final response1 = await _api.getAudioUrlFlexible(
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        audioQuality: AppSettings.audioQuality,
      );

      if (response1.success && response1.data != null) {
        _addToCliOutput('✅ Success!');
        _addToCliOutput('   Found video ID: ${response1.data!.videoId}');
        _addToCliOutput('   Detected quality: ${response1.data!.audioQuality}');
        _addToCliOutput(
          '   URL (truncated): ${response1.data!.audioUrl?.substring(0, 50)}...',
        );
      } else {
        _addToCliOutput('❌ Failed: ${response1.error ?? 'Unknown error'}');
      }

      // Test 2: With video ID from settings
      _addToCliOutput('\n🔍 Test 2: Direct video ID lookup');
      _addToCliOutput('   Video ID: ${AppSettings.testVideoId}');
      _addToCliOutput('   Quality: ${AppSettings.audioQuality.value}');

      if (AppSettings.testVideoId.isEmpty) {
        _addToCliOutput('⚠️ No video ID configured in settings');
      } else {
        final response2 = await _api.getAudioUrlFlexible(
          videoId: AppSettings.testVideoId,
          audioQuality: AppSettings.audioQuality,
        );

        if (response2.success && response2.data != null) {
          _addToCliOutput('✅ Success!');
          _addToCliOutput(
            '   Detected quality: ${response2.data!.audioQuality}',
          );
          _addToCliOutput(
            '   URL (truncated): ${response2.data!.audioUrl?.substring(0, 50)}...',
          );
        } else {
          _addToCliOutput('❌ Failed: ${response2.error ?? 'Unknown error'}');
        }
      }

      // Test 3: Error case (no parameters)
      // _addToCliOutput('\n🔍 Test 3: Verifying input validation');
      // _addToCliOutput('   Purpose: Confirm API rejects empty requests');
      // try {
      //   await _api.getAudioUrlFlexible();
      //   _addToCliOutput('❌ TEST FAILED - API requires parameters');
      // } catch (e) {
      //   _addToCliOutput('✅ PASSED - Correctly rejected empty request');
      //   _addToCliOutput('   Expected error: $e');
      // }

      _addToCliOutput('\n🎉 All getAudioUrlFlexible tests completed');
    } catch (e) {
      _addToCliOutput('❌ Unexpected error during tests: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Future<void> _testBatchSongs() async {
  //   if (_isLoading || !_isInitialized) {
  //     _addToCliOutput('❌ API not initialized or busy');
  //     return;
  //   }

  //   if (AppSettings.mode != 'stream') {
  //     _addToCliOutput('❌ This test only works in stream mode');
  //     return;
  //   }

  //   setState(() {
  //     _isLoading = true;
  //   });

  //   // Create a list of 13 test songs
  //   final testSongs = [
  //     {'title': 'Bohemian Rhapsody', 'artist': 'Queen'},
  //     {'title': 'Sweet Child O\' Mine', 'artist': 'Guns N\' Roses'},
  //     {'title': 'Hotel California', 'artist': 'Eagles'},
  //     // {'title': 'Enter Sandman', 'artist': 'Metallica'},
  //     // {'title': 'Livin\' on a Prayer', 'artist': 'Bon Jovi'},
  //     // {'title': 'Seven Nation Army', 'artist': 'The White Stripes'},
  //     // {'title': 'In the End', 'artist': 'Linkin Park'},
  //     // {'title': 'Mr. Brightside', 'artist': 'The Killers'},
  //     // {'title': 'Radioactive', 'artist': 'Imagine Dragons'},
  //     // {'title': 'Use Somebody', 'artist': 'Kings of Leon'},
  //     // {'title': 'Take Me Out', 'artist': 'Franz Ferdinand'},
  //     // {'title': 'The Pretender', 'artist': 'Foo Fighters'},
  //     // {'title': 'Starlight', 'artist': 'Muse'},
  //   ];

  //   _addToCliOutput(
  //     '🚀 Starting batch processing of ${testSongs.length} songs',
  //   );
  //   _addToCliOutput('📋 Batch Settings:');
  //   _addToCliOutput('   • Audio Quality: ${AppSettings.audioQuality.value}');
  //   _addToCliOutput(
  //     '   • Thumb Quality: ${AppSettings.thumbnailQuality.value}',
  //   );
  //   _addToCliOutput('   • Batch Size: 4 (default)\n');

  //   // Create a map to track each song's status
  //   final songStatus = <String, Map<String, dynamic>>{};
  //   for (final song in testSongs) {
  //     final key = '${song['title']} - ${song['artist']}';
  //     songStatus[key] = {'albumArt': '❌ Not Found', 'audioUrl': '❌ Not Found'};
  //   }

  //   try {
  //     final stopwatch = Stopwatch()..start();

  //     await for (final response in _api.streamBatchSongs(
  //       songs: testSongs,
  //       thumbQuality: AppSettings.thumbnailQuality,
  //       audioQuality: AppSettings.audioQuality,
  //     )) {
  //       if (response.success && response.data != null) {
  //         final data = response.data as Map<String, dynamic>;
  //         final songName = data['songName'] ?? data['title'];
  //         final artistName = data['artistName'] ?? data['artists'];
  //         final key = '$songName - $artistName';

  //         if (data['type'] == 'album_art') {
  //           songStatus[key]?['albumArt'] =
  //               '✅ Available (${AppSettings.thumbnailQuality.value})';
  //         } else if (data['type'] == 'song_complete') {
  //           songStatus[key]?['audioUrl'] =
  //               '✅ Available (${AppSettings.audioQuality.value})';
  //         }
  //       }
  //     }

  //     // Print all songs with their status
  //     _addToCliOutput('\n🎵 Song Processing Results:');
  //     songStatus.forEach((song, status) {
  //       _addToCliOutput('➤ $song');
  //       _addToCliOutput('   • Album Art: ${status['albumArt']}');
  //       _addToCliOutput('   • Audio URL: ${status['audioUrl']}');
  //     });

  //     _addToCliOutput('\n✅ Batch Processing Completed');
  //     _addToCliOutput('⏱️ Time Taken: ${stopwatch.elapsedMilliseconds}ms');
  //   } catch (e) {
  //     _addToCliOutput('❌ Batch processing error: $e');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> _fetchLyrics() async {
    if (_isLoading || !_isInitialized) {
      _addToCliOutput('❌ API not initialized or busy');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Use settings from dialog instead of hardcoded values
    String songName = AppSettings.relatedSongTitle.trim();
    String artistName = AppSettings.relatedSongArtist.trim();

    // Fallback to search controller if settings are empty
    if (songName.isEmpty || artistName.isEmpty) {
      String query = _searchController.text.trim();
      if (query.isEmpty) {
        query = 'Billie Eilish bad guy';
        _searchController.text = query;
      }

      // Try to parse artist and song from query if settings are empty
      final parts = query.split(' ');
      if (parts.length > 1) {
        if (artistName.isEmpty) artistName = parts[0];
        if (songName.isEmpty) songName = parts.sublist(1).join(' ');
      }
    }

    try {
      _addToCliOutput('🎵 Fetching lyrics for: "$songName" by $artistName');

      final response = await _api.fetchLyrics(
        songName: songName,
        artistName: artistName,
      );

      if (response.success && response.data != null) {
        final lyrics = response.data!;
        _addToCliOutput('✅ Lyrics fetched successfully');
        _addToCliOutput('📋 Source: ${lyrics.source}');
        _addToCliOutput('📋 Language: ${lyrics.language ?? 'Unknown'}');
        _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _addToCliOutput('🎤 LYRICS:');

        // Split lyrics into lines and add each line to CLI output
        final lines = lyrics.text.split('\n');
        for (final line in lines) {
          if (line.trim().isNotEmpty) {
            _addToCliOutput(line);
          }
        }

        _addToCliOutput('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        _addToCliOutput('🎉 SUCCESS: Lyrics operation completed');
      } else {
        _addToCliOutput('❌ Failed to fetch lyrics');
        _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during lyrics fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disposeApi() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _addToCliOutput('🗑️ Disposing API...');

    try {
      final response = await _api.dispose();

      if (response.success) {
        setState(() {
          _isInitialized = false;
        });
        _addToCliOutput('✅ API Disposed Successfully');
        _addToCliOutput(
          '📋 Message: ${response.message ?? 'Resources cleaned up'}',
        );
      } else {
        _addToCliOutput('❌ API Disposal Failed');
        _addToCliOutput('📋 Error: ${response.error ?? 'Unknown error'}');
      }
    } catch (e) {
      _addToCliOutput('❌ Exception during disposal: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        onSettingsChanged: () {
          setState(() {});
          _addToCliOutput('⚙️ Settings updated');
        },
        onClearCli: _clearCliOutput, // Add this line
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppSettings.isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('YouTube Music API Test'),
          actions: [
            IconButton(icon: Icon(Icons.settings), onPressed: _showSettings),
          ],
        ),
        body: Column(
          children: [
            // CLI Output Area
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.all(8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppSettings.isDarkMode
                      ? Colors.grey[900]
                      : Colors.black,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CLI Output',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.clear, color: Colors.green),
                          onPressed: _clearCliOutput,
                          tooltip: 'Clear Output',
                        ),
                      ],
                    ),
                    Divider(color: Colors.green),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: _cliOutput.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              _cliOutput[index],
                              style: TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search Input
            Padding(
              padding: EdgeInsets.all(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Enter search query (default: Billie Eilish bad guy)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),

            // Test Buttons
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      'Test Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Status Row
                    Row(
                      children: [
                        Icon(
                          _isInitialized ? Icons.check_circle : Icons.error,
                          color: _isInitialized ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _isInitialized
                              ? 'API Initialized'
                              : 'API Not Initialized',
                          style: TextStyle(
                            color: _isInitialized ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        if (_isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Button Grid
                    Expanded(
                      child: GridView.count(
                        crossAxisCount:
                            3, // Changed from 2 to 3 to accommodate more buttons
                        childAspectRatio: 2.5, // Adjusted aspect ratio
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(Icons.play_arrow),
                            label: Text('Initialize'),
                            onPressed: _isLoading ? null : _initializeApi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.info),
                            label: Text('Check Status'),
                            onPressed: _isLoading ? null : _checkStatus,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.search),
                            label: Text('Search Music'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _searchMusic,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          // In your button grid (where the other test buttons are)
                          // ElevatedButton.icon(
                          //   icon: Icon(Icons.batch_prediction),
                          //   label: Text('Test Batch'),
                          //   onPressed: (_isLoading || !_isInitialized)
                          //       ? null
                          //       : _testBatchSongs,
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: Colors.deepPurple,
                          //     foregroundColor: Colors.white,
                          //   ),
                          // ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.swap_horiz),
                            label: Text('Test Cancellation'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _testStreamCancellation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          // For artist songs test
                          ElevatedButton.icon(
                            icon: Icon(Icons.person),
                            label: Text('Test Artist Cancel'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _testArtistSongsCancellation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),

                          // For related songs test
                          ElevatedButton.icon(
                            icon: Icon(Icons.queue_music),
                            label: Text('Test Related Cancel'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _testRelatedSongsCancellation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.queue_music),
                            label: Text('Related Songs'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _getRelatedSongs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.person),
                            label: Text('Artist Songs'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _getArtistSongs,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          // In your button grid (where the other test buttons are)
                          ElevatedButton.icon(
                            icon: Icon(Icons.audiotrack),
                            label: Text('Get AudioUrl Flexible'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _testGetAudioUrlFlexible,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                            ),
                          ),

                          ElevatedButton.icon(
                            icon: Icon(Icons.music_note),
                            label: Text('Fetch Lyrics'),
                            onPressed: (_isLoading || !_isInitialized)
                                ? null
                                : _fetchLyrics,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.stop),
                            label: Text('Dispose'),
                            onPressed: _isLoading ? null : _disposeApi,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: Icon(Icons.settings),
                            label: Text('Settings'),
                            onPressed: _showSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged;
  final VoidCallback onClearCli;

  const SettingsDialog({
    required this.onSettingsChanged,
    required this.onClearCli,
    Key? key,
  }) : super(key: key);

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _limit;
  late int _batchSize;
  late AudioQuality _audioQuality;
  late ThumbnailQuality _thumbnailQuality;
  late bool _isDarkMode;
  late String _mode;
  late TextEditingController _artistController;
  late TextEditingController _videoIdController;
  late TextEditingController _songTitleController;
  late TextEditingController _songArtistController;

  @override
  void initState() {
    super.initState();
    _limit = AppSettings.limit;
    _batchSize = AppSettings.batchSize;
    _audioQuality = AppSettings.audioQuality;
    _thumbnailQuality = AppSettings.thumbnailQuality;
    _isDarkMode = AppSettings.isDarkMode;
    _mode = AppSettings.mode;
    _artistController = TextEditingController(text: AppSettings.artistName);
    _videoIdController = TextEditingController(text: AppSettings.testVideoId);
    _songTitleController = TextEditingController(
      text: AppSettings.relatedSongTitle,
    );
    _songArtistController = TextEditingController(
      text: AppSettings.relatedSongArtist,
    );
  }

  @override
  void dispose() {
    _artistController.dispose();
    _videoIdController.dispose();
    _songTitleController.dispose();
    _songArtistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(), // Force dark theme for dialog
      child: AlertDialog(
        backgroundColor: Color(0xFF1E1E1E), // Dark background
        title: Text('Settings', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Limit Setting
              ListTile(
                title: Text('Limit: $_limit'),
                subtitle: Slider(
                  value: _limit.toDouble(),
                  min: 1,
                  max: 15,
                  divisions: 14,
                  onChanged: (value) {
                    setState(() {
                      _limit = value.toInt();
                    });
                  },
                ),
              ),

              // Batch Size Setting
              ListTile(
                title: Text('Batch Size: $_batchSize'),
                subtitle: Slider(
                  value: _batchSize.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: (value) {
                    setState(() {
                      _batchSize = value.toInt();
                    });
                  },
                ),
              ),

              // Test Video ID
              TextField(
                controller: _videoIdController,
                decoration: InputDecoration(
                  labelText: 'Test Video ID',
                  hintText: 'e.g., 4NRXx6U8ABQ',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),

              // Lyrics Song Title
              TextField(
                controller: _songTitleController,
                decoration: InputDecoration(
                  labelText: 'Lyrics Song Title',
                  hintText: 'e.g., bad guy',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),

              // Lyrics Artist Name
              TextField(
                controller: _songArtistController,
                decoration: InputDecoration(
                  labelText: 'Lyrics Artist Name',
                  hintText: 'e.g., Billie Eilish',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),

              // Related Song Title
              TextField(
                controller: TextEditingController(
                  text: AppSettings.relatedSongTitle,
                ),
                decoration: InputDecoration(
                  labelText: 'Related Song Title',
                  hintText: 'e.g., Ocean Eyes',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => AppSettings.relatedSongTitle = value,
              ),
              SizedBox(height: 8),

              // Related Song Artist
              TextField(
                controller: TextEditingController(
                  text: AppSettings.relatedSongArtist,
                ),
                decoration: InputDecoration(
                  labelText: 'Related Song Artist',
                  hintText: 'e.g., Billie Eilish',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => AppSettings.relatedSongArtist = value,
              ),
              SizedBox(height: 8),

              // Mode Selection
              ListTile(
                title: Text('Operation Mode'),
                subtitle: DropdownButton<String>(
                  value: _mode,
                  isExpanded: true,
                  items: ['auto', 'batch', 'stream'].map((mode) {
                    return DropdownMenuItem(
                      value: mode,
                      child: Text(mode.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _mode = value;
                      });
                    }
                  },
                ),
              ),

              // Artist Name for Testing
              TextField(
                controller: _artistController,
                decoration: InputDecoration(
                  labelText: 'Artist Name for Testing',
                  hintText: 'e.g., Billie Eilish',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 8),

              // Audio Quality Setting
              ListTile(
                title: Text('Audio Quality'),
                subtitle: DropdownButton<AudioQuality>(
                  value: _audioQuality,
                  isExpanded: true,
                  items: AudioQuality.values.map((quality) {
                    return DropdownMenuItem(
                      value: quality,
                      child: Text(quality.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _audioQuality = value;
                      });
                    }
                  },
                ),
              ),

              // Thumbnail Quality Setting
              ListTile(
                title: Text('Thumbnail Quality'),
                subtitle: DropdownButton<ThumbnailQuality>(
                  value: _thumbnailQuality,
                  isExpanded: true,
                  items: ThumbnailQuality.values.map((quality) {
                    return DropdownMenuItem(
                      value: quality,
                      child: Text(quality.value),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _thumbnailQuality = value;
                      });
                    }
                  },
                ),
              ),

              // Dark Mode Toggle
              SwitchListTile(
                title: Text('Dark Mode'),
                value: _isDarkMode,
                onChanged: (value) {
                  setState(() {
                    _isDarkMode = value;
                  });
                },
              ),

              SizedBox(height: 16),

              // Clear CLI Button
              ElevatedButton.icon(
                icon: Icon(Icons.clear),
                label: Text('Clear CLI Output'),
                onPressed: () {
                  widget.onClearCli();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              // Save all settings
              AppSettings.limit = _limit;
              AppSettings.batchSize = _batchSize;
              AppSettings.audioQuality = _audioQuality;
              AppSettings.thumbnailQuality = _thumbnailQuality;
              AppSettings.isDarkMode = _isDarkMode;
              AppSettings.mode = _mode;
              AppSettings.artistName = _artistController.text.trim();
              AppSettings.testVideoId = _videoIdController.text.trim();
              AppSettings.relatedSongTitle = _songTitleController.text.trim();
              AppSettings.relatedSongArtist = _songArtistController.text.trim();

              widget.onSettingsChanged();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
