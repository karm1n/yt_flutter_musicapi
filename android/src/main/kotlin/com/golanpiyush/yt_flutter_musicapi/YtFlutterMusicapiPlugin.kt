package com.golanpiyush.yt_flutter_musicapi

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import com.chaquo.python.PyObject
import android.content.Context
import android.util.Log
import android.icu.util.TimeUnit
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeoutException
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.golanpiyush.yt_flutter_musicapi.SearchStreamHandler
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException

class YtFlutterMusicapiPlugin: FlutterPlugin, MethodCallHandler, CoroutineScope {
    private val job = SupervisorJob()
    override val coroutineContext: CoroutineContext = Dispatchers.IO + job
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var python: Python? = null
    private var pythonModule: PyObject? = null
    private var musicSearcher: PyObject? = null
    private var relatedFetcher: PyObject? = null
    
    // Event Channels
    private lateinit var searchStreamChannel: EventChannel
    private lateinit var relatedSongsStreamChannel: EventChannel
    private lateinit var artistSongsStreamChannel: EventChannel
    private lateinit var songDetailsStreamChannel: EventChannel

    // Search Manager
    internal val searchManager = SearchManager()
    
    // Performance optimizations
    internal val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val threadPoolExecutor = Executors.newFixedThreadPool(4) as ThreadPoolExecutor
    private val instanceCache = ConcurrentHashMap<String, PyObject>()
    
    companion object {
        private const val TAG = "YTMusicAPI"
        private const val CHANNEL_NAME = "yt_flutter_musicapi"

        const val SEARCH_TYPE_LYRICS = "fetch_lyrics"

        // Methods available
        const val SEARCH_TYPE_SEARCH = "music_search"
        const val SEARCH_TYPE_RELATED = "related_songs"
        const val SEARCH_TYPE_ARTIST = "artist_songs"
        const val SEARCH_TYPE_DETAILS = "song_details"
    }

    fun getMusicSearcher(): PyObject? = musicSearcher
    fun getRelatedFetcher(): PyObject? = relatedFetcher
    fun getPythonInstance(): Python? = python
    

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext

        // Initialize event channels
        searchStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/searchStream").apply {
            setStreamHandler(SearchStreamHandler(this@YtFlutterMusicapiPlugin))
        }
        relatedSongsStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/relatedSongsStream").apply {
            setStreamHandler(RelatedSongsStreamHandler(this@YtFlutterMusicapiPlugin))
        }
        songDetailsStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/songDetailsStream").apply {
            setStreamHandler(SongDetailsStreamHandler(this@YtFlutterMusicapiPlugin))
        }
        artistSongsStreamChannel = EventChannel(flutterPluginBinding.binaryMessenger, "yt_flutter_musicapi/artistSongsStream").apply {
            setStreamHandler(ArtistSongsStreamHandler(this@YtFlutterMusicapiPlugin))
        }
       
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        logMethodCall(call)
        when (call.method) {
            "checkStatus" -> handleCheckStatus(result)
            "initialize" -> handleInitialize(call, result)
            "searchMusic" -> handleSearchMusic(call, result)
            "startStreamingSearch" -> handleStartStreamingSearch(call, result)
            "startStreamingRelated" -> handleStartStreamingRelated(call, result)
            "startStreamingArtist" -> handleStartStreamingArtist(call, result)
            "startStreamingSongDetails" -> handleStartStreamingSongDetails(call, result)
            "getSongDetails" -> handleGetSongDetails(call, result)
            "getArtistSongs" -> handleGetArtistSongs(call, result)
            "getRelatedSongs" -> handleGetRelatedSongs(call, result)
            "fetchLyrics" -> handleFetchLyrics(call, result)
            "dispose" -> handleDispose(result)
            else -> result.notImplemented()
        }
    }

    private fun logMethodCall(call: MethodCall) {
        Log.d(TAG, """
            Method: ${call.method}
            Args: ${call.arguments}
            Python: ${python != null}
            Module: ${pythonModule != null}
            Searcher: ${musicSearcher != null}
            """.trimIndent())
    }

    private fun handleCheckStatus(result: Result) {
        coroutineScope.launch {
            try {
                Log.d(TAG, "Checking status...")
                
                // Force initialization if components are missing
                if (pythonModule == null || musicSearcher == null || relatedFetcher == null) {
                    Log.d(TAG, "Components missing, forcing reinitialization...")
                    initializePython()
                }
                
                val statusResult = pythonModule!!.callAttr("check_ytmusic_and_ytdlp_ready")
                val statusMap = convertPythonDictToMap(statusResult)
                
                // Add our own status info
                val enhancedStatus = statusMap.toMutableMap().apply {
                    put("python_initialized", python != null)
                    put("module_loaded", pythonModule != null)
                    put("searcher_ready", musicSearcher != null)
                    put("related_fetcher_ready", relatedFetcher != null)
                    put("cache_size", instanceCache.size)
                }
                
                Log.d(TAG, "Status check completed: $enhancedStatus")
                
                withContext(Dispatchers.Main) {
                    result.success(enhancedStatus)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Status check failed", e)
                withContext(Dispatchers.Main) {
                    result.error("STATUS_ERROR", "Failed to check status: ${e.message}", mapOf(
                        "success" to false,
                        "error" to e.message,
                        "python_started" to Python.isStarted(),
                        "stackTrace" to Log.getStackTraceString(e)
                    ))
                }
            }
        }
    }

    private fun initializePython() {
    try {
        Log.d(TAG, "=== Starting Python Initialization ===")
        Log.d(TAG, "Current state - Python: ${python != null}, Module: ${pythonModule != null}, Searcher: ${musicSearcher != null}")
        
        // Always force complete cleanup before reinitializing
        Log.d(TAG, "Performing aggressive cleanup...")
        
        // Clean up existing objects
        try { 
            musicSearcher?.callAttr("SearchStreamsCleanup")
            Log.d(TAG, "musicSearcher cleanup called")
        } catch (e: Exception) { 
            Log.d(TAG, "musicSearcher cleanup not available: ${e.message}")
        }
        
        try { 
            relatedFetcher?.callAttr("RelatedStreamCleanup")
            Log.d(TAG, "relatedFetcher cleanup called")
        } catch (e: Exception) { 
            Log.d(TAG, "relatedFetcher cleanup not available: ${e.message}")
        }
        
        // Close references
        try { musicSearcher?.close() } catch (e: Exception) { /* ignore */ }
        try { relatedFetcher?.close() } catch (e: Exception) { /* ignore */ }
        try { pythonModule?.close() } catch (e: Exception) { /* ignore */ }
        
        musicSearcher = null
        relatedFetcher = null
        pythonModule = null
        
        Log.d(TAG, "Starting fresh Python initialization...")
        
        // Initialize Python if not started
        if (!Python.isStarted()) {
            Log.d(TAG, "Starting Python interpreter...")
            Python.start(AndroidPlatform(context))
            Log.d(TAG, "Python interpreter started successfully")
        } else {
            Log.d(TAG, "Python interpreter already started")
        }
        
        // Get Python instance
        Log.d(TAG, "Getting Python instance...")
        python = Python.getInstance()
        Log.d(TAG, "Python instance obtained: ${python != null}")
        
        // Force aggressive garbage collection
        Log.d(TAG, "Running aggressive Python cleanup...")
        try {
            python?.getModule("gc")?.callAttr("collect")
            // Force multiple GC cycles
            repeat(3) {
                python?.getModule("gc")?.callAttr("collect")
            }
            Log.d(TAG, "Python garbage collection completed")
        } catch (e: Exception) {
            Log.w(TAG, "Python garbage collection failed: ${e.message}")
        }
        
        // Clear module from sys.modules and force reimport
        Log.d(TAG, "Clearing module from sys.modules...")
        try {
            val sysModule = python?.getModule("sys")
            val modules = sysModule?.get("modules")
            
            // Remove all related modules
            val moduleNames = listOf("globalsearcher", "ytmusicapi", "yt_dlp")
            for (modName in moduleNames) {
                try {
                    if (modules?.callAttr("__contains__", modName)?.toBoolean() == true) {
                        modules.callAttr("__delitem__", modName)
                        Log.d(TAG, "Removed $modName from sys.modules")
                    }
                } catch (e: Exception) {
                    Log.d(TAG, "Could not remove $modName: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Module cleanup failed: ${e.message}")
        }
        
        // Wait a bit for cleanup to complete
        Thread.sleep(1000)
        
        // Import the module with timeout using ExecutorService
        Log.d(TAG, "Loading globalsearcher module with timeout...")
        val moduleExecutor = Executors.newSingleThreadExecutor()
        try {
            pythonModule = try {
                val future = moduleExecutor.submit<PyObject?> {
                    var lastException: Exception? = null
                    
                    // Try multiple import strategies
                    val strategies = listOf(
                        "Direct import" to { python?.getModule("globalsearcher") },
                        "Exec import" to { 
                            python?.getBuiltins()?.callAttr("exec", "import globalsearcher")
                            python?.getModule("globalsearcher")
                        },
                        "__import__ builtin" to {
                            python?.getBuiltins()?.callAttr("__import__", "globalsearcher")
                            python?.getModule("globalsearcher")
                        }
                    )
                    
                    for ((strategyName, strategy) in strategies) {
                        try {
                            Log.d(TAG, "Trying strategy: $strategyName")
                            val result = strategy()
                            if (result != null) {
                                Log.d(TAG, "Strategy '$strategyName' succeeded")
                                return@submit result
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Strategy '$strategyName' failed: ${e.message}")
                            lastException = e
                            
                            // Wait between strategies
                            Thread.sleep(500)
                        }
                    }
                    
                    throw lastException ?: IllegalStateException("All import strategies failed")
                }
                future.get(20, java.util.concurrent.TimeUnit.SECONDS)
            } catch (e: TimeoutException) {
                throw Exception("Module import timed out after 20 seconds", e)
            } catch (e: ExecutionException) {
                throw Exception("Module import failed", e.cause ?: e)
            }
        } finally {
            moduleExecutor.shutdown()
            try {
                if (!moduleExecutor.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    moduleExecutor.shutdownNow()
                }
            } catch (e: InterruptedException) {
                moduleExecutor.shutdownNow()
                Thread.currentThread().interrupt()
            }
        }
        
        Log.d(TAG, "globalsearcher module loaded successfully")
        
        // Create YTMusicSearcher instance with timeout
        Log.d(TAG, "Creating fresh YTMusicSearcher instance...")
        val searcherExecutor = Executors.newSingleThreadExecutor()
        try {
            musicSearcher = try {
                val future = searcherExecutor.submit<PyObject?> {
                    pythonModule?.callAttr("YTMusicSearcher", null, "US")
                }
                future.get(15, java.util.concurrent.TimeUnit.SECONDS)
            } catch (e: TimeoutException) {
                throw Exception("YTMusicSearcher creation timed out after 15 seconds", e)
            } catch (e: ExecutionException) {
                throw Exception("YTMusicSearcher creation failed", e.cause ?: e)
            }
        } finally {
            searcherExecutor.shutdown()
            try {
                if (!searcherExecutor.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    searcherExecutor.shutdownNow()
                }
            } catch (e: InterruptedException) {
                searcherExecutor.shutdownNow()
                Thread.currentThread().interrupt()
            }
        }
        Log.d(TAG, "YTMusicSearcher created: ${musicSearcher != null}")
        
        // Create YTMusicRelatedFetcher instance with timeout
        Log.d(TAG, "Creating fresh YTMusicRelatedFetcher instance...")
        val fetcherExecutor = Executors.newSingleThreadExecutor()
        try {
            relatedFetcher = try {
                val future = fetcherExecutor.submit<PyObject?> {
                    pythonModule?.callAttr("YTMusicRelatedFetcher", null, "US")
                }
                future.get(15, java.util.concurrent.TimeUnit.SECONDS)
            } catch (e: TimeoutException) {
                throw Exception("YTMusicRelatedFetcher creation timed out after 15 seconds", e)
            } catch (e: ExecutionException) {
                throw Exception("YTMusicRelatedFetcher creation failed", e.cause ?: e)
            }
        } finally {
            fetcherExecutor.shutdown()
            try {
                if (!fetcherExecutor.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    fetcherExecutor.shutdownNow()
                }
            } catch (e: InterruptedException) {
                fetcherExecutor.shutdownNow()
                Thread.currentThread().interrupt()
            }
        }
        Log.d(TAG, "YTMusicRelatedFetcher created: ${relatedFetcher != null}")
        
        if (musicSearcher == null || relatedFetcher == null) {
            throw IllegalStateException("Failed to initialize music searchers - musicSearcher: ${musicSearcher != null}, relatedFetcher: ${relatedFetcher != null}")
        }
        
        Log.d(TAG, "=== Python initialization completed successfully ===")
        
    } catch (e: Exception) {
        Log.e(TAG, "=== Python initialization FAILED ===", e)
        Log.e(TAG, "Error details: ${e.message}")
        Log.e(TAG, "Stack trace: ${Log.getStackTraceString(e)}")
        
        // Clean up partial initialization
        try { musicSearcher?.close() } catch (ex: Exception) { 
            Log.w(TAG, "Error closing musicSearcher during cleanup: ${ex.message}")
        }
        try { relatedFetcher?.close() } catch (ex: Exception) { 
            Log.w(TAG, "Error closing relatedFetcher during cleanup: ${ex.message}")
        }
        try { pythonModule?.close() } catch (ex: Exception) { 
            Log.w(TAG, "Error closing pythonModule during cleanup: ${ex.message}")
        }
        
        musicSearcher = null
        relatedFetcher = null
        pythonModule = null
        throw e
    }
}

    private var isPythonInitializing = false
    private var isPythonInitialized = false

    private fun handleInitialize(call: MethodCall, result: Result) {
        val proxy = call.argument<String>("proxy")
        val country = call.argument<String>("country") ?: "US"
        
        Log.d(TAG, "Initialize called with proxy: $proxy, country: $country")

        // Immediately respond success to Flutter:
        CoroutineScope(Dispatchers.Main).launch {
            result.success(
                mapOf(
                    "success" to true,
                    "message" to "YTMusic API initialization started",
                    "proxy" to proxy,
                    "country" to country
                )
            )
        }

        // If not already initializing, start initialization in the background
        if (!isPythonInitialized && !isPythonInitializing) {
            isPythonInitializing = true

            coroutineScope.launch(Dispatchers.IO) {
                try {
                    withTimeout(15_000) {
                        initializePython() // your heavy work here
                    }

                    val searcherKey = "searcher_${proxy}_${country}"
                    val relatedKey = "related_${proxy}_${country}"

                    // Create and cache instances
                    musicSearcher = pythonModule!!.callAttr("YTMusicSearcher", proxy, country)
                    relatedFetcher = pythonModule!!.callAttr("YTMusicRelatedFetcher", proxy, country)
                    
                    instanceCache[searcherKey] = musicSearcher!!
                    instanceCache[relatedKey] = relatedFetcher!!

                    isPythonInitialized = true
                    Log.d(TAG, "Background initialization successful")

                    // Optionally send an event or callback to Flutter here about successful initialization

                } catch (e: TimeoutCancellationException) {
                    Log.e(TAG, "Background initialization timed out")
                    cleanupOnFailure()
                    // Optionally notify Flutter about failure via event channel or other mechanism
                } catch (e: Exception) {
                    Log.e(TAG, "Background initialization failed", e)
                    cleanupOnFailure()
                    // Optionally notify Flutter about failure
                } finally {
                    isPythonInitializing = false
                }
            }
        }
    }

    private fun cleanupOnFailure() {
        musicSearcher = null
        relatedFetcher = null
        pythonModule = null
        instanceCache.clear()
        isPythonInitialized = false
    }



    private fun handleSearchMusic(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val query = call.argument<String>("query") 
                    ?: throw IllegalArgumentException("Query is required")
                
                val limit = call.argument<Int>("limit") ?: 10
                val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
                val audioQuality = call.argument<String>("audioQuality") ?: "HIGH"
                val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
                val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
                
                if (python == null || pythonModule == null) {
                    initializePython()
                }
                
                if (musicSearcher == null) {
                    throw IllegalStateException("YTMusic API not initialized")
                }

                Log.d(TAG, "Executing search for: $query (limit: $limit)")
                
                val pyThumbQuality = getPythonThumbnailQuality(thumbQuality)
                val pyAudioQuality = getPythonAudioQuality(audioQuality)
                
                val searchResults = musicSearcher!!.callAttr(
                    "get_music_details",
                    query,
                    limit,
                    pyThumbQuality,
                    pyAudioQuality,
                    includeAudioUrl,
                    includeAlbumArt
                )
                
                val pythonList = python?.getBuiltins()?.callAttr("list", searchResults)
                    ?: throw Exception("Failed to convert results to list")
                
                val count = pythonList.callAttr("__len__").toInt()
                val results = mutableListOf<Map<String, Any?>>()
                
                Log.d(TAG, "Processing $count search results...")
                
                for (i in 0 until count) {
                    try {
                        val item = pythonList.callAttr("__getitem__", i)
                        val itemMap = convertPythonDictToMap(item)
                        
                        results.add(mapOf(
                            "title" to (itemMap["title"]?.toString() ?: "Unknown"),
                            "artists" to (itemMap["artists"]?.toString() ?: "Unknown"),
                            "videoId" to (itemMap["videoId"]?.toString() ?: ""),
                            "duration" to itemMap["duration"]?.toString(),
                            "year" to itemMap["year"]?.toString(),
                            "albumArt" to itemMap["albumArt"]?.toString(),
                            "audioUrl" to itemMap["audioUrl"]?.toString()
                        ))
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing search result $i", e)
                    }
                }
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "data" to results,
                        "count" to results.size,
                        "query" to query
                    ))
                }
                
            } catch (e: Exception) {
                Log.e(TAG, "Search failed", e)
                withContext(Dispatchers.Main) {
                    result.error(
                        "SEARCH_ERROR", 
                        "Search failed: ${e.message}", 
                        mapOf(
                            "success" to false,
                            "error" to e.message,
                            "stackTrace" to Log.getStackTraceString(e)
                        )
                    )
                }
            }
        }
    }

    
    private fun handleStartStreamingSearch(call: MethodCall, result: Result) {
        Log.d(TAG, "handleStartStreamingSearch called")
        
        val query = call.argument<String>("query")
        if (query.isNullOrEmpty()) {
            result.error("INVALID_QUERY", "Query is required", null)
            return
        }
        
        result.success(mapOf(
            "started" to true,
            "message" to "Streaming search will start when EventChannel is listened to",
            "query" to query
        ))
    }

    private fun handleStartStreamingRelated(call: MethodCall, result: Result) {
        Log.d(TAG, "handleStartStreamingRelated called")
        
        val songName = call.argument<String>("songName")
        val artistName = call.argument<String>("artistName")
        
        if (songName.isNullOrEmpty() || artistName.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENTS", "Song name and artist name are required", null)
            return
        }
        
        result.success(mapOf(
            "started" to true,
            "message" to "Streaming related songs will start when EventChannel is listened to",
            "songName" to songName,
            "artistName" to artistName
        ))
    }

    private fun handleStartStreamingArtist(call: MethodCall, result: Result) {
        Log.d(TAG, "handleStartStreamingArtist called")
        
        val artistName = call.argument<String>("artistName")
        
        if (artistName.isNullOrEmpty()) {
            result.error("INVALID_ARGUMENTS", "Artist name is required", null)
            return
        }
        
        result.success(mapOf(
            "started" to true,
            "message" to "Streaming artist songs will start when EventChannel is listened to",
            "artistName" to artistName
        ))
    }

    private fun handleStartStreamingSongDetails(call: MethodCall, result: Result) {
        Log.d(TAG, "handleStartStreamingSongDetails called")
        
        val songs = call.argument<List<Map<String, String>>>("songs")
        if (songs.isNullOrEmpty()) {
            result.error("INVALID_SONGS", "Songs list is required", null)
            return
        }
        
        result.success(mapOf(
            "started" to true,
            "message" to "Streaming song details will start when EventChannel is listened to",
            "count" to songs.size
        ))
    }

    private fun handleGetRelatedSongs(call: MethodCall, result: Result) {
        try {
            val songName = call.argument<String>("songName")
                ?: throw IllegalArgumentException("Song name is required")
            val artistName = call.argument<String>("artistName")
                ?: throw IllegalArgumentException("Artist name is required")

            result.success(mapOf(
                "success" to true,
                "message" to "Streaming started for related songs of '$songName' by '$artistName'",
                "songName" to songName,
                "artistName" to artistName
            ))
        } catch (e: Exception) {
            Log.e(TAG, "Get related songs failed", e)
            result.error("RELATED_ERROR", "Get related songs failed: ${e.message}", null)
        }
    }

    private fun handleGetSongDetails(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val songs = call.argument<List<Map<String, String>>>("songs")
                    ?: throw IllegalArgumentException("Songs list is required")
                
                val mode = call.argument<String>("mode")?.lowercase() ?: "batch"
                val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
                val audioQuality = call.argument<String>("audioQuality") ?: "VERY_HIGH"
                val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
                val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
                
                if (musicSearcher == null) {
                    throw IllegalStateException("YTMusic API not initialized. Call initialize() first.")
                }
                
                val pythonThumbQuality = getPythonThumbnailQuality(thumbQuality)
                val pythonAudioQuality = getPythonAudioQuality(audioQuality)
                
                Log.d(TAG, "Getting song details in $mode mode for ${songs.size} songs")
                
                val pySongs = python?.getBuiltins()?.callAttr("list") ?: 
                    throw IllegalStateException("Python builtins not available")
                
                for (song in songs) {
                    val pySong = python?.getBuiltins()?.callAttr("dict") ?: continue
                    pySong.callAttr("__setitem__", "song_name", song["song_name"] ?: "")
                    pySong.callAttr("__setitem__", "artist_name", song["artist_name"] ?: "")
                    pySongs.callAttr("append", pySong)
                }
                
                val pythonResult = musicSearcher!!.callAttr(
                    "get_song_details",
                    pySongs,
                    pythonThumbQuality,
                    pythonAudioQuality,
                    includeAudioUrl,
                    includeAlbumArt,
                    mode.lowercase()
                )
                
                when (mode) {
                    "single" -> {
                        val songData = convertPythonDictToMap(pythonResult)
                        
                        withContext(Dispatchers.Main) {
                            if (songData.isNotEmpty()) {
                                result.success(mapOf(
                                    "success" to true,
                                    "data" to songData,
                                    "mode" to "single"
                                ))
                            } else {
                                result.error(
                                    "NO_RESULTS", 
                                    "No song details found", 
                                    mapOf("success" to false)
                                )
                            }
                        }
                    }
                    else -> {
                        val resultList = mutableListOf<Map<String, Any?>>()
                        
                        try {
                            val iterator = pythonResult.callAttr("__iter__")
                            var hasNext = true
                            
                            while (hasNext) {
                                try {
                                    val item = iterator.callAttr("__next__")
                                    val itemMap = convertPythonDictToMap(item)
                                    
                                    if (itemMap.containsKey("error")) {
                                        resultList.add(mapOf(
                                            "error" to itemMap["error"],
                                            "success" to false
                                        ))
                                    } else {
                                        resultList.add(itemMap)
                                    }
                                    Log.d(TAG, "Processed batch item: ${itemMap["title"]}")
                                } catch (e: Exception) {
                                    if (e.message?.contains("StopIteration") == true) {
                                        hasNext = false
                                    } else {
                                        Log.e(TAG, "Error processing batch item", e)
                                        resultList.add(mapOf(
                                            "error" to e.message,
                                            "success" to false
                                        ))
                                    }
                                }
                            }
                            
                            withContext(Dispatchers.Main) {
                                result.success(mapOf(
                                    "success" to true,
                                    "data" to resultList,
                                    "mode" to "batch",
                                    "count" to resultList.size,
                                    "processed" to resultList.count { it["success"] != false },
                                    "errors" to resultList.count { it["success"] == false }
                                ))
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error consuming generator", e)
                            withContext(Dispatchers.Main) {
                                result.error(
                                    "BATCH_ERROR", 
                                    "Error processing batch: ${e.message}", 
                                    null
                                )
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get song details", e)
                withContext(Dispatchers.Main) {
                    result.error(
                        "SONG_DETAILS_ERROR", 
                        "Failed to get song details: ${e.message}", 
                        null
                    )
                }
            }
        }
    }

    private fun handleGetArtistSongs(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val artistName = call.argument<String>("artistName") 
                    ?: throw IllegalArgumentException("Artist name is required")
                
                val limit = call.argument<Int>("limit") ?: 25
                val thumbQuality = call.argument<String>("thumbQuality") ?: "VERY_HIGH"
                val audioQuality = call.argument<String>("audioQuality") ?: "HIGH"
                val includeAudioUrl = call.argument<Boolean>("includeAudioUrl") ?: true
                val includeAlbumArt = call.argument<Boolean>("includeAlbumArt") ?: true
                
                if (musicSearcher == null) {
                    throw IllegalStateException("YTMusic API not initialized")
                }

                Log.d(TAG, "Fetching songs for artist: $artistName (limit: $limit)")

                val generator = musicSearcher!!.callAttr(
                    "get_artist_songs",
                    artistName,
                    limit,
                    thumbQuality,
                    audioQuality,
                    includeAudioUrl,
                    includeAlbumArt
                )

                val pythonList = python?.getBuiltins()?.callAttr("list", generator)
                    ?: throw Exception("Failed to convert generator to list")

                val songs = mutableListOf<Map<String, Any?>>()
                val count = pythonList.callAttr("__len__").toInt()

                Log.d(TAG, "Processing $count songs...")

                for (i in 0 until count) {
                    try {
                        val song = pythonList.callAttr("__getitem__", i)
                        val songMap = convertPythonDictToMap(song)
                        
                        songs.add(mapOf<String, Any?>(
                            "title" to (songMap["title"]?.toString() ?: "Unknown"),
                            "artists" to (songMap["artists"]?.toString() ?: "Unknown"),
                            "videoId" to (songMap["videoId"]?.toString() ?: ""),
                            "duration" to songMap["duration"]?.toString(),
                            "albumArt" to songMap["albumArt"]?.toString(),
                            "audioUrl" to songMap["audioUrl"]?.toString(),
                            "artistName" to artistName
                        ))
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing song $i", e)
                    }
                }

                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "data" to songs,
                        "count" to songs.size,
                        "skipped" to (count - songs.size)
                    ))
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error in handleGetArtistSongs", e)
                withContext(Dispatchers.Main) {
                    result.error(
                        "ARTIST_SONGS_ERROR", 
                        "Failed to get artist songs: ${e.message}", 
                        null
                    )
                }
            }
        }
    }

    
    private fun handleFetchLyrics(call: MethodCall, result: Result) {
        coroutineScope.launch {
            try {
                val songName = call.argument<String>("songName")
                    ?: throw IllegalArgumentException("Song name is required")
                val artistName = call.argument<String>("artistName")
                    ?: throw IllegalArgumentException("Artist name is required")

                if (python == null || pythonModule == null) {
                    initializePython()
                }

                if (musicSearcher == null) {
                    throw IllegalStateException("YTMusic API not initialized")
                }

                Log.d(TAG, "Fetching lyrics for: $songName by $artistName")

                val lyricsResult = withTimeout(45_000) { // Increased timeout
                    Log.d(TAG, "Calling Python lyrics fetcher...")
                    val result = musicSearcher!!.callAttr(
                        "fetch_ytmusic_lyrics",
                        songName,
                        artistName
                    )
                    Log.d(TAG, "Python call completed, processing result...")
                    result
                }

                Log.d(TAG, "Converting Python result to map...")
                val lyricsMap = convertPythonDictToMap(lyricsResult)
                
                // Enhanced logging to see what we actually got
                Log.d(TAG, "Lyrics map keys: ${lyricsMap.keys}")
                Log.d(TAG, "Lyrics map size: ${lyricsMap.size}")
                
                // Safe structure logging
                Log.d(TAG, "Converted map structure:")
                lyricsMap.forEach { (key, value) ->
                    when (value) {
                        is String -> Log.d(TAG, "  $key: String (length: ${value.length}) - ${value.take(50)}...")
                        is List<*> -> {
                            Log.d(TAG, "  $key: List with ${value.size} items")
                            if (value.isNotEmpty()) {
                                Log.d(TAG, "    First item type: ${value[0]?.javaClass?.simpleName}")
                                if (value[0] is Map<*,*>) {
                                    val firstMap = value[0] as Map<*,*>
                                    Log.d(TAG, "    First item keys: ${firstMap.keys}")
                                    // Log first few characters of text if it exists
                                    val text = firstMap["text"]
                                    if (text is String && text.isNotEmpty()) {
                                        Log.d(TAG, "    First item text preview: ${text.take(30)}...")
                                    }
                                }
                            }
                        }
                        is Map<*, *> -> Log.d(TAG, "  $key: Map with ${value.size} entries - keys: ${value.keys}")
                        is Boolean -> Log.d(TAG, "  $key: Boolean = $value")
                        is Number -> Log.d(TAG, "  $key: Number = $value")
                        else -> Log.d(TAG, "  $key: ${value?.javaClass?.simpleName} = $value")
                    }
                }

                withContext(Dispatchers.Main) {
                    // Create a properly typed response map
                    val response = hashMapOf<String, Any?>(
                        "success" to true,
                        "data" to ensureProperMapStructure(lyricsMap),
                        "songName" to songName,
                        "artistName" to artistName,
                        "debug_info" to hashMapOf(
                            "python_keys" to lyricsMap.keys.toList(),
                            "map_size" to lyricsMap.size,
                            "has_lyrics" to lyricsMap.containsKey("lyrics"),
                            "has_text" to lyricsMap.containsKey("text"),
                            "has_content" to lyricsMap.containsKey("content"),
                            "lyrics_type" to lyricsMap["lyrics"]?.javaClass?.simpleName,
                            "lyrics_size" to if (lyricsMap["lyrics"] is List<*>) (lyricsMap["lyrics"] as List<*>).size else null
                        )
                    )
                    Log.d(TAG, "Sending success response to Flutter")
                    result.success(response)
                }
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "Lyrics fetch timed out after 45 seconds", e)
                withContext(Dispatchers.Main) {
                    result.error(
                        "LYRICS_TIMEOUT",
                        "Lyrics fetch timed out - the song might not have lyrics available",
                        hashMapOf<String, Any?>(
                            "success" to false,
                            "error" to "Timeout after 45 seconds",
                            "errorCode" to "LYRICS_TIMEOUT"
                        )
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Lyrics fetch failed", e)
                withContext(Dispatchers.Main) {
                    result.error(
                        "LYRICS_ERROR",
                        "Failed to fetch lyrics: ${e.message}",
                        hashMapOf<String, Any?>(
                            "success" to false,
                            "error" to e.message,
                            "errorCode" to "LYRICS_ERROR",
                            "exception_type" to e.javaClass.simpleName
                        )
                    )
                }
            }
        }
    }

    /**
     * Ensures that all nested maps are properly typed HashMap<String, Any?>
     * This prevents type casting issues when data crosses the platform boundary
     */
    private fun ensureProperMapStructure(data: Any?): Any? {
        return when (data) {
            is Map<*, *> -> {
                val properMap = hashMapOf<String, Any?>()
                data.forEach { (key, value) ->
                    val stringKey = key?.toString() ?: ""
                    properMap[stringKey] = ensureProperMapStructure(value)
                }
                properMap
            }
            is List<*> -> {
                data.map { ensureProperMapStructure(it) }
            }
            else -> data
        }
    }


    private fun handleDispose(result: Result) {
        try {
            Log.d(TAG, "Starting dispose process...")
            
            // Cancel all coroutines first
            coroutineScope.cancel()
            job.cancel()
            
            // Clear caches
            instanceCache.clear()
            searchManager.dispose() // Now this method exists
            
            // Shutdown thread pool
            threadPoolExecutor.shutdown()
            try {
                if (!threadPoolExecutor.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS)) {
                    threadPoolExecutor.shutdownNow()
                }
            } catch (e: InterruptedException) {
                threadPoolExecutor.shutdownNow()
            }
            
            // Clean up Python objects explicitly
            try {
                // Try to call cleanup method if it exists
                musicSearcher?.callAttr("SearchStreamsCleanup")
            } catch (e: Exception) {
                Log.d(TAG, "musicSearcher cleanup method not available or failed: ${e.message}")
            }
            
            try {
                // Try to call cleanup method if it exists
                relatedFetcher?.callAttr("RelatedStreamCleanup")
            } catch (e: Exception) {
                Log.d(TAG, "relatedFetcher cleanup method not available or failed: ${e.message}")
            }
            
            // Clear Python references (close() releases the Python object reference)
            try {
                musicSearcher?.close()
                Log.d(TAG, "musicSearcher reference closed")
            } catch (e: Exception) {
                Log.w(TAG, "Error closing musicSearcher reference", e)
            }
            
            try {
                relatedFetcher?.close()
                Log.d(TAG, "relatedFetcher reference closed")
            } catch (e: Exception) {
                Log.w(TAG, "Error closing relatedFetcher reference", e)
            }
            
            try {
                pythonModule?.close()
                Log.d(TAG, "pythonModule reference closed")
            } catch (e: Exception) {
                Log.w(TAG, "Error closing pythonModule reference", e)
            }
            
            // Nullify references
            musicSearcher = null
            relatedFetcher = null
            pythonModule = null
            
            // Force Python garbage collection
            python?.getModule("gc")?.callAttr("collect")
            
            Log.d(TAG, "Dispose completed successfully")
            
            result.success(mapOf(
                "success" to true,
                "message" to "Resources disposed successfully"
            ))
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dispose resources", e)
            result.error("DISPOSE_ERROR", "Failed to dispose: ${e.message}", null)
        }
    }


    internal  fun getPythonThumbnailQuality(quality: String): PyObject {
        return try {
            val thumbnailQualityEnum = pythonModule?.get("ThumbnailQuality")
                ?: throw IllegalStateException("ThumbnailQuality enum not found")
            
            when (quality.uppercase()) {
                "LOW" -> thumbnailQualityEnum["LOW"] ?: throw Exception("LOW quality not found")
                "MED" -> thumbnailQualityEnum["MED"] ?: throw Exception("MED quality not found")
                "HIGH" -> thumbnailQualityEnum["HIGH"] ?: throw Exception("HIGH quality not found")
                "VERY_HIGH" -> thumbnailQualityEnum["VERY_HIGH"] ?: throw Exception("VERY_HIGH quality not found")
                else -> throw IllegalArgumentException("Unknown thumbnail quality: $quality")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting thumbnail quality", e)
            throw e
        }
    }

    internal  fun getPythonAudioQuality(quality: String): PyObject {
        return try {
            val audioQualityEnum = pythonModule?.get("AudioQuality")
                ?: throw IllegalStateException("AudioQuality enum not found")
            
            when (quality.uppercase()) {
                "LOW" -> audioQualityEnum["LOW"] ?: throw Exception("LOW quality not found")
                "MED" -> audioQualityEnum["MED"] ?: throw Exception("MED quality not found")
                "HIGH" -> audioQualityEnum["HIGH"] ?: throw Exception("HIGH quality not found")
                "VERY_HIGH" -> audioQualityEnum["VERY_HIGH"] ?: throw Exception("VERY_HIGH quality not found")
                else -> throw IllegalArgumentException("Unknown audio quality: $quality")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting audio quality", e)
            throw e
        }
    }

    internal fun convertPythonDictToMap(pyObject: PyObject?): Map<String, Any?> {
        if (pyObject == null) {
            return emptyMap()
        }

        val resultMap = mutableMapOf<String, Any?>()
        
        try {
            val keysList = python?.getBuiltins()?.callAttr("list", pyObject.callAttr("keys"))
            
            if (keysList != null) {
                val size = keysList.callAttr("__len__").toInt()
                
                for (i in 0 until size) {
                    try {
                        val key = keysList.callAttr("__getitem__", i).toString()
                        val value = pyObject.callAttr("__getitem__", key)
                        
                        resultMap[key] = convertPythonValue(value)
                    } catch (e: Exception) {
                        Log.w(TAG, "Error processing key at index $i", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error converting Python dict to map", e)
        }
        
        return resultMap
    }

    private fun convertPythonValue(pyValue: PyObject?): Any? {
        return when {
            pyValue == null -> null
            pyValue.isNone -> null
            pyValue.isTrue -> true
            pyValue.isFalse -> false
            pyValue.isString -> pyValue.toString()
            pyValue.isNumber -> {
                try {
                    pyValue.toLong()
                } catch (e: Exception) {
                    try {
                        pyValue.toDouble()
                    } catch (e: Exception) {
                        pyValue.toString()
                    }
                }
            }
            // Handle Python lists - use a safer type checking method
            isPythonList(pyValue) -> {
                try {
                    val listSize = pyValue.callAttr("__len__").toInt()
                    val resultList = mutableListOf<Any?>()
                    
                    for (i in 0 until listSize) {
                        val item = pyValue.callAttr("__getitem__", i)
                        resultList.add(convertPythonValue(item))
                    }
                    
                    resultList
                } catch (e: Exception) {
                    Log.w(TAG, "Error converting Python list", e)
                    pyValue.toString()
                }
            }
            // Handle Python dictionaries - use a safer type checking method
            isPythonDict(pyValue) -> {
                try {
                    convertPythonDictToMap(pyValue)
                } catch (e: Exception) {
                    Log.w(TAG, "Error converting nested Python dict", e)
                    pyValue.toString()
                }
            }
            else -> pyValue.toString()
        }
    }

    private fun isPythonList(pyValue: PyObject): Boolean {
        return try {
            // Try to call list-specific methods to detect if it's a list
            pyValue.callAttr("__len__")
            pyValue.callAttr("__getitem__", 0)
            true
        } catch (e: Exception) {
            try {
                // Alternative: check if it has list-like behavior
                python?.getBuiltins()?.callAttr("isinstance", pyValue, python?.getBuiltins()?.callAttr("list"))?.toBoolean() == true
            } catch (e2: Exception) {
                false
            }
        }
    }

    private fun isPythonDict(pyValue: PyObject): Boolean {
        return try {
            // Try to call dict-specific methods to detect if it's a dict
            pyValue.callAttr("keys")
            pyValue.callAttr("values")
            true
        } catch (e: Exception) {
            try {
                // Alternative: check if it has dict-like behavior
                python?.getBuiltins()?.callAttr("isinstance", pyValue, python?.getBuiltins()?.callAttr("dict"))?.toBoolean() == true
            } catch (e2: Exception) {
                false
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try {
            coroutineScope.cancel()
            instanceCache.clear()
            threadPoolExecutor.shutdown()
        } catch (e: Exception) {
            Log.e(TAG, "Error during cleanup", e)
        }
    }
}