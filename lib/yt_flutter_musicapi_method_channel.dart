// lib/yt_flutter_musicapi_platform_interface.dart

import 'package:flutter/services.dart';
import 'yt_flutter_musicapi_platform_interface.dart';

class MethodChannelYtFlutterMusicapi extends YtFlutterMusicapiPlatform {
  final MethodChannel _methodChannel =
      const MethodChannel('yt_flutter_musicapi');
  final EventChannel _searchEventChannel =
      const EventChannel('yt_flutter_musicapi/searchStream');
  final EventChannel _relatedEventChannel =
      const EventChannel('yt_flutter_musicapi/relatedSongsStream');
  final EventChannel _artistEventChannel =
      const EventChannel('yt_flutter_musicapi/artistSongsStream');
  final EventChannel _detailsEventChannel =
      const EventChannel('yt_flutter_musicapi/songDetailsStream');

  @override
  Future<Map<String, dynamic>> initialize({
    String? proxy,
    String country = 'US',
  }) async {
    final result = await _methodChannel.invokeMethod('initialize', {
      'proxy': proxy,
      'country': country,
    });
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> searchMusic({
    required String query,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod('searchMusic', {
        'query': query,
        'limit': limit,
        'thumbQuality': thumbQuality,
        'audioQuality': audioQuality,
        'includeAudioUrl': includeAudioUrl,
        'includeAlbumArt': includeAlbumArt,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      // Convert platform exceptions to error map
      return {
        'success': false,
        'error': e.message,
        'code': e.code,
      };
    }
  }

  @override
  Stream<Map<String, dynamic>> streamSearchResults({
    required String query,
    int limit = 35,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    _methodChannel.invokeMethod('startStreamingSearch', {
      'query': query,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });

    return _searchEventChannel.receiveBroadcastStream({
      'query': query,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    }).map((event) => Map<String, dynamic>.from(event));
  }

  @override
  Future<Map<String, dynamic>> getRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    final result = await _methodChannel.invokeMethod('getRelatedSongs', {
      'songName': songName,
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });
    return Map<String, dynamic>.from(result);
  }

  @override
  Stream<Map<String, dynamic>> streamRelatedSongs({
    required String songName,
    required String artistName,
    int limit = 65,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    _methodChannel.invokeMethod('startStreamingRelated', {
      'songName': songName,
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });

    return _relatedEventChannel.receiveBroadcastStream({
      'songName': songName,
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    }).map((event) => Map<String, dynamic>.from(event));
  }

  @override
  Future<Map<String, dynamic>> getArtistSongs({
    required String artistName,
    int limit = 10,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    final result = await _methodChannel.invokeMethod('getArtistSongs', {
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });
    return Map<String, dynamic>.from(result);
  }

  @override
  Stream<Map<String, dynamic>> streamArtistSongs({
    required String artistName,
    int limit = 45,
    String thumbQuality = 'VERY_HIGH',
    String audioQuality = 'HIGH',
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) {
    _methodChannel.invokeMethod('startStreamingArtist', {
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });

    return _artistEventChannel.receiveBroadcastStream({
      'artistName': artistName,
      'limit': limit,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    }).map((event) => Map<String, dynamic>.from(event));
  }

  @override
  Future<Map<String, dynamic>> getSongDetails({
    required List<Map<String, String>> songs,
    String mode = "batch",
    String thumbQuality = "VERY_HIGH",
    String audioQuality = "HIGH",
    bool includeAudioUrl = true,
    bool includeAlbumArt = true,
  }) async {
    final result = await _methodChannel.invokeMethod('getSongDetails', {
      'songs': songs,
      'mode': mode,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });
    return Map<String, dynamic>.from(result);
  }

  @override
  Stream<Map<String, dynamic>> streamSongDetails({
    required List<Map<String, dynamic>> songs,
    required String thumbQuality,
    required String audioQuality,
    required bool includeAudioUrl,
    required bool includeAlbumArt,
  }) {
    // Invoke the method to start streaming
    _methodChannel.invokeMethod('startStreamingDetails', {
      'songs': songs,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    });

    // Return the event stream
    return _detailsEventChannel.receiveBroadcastStream({
      'songs': songs,
      'thumbQuality': thumbQuality,
      'audioQuality': audioQuality,
      'includeAudioUrl': includeAudioUrl,
      'includeAlbumArt': includeAlbumArt,
    }).map((event) => Map<String, dynamic>.from(event));
  }

  @override
  Future<Map<String, dynamic>> fetchLyrics({
    required String songName,
    required String artistName,
  }) async {
    final result = await _methodChannel.invokeMethod('fetchLyrics', {
      'songName': songName,
      'artistName': artistName,
    });
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> cancelAllSearches() async {
    final result = await _methodChannel.invokeMethod('cancelAllSearches');
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<Map<String, dynamic>> dispose() async {
    final result = await _methodChannel.invokeMethod('dispose');
    return Map<String, dynamic>.from(result);
  }
}
