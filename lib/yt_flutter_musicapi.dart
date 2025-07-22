// lib/yt_flutter_musicapi.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'yt_flutter_musicapi_platform_interface.dart';

/// Enum for Audio Quality
enum AudioQuality {
  low('LOW'),
  med('MED'),
  high('HIGH'),
  veryHigh('VERY_HIGH');

  const AudioQuality(this.value);
  final String value;
}

/// Enum for Thumbnail Quality
enum ThumbnailQuality {
  low('LOW'),
  med('MED'),
  high('HIGH'),
  veryHigh('VERY_HIGH');

  const ThumbnailQuality(this.value);
  final String value;
}

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
  });

  factory ApiResponse.fromMap(Map<String, dynamic> map) {
    return ApiResponse<T>(
      success: map['success'] ?? false,
      message: map['message'],
      data: map['results'] as T?,
    );
  }
}

/// YouTube Music API Response wrapper
class YTMusicResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final String? error;
  final int? count;
  final int? processed;
  final int? errorCount;
  final List<Map<String, dynamic>>? errors;

  YTMusicResponse({
    required this.success,
    this.data,
    this.message,
    this.error,
    this.count,
    this.processed,
    this.errorCount,
    this.errors,
  });

  factory YTMusicResponse.fromMap(Map<String, dynamic> map) {
    // Handle batch mode responses that include processing stats
    if (map.containsKey('processed')) {
      return YTMusicResponse<T>(
        success: map['success'] ?? false,
        data: map['data'] as T?,
        message: map['message'],
        error: map['error'],
        count: map['count'] ??
            (map['data'] is List ? (map['data'] as List).length : null),
        processed: map['processed'],
        errorCount: map['error_count'],
        errors: map['errors'] is List
            ? List<Map<String, dynamic>>.from(map['errors'])
            : null,
      );
    }

    // Standard response handling
    return YTMusicResponse<T>(
      success: map['success'] ?? false,
      data: map['data'] as T?,
      message: map['message'],
      error: map['error'],
      count: map['count'] ??
          (map['data'] is List ? (map['data'] as List).length : null),
    );
  }
}

/// Main YtFlutterMusicapi class that provides access to YouTube Music API
class YtFlutterMusicapi {
  static final YtFlutterMusicapi _instance = YtFlutterMusicapi._internal();
  MethodChannel _channel = MethodChannel('yt_flutter_musicapi');

  static bool _isInitialized = false;
  static String? _lastError;

  // Getters
  static String? get lastError => _lastError;

  factory YtFlutterMusicapi() => _instance;

  YtFlutterMusicapi._internal();

  /// Initializes the YouTube Music API
  Future<YTMusicResponse<void>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    try {
      final result = (await YtFlutterMusicapiPlatform.instance.initialize(
        proxy: proxy,
        country: country,
      ))
          .cast<String, dynamic>();
      _isInitialized = result['success'] ?? false;

      if (!_isInitialized) {
        throw Exception(result['error'] ?? 'Initialization failed');
      }

      return YTMusicResponse<void>(
        success: true,
        message: result['message'],
      );
    } catch (e) {
      return YTMusicResponse<void>(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Searches for music on YouTube Music
  Future<YTMusicResponse<List<SearchResult>>> searchMusic({
    required String query,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    return _executeApiCall<List<SearchResult>>(
      () async {
        try {
          final dynamic result =
              await YtFlutterMusicapiPlatform.instance.searchMusic(
            query: query,
            limit: limit,
            thumbQuality: thumbQuality.value,
            audioQuality: audioQuality.value,
            includeAudioUrl: includeAudioUrl,
            includeAlbumArt: includeAlbumArt,
          );

          debugPrint('Raw search results: ${result.runtimeType}');

          // Handle case where result might be a Map or already a List
          dynamic resultsData;
          if (result is Map<String, dynamic>) {
            resultsData = result['data'] ?? result['results'] ?? [];
          } else if (result is List) {
            resultsData = result;
          } else {
            throw Exception('Unexpected response type: ${result.runtimeType}');
          }

          // Ensure we have a List
          final List<dynamic> resultsList =
              resultsData is List ? resultsData : [resultsData];

          final List<SearchResult> searchResults = [];
          for (final item in resultsList) {
            try {
              if (item is Map) {
                // Convert to Map<String, dynamic> and handle potential nulls
                final itemMap = Map<String, dynamic>.from(item);
                searchResults.add(SearchResult.fromMap(itemMap));
              } else {
                debugPrint('Skipping invalid item (not a Map): $item');
              }
            } catch (e, stackTrace) {
              debugPrint('Error processing item: $e\n$stackTrace\nItem: $item');
            }
          }

          debugPrint(
              'Successfully mapped ${searchResults.length} search results');
          return searchResults;
        } catch (e, stackTrace) {
          debugPrint('Error in searchMusic: $e\n$stackTrace');
          rethrow;
        }
      },
    );
  }

  /// Stream search results as they are found (experimental streaming support)
  Stream<SearchResult> streamSearchResults({
    required String query,
    int limit = 10,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    final stream = YtFlutterMusicapiPlatform.instance.streamSearchResults(
      query: query,
      limit: limit,
      audioQuality: audioQuality.value,
      thumbQuality: thumbQuality.value,
      includeAudioUrl: includeAudioUrl,
      includeAlbumArt: includeAlbumArt,
    );

    return stream.map((item) => SearchResult.fromMap(item));
  }

  /// Gets related songs for a given track
  Future<YTMusicResponse<List<RelatedSong>>> getRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    return _executeApiCall(() async {
      final response = await YtFlutterMusicapiPlatform.instance.getRelatedSongs(
        songName: songName,
        artistName: artistName,
        limit: limit,
        thumbQuality: thumbQuality.value,
        audioQuality: audioQuality.value,
        includeAudioUrl: includeAudioUrl,
        includeAlbumArt: includeAlbumArt,
      );

      final responseMap = Map<String, dynamic>.from(response);
      final dynamic data = responseMap['data'];
      final List<dynamic> resultsList = data is List ? data : [data];

      return resultsList.map((item) {
        return RelatedSong.fromMap(Map<String, dynamic>.from(item));
      }).toList();
    });
  }

  Stream<RelatedSong> streamRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    return YtFlutterMusicapiPlatform.instance
        .streamRelatedSongs(
          songName: songName,
          artistName: artistName,
          limit: limit,
          thumbQuality: thumbQuality.value,
          audioQuality: audioQuality.value,
          includeAudioUrl: includeAudioUrl,
          includeAlbumArt: includeAlbumArt,
        )
        .map((item) => RelatedSong.fromMap(item));
  }

  Future<YTMusicResponse<List<ArtistSong>>> getArtistSongs({
    required String artistName,
    int limit = 25,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.high,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    return _executeApiCall(() async {
      final response = await YtFlutterMusicapiPlatform.instance.getArtistSongs(
        artistName: artistName,
        limit: limit,
        thumbQuality: thumbQuality.value,
        audioQuality: audioQuality.value,
        includeAudioUrl: includeAudioUrl,
        includeAlbumArt: includeAlbumArt,
      );

      final responseMap = Map<String, dynamic>.from(response);
      final dynamic data = responseMap['data'];
      final List<dynamic> items = data is List ? data : [data];

      return items.map((item) {
        return ArtistSong.fromMap({
          ...Map<String, dynamic>.from(item),
          'artistName': artistName,
        });
      }).toList();
    });
  }

  Stream<ArtistSong> streamArtistSongs({
    required String artistName,
    int limit = 25,
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.high,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    return YtFlutterMusicapiPlatform.instance
        .streamArtistSongs(
          artistName: artistName,
          limit: limit,
          thumbQuality: thumbQuality.value,
          audioQuality: audioQuality.value,
          includeAudioUrl: includeAudioUrl,
          includeAlbumArt: includeAlbumArt,
        )
        .map((item) => ArtistSong.fromMap(item));
  }

  /// Gets detailed information for songs in single or batch mode
  Future<YTMusicResponse<dynamic>> getSongDetails({
    required List<Map<String, String>> songs,
    String mode = "batch", // "single" or "batch"
    ThumbnailQuality thumbQuality = ThumbnailQuality.veryHigh,
    AudioQuality audioQuality = AudioQuality.veryHigh,
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    return _executeApiCall<dynamic>(
      () async {
        try {
          // Transform the input songs to match Android parameter names
          final processedSongs = songs.map((song) {
            return {
              'song_name': song['title'] ?? '',
              'artist_name': song['artist'] ?? '',
            };
          }).toList();

          final response = await _channel.invokeMethod('getSongDetails', {
            'songs': processedSongs,
            'mode': mode.toLowerCase(),
            'thumbQuality': thumbQuality.value,
            'audioQuality': audioQuality.value,
            'includeAudioUrl': includeAudioUrl,
            'includeAlbumArt': includeAlbumArt,
          });

          // Convert response to Map if it isn't already
          final Map<String, dynamic> responseMap = response is Map
              ? Map<String, dynamic>.from(response)
              : {'data': response};

          // Check for error response first
          if (responseMap.containsKey('error')) {
            throw PlatformException(
              code: responseMap['errorCode'] ?? 'UNKNOWN_ERROR',
              message: responseMap['error']?.toString(),
              details: responseMap,
            );
          }

          // Handle based on mode
          if (mode.toLowerCase() == "single") {
            // Single mode - expect a single song detail
            final songData = responseMap['data'] is Map
                ? Map<String, dynamic>.from(responseMap['data'])
                : responseMap;

            if (songData.isEmpty) {
              throw Exception('No song data found');
            }

            return SongDetail.fromMap(songData);
          } else {
            // Batch mode - expect a list of results
            dynamic data = responseMap['data'];
            if (data == null) {
              throw Exception('No data received in batch mode');
            }

            // Ensure we have a List
            final List<dynamic> resultsList = data is List ? data : [data];

            final List<SongDetail> songDetails = [];
            final List<Map<String, dynamic>> errors = [];

            for (final item in resultsList) {
              try {
                if (item is Map) {
                  final itemMap = Map<String, dynamic>.from(item);
                  if (itemMap.containsKey('error')) {
                    errors.add({
                      'error': itemMap['error'],
                      'success': false,
                    });
                  } else {
                    songDetails.add(SongDetail.fromMap(itemMap));
                  }
                }
              } catch (e, stackTrace) {
                debugPrint(
                    'Error processing song detail: $e\n$stackTrace\nItem: $item');
                errors.add({
                  'error': e.toString(),
                  'success': false,
                });
              }
            }

            // Return structured batch response
            return {
              'success': true,
              'data': songDetails,
              'errors': errors,
              'count':
                  responseMap['count'] ?? (songDetails.length + errors.length),
              'processed': responseMap['processed'] ?? songDetails.length,
              'error_count': responseMap['errors'] ?? errors.length,
            };
          }
        } catch (e, stackTrace) {
          debugPrint('Error in getSongDetails: $e\n$stackTrace');
          rethrow;
        }
      },
    );
  }

  /// Cleans up resources
  Future<YTMusicResponse<void>> dispose() async {
    try {
      final result = await YtFlutterMusicapiPlatform.instance.dispose();
      _isInitialized = false;
      return YTMusicResponse<void>(
        success: result['success'] ?? false,
        message: result['message'],
        error: result['error'],
      );
    } catch (e) {
      return YTMusicResponse<void>(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<ApiResponse<SystemStatus>> checkStatus() async {
    try {
      final result = await _channel.invokeMethod('checkStatus');

      if (result is Map) {
        final responseMap = Map<String, dynamic>.from(result);

        // Log the response for debugging
        print('Status check response: $responseMap');

        // Create SystemStatus from the response
        final systemStatus = SystemStatus.fromMap(responseMap);

        return ApiResponse<SystemStatus>(
          success: systemStatus.success,
          message: systemStatus.message,
          data: systemStatus,
        );
      } else {
        return ApiResponse<SystemStatus>(
          success: false,
          message:
              'Invalid response type: ${result.runtimeType}. Expected Map but got ${result.toString()}',
        );
      }
    } on PlatformException catch (e) {
      return ApiResponse<SystemStatus>(
        success: false,
        message: 'Platform error: ${e.message}',
      );
    } catch (e) {
      return ApiResponse<SystemStatus>(
        success: false,
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Helper method to execute API calls with common error handling
  Future<YTMusicResponse<T>> _executeApiCall<T>(
      Future<T> Function() call) async {
    if (!_isInitialized) {
      return YTMusicResponse<T>(
        success: false,
        error: 'YTMusic API not initialized. Call initialize() first.',
      );
    }

    try {
      final data = await call();
      return YTMusicResponse<T>(
        success: true,
        data: data,
      );
    } catch (e) {
      return YTMusicResponse<T>(
        success: false,
        error: e.toString(),
      );
    }
  }

  bool get isInitialized => _isInitialized;
}

// 1. SystemStatus model class
class SystemStatus {
  final bool success;
  final String message;
  final bool ytmusicReady;
  final String ytmusicVersion;
  final bool ytdlpReady;
  final String ytdlpVersion;

  SystemStatus({
    required this.success,
    required this.message,
    required this.ytmusicReady,
    required this.ytmusicVersion,
    required this.ytdlpReady,
    required this.ytdlpVersion,
  });

  factory SystemStatus.fromMap(Map<String, dynamic> map) {
    return SystemStatus(
      success: map['success'] ?? false,
      message: map['message'] ?? 'Unknown',
      ytmusicReady: map['ytmusic_ready'] ?? false,
      ytmusicVersion: map['ytmusic_version'] ?? 'Unknown',
      ytdlpReady: map['ytdlp_ready'] ?? false,
      ytdlpVersion: map['ytdlp_version'] ?? 'Unknown',
    );
  }

  bool get isFullyOperational => ytmusicReady && ytdlpReady;

  String get statusSummary {
    if (isFullyOperational) {
      return 'All systems operational';
    } else if (ytmusicReady || ytdlpReady) {
      return 'Partial functionality available';
    } else {
      return 'System offline';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'ytmusic_ready': ytmusicReady,
      'ytmusic_version': ytmusicVersion,
      'ytdlp_ready': ytdlpReady,
      'ytdlp_version': ytdlpVersion,
    };
  }
}

/// Data class for Song Details
/// Data class for Song Details
class SongDetail {
  final String title;
  final String artists;
  final String videoId;
  final String? duration;
  final String? albumArt;
  final String? audioUrl;
  final String? year;
  final String? album;
  final bool? isOriginal;

  SongDetail({
    required this.title,
    required this.artists,
    required this.videoId,
    this.duration,
    this.albumArt,
    this.audioUrl,
    this.year,
    this.album,
    this.isOriginal,
  });

  factory SongDetail.fromMap(Map<String, dynamic> map) {
    return SongDetail(
      title: map['title']?.toString() ?? 'Unknown',
      artists: map['artists']?.toString() ?? 'Unknown',
      videoId: map['videoId']?.toString() ?? '',
      duration: map['duration']?.toString(),
      albumArt: map['albumArt']?.toString(),
      audioUrl: map['audioUrl']?.toString(),
      year: map['year']?.toString(),
      album: map['album']?.toString(),
      isOriginal: map['isOriginal'] is bool
          ? map['isOriginal'] as bool
          : (map['isOriginal']?.toString().toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artists': artists,
      'videoId': videoId,
      'duration': duration,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'year': year,
      'album': album,
      'isOriginal': isOriginal,
    };
  }

  @override
  String toString() {
    return 'SongDetail(title: $title, artists: $artists, videoId: $videoId, duration: $duration, albumArt: $albumArt, audioUrl: $audioUrl, year: $year, album: $album)';
  }
}

/// Data class for Artist Songs
class ArtistSong {
  final String title;
  final String artists;
  final String videoId;
  final String? duration;
  final String? albumArt;
  final String? audioUrl;
  final String artistName;

  ArtistSong({
    required this.title,
    required this.artists,
    required this.videoId,
    this.duration,
    this.albumArt,
    this.audioUrl,
    required this.artistName,
  });

  // Update ArtistSong model
  factory ArtistSong.fromMap(Map<String, dynamic> map) {
    return ArtistSong(
      title: map['title']?.toString() ?? 'Unknown',
      artists: map['artists']?.toString() ?? 'Unknown',
      videoId: map['videoId']?.toString() ?? '',
      duration: map['duration']?.toString(),
      albumArt: map['albumArt']?.toString(),
      audioUrl: map['audioUrl']?.toString(),
      artistName: map['artistName']?.toString() ??
          map['artists']?.toString() ??
          'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artists': artists,
      'videoId': videoId,
      'duration': duration,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'artistName': artistName,
    };
  }

  @override
  String toString() {
    return 'ArtistSong(title: $title, artists: $artists, videoId: $videoId, duration: $duration, albumArt: $albumArt, audioUrl: $audioUrl, artistName: $artistName)';
  }
}

/// Data class for Search Results
class SearchResult {
  final String title;
  final String artists;
  final String videoId;
  final String? duration;
  final String? year;
  final String? albumArt;
  final String? audioUrl;

  SearchResult({
    required this.title,
    required this.artists,
    required this.videoId,
    this.duration,
    this.year,
    this.albumArt,
    this.audioUrl,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      title: map['title'] as String? ?? 'Unknown',
      artists: map['artists'] as String? ?? 'Unknown',
      videoId: map['videoId'] as String? ?? '',
      duration: map['duration'] as String?,
      year: map['year'] as String?,
      albumArt: map['albumArt'] as String?,
      audioUrl: map['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artists': artists,
      'videoId': videoId,
      'duration': duration,
      'year': year,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
    };
  }

  @override
  String toString() {
    return 'SearchResult(title: $title, artists: $artists, videoId: $videoId, duration: $duration, year: $year, albumArt: $albumArt, audioUrl: $audioUrl)';
  }
}

/// Data class for Related Songs
class RelatedSong {
  final String title;
  final String artists;
  final String videoId;
  final String? duration;
  final String? albumArt;
  final String? audioUrl;
  final bool isOriginal;

  RelatedSong({
    required this.title,
    required this.artists,
    required this.videoId,
    this.duration,
    this.albumArt,
    this.audioUrl,
    this.isOriginal = false,
  });

  factory RelatedSong.fromMap(Map<String, dynamic> map) {
    return RelatedSong(
      title: map['title']?.toString() ?? 'Unknown',
      artists: map['artists']?.toString() ?? 'Unknown',
      videoId: map['videoId']?.toString() ?? '',
      duration: map['duration']?.toString(),
      albumArt: map['albumArt']?.toString(),
      audioUrl: map['audioUrl']?.toString(),
      isOriginal: map['isOriginal'] is bool
          ? map['isOriginal'] as bool
          : (map['isOriginal']?.toString().toLowerCase() == 'true'),
    );
  }
}
