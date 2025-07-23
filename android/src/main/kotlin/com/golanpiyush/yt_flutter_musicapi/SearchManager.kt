package com.golanpiyush.yt_flutter_musicapi

import com.chaquo.python.PyObject
import kotlinx.coroutines.Job
import java.util.concurrent.ConcurrentHashMap
import android.util.Log

class SearchManager {
    private val activeSearches = ConcurrentHashMap<String, SearchHandle>()
    private val lock = Any()

    fun registerSearch(
        searchId: String,
        searchType: String,
        generator: PyObject,
        coroutineJob: Job
    ): String {
        synchronized(lock) {
            try {
                cancelType(searchType)
                
                val handle = SearchHandle(generator, coroutineJob, searchType)
                activeSearches[searchId] = handle
                Log.d("YTMusicAPI", "Registered new search: $searchId of type $searchType")
                return searchId
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "Failed to register search: ${e.message}", e)
                throw RuntimeException("Search registration failed: ${e.message}")
            }
        }
    }

    fun cancelSearch(searchId: String): Boolean {
        synchronized(lock) {
            val handle = activeSearches.remove(searchId) ?: run {
                Log.w("YTMusicAPI", "Search $searchId not found for cancellation")
                return false
            }
            
            try {
                handle.cancel()
                Log.d("YTMusicAPI", "Cancelled search: $searchId")
                return true
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "Failed to cancel search $searchId: ${e.message}", e)
                return false
            }
        }
    }

    fun cancelType(searchType: String): Int {
        synchronized(lock) {
            val toRemove = activeSearches.filter { it.value.searchType == searchType }.keys
            var cancelled = 0
            
            toRemove.forEach { searchId ->
                try {
                    if (cancelSearch(searchId)) {
                        cancelled++
                    }
                } catch (e: Exception) {
                    Log.w("YTMusicAPI", "Error canceling $searchType search $searchId: ${e.message}")
                }
            }
            
            Log.d("YTMusicAPI", "Cancelled $cancelled searches of type $searchType")
            return cancelled
        }
    }

    fun cancelAll(): Int {
        synchronized(lock) {
            val count = activeSearches.size
            try {
                activeSearches.values.forEach { handle ->
                    try {
                        handle.cancel()
                    } catch (e: Exception) {
                        Log.w("YTMusicAPI", "Error closing search handle: ${e.message}")
                    }
                }
                activeSearches.clear()
                Log.d("YTMusicAPI", "Cancelled all $count active searches")
                return count
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "Failed to cancel all searches: ${e.message}")
                return 0
            }
        }
    }

    fun isActive(searchId: String): Boolean {
        synchronized(lock) {
            return try {
                if (activeSearches.containsKey(searchId)) {
                    activeSearches[searchId]?.updateLastAccessed()
                    true
                } else false
            } catch (e: Exception) {
                Log.w("YTMusicAPI", "Error checking search activity for $searchId: ${e.message}")
                false
            }
        }
    }

    fun getActiveCounts(): Map<String, Int> {
        synchronized(lock) {
            return try {
                val counts = mutableMapOf<String, Int>()
                activeSearches.values.forEach { handle ->
                    counts[handle.searchType] = counts.getOrDefault(handle.searchType, 0) + 1
                }
                counts
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "Failed to get active counts: ${e.message}")
                emptyMap()
            }
        }
    }

    fun cleanupStale(timeoutMillis: Long = 300_000): Int {
        synchronized(lock) {
            val now = System.currentTimeMillis()
            val toRemove = activeSearches.filter { 
                now - it.value.lastAccessed > timeoutMillis 
            }.keys
            
            var cleaned = 0
            toRemove.forEach { searchId ->
                try {
                    if (cancelSearch(searchId)) {
                        cleaned++
                    }
                } catch (e: Exception) {
                    Log.w("YTMusicAPI", "Error cleaning up stale search $searchId: ${e.message}")
                }
            }
            
            if (cleaned > 0) {
                Log.i("YTMusicAPI", "Cleaned up $cleaned stale searches")
            }
            return cleaned
        }
    }

    inner class SearchHandle(
        val generator: PyObject,
        val job: Job,
        val searchType: String,
        var lastAccessed: Long = System.currentTimeMillis()
    ) {
        fun cancel() {
            try {
                // Fixed: Using cancel() without message or with proper CancellationException
                job.cancel()
                generator.callAttr("close")
            } catch (e: Exception) {
                Log.e("YTMusicAPI", "Error cancelling search handle", e)
            }
        }
        
        fun updateLastAccessed() {
            lastAccessed = System.currentTimeMillis()
        }
    }
}