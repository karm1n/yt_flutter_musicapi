
package com.golanpiyush.yt_flutter_musicapi

import io.flutter.plugin.common.EventChannel
import com.chaquo.python.PyObject
import kotlinx.coroutines.*
import android.util.Log
import com.golanpiyush.yt_flutter_musicapi.SearchManager
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.ExecutorService
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@OptIn(ExperimentalCoroutinesApi::class)
class SearchStreamHandler(private val plugin: YtFlutterMusicapiPlugin) : EventChannel.StreamHandler {
    companion object {
        const val SEARCH_TYPE = YtFlutterMusicapiPlugin.SEARCH_TYPE_SEARCH
    }
    
    private var eventSink: EventChannel.EventSink? = null
    private var searchId: String? = null
    private var job: Job? = null
    private var pythonExecutor: ExecutorService? = null
    private val executorLock = Object()
    
    private fun getOrCreateExecutor(): ExecutorService {
        return synchronized(executorLock) {
            pythonExecutor?.takeIf { !it.isShutdown && !it.isTerminated } ?: run {
                Executors.newSingleThreadExecutor { r ->
                    Thread(r, "PythonExecutor-Search").apply { isDaemon = true }
                }.also { pythonExecutor = it }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val args = arguments as? Map<*, *> ?: run {
            events?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
            return
        }

        job = plugin.coroutineScope.launch {
            try {
                Log.d("YTMusicAPI", "SearchStreamHandler: Starting search execution")
                
                val query = args["query"] as? String ?: throw IllegalArgumentException("Query is required")
                searchId = "search_${query.hashCode()}_${System.currentTimeMillis()}"

                plugin.searchManager.cancelType(SEARCH_TYPE)
                
                val limit = args["limit"] as? Int ?: 50
                val thumbQuality = args["thumbQuality"] as? String ?: "VERY_HIGH" 
                val audioQuality = args["audioQuality"] as? String ?: "HIGH"
                val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                val searcher = plugin.getMusicSearcher() ?: throw IllegalStateException("Music searcher not initialized")

                Log.d("YTMusicAPI", "SearchStreamHandler: Creating generator for query: $query")
                
                val generator = withContext(Dispatchers.IO) {
                    suspendCancellableCoroutine<PyObject> { continuation ->
                        val executor = getOrCreateExecutor()
                        try {
                            executor.execute {
                                try {
                                    val result = searcher.callAttr(
                                        "get_music_details",
                                        query,
                                        limit,
                                        plugin.getPythonThumbnailQuality(thumbQuality),
                                        plugin.getPythonAudioQuality(audioQuality),
                                        includeAudioUrl,
                                        includeAlbumArt
                                    )
                                    continuation.resume(result)
                                } catch (e: Exception) {
                                    continuation.resumeWithException(e)
                                }
                            }
                        } catch (e: Exception) {
                            continuation.resumeWithException(e)
                        }
                        
                        continuation.invokeOnCancellation {
                            Log.d("YTMusicAPI", "SearchStreamHandler: Generator creation cancelled")
                        }
                    }
                }

                plugin.searchManager.registerSearch(searchId!!, SEARCH_TYPE, generator, job!!)

                Log.d("YTMusicAPI", "SearchStreamHandler: Starting iteration")
                
                processSearchResults(generator, events, limit)
                
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.endOfStream()
                    }
                }
                
            } catch (e: TimeoutCancellationException) {
                Log.e("YTMusicAPI", "SearchStreamHandler: Overall timeout", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("TIMEOUT_ERROR", "Search request timed out", null)
                    }
                }
            } catch (e: CancellationException) {
                Log.d("YTMusicAPI", "SearchStreamHandler: Search cancelled")
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "SearchStreamHandler: Stream error: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("STREAM_ERROR", e.message ?: "Unknown error", null)
                    }
                }
            } finally {
                searchId?.let { plugin.searchManager.cancelSearch(it) }
            }
        }
    }

    private suspend fun processSearchResults(generator: PyObject, events: EventChannel.EventSink?, limit: Int) {
        var itemCount = 0
        val cancelled = AtomicBoolean(false)
        val iterator = generator.callAttr("__iter__")

        while (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE) && itemCount < limit && !cancelled.get()) {
            try {
                Log.d("YTMusicAPI", "SearchStreamHandler: Attempting to get next item ($itemCount)")
                
                val item = withTimeoutOrNull(20000L) {
                    suspendCancellableCoroutine<PyObject?> { continuation ->
                        val executor = getOrCreateExecutor()
                        try {
                            executor.execute {
                                try {
                                    val result = iterator.callAttr("__next__")
                                    continuation.resume(result)
                                } catch (e: Exception) {
                                    if (e.message?.contains("StopIteration") == true || 
                                        e.toString().contains("StopIteration")) {
                                        Log.d("YTMusicAPI", "SearchStreamHandler: StopIteration detected")
                                        continuation.resume(null)
                                    } else {
                                        continuation.resumeWithException(e)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            continuation.resumeWithException(e)
                        }
                        
                        continuation.invokeOnCancellation {
                            cancelled.set(true)
                            Log.d("YTMusicAPI", "SearchStreamHandler: Item fetch cancelled")
                        }
                    }
                }
                
                if (item == null || item.isNone) {
                    Log.d("YTMusicAPI", "SearchStreamHandler: No more items, breaking")
                    break
                }
                
                Log.d("YTMusicAPI", "SearchStreamHandler: Converting Python dict to map")
                val songData = plugin.convertPythonDictToMap(item)
                Log.d("YTMusicAPI", "SearchStreamHandler: Processing item: ${songData["title"]}")
                
                // Send result on Main thread with latest check
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.success(mapOf(
                            "title" to (songData["title"]?.toString() ?: "Unknown"),
                            "artists" to (songData["artists"]?.toString() ?: "Unknown"), 
                            "videoId" to (songData["videoId"]?.toString() ?: ""),
                            "duration" to (songData["duration"]?.toString() ?: ""),
                            "year" to (songData["year"]?.toString() ?: ""),
                            "albumArt" to (songData["albumArt"]?.toString() ?: ""),
                            "audioUrl" to (songData["audioUrl"]?.toString() ?: "")
                        ))
                    }
                }
                
                itemCount++
                Log.d("YTMusicAPI", "SearchStreamHandler: Processed $itemCount items")
                
                // Cooperative cancellation check
                yield()
                
            } catch (e: TimeoutCancellationException) {
                Log.e("YTMusicAPI", "SearchStreamHandler: Timeout getting item $itemCount", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("TIMEOUT_ERROR", "Request timed out getting item $itemCount", null)
                    }
                }
                break
            } catch (e: CancellationException) {
                Log.d("YTMusicAPI", "SearchStreamHandler: Operation cancelled")
                break
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "SearchStreamHandler: Error processing item $itemCount: ${e.message}", e)
                if (itemCount == 0) {
                    throw e
                }
                continue
            }
        }

        Log.d("YTMusicAPI", "SearchStreamHandler: Finished processing $itemCount items")
    }

    override fun onCancel(arguments: Any?) {
        Log.d("YTMusicAPI", "SearchStreamHandler: onCancel called")
        job?.cancel()
        searchId?.let { plugin.searchManager.cancelSearch(it) }
        eventSink = null
        
        synchronized(executorLock) {
            pythonExecutor?.let { executor ->
                if (!executor.isShutdown) {
                    executor.shutdown()
                }
            }
            pythonExecutor = null
        }
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class RelatedSongsStreamHandler(private val plugin: YtFlutterMusicapiPlugin) : EventChannel.StreamHandler {
    companion object {
        const val SEARCH_TYPE = YtFlutterMusicapiPlugin.SEARCH_TYPE_RELATED
    }
    
    private var eventSink: EventChannel.EventSink? = null
    private var searchId: String? = null
    private var job: Job? = null
    private var pythonExecutor: ExecutorService? = null
    private val executorLock = Object()
    
    private fun getOrCreateExecutor(): ExecutorService {
        return synchronized(executorLock) {
            pythonExecutor?.takeIf { !it.isShutdown && !it.isTerminated } ?: run {
                Executors.newSingleThreadExecutor { r ->
                    Thread(r, "PythonExecutor-Related").apply { isDaemon = true }
                }.also { pythonExecutor = it }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val args = arguments as? Map<*, *> ?: run {
            events?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
            return
        }

        job = plugin.coroutineScope.launch {
            try {
                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Starting related songs execution")
                
                val songName = args["songName"] as? String ?: throw IllegalArgumentException("Song name required")
                val artistName = args["artistName"] as? String ?: throw IllegalArgumentException("Artist name required")
                searchId = "related_${songName.hashCode()}_${artistName.hashCode()}_${System.currentTimeMillis()}"

                plugin.searchManager.cancelType(SEARCH_TYPE)
                
                val limit = args["limit"] as? Int ?: 65
                val thumbQuality = args["thumbQuality"] as? String ?: "VERY_HIGH"
                val audioQuality = args["audioQuality"] as? String ?: "HIGH"
                val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                val fetcher = plugin.getRelatedFetcher() ?: throw IllegalStateException("Related fetcher not initialized")

                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Creating generator for $songName by $artistName")
                
                val generator = suspendCancellableCoroutine<PyObject> { continuation ->
                    val executor = getOrCreateExecutor()
                    try {
                        executor.execute {
                            try {
                                val result = fetcher.callAttr(
                                    "getRelated",
                                    songName,
                                    artistName,
                                    limit,
                                    plugin.getPythonThumbnailQuality(thumbQuality),
                                    plugin.getPythonAudioQuality(audioQuality),
                                    includeAudioUrl,
                                    includeAlbumArt
                                )
                                continuation.resume(result)
                            } catch (e: Exception) {
                                continuation.resumeWithException(e)
                            }
                        }
                    } catch (e: Exception) {
                        continuation.resumeWithException(e)
                    }
                    
                    continuation.invokeOnCancellation {
                        Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Generator creation cancelled")
                    }
                }

                plugin.searchManager.registerSearch(searchId!!, SEARCH_TYPE, generator, job!!)

                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Starting iteration")
                
                processRelatedResults(generator, events, limit)
                
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.endOfStream()
                    }
                }
                
            } catch (e: TimeoutCancellationException) {
                Log.e("YTMusicAPI", "RelatedSongsStreamHandler: Overall timeout", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("TIMEOUT_ERROR", "Related songs request timed out", null)
                    }
                }
            } catch (e: CancellationException) {
                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Search cancelled")
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "RelatedSongsStreamHandler: Stream error", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("STREAM_ERROR", e.message ?: "Unknown error", null)
                    }
                }
            } finally {
                searchId?.let { plugin.searchManager.cancelSearch(it) }
            }
        }
    }

    private suspend fun processRelatedResults(generator: PyObject, events: EventChannel.EventSink?, limit: Int) {
        var itemCount = 0
        val cancelled = AtomicBoolean(false)
        val iterator = generator.callAttr("__iter__")

        while (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE) && itemCount < limit && !cancelled.get()) {
            try {
                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Attempting to get next item ($itemCount)")
                
                val item = withTimeoutOrNull(20000L) {
                    suspendCancellableCoroutine<PyObject?> { continuation ->
                        val executor = getOrCreateExecutor()
                        try {
                            executor.execute {
                                try {
                                    val result = iterator.callAttr("__next__")
                                    continuation.resume(result)
                                } catch (e: Exception) {
                                    if (e.message?.contains("StopIteration") == true || 
                                        e.toString().contains("StopIteration")) {
                                        continuation.resume(null)
                                    } else {
                                        continuation.resumeWithException(e)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            continuation.resumeWithException(e)
                        }
                        
                        continuation.invokeOnCancellation {
                            cancelled.set(true)
                        }
                    }
                }
                
                if (item == null || item.isNone) {
                    Log.d("YTMusicAPI", "RelatedSongsStreamHandler: No more items")
                    break
                }
                
                val songData = plugin.convertPythonDictToMap(item)
                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Processing item: ${songData["title"]}")
                
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.success(mapOf(
                            "title" to (songData["title"]?.toString() ?: "Unknown"),
                            "artists" to (songData["artists"]?.toString() ?: "Unknown"),
                            "videoId" to (songData["videoId"]?.toString() ?: ""),
                            "duration" to (songData["duration"]?.toString() ?: ""),
                            "albumArt" to (songData["albumArt"]?.toString() ?: ""),
                            "audioUrl" to (songData["audioUrl"]?.toString() ?: ""),
                            "isOriginal" to (songData["isOriginal"]?.toString()?.toBoolean() ?: false)
                        ))
                    }
                }
                
                itemCount++
                Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Processed $itemCount items")
                
                yield()
                
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "RelatedSongsStreamHandler: Error processing item $itemCount: ${e.message}", e)
                if (itemCount == 0) {
                    throw e
                }
                continue
            }
        }

        Log.d("YTMusicAPI", "RelatedSongsStreamHandler: Finished processing $itemCount items")
    }

    override fun onCancel(arguments: Any?) {
        Log.d("YTMusicAPI", "RelatedSongsStreamHandler: onCancel called")
        job?.cancel()
        searchId?.let { plugin.searchManager.cancelSearch(it) }
        eventSink = null
        
        synchronized(executorLock) {
            pythonExecutor?.let { executor ->
                if (!executor.isShutdown) {
                    executor.shutdown()
                }
            }
            pythonExecutor = null
        }
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class ArtistSongsStreamHandler(private val plugin: YtFlutterMusicapiPlugin) : EventChannel.StreamHandler {

    companion object {
        const val SEARCH_TYPE = YtFlutterMusicapiPlugin.SEARCH_TYPE_ARTIST
    }

    private var eventSink: EventChannel.EventSink? = null
    private var searchId: String? = null
    private var job: Job? = null
    private var pythonExecutor: ExecutorService? = null
    private val executorLock = Object()

    private fun getOrCreateExecutor(): ExecutorService {
        return synchronized(executorLock) {
            pythonExecutor?.takeIf { !it.isShutdown && !it.isTerminated } ?: run {
                Executors.newSingleThreadExecutor { r ->
                    Thread(r, "PythonExecutor-Artist").apply { isDaemon = true }
                }.also { pythonExecutor = it }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val args = arguments as? Map<*, *> ?: run {
            events?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
            return
        }

        job = plugin.coroutineScope.launch {
            try {
                Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Starting artist songs execution")

                val artistName = args["artistName"] as? String ?: throw IllegalArgumentException("artistName required")
                searchId = "artist_${artistName.hashCode()}_${System.currentTimeMillis()}"

                val limit = args["limit"] as? Int ?: 25
                val thumbQuality = args["thumbQuality"] as? String ?: "VERY_HIGH"
                val audioQuality = args["audioQuality"] as? String ?: "HIGH"
                val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                plugin.searchManager.cancelType(SEARCH_TYPE)

                val searcher = plugin.getMusicSearcher() ?: throw IllegalStateException("Music searcher unavailable")

                Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Creating generator for: $artistName")

                val generator = suspendCancellableCoroutine<PyObject> { continuation ->
                    val executor = getOrCreateExecutor()
                    try {
                        executor.execute {
                            try {
                                val result = searcher.callAttr(
                                    "get_artist_songs",
                                    artistName,
                                    limit,
                                    thumbQuality,
                                    audioQuality,
                                    includeAudioUrl,
                                    includeAlbumArt
                                )
                                continuation.resume(result)
                            } catch (e: Exception) {
                                continuation.resumeWithException(e)
                            }
                        }
                    } catch (e: Exception) {
                        continuation.resumeWithException(e)
                    }

                    continuation.invokeOnCancellation {
                        Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Generator creation cancelled")
                    }
                }

                plugin.searchManager.registerSearch(searchId!!, SEARCH_TYPE, generator, job!!)

                Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Starting iteration")
                processArtistResults(generator, events, limit, artistName)

                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.endOfStream()
                    }
                }

            } catch (e: TimeoutCancellationException) {
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("TIMEOUT_ERROR", "Artist songs request timed out", null)
                    }
                }
            } catch (e: CancellationException) {
                Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Search cancelled")
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "ArtistSongsStreamHandler: Stream error", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("STREAM_ERROR", e.message ?: "Unknown error", null)
                    }
                }
            } finally {
                searchId?.let {
                    if (plugin.searchManager.has(it)) {
                        plugin.searchManager.cancelSearch(it)
                    } else {
                        Log.d("YTMusicAPI", "Search $it not found for cancellation (already closed)")
                    }
                }
            }
        }
    }

    private suspend fun processArtistResults(generator: PyObject, events: EventChannel.EventSink?, limit: Int, artistName: String) {
        var itemCount = 0
        val cancelled = AtomicBoolean(false)
        val iterator = generator.callAttr("__iter__")

        while (
            plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE) &&
            itemCount < limit &&
            !cancelled.get()
        ) {
            try {
                Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Getting item $itemCount")

                val item = withTimeoutOrNull(20000L) {
                    suspendCancellableCoroutine<PyObject?> { continuation ->
                        val executor = getOrCreateExecutor()
                        try {
                            executor.execute {
                                try {
                                    val result = iterator.callAttr("__next__")
                                    continuation.resume(result)
                                } catch (e: Exception) {
                                    if (e.message?.contains("StopIteration") == true) {
                                        continuation.resume(null)
                                    } else {
                                        continuation.resumeWithException(e)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            continuation.resumeWithException(e)
                        }

                        continuation.invokeOnCancellation {
                            cancelled.set(true)
                        }
                    }
                }

                if (item == null || item.isNone) {
                    Log.d("YTMusicAPI", "ArtistSongsStreamHandler: No more items")
                    break
                }

                val songData = plugin.convertPythonDictToMap(item)
                Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Processing: ${songData["title"]}")

                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.success(
                            mapOf(
                                "title" to (songData["title"]?.toString() ?: "Unknown"),
                                "artists" to (songData["artists"]?.toString() ?: "Unknown"),
                                "videoId" to (songData["videoId"]?.toString() ?: ""),
                                "duration" to (songData["duration"]?.toString() ?: ""),
                                "albumArt" to (songData["albumArt"]?.toString() ?: ""),
                                "audioUrl" to (songData["audioUrl"]?.toString() ?: ""),
                                "artistName" to artistName
                            )
                        )
                    } else {
                        Log.d("YTMusicAPI", "⚠️ Skipped result for stale search: $searchId")
                    }
                }

                itemCount++
                yield()

            } catch (e: Exception) {
                Log.e("YTMusicAPI", "ArtistSongsStreamHandler: Error at item $itemCount (${e.message})", e)
                if (itemCount == 0) throw e
                continue
            }
        }

        Log.d("YTMusicAPI", "ArtistSongsStreamHandler: Finished processing $itemCount items")
    }

    override fun onCancel(arguments: Any?) {
        Log.d("YTMusicAPI", "ArtistSongsStreamHandler: onCancel called")
        job?.cancel()
        searchId?.let {
            if (plugin.searchManager.has(it)) {
                plugin.searchManager.cancelSearch(it)
            } else {
                Log.d("YTMusicAPI", "Nothing to cancel for $it")
            }
        }
        eventSink = null

        synchronized(executorLock) {
            pythonExecutor?.takeIf { !it.isShutdown }?.shutdown()
            pythonExecutor = null
        }
    }
}


@OptIn(ExperimentalCoroutinesApi::class)
class SongDetailsStreamHandler(private val plugin: YtFlutterMusicapiPlugin) : EventChannel.StreamHandler {
    companion object {
        const val SEARCH_TYPE = YtFlutterMusicapiPlugin.SEARCH_TYPE_DETAILS
    }
    
    private var eventSink: EventChannel.EventSink? = null
    private var searchId: String? = null
    private var job: Job? = null
    private val pythonExecutor by lazy {
        Executors.newSingleThreadExecutor { r ->
            Thread(r, "PythonExecutor-Details").apply { isDaemon = true }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        val args = arguments as? Map<*, *> ?: run {
            plugin.coroutineScope.launch(Dispatchers.Main) {
                events?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
            }
            return
        }

        job = plugin.coroutineScope.launch {
            try {
                val songs = when (val songsArg = args["songs"]) {
                    is List<*> -> songsArg.filterIsInstance<Map<String, String>>()
                    else -> null
                } ?: throw IllegalArgumentException("Songs list is required and must contain Map<String, String> elements")

                searchId = "song_details_${songs.hashCode()}_${System.currentTimeMillis()}"
                
                val thumbQuality = args["thumbQuality"] as? String ?: "VERY_HIGH"
                val audioQuality = args["audioQuality"] as? String ?: "VERY_HIGH"
                val includeAudioUrl = args["includeAudioUrl"] as? Boolean ?: true
                val includeAlbumArt = args["includeAlbumArt"] as? Boolean ?: true

                val searcher = plugin.getMusicSearcher() ?: throw IllegalStateException("Music searcher not initialized")
                plugin.searchManager.cancelType(SEARCH_TYPE)

                val generator = withContext(Dispatchers.IO) {
                    suspendCancellableCoroutine<PyObject> { continuation ->
                        try {
                            val pySongs = plugin.getPythonInstance()?.getBuiltins()?.callAttr("list") 
                                ?: throw IllegalStateException("Python builtins not available")
                            
                            for (song in songs) {
                                val pySong = plugin.getPythonInstance()?.getBuiltins()?.callAttr("dict") ?: continue
                                pySong.callAttr("__setitem__", "song_name", song["title"] ?: "")
                                pySong.callAttr("__setitem__", "artist_name", song["artist"] ?: "")
                                pySongs.callAttr("append", pySong)
                            }

                            val result = searcher.callAttr(
                                "stream_song_details",
                                pySongs,
                                plugin.getPythonThumbnailQuality(thumbQuality),
                                plugin.getPythonAudioQuality(audioQuality),
                                includeAudioUrl,
                                includeAlbumArt
                            )
                            continuation.resume(result)
                        } catch (e: Exception) {
                            continuation.resumeWithException(e)
                        }
                    }
                }

                plugin.searchManager.registerSearch(searchId!!, SEARCH_TYPE, generator, job!!)

                val iterator = generator.callAttr("__iter__")
                var itemCount = 0

                while (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                    try {
                        val item = withTimeoutOrNull(18000L) {
                            withContext(Dispatchers.IO) {
                                iterator.callAttr("__next__")
                            }
                        } ?: break

                        if (item.isNone) break

                        val itemMap = plugin.convertPythonDictToMap(item)
                        
                        withContext(Dispatchers.Main) {
                            if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                                if (itemMap.containsKey("error")) {
                                    events?.success(mapOf(
                                        "error" to itemMap["error"],
                                        "success" to false
                                    ))
                                } else {
                                    events?.success(itemMap)
                                }
                            }
                        }
                        
                        itemCount++
                    } catch (e: Exception) {
                        if (e.message?.contains("StopIteration") == true || e.toString().contains("StopIteration")) {
                            break
                        }
                        Log.e("YTMusicAPI", "Error processing song detail", e)
                        withContext(Dispatchers.Main) {
                            if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                                events?.error("PROCESSING_ERROR", e.message, null)
                            }
                        }
                        continue
                    }
                }

                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.endOfStream()
                    }
                }
                
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "Song details stream error", e)
                withContext(Dispatchers.Main) {
                    if (plugin.searchManager.isLatestOfType(searchId!!, SEARCH_TYPE)) {
                        events?.error("STREAM_ERROR", e.message, null)
                    }
                }
            } finally {
                searchId?.let { plugin.searchManager.cancelSearch(it) }
                pythonExecutor.shutdown()
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        job?.cancel()
        searchId?.let { plugin.searchManager.cancelSearch(it) }
        eventSink = null
        pythonExecutor.shutdown()
    }
}