import base64
from enum import Enum
import re
from typing import Any, Dict, Generator, List, Optional, Union
import warnings
import random
import time
import socket
from urllib.error import URLError
import requests
import threading
# Suppress warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

ytmv = "1.10.3"
ytdlpv = "2025.06.30"

# For Debugging
try:
    from ytmusicapi import YTMusic
    import yt_dlp
    print("✅ Imported ytmusicapi and yt-dlp successfully")
except Exception as e:
    print("❌ Failed to import:", e)


_instance = None

@classmethod

def get_instance(cls):
    if cls._instance is None:
        cls._instance = cls()
    return cls._instance

def check_ytmusic_and_ytdlp_ready():
    try:
        # Import and get version info
        import ytmusicapi
        import yt_dlp
        
        # Initialize YTMusic
        ytmusic = ytmusicapi.YTMusic()
        
        # Initialize yt-dlp
        ydl = yt_dlp.YoutubeDL()
        
        # Get version information
        ytmusic_version = ytmusicapi.__version__ if hasattr(ytmusicapi, '__version__') else 'Unknown'
        ytdlp_version = yt_dlp.version.__version__ if hasattr(yt_dlp, 'version') else 'Unknown'
        
        print("✅ YTMusic and yt-dlp initialized successfully")
        
        return {
            "success": True,
            "ytmusic_ready": True,
            "ytmusic_version": ytmusic_version,
            "ytdlp_ready": True,
            "ytdlp_version": ytdlp_version,
            "message": "✅ All systems ready and working.."
        }
    except Exception as e:
        print(f"❌ Initialization failed: {e}")
        return {
            "success": False,
            "message": f"Initialization failed: {str(e)}",
            "ytmusic_ready": False,
            "ytdlp_ready": False
        }

def debug_dependencies():
    import sys
    from importlib.util import find_spec
    
    dependencies = {
        'ytmusicapi': find_spec("ytmusicapi") is not None,
        'yt_dlp': find_spec("yt_dlp") is not None,
        'python_version': sys.version,
        'python_path': sys.path
    }
    return dependencies


# Enums for quality settings
class AudioQuality(Enum):
    LOW = 0
    MED = 1
    HIGH = 2
    VERY_HIGH = 3

class ThumbnailQuality(Enum):
    LOW = 0
    MED = 1
    HIGH = 2
    VERY_HIGH = 3

class YTMusicSearcher:
    def __init__(self, proxy: Optional[str] = None, country: str = "US"):
        self.proxy = proxy
        self.country = country.upper() if country else "US"
        self.ytmusic = None
        self._initialize_ytmusic()
        
    def _initialize_ytmusic(self):
        max_retries = 3
        for attempt in range(max_retries):
            try:
                self.ytmusic = YTMusic()
                return
            except Exception as e:
                if attempt == max_retries - 1:
                    raise ConnectionError(f"Failed to initialize YTMusic after {max_retries} attempts: {str(e)}")
                time.sleep(2 ** attempt)

    def _get_ytdlp_instance(self, format_selector: str):
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "nocheckcertificate": True,
            "format": format_selector,
            "extract_flat": False,
            "age_limit": 99,
            "socket_timeout": 30,
            "source_address": "0.0.0.0",
            "force_ipv4": True,
            "retries": 3,
            "fragment_retries": 10,
            "extractor_retries": 3,
            "buffersize": 1024 * 1024,
            "http_chunk_size": 1024 * 1024,
            "extractor_args": {
                "youtube": {
                    "player_client": ["android", "web"],
                    "player_skip": ["configs"],
                    "skip": ["translated_subs", "hls"]
                }
            },
            "compat_opts": ["no-youtube-unavailable-videos"],
            "headers": self._generate_headers()
        }

        if self.proxy:
            ydl_opts["proxy"] = self.proxy
            ydl_opts["proxy_headers"] = ydl_opts["headers"]

        return yt_dlp.YoutubeDL(ydl_opts)

    def _generate_headers(self):
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ]
        
        return {
            'User-Agent': random.choice(user_agents),
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br'
        }

    def get_audio_url(self, video_id: str, quality: AudioQuality) -> Optional[str]:
        format_strategies = [
            "bestaudio[ext=m4a]/bestaudio[ext=mp4]/best[ext=m4a]/best[ext=mp4]",
            "251/250/249/140/139/171/18/22",
            "bestaudio/best",
            "worstaudio/worst"
        ]
        
        for format_selector in format_strategies:
            try:
                ydl = self._get_ytdlp_instance(format_selector)
                time.sleep(random.uniform(0.5, 1.5))
                
                info = ydl.extract_info(
                    f"https://www.youtube.com/watch?v={video_id}",
                    download=False,
                    process=False
                )
                info = ydl.process_ie_result(info, download=False)
                
                if info.get('is_live') or info.get('availability') == 'unavailable':
                    continue
                
                if info.get('drm') or any(f.get('drm') for f in info.get('formats', [])):
                    continue
                
                requested_formats = info.get('requested_formats', [info])
                formats = info.get('formats', requested_formats)
                
                audio_formats = [
                    f for f in formats 
                    if f.get('acodec') != 'none' 
                    and f.get('url')
                    and not any(x in f['url'].lower() for x in ["manifest", ".m3u8"])
                ]
                
                if not audio_formats:
                    continue
                
                audio_formats.sort(key=lambda f: f.get('abr', 0) or f.get('tbr', 0) or 0, reverse=True)
                return audio_formats[0]['url']
                        
            except yt_dlp.utils.DownloadError as e:
                if "HTTP Error 403" in str(e):
                    time.sleep(2)
                    continue
                if "unavailable" in str(e).lower():
                    break
                continue
            except (URLError, socket.timeout, ConnectionError):
                time.sleep(2)
                continue
            except Exception:
                continue
        
        return None
    
    def get_hq_album_art_from_ytdlp(self, video_id: str) -> Optional[str]:
        """Get high quality album art using yt-dlp from video metadata"""
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "skip_download": True,
                "nocheckcertificate": True,
                "extract_flat": False,
                "socket_timeout": 30,
                "source_address": "0.0.0.0",
                "force_ipv4": True,
                "retries": 2,
                "headers": self._generate_headers()
            }
            
            if self.proxy:
                ydl_opts["proxy"] = self.proxy
                ydl_opts["proxy_headers"] = ydl_opts["headers"]
            
            ydl = yt_dlp.YoutubeDL(ydl_opts)
            
            info = ydl.extract_info(
                f"https://www.youtube.com/watch?v={video_id}",
                download=False
            )
            
            # First try to get album art from metadata
            album_art_url = self._get_album_art_from_metadata(info)
            
            # If no album art from metadata, fall back to high quality thumbnails
            if not album_art_url:
                thumbnails = info.get('thumbnails', [])
                if thumbnails:
                    # Filter for high quality thumbnails (prefer square ones for album art)
                    hq_thumbnails = [
                        t for t in thumbnails 
                        if t.get('width', 0) >= 720 and t.get('height', 0) >= 720
                    ]
                    
                    if hq_thumbnails:
                        # Sort by resolution and prefer square aspect ratios
                        hq_thumbnails.sort(
                            key=lambda t: (
                                abs(1.0 - (t.get('width', 1) / t.get('height', 1))),  # Prefer square
                                (t.get('width', 0) * t.get('height', 0))  # Then by resolution
                            ),
                            reverse=True
                        )
                        album_art_url = hq_thumbnails[0].get('url', '')
                    else:
                        # Fall back to highest resolution thumbnail
                        thumbnails.sort(
                            key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                            reverse=True
                        )
                        album_art_url = thumbnails[0].get('url', '')
            
            if album_art_url:
                print(f"HQ Album Art found: {album_art_url}")
                return album_art_url
            
            return None
            
        except Exception as e:
            print(f"Error getting HQ album art for {video_id}: {e}")
            return None

    def _get_album_art_from_metadata(self, info: dict) -> Optional[str]:
        """Try to get album art from video metadata"""
        try:
            # Check for album art in various metadata fields
            album_art_fields = ['album_art', 'album_artwork', 'artwork', 'cover']
            
            for field in album_art_fields:
                if info.get(field):
                    return info[field]
            
            # Try to get from uploader avatar if it's an official channel
            uploader = info.get('uploader', '').lower()
            if any(keyword in uploader for keyword in ['official', 'records', 'music', 'vevo']):
                uploader_avatar = info.get('uploader_avatar_url')
                if uploader_avatar:
                    return uploader_avatar
            
            return None
            
        except Exception:
            return None

    def get_youtube_music_album_art(self, video_id: str) -> Optional[str]:
        """Get album art specifically from YouTube Music metadata"""
        try:
            # Use YTMusic to get song details which might have better album art
            song_info = self.ytmusic.get_song(video_id)
            
            # Extract album art from song info
            thumbnails = song_info.get('videoDetails', {}).get('thumbnail', {}).get('thumbnails', [])
            
            if thumbnails:
                # Sort by resolution to get highest quality
                thumbnails.sort(
                    key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                    reverse=True
                )
                
                # Prefer square thumbnails for album art
                square_thumbnails = [
                    t for t in thumbnails 
                    if abs(1.0 - (t.get('width', 1) / t.get('height', 1))) < 0.1
                ]
                
                if square_thumbnails:
                    return square_thumbnails[0].get('url', '')
                else:
                    return thumbnails[0].get('url', '')
            
            return None
            
        except Exception as e:
            print(f"Error getting YouTube Music album art for {video_id}: {e}")
            return None

    def _get_album_art_unified(self, video_id: str, song_data: dict, thumb_quality: ThumbnailQuality) -> str:
        """Unified method to get album art with quality settings"""
        album_art = ""
        
        if thumb_quality in [ThumbnailQuality.HIGH, ThumbnailQuality.VERY_HIGH]:
            print(f"🖼️ Getting HQ album art for: {video_id}")
            
            # Method 1: Try YouTube Music specific album art
            album_art = self.get_youtube_music_album_art(video_id)
            
            # Method 2: Try yt-dlp with album art focus
            if not album_art:
                album_art = self.get_hq_album_art_from_ytdlp(video_id)
            
            # Method 3: Fallback to song thumbnails
            if not album_art:
                print("🔄 Falling back to song thumbnails")
                thumbnails = song_data.get("thumbnails", [])
                if thumbnails:
                    base_url = thumbnails[-1].get("url", "")
                    if base_url:
                        if thumb_quality == ThumbnailQuality.HIGH:
                            album_art = re.sub(r'w\d+-h\d+', 'w320-h320', base_url)
                        elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                            album_art = re.sub(r'w\d+-h\d+', 'w544-h544', base_url)
                        else:
                            album_art = base_url
            
            # Apply quality settings to HQ URLs if they contain YouTube image patterns
            if album_art and any(pattern in album_art for pattern in ['googleusercontent.com', 'ytimg.com', 'youtube.com']):
                if thumb_quality == ThumbnailQuality.HIGH:
                    album_art = re.sub(r'w\d+-h\d+', 'w320-h320', album_art)
                elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                    album_art = re.sub(r'w\d+-h\d+', 'w544-h544', album_art)
        else:
            # Use song thumbnails for LOW and MED quality
            thumbnails = song_data.get("thumbnails", [])
            if thumbnails:
                base_url = thumbnails[-1].get("url", "")
                if base_url:
                    if thumb_quality == ThumbnailQuality.LOW:
                        album_art = re.sub(r'w\d+-h\d+', 'w60-h60', base_url)
                    elif thumb_quality == ThumbnailQuality.MED:
                        album_art = re.sub(r'w\d+-h\d+', 'w120-h120', base_url)
                    else:
                        album_art = base_url
        
        print(f"🖼️ Album art URL: {album_art}")
        return album_art

    def _get_audio_url_with_retries(self, video_id: str, audio_quality: AudioQuality) -> Optional[str]:
        """Unified method to get audio URL with retries"""
        print(f"🎵 Getting audio URL for: {video_id}")
        
        for attempt in range(3):
            try:
                audio_url = self.get_audio_url(video_id, audio_quality)
                if audio_url:
                    print(f"✅ Got audio URL on attempt {attempt + 1}")
                    return audio_url
                else:
                    print(f"⚠️ No audio URL on attempt {attempt + 1}")
            except Exception as e:
                print(f"❌ Audio URL attempt {attempt + 1} failed: {e}")
            time.sleep(1)
        
        return None

    def _build_song_data(self, video_id: str, title: str, artists: str, duration: str, 
                        song_data: dict, thumb_quality: ThumbnailQuality, audio_quality: AudioQuality,
                        include_audio_url: bool, include_album_art: bool, **extra_fields) -> dict:
        """Unified method to build song data dictionary"""
        result = {
            "title": title,
            "artists": artists,
            "videoId": video_id,
            "duration": duration,
            **extra_fields
        }
        
        # Get album art
        if include_album_art:
            album_art = self._get_album_art_unified(video_id, song_data, thumb_quality)
            result["albumArt"] = album_art
        
        # Get audio URL
        if include_audio_url:
            audio_url = self._get_audio_url_with_retries(video_id, audio_quality)
            if audio_url:
                result["audioUrl"] = audio_url
        
        return result

    def get_music_details(
        self,
        query: str,
        limit: int = 50,
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        inspector = SearchInspector.get_instance()
        search_id = f"search_{query[:20]}_{int(time.time())}"
        
        def generator():
            nonlocal query, limit, thumb_quality, audio_quality, include_audio_url, include_album_art
            print(f"Starting search for query: {query}, limit: {limit}")
            processed_count = 0
            skipped_count = 0
            max_attempts = limit * 3
            
            results = None
            for attempt in range(3):
                if not inspector.is_active(search_id):
                    print("Search cancelled by inspector")
                    return
                    
                try:
                    print(f"Attempt {attempt + 1} to search...")
                    results = self.ytmusic.search(query, filter="songs", limit=max_attempts)
                    print(f"Search returned {len(results) if results else 0} results")
                    break
                except Exception as e:
                    print(f"Search attempt {attempt + 1} failed: {e}")
                    if attempt == 2:
                        print("All search attempts failed, returning empty")
                        return
                    time.sleep(2 ** attempt)
                    self._initialize_ytmusic()

            if not results:
                print("No results found")
                return

            print(f"Processing {len(results)} results...")
            for i, item in enumerate(results):
                if not inspector.is_active(search_id):
                    print("Search cancelled during processing")
                    return
                    
                if processed_count >= limit:
                    print(f"Reached limit of {limit} items")
                    break
                    
                try:
                    video_id = item.get("videoId")
                    if not video_id:
                        print(f"Skipping item {i + 1}: No videoId")
                        skipped_count += 1
                        continue

                    title = item.get("title", "Unknown Title")
                    artists = ", ".join(a.get("name", "Unknown") for a in item.get("artists", [])) or "Unknown Artist"
                    duration = item.get("duration")
                    year = item.get("year")

                    print(f"Basic info extracted - Title: {title}, Artists: {artists}")

                    # Build song data using unified method
                    song_data = self._build_song_data(
                        video_id=video_id,
                        title=title,
                        artists=artists,
                        duration=duration,
                        song_data=item,
                        thumb_quality=thumb_quality,
                        audio_quality=audio_quality,
                        include_audio_url=include_audio_url,
                        include_album_art=include_album_art,
                        year=year
                    )

                    # Check if we should yield this result
                    should_yield = not include_audio_url or song_data.get("audioUrl")
                    print(f"Should yield: {should_yield}")

                    if should_yield:
                        processed_count += 1
                        print(f"Yielding song data {processed_count}: {song_data}")
                        yield song_data
                    else:
                        print(f"Skipping item {i + 1}: Could not get audio URL")
                        skipped_count += 1

                except Exception as e:
                    print(f"Error processing item {i + 1}: {e}")
                    skipped_count += 1
                    continue

            print(f"Finished processing. Found {processed_count} valid results (skipped {skipped_count})")

        # Register the search with inspector and yield results
        gen = generator()
        inspector.register_search(search_id, "music_search", gen)
        
        try:
            yield from gen
        finally:
            inspector.cancel_search(search_id)

    def get_song_details(
        self,
        songs: List[Dict[str, str]],
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.VERY_HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True,
        mode: str = "batch"
    ) -> Union[Generator[dict, None, None], Optional[dict]]:
        """Get song details with flexible return type based on mode"""
        if mode not in ["single", "batch"]:
            raise ValueError("Mode must be either 'single' or 'batch'")

        if mode == "single":
            if not songs:
                return None
            
            song = songs[0]
            song_name = song.get("song_name", "")
            artist_name = song.get("artist_name", "")
            
            if not song_name or not artist_name:
                print("⚠️ Missing song_name or artist_name")
                return None
            
            print(f"\n🔍 Processing single song: '{song_name}' by '{artist_name}'")
            
            try:
                details = self._get_single_song_details(
                    song_name=song_name,
                    artist_name=artist_name,
                    thumb_quality=thumb_quality,
                    audio_quality=audio_quality,
                    include_audio_url=include_audio_url,
                    include_album_art=include_album_art
                )
                return details
            except Exception as e:
                print(f"❌ Error processing song '{song_name}': {str(e)}")
                return None
        else:
            # Batch mode - return generator with yield
            print(f"🎶 Processing batch of {len(songs)} songs")
            return self._process_batch_songs(
                songs=songs,
                thumb_quality=thumb_quality,
                audio_quality=audio_quality,
                include_audio_url=include_audio_url,
                include_album_art=include_album_art
            )

    def _get_single_song_details(
        self,
        song_name: str,
        artist_name: str,
        thumb_quality: ThumbnailQuality,
        audio_quality: AudioQuality,
        include_audio_url: bool,
        include_album_art: bool
    ) -> Optional[dict]:
        """Internal method to get details for a single song"""
        query = f"{song_name} {artist_name}"
        video_id = None
        song_data = None
        
        for attempt in range(3):
            try:
                results = self.ytmusic.search(query, filter="songs", limit=5)
                
                if not results:
                    print("❌ No results found for query")
                    return None
                    
                # Find best matching song using string matching
                best_match = None
                best_score = 0
                
                # Pre-process search terms
                search_song = song_name.lower().strip()
                search_artist = artist_name.lower().strip()
                
                for item in results:
                    title = item.get("title", "").lower().strip()
                    artists = [a.get("name", "").lower().strip() for a in item.get("artists", [])]
                    
                    # Calculate title match (check if search term is in title)
                    title_match = 100 if search_song in title else 0
                    
                    # Calculate artist match (check if any artist matches)
                    artist_match = 100 if any(
                        search_artist in artist for artist in artists
                    ) else 0
                    
                    # Simple scoring - prioritize exact matches
                    if title_match == 100 and artist_match == 100:
                        # Perfect match found, use it immediately
                        song_data = item
                        video_id = item.get("videoId")
                        break
                        
                    # Otherwise calculate partial score
                    total_score = (title_match * 0.6) + (artist_match * 0.4)
                    
                    if total_score > best_score:
                        best_score = total_score
                        best_match = item
                
                if video_id:  # If we found perfect match and broke early
                    break
                    
                # Use best match if we have one, otherwise first result
                if best_match and best_score > 0:
                    song_data = best_match
                    print(f"Using best match (score: {best_score})")
                else:
                    song_data = results[0]
                    print("⚠️ Using first result (no good matches found)")
                
                video_id = song_data.get("videoId")
                if video_id:
                    break
                    
            except Exception as e:
                print(f"❌ Search attempt {attempt + 1} failed: {e}")
                if attempt == 2:
                    return None
                time.sleep(2 ** attempt)
                self._initialize_ytmusic()
        
        if not video_id or not song_data:
            print("❌ Song not found")
            return None
        
        print(f"✅ Found song: {song_data.get('title')} (ID: {video_id})")
        
        # Extract basic info
        title = song_data.get("title", "Unknown Title")
        artists = ", ".join(a.get("name", "Unknown") for a in song_data.get("artists", [])) or "Unknown Artist"
        duration = song_data.get("duration")
        
        # Build song data using unified method
        result = {
            "title": title,
            "artists": artists,
            "videoId": video_id,
            "duration": duration,
        }
        
        # Get album art if requested
        if include_album_art:
            try:
                album_art = self._get_album_art_unified(
                    video_id, 
                    song_data, 
                    thumb_quality
                )
                result["albumArt"] = album_art
            except Exception as e:
                print(f"❌ Error getting album art: {e}")
                result["albumArt"] = None
        
        # Get audio URL if requested
        if include_audio_url:
            try:
                audio_url = self._get_audio_url_with_retries(video_id, audio_quality)
                result["audioUrl"] = audio_url
            except Exception as e:
                print(f"❌ Error getting audio URL: {e}")
                result["audioUrl"] = None
        
        return result
        
    def _process_batch_songs(
        self,
        songs: List[Dict[str, str]],
        thumb_quality: ThumbnailQuality,
        audio_quality: AudioQuality,
        include_audio_url: bool,
        include_album_art: bool
    ) -> Generator[dict, None, None]:
        """Internal method to process songs in batch mode"""
        total_songs = len(songs)
        processed_count = 0
        success_count = 0
        
        print(f"🎶 Starting batch processing of {total_songs} songs")
        
        for i, song in enumerate(songs, 1):
            song_name = song.get("song_name", "").strip()
            artist_name = song.get("artist_name", "").strip()

            if not song_name or not artist_name:
                print(f"⚠️ Skipping item {i}: Missing song_name or artist_name")
                continue

            print(f"\n🔍 Processing song {i}/{total_songs}: '{song_name}' by '{artist_name}'")
            processed_count += 1

            try:
                details = self._get_single_song_details(
                    song_name=song_name,
                    artist_name=artist_name,
                    thumb_quality=thumb_quality,
                    audio_quality=audio_quality,
                    include_audio_url=include_audio_url,
                    include_album_art=include_album_art
                )

                if details:
                    success_count += 1
                    print(f"✅ Successfully processed song {i}")
                    yield details
                else:
                    print(f"❌ Song not found: '{song_name}' by '{artist_name}'")
                    yield {
                        "error": f"Song not found: '{song_name}'",
                        "success": False,
                        "song_name": song_name,
                        "artist_name": artist_name
                    }

            except Exception as e:
                print(f"❌ Error processing song '{song_name}': {str(e)}")
                yield {
                    "error": str(e),
                    "success": False,
                    "song_name": song_name,
                    "artist_name": artist_name
                }

            # Small delay between songs to avoid rate limiting
            if i < total_songs:
                time.sleep(0.5)

        print(f"✅ Batch processing completed. Success: {success_count}/{processed_count}")

    def stream_song_details(
        self,
        songs: List[Dict[str, str]],
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.VERY_HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        inspector = SearchInspector.get_instance()
        search_id = f"batch_{int(time.time())}"
        
        def generator():
            nonlocal songs, thumb_quality, audio_quality, include_audio_url, include_album_art
            total_songs = len(songs)
            processed_count = 0
            success_count = 0
            
            print(f"🎶 Starting streaming of {total_songs} songs")
            
            for i, song in enumerate(songs, 1):
                if not inspector.is_active(search_id):
                    print("Streaming cancelled by inspector")
                    return
                    
                song_name = song.get("song_name", "").strip()
                artist_name = song.get("artist_name", "").strip()

                if not song_name or not artist_name:
                    print(f"⚠️ Skipping item {i}: Missing song_name or artist_name")
                    yield {
                        "error": "Missing song_name or artist_name",
                        "success": False,
                        "song_name": song_name,
                        "artist_name": artist_name
                    }
                    continue

                print(f"\n🔍 Processing song {i}/{total_songs}: '{song_name}' by '{artist_name}'")
                processed_count += 1

                try:
                    details = self._get_single_song_details(
                        song_name=song_name,
                        artist_name=artist_name,
                        thumb_quality=thumb_quality,
                        audio_quality=audio_quality,
                        include_audio_url=include_audio_url,
                        include_album_art=include_album_art
                    )

                    if details:
                        success_count += 1
                        print(f"✅ Successfully processed song {i}")
                        yield {
                            **details,
                            "success": True,
                            "processed": processed_count,
                            "total": total_songs
                        }
                    else:
                        print(f"❌ Song not found: '{song_name}' by '{artist_name}'")
                        yield {
                            "error": f"Song not found: '{song_name}'",
                            "success": False,
                            "song_name": song_name,
                            "artist_name": artist_name,
                            "processed": processed_count,
                            "total": total_songs
                        }

                except Exception as e:
                    print(f"❌ Error processing song '{song_name}': {str(e)}")
                    yield {
                        "error": str(e),
                        "success": False,
                        "song_name": song_name,
                        "artist_name": artist_name,
                        "processed": processed_count,
                        "total": total_songs
                    }

                # Small delay between songs to avoid rate limiting
                if i < total_songs:
                    time.sleep(0.5)

            print(f"✅ Streaming completed. Success: {success_count}/{processed_count}")

        # Register the search with inspector and yield results
        gen = generator()
        inspector.register_search(search_id, "batch_stream", gen)
        
        try:
            yield from gen
        finally:
            inspector.cancel_search(search_id)

    def get_artist_songs(
        self,
        artist_name: str,
        limit: int = 65,
        thumb_quality: str = "VERY_HIGH",
        audio_quality: str = "HIGH",
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[Dict[str, Any], None, None]:
        inspector = SearchInspector.get_instance()
        search_id = f"artist_{artist_name[:20]}_{int(time.time())}"
        
        def generator():
            nonlocal artist_name, limit, thumb_quality, audio_quality, include_audio_url, include_album_art
            def log(message: str):
                print(f"[ArtistSongs] {message}")

            log(f"Starting streaming search for {artist_name} (limit: {limit})")
            
            processed_count = 0
            retry_count = 0
            max_retries = 3
            
            while retry_count < max_retries and processed_count < limit:
                if not inspector.is_active(search_id):
                    log("Artist search cancelled by inspector")
                    return
                    
                try:
                    # Search for artist
                    artist_results = self.ytmusic.search(
                        artist_name, 
                        filter="artists", 
                        limit=limit
                    )
                    
                    if not artist_results:
                        log("No artist results found")
                        break
                        
                    # Find best matching artist
                    target_artist = next(
                        (a for a in artist_results 
                        if a.get('artist', '').lower() == artist_name.lower()),
                        artist_results[0]
                    )
                    
                    browse_id = target_artist.get('browseId')
                    if not browse_id:
                        log("No browseId found for artist")
                        break
                        
                    log(f"Found artist: {target_artist.get('artist')} ({browse_id})")
                    
                    # Get artist details
                    artist_info = self.ytmusic.get_artist(browse_id)
                    
                    # Extract songs from different possible locations
                    song_items = []
                    
                    # Check primary songs section
                    if 'songs' in artist_info and artist_info['songs']:
                        songs_data = artist_info['songs']
                        if isinstance(songs_data, dict):
                            song_items.extend(songs_data.get('results', []))
                        elif isinstance(songs_data, list):
                            song_items.extend(songs_data)
                    
                    # Fallback to album tracks if needed
                    if not song_items and 'albums' in artist_info:
                        for album in artist_info['albums'].get('results', [])[:3]:
                            try:
                                if not inspector.is_active(search_id):
                                    log("Artist search cancelled during album processing")
                                    return
                                    
                                album_tracks = self.ytmusic.get_album(
                                    album['browseId']
                                ).get('tracks', [])
                                song_items.extend(album_tracks)
                            except Exception as e:
                                log(f"Error getting album {album.get('title')}: {str(e)}")
                                continue
                    
                    # Process and yield each song one by one
                    for song in song_items:
                        if not inspector.is_active(search_id):
                            log("Artist search cancelled during song processing")
                            return
                            
                        if processed_count >= limit:
                            break
                            
                        try:
                            if not isinstance(song, dict):
                                continue
                                
                            video_id = song.get("videoId")
                            if not video_id:
                                continue
                                
                            # Basic info
                            title = song.get("title", "Unknown Title")
                            artists = ", ".join(
                                a.get("name", "Unknown") 
                                for a in song.get("artists", [])
                            ) or artist_name
                            duration = song.get("duration")
                            
                            # Album art
                            album_art = ""
                            if include_album_art:
                                try:
                                    if thumb_quality in ["HIGH", "VERY_HIGH"]:
                                        album_art = self.get_youtube_music_album_art(video_id)
                                        if not album_art:
                                            album_art = self.get_hq_album_art_from_ytdlp(video_id)
                                    
                                    if not album_art:
                                        thumbnails = song.get("thumbnails", [])
                                        if thumbnails:
                                            base_url = thumbnails[-1].get("url", "")
                                            if base_url:
                                                if thumb_quality == "HIGH":
                                                    album_art = re.sub(r'w\d+-h\d+', 'w320-h320', base_url)
                                                elif thumb_quality == "VERY_HIGH":
                                                    album_art = re.sub(r'w\d+-h\d+', 'w544-h544', base_url)
                                                else:
                                                    album_art = base_url
                                except Exception as e:
                                    log(f"Error getting album art: {str(e)}")
                            
                            # Audio URL
                            audio_url = None
                            if include_audio_url:
                                try:
                                    audio_url = self.get_audio_url(video_id, audio_quality)
                                except Exception as e:
                                    log(f"Error getting audio URL: {str(e)}")
                            
                            # Only yield if we have audio URL or don't need it
                            if include_audio_url and not audio_url:
                                continue
                                
                            processed_count += 1
                            
                            yield {
                                "title": title,
                                "artists": artists,
                                "videoId": video_id,
                                "duration": duration,
                                "albumArt": album_art if include_album_art else None,
                                "audioUrl": audio_url if include_audio_url else None,
                                "artistName": artist_name
                            }
                            
                        except Exception as e:
                            log(f"Error processing song: {str(e)}")
                            continue
                            
                    break  # Successfully processed
                    
                except Exception as e:
                    retry_count += 1
                    log(f"Attempt {retry_count} failed: {str(e)}")
                    if retry_count < max_retries:
                        time.sleep(2 ** retry_count)
                        self._initialize_ytmusic()
                    else:
                        log("Max retries reached")
                        break
            
            log(f"Streamed {processed_count} songs")

        # Register the search with inspector and yield results
        gen = generator()
        inspector.register_search(search_id, "artist_songs", gen)
        
        try:
            yield from gen
        finally:
            inspector.cancel_search(search_id)

# =================================================================================================================================
# =================================================================================================================================


class YTMusicRelatedFetcher:
    def __init__(self, proxy: Optional[str] = None, country: str = "US"):
        self.proxy = proxy
        self.country = country.upper() if country else "US"
        self.ytmusic = None
        self._initialize_ytmusic()
        
    def _initialize_ytmusic(self):
        max_retries = 3
        for attempt in range(max_retries):
            try:
                self.ytmusic = YTMusic()
                return
            except Exception as e:
                if attempt == max_retries - 1:
                    raise ConnectionError(f"Failed to initialize YTMusic after {max_retries} attempts: {str(e)}")
                time.sleep(2 ** attempt)

    def _get_ytdlp_instance(self, format_selector: str):
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "nocheckcertificate": True,
            "format": format_selector,
            "extract_flat": False,
            "age_limit": 99,
            "socket_timeout": 30,
            "source_address": "0.0.0.0",
            "force_ipv4": True,
            "retries": 3,
            "fragment_retries": 10,
            "extractor_retries": 3,
            "buffersize": 1024 * 1024,
            "http_chunk_size": 1024 * 1024,
            "extractor_args": {
                "youtube": {
                    "player_client": ["android", "web"],
                    "player_skip": ["configs"],
                    "skip": ["translated_subs", "hls"]
                }
            },
            "compat_opts": ["no-youtube-unavailable-videos"],
            "headers": self._generate_headers()
        }

        if self.proxy:
            ydl_opts["proxy"] = self.proxy
            ydl_opts["proxy_headers"] = ydl_opts["headers"]

        return yt_dlp.YoutubeDL(ydl_opts)

    def _generate_headers(self):
        user_agents = [
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15',
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        ]
        
        return {
            'User-Agent': random.choice(user_agents),
            'Accept-Language': 'en-US,en;q=0.9',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate, br'
        }

    def get_audio_url(self, video_id: str, quality: AudioQuality) -> Optional[str]:
        format_strategies = [
            "bestaudio[ext=m4a]/bestaudio[ext=mp4]/best[ext=m4a]/best[ext=mp4]",
            "251/250/249/140/139/171/18/22",
            "bestaudio/best",
            "worstaudio/worst"
        ]
        
        for format_selector in format_strategies:
            try:
                ydl = self._get_ytdlp_instance(format_selector)
                time.sleep(random.uniform(0.5, 1.5))
                
                info = ydl.extract_info(
                    f"https://www.youtube.com/watch?v={video_id}",
                    download=False,
                    process=False
                )
                info = ydl.process_ie_result(info, download=False)
                
                if info.get('is_live') or info.get('availability') == 'unavailable':
                    continue
                
                if info.get('drm') or any(f.get('drm') for f in info.get('formats', [])):
                    continue
                
                requested_formats = info.get('requested_formats', [info])
                formats = info.get('formats', requested_formats)
                
                audio_formats = [
                    f for f in formats 
                    if f.get('acodec') != 'none' 
                    and f.get('url')
                    and not any(x in f['url'].lower() for x in ["manifest", ".m3u8"])
                ]
                
                if not audio_formats:
                    continue
                
                audio_formats.sort(key=lambda f: f.get('abr', 0) or f.get('tbr', 0) or 0, reverse=True)
                return audio_formats[0]['url']
                        
            except yt_dlp.utils.DownloadError as e:
                if "HTTP Error 403" in str(e):
                    time.sleep(2)
                    continue
                if "unavailable" in str(e).lower():
                    break
                continue
            except (URLError, socket.timeout, ConnectionError):
                time.sleep(2)
                continue
            except Exception:
                continue
        
        return None
    
    def get_hq_album_art_from_ytdlp(self, video_id: str) -> Optional[str]:
        """
        Get high quality album art using yt-dlp from video metadata
        Returns the highest quality album art URL available
        """
        try:
            ydl_opts = {
                "quiet": True,
                "no_warnings": True,
                "skip_download": True,
                "nocheckcertificate": True,
                "extract_flat": False,
                "socket_timeout": 30,
                "source_address": "0.0.0.0",
                "force_ipv4": True,
                "retries": 2,
                "headers": self._generate_headers()
            }
            
            if self.proxy:
                ydl_opts["proxy"] = self.proxy
                ydl_opts["proxy_headers"] = ydl_opts["headers"]
            
            ydl = yt_dlp.YoutubeDL(ydl_opts)
            
            info = ydl.extract_info(
                f"https://www.youtube.com/watch?v={video_id}",
                download=False
            )
            
            # First try to get album art from metadata
            album_art_url = None
            
            # Check for album art in various metadata fields
            if info.get('album_artist') and info.get('album'):
                # Try to construct album art URL from metadata
                album_art_url = self._get_album_art_from_metadata(info)
            
            # If no album art from metadata, fall back to high quality thumbnails
            if not album_art_url:
                thumbnails = info.get('thumbnails', [])
                if thumbnails:
                    # Filter for high quality thumbnails (prefer square ones for album art)
                    hq_thumbnails = [
                        t for t in thumbnails 
                        if t.get('width', 0) >= 720 and t.get('height', 0) >= 720
                    ]
                    
                    if hq_thumbnails:
                        # Sort by resolution and prefer square aspect ratios
                        hq_thumbnails.sort(
                            key=lambda t: (
                                abs(1.0 - (t.get('width', 1) / t.get('height', 1))),  # Prefer square
                                (t.get('width', 0) * t.get('height', 0))  # Then by resolution
                            ),
                            reverse=True
                        )
                        album_art_url = hq_thumbnails[0].get('url', '')
                    else:
                        # Fall back to highest resolution thumbnail
                        thumbnails.sort(
                            key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                            reverse=True
                        )
                        album_art_url = thumbnails[0].get('url', '')
            
            if album_art_url:
                print(f"HQ Album Art found: {album_art_url}")
                return album_art_url
            
            return None
            
        except Exception as e:
            print(f"Error getting HQ album art for {video_id}: {e}")
            return None

    def _get_album_art_from_metadata(self, info: dict) -> Optional[str]:
        """
        Try to get album art from video metadata
        """
        try:
            # Check for album art in various metadata fields
            album_art_fields = ['album_art', 'album_artwork', 'artwork', 'cover']
            
            for field in album_art_fields:
                if info.get(field):
                    return info[field]
            
            # Try to get from uploader avatar if it's an official channel
            uploader = info.get('uploader', '').lower()
            if any(keyword in uploader for keyword in ['official', 'records', 'music', 'vevo']):
                uploader_avatar = info.get('uploader_avatar_url')
                if uploader_avatar:
                    return uploader_avatar
            
            return None
            
        except Exception:
            return None

    def get_youtube_music_album_art(self, video_id: str) -> Optional[str]:
        """
        Get album art specifically from YouTube Music metadata
        """
        try:
            # Use YTMusic to get song details which might have better album art
            song_info = self.ytmusic.get_song(video_id)
            
            # Extract album art from song info
            thumbnails = song_info.get('videoDetails', {}).get('thumbnail', {}).get('thumbnails', [])
            
            if thumbnails:
                # Sort by resolution to get highest quality
                thumbnails.sort(
                    key=lambda t: (t.get('width', 0) * t.get('height', 0)),
                    reverse=True
                )
                
                # Prefer square thumbnails for album art
                square_thumbnails = [
                    t for t in thumbnails 
                    if abs(1.0 - (t.get('width', 1) / t.get('height', 1))) < 0.1
                ]
                
                if square_thumbnails:
                    return square_thumbnails[0].get('url', '')
                else:
                    return thumbnails[0].get('url', '')
            
            return None
            
        except Exception as e:
            print(f"Error getting YouTube Music album art for {video_id}: {e}")
            return None

    def _find_song_video_id(self, song_name: str, artist_name: str) -> Optional[str]:
        query = f"{song_name} {artist_name}"
        
        for attempt in range(3):
            try:
                results = self.ytmusic.search(query, filter="songs", limit=10)
                
                for item in results:
                    title = item.get("title", "").lower()
                    artists = [a.get("name", "").lower() for a in item.get("artists", [])]
                    
                    if any(word in title for word in song_name.lower().split()):
                        if any(artist_name.lower() in artist for artist in artists):
                            return item.get("videoId")
                
                if results:
                    return results[0].get("videoId")
                    
            except Exception:
                if attempt == 2:
                    return None
                time.sleep(2 ** attempt)
                self._initialize_ytmusic()
        
        return None

    def get_video_info(self, video_id: str) -> Optional[dict]:
        try:
            song_info = self.ytmusic.get_song(video_id)
            watch_playlist = self.ytmusic.get_watch_playlist(video_id)
            
            return {
                "song_info": song_info,
                "related_tracks": watch_playlist.get("tracks", [])
            }
            
        except Exception as e:
            print(f"Error getting video info for {video_id}: {str(e)}")
            return None
        
    def getRelated(
        self,
        song_name: str,
        artist_name: str,
        limit: int = 65,
        thumb_quality: ThumbnailQuality = ThumbnailQuality.VERY_HIGH,
        audio_quality: AudioQuality = AudioQuality.HIGH,
        include_audio_url: bool = True,
        include_album_art: bool = True
    ) -> Generator[dict, None, None]:
        inspector = SearchInspector.get_instance()
        search_id = f"related_{song_name[:10]}_{artist_name[:10]}_{int(time.time())}"
        
        def generator():
            nonlocal song_name, artist_name, limit, thumb_quality, audio_quality, include_audio_url, include_album_art
            if not song_name.strip() or not artist_name.strip():
                print("YTMusic getRelated Error: Both song_name and artist_name are required.")
                return

            print(f"Searching for related songs to '{song_name}' by '{artist_name}'...")
            
            video_id = self._find_song_video_id(song_name, artist_name)
            
            if not video_id:
                print(f"Could not find '{song_name}' by '{artist_name}'")
                return
            
            print(f"Found song with video ID: {video_id}")
            
            video_info = self.get_video_info(video_id)
            
            if not video_info or not video_info.get("related_tracks"):
                print("No related tracks found")
                return
            
            related_tracks = video_info["related_tracks"]
            processed_count = 0
            skipped_count = 0
            
            print(f"Processing {len(related_tracks)} related tracks...")
            
            for item in related_tracks:
                if not inspector.is_active(search_id):
                    print("Related search cancelled by inspector")
                    return
                    
                if processed_count >= limit:
                    break
                    
                try:
                    track_video_id = item.get("videoId")
                    if not track_video_id or track_video_id == video_id:
                        skipped_count += 1
                        continue

                    title = item.get("title", "Unknown Title")
                    artists = ", ".join(a.get("name", "Unknown") for a in item.get("artists", [])) or "Unknown Artist"
                    duration = item.get("length", "N/A")
                    
                    album_art = ""
                    if include_album_art:
                        if thumb_quality in [ThumbnailQuality.HIGH, ThumbnailQuality.VERY_HIGH]:
                            print(f"Trying to get HQ album art for related track: {track_video_id}")
                            
                            # Method 1: Try YouTube Music specific album art
                            album_art = self.get_youtube_music_album_art(track_video_id)
                            
                            # Method 2: Try yt-dlp with album art focus
                            if not album_art:
                                album_art = self.get_hq_album_art_from_ytdlp(track_video_id)
                            
                            # Method 3: Fallback to YTMusic thumbnails
                            if not album_art:
                                print("Falling back to YTMusic thumbnails for related track")
                                thumbnails = item.get("thumbnail", [])
                                if thumbnails:
                                    base_url = thumbnails[-1].get("url", "")
                                    if base_url:
                                        if thumb_quality == ThumbnailQuality.HIGH:
                                            album_art = re.sub(r'w\d+-h\d+', 'w320-h320', base_url)
                                        elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                            album_art = re.sub(r'w\d+-h\d+', 'w544-h544', base_url)
                                        else:
                                            album_art = base_url
                            
                            # Apply quality settings to HQ URLs
                            if album_art and any(pattern in album_art for pattern in ['googleusercontent.com', 'ytimg.com', 'youtube.com']):
                                if thumb_quality == ThumbnailQuality.HIGH:
                                    album_art = re.sub(r'w\d+-h\d+', 'w320-h320', album_art)
                                elif thumb_quality == ThumbnailQuality.VERY_HIGH:
                                    album_art = re.sub(r'w\d+-h\d+', 'w544-h544', album_art)
                        else:
                            # Use YTMusic thumbnails for all quality levels
                            thumbnails = item.get("thumbnail", [])
                            if thumbnails:
                                base_url = thumbnails[-1].get("url", "")
                                if base_url:
                                    if thumb_quality == ThumbnailQuality.LOW:
                                        album_art = re.sub(r'w\d+-h\d+', 'w60-h60', base_url)
                                    elif thumb_quality == ThumbnailQuality.MED:
                                        album_art = re.sub(r'w\d+-h\d+', 'w120-h120', base_url)
                                    else:
                                        album_art = base_url
                                else:
                                    album_art = ""
                    audio_url = None
                    if include_audio_url:
                        for _ in range(3):
                            if not inspector.is_active(search_id):
                                print("Related search cancelled during audio URL fetch")
                                return
                            audio_url = self.get_audio_url(track_video_id, audio_quality)
                            if audio_url:
                                break
                            time.sleep(1)

                    if not include_audio_url or audio_url:
                        song_data = {
                            "title": title,
                            "artists": artists,
                            "videoId": track_video_id,
                            "duration": duration,
                            "isOriginal": track_video_id == video_id
                        }
                        if include_album_art:
                            song_data["albumArt"] = album_art
                        if include_audio_url:
                            song_data["audioUrl"] = audio_url

                        processed_count += 1
                        yield song_data
                    else:
                        skipped_count += 1

                except Exception as e:
                    print(f"Error processing track: {str(e)}")
                    skipped_count += 1
                    continue

            print(f"Found {processed_count} valid related songs (skipped {skipped_count})")

        # Register the search with inspector and yield results
        gen = generator()
        inspector.register_search(search_id, "related_songs", gen)
        
        try:
            yield from gen
        finally:
            inspector.cancel_search(search_id)

# =================================================================================================================================
# =================================================================================================================================

import threading
import time
from typing import Dict, Generator, Optional
from types import GeneratorType
import logging

class SearchInspector:
    def __init__(self):
        self.active_searches = {}
        self.lock = threading.Lock()
        self.logger = logging.getLogger(__name__)
        
    def register_search(self, search_id: Optional[str] = None, 
                      search_type: Optional[str] = None, 
                      generator: Optional[Generator] = None) -> str:
        """
        Register a new search and cancel any existing ones of the same type.
        
        Args:
            search_id: Optional custom ID for the search
            search_type: The type/category of search
            generator: The generator instance to manage
            
        Returns:
            The search ID (generated if not provided)
            
        Raises:
            ValueError: If required parameters are missing or invalid
            TypeError: If generator is not a generator object
        """
        if not search_type:
            raise ValueError("search_type is required")
        if not isinstance(generator, GeneratorType):
            raise TypeError("generator must be a generator object")
            
        with self.lock:
            try:
                # Cancel any existing searches of this type
                self.cancel_type(search_type)
                
                # Generate a unique ID if not provided
                if not search_id:
                    search_id = f"{search_type}_{int(time.time() * 1000)}"
                    
                # Validate generator state
                if generator.gi_running:
                    self.logger.warning("Registering an already-running generator may cause issues")
                
                # Store the generator
                self.active_searches[search_id] = {
                    'generator': generator,
                    'type': search_type,
                    'active': True,
                    'created': time.time(),
                    'last_accessed': time.time()
                }
                
                self.logger.debug(f"Registered new search: {search_id} of type {search_type}")
                return search_id
                
            except Exception as e:
                self.logger.error(f"Failed to register search: {str(e)}", exc_info=True)
                raise RuntimeError(f"Search registration failed: {str(e)}")
            
    def cancel_search(self, search_id: str) -> bool:
        """
        Cancel a specific search by ID.
        
        Args:
            search_id: The ID of the search to cancel
            
        Returns:
            bool: True if search was found and cancelled, False otherwise
            
        Raises:
            ValueError: If search_id is not provided
        """
        if not search_id:
            raise ValueError("search_id is required")
            
        with self.lock:
            if search_id not in self.active_searches:
                self.logger.warning(f"Search {search_id} not found for cancellation")
                return False
                
            try:
                search_data = self.active_searches[search_id]
                
                # Close the generator safely
                try:
                    if not search_data['generator'].gi_running:
                        search_data['generator'].close()
                except Exception as e:
                    self.logger.warning(f"Error closing generator for {search_id}: {str(e)}")
                
                # Clean up references
                del self.active_searches[search_id]
                self.logger.debug(f"Cancelled search: {search_id}")
                return True
                
            except Exception as e:
                self.logger.error(f"Failed to cancel search {search_id}: {str(e)}", exc_info=True)
                return False
            
    def cancel_type(self, search_type: str) -> int:
        """
        Cancel all searches of a specific type.
        
        Args:
            search_type: The type of searches to cancel
            
        Returns:
            int: Number of searches cancelled
            
        Raises:
            ValueError: If search_type is not provided
        """
        if not search_type:
            raise ValueError("search_type is required")
            
        with self.lock:
            canceled = 0
            to_remove = []
            
            try:
                for search_id, search_data in list(self.active_searches.items()):
                    if search_data['type'] == search_type:
                        try:
                            if not search_data['generator'].gi_running:
                                search_data['generator'].close()
                            to_remove.append(search_id)
                            canceled += 1
                        except Exception as e:
                            self.logger.warning(
                                f"Error canceling {search_type} search {search_id}: {str(e)}"
                            )
                            
                for search_id in to_remove:
                    try:
                        del self.active_searches[search_id]
                    except KeyError:
                        pass
                        
                self.logger.debug(f"Cancelled {canceled} searches of type {search_type}")
                return canceled
                
            except Exception as e:
                self.logger.error(f"Failed to cancel searches of type {search_type}: {str(e)}")
                return 0
            
    def cancel_all(self) -> int:
        """
        Cancel all ongoing searches.
        
        Returns:
            int: Number of searches cancelled
        """
        with self.lock:
            count = len(self.active_searches)
            try:
                for search_data in list(self.active_searches.values()):
                    try:
                        if not search_data['generator'].gi_running:
                            search_data['generator'].close()
                    except Exception as e:
                        self.logger.warning(f"Error closing generator: {str(e)}")
                        
                self.active_searches.clear()
                self.logger.debug(f"Cancelled all {count} active searches")
                return count
                
            except Exception as e:
                self.logger.error(f"Failed to cancel all searches: {str(e)}")
                return 0
            
    def is_active(self, search_id: str) -> bool:
        """
        Check if a search is still active.
        
        Args:
            search_id: The ID of the search to check
            
        Returns:
            bool: True if search is active, False otherwise
            
        Raises:
            ValueError: If search_id is not provided
        """
        if not search_id:
            raise ValueError("search_id is required")
            
        with self.lock:
            try:
                if search_id in self.active_searches:
                    self.active_searches[search_id]['last_accessed'] = time.time()
                    return True
                return False
            except Exception as e:
                self.logger.warning(f"Error checking search activity for {search_id}: {str(e)}")
                return False
            
    def get_active_counts(self) -> Dict[str, int]:
        """
        Get counts of active searches by type.
        
        Returns:
            dict: Mapping of search types to active counts
        """
        with self.lock:
            try:
                counts = {}
                for search_data in self.active_searches.values():
                    counts[search_data['type']] = counts.get(search_data['type'], 0) + 1
                return counts
            except Exception as e:
                self.logger.error(f"Failed to get active counts: {str(e)}")
                return {}
            
    def cleanup_stale(self, timeout: int = 300) -> int:
        """
        Clean up searches that have been inactive for too long.
        
        Args:
            timeout: Seconds of inactivity before considering stale (default 300)
            
        Returns:
            int: Number of stale searches cleaned up
            
        Raises:
            ValueError: If timeout is not positive
        """
        if timeout <= 0:
            raise ValueError("timeout must be positive")
            
        with self.lock:
            cleaned = 0
            current_time = time.time()
            to_remove = []
            
            try:
                for search_id, search_data in list(self.active_searches.items()):
                    if current_time - search_data['last_accessed'] > timeout:
                        try:
                            if not search_data['generator'].gi_running:
                                search_data['generator'].close()
                            to_remove.append(search_id)
                            cleaned += 1
                        except Exception as e:
                            self.logger.warning(
                                f"Error cleaning up stale search {search_id}: {str(e)}"
                            )
                            
                for search_id in to_remove:
                    try:
                        del self.active_searches[search_id]
                    except KeyError:
                        pass
                        
                if cleaned > 0:
                    self.logger.info(f"Cleaned up {cleaned} stale searches")
                return cleaned
                
            except Exception as e:
                self.logger.error(f"Failed to clean stale searches: {str(e)}")
                return 0

    def __del__(self):
        """Destructor to ensure all resources are cleaned up"""
        try:
            self.cancel_all()
        except Exception as e:
            self.logger.warning(f"Error during cleanup: {str(e)}")

class DynamicLyricsProvider:
    """
    A dynamic lyrics provider that fetches lyrics with timestamps from KuGou.
    Designed for Flutter/Kotlin integration to provide real-time lyrics display.
    """
    
    PAGE_SIZE = 8
    HEAD_CUT_LIMIT = 30
    DURATION_TOLERANCE = 8
    ACCEPTED_REGEX = re.compile(r"\[(\d\d):(\d\d)\.(\d{2,3})\].*")
    BANNED_REGEX = re.compile(r".+].+[:：].+")
    
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
    
    def normalize_title(self, title: str) -> str:
        """Clean title for better search results"""
        return re.sub(r'\(.*\)|（.*）|「.*」|『.*』|<.*>|《.*》|〈.*〉|＜.*＞', '', title).strip()
    
    def normalize_artist(self, artist: str) -> str:
        """Clean artist name for better search results"""
        artist = re.sub(r', | & |\.|和', '、', artist)
        return re.sub(r'\(.*\)|（.*）', '', artist).strip()
    
    def generate_keyword(self, title: str, artist: str) -> Dict[str, str]:
        """Generate search keywords from title and artist"""
        return {
            'title': self.normalize_title(title),
            'artist': self.normalize_artist(artist)
        }
    
    def normalize_lyrics(self, lyrics: str) -> str:
        """Clean and filter lyrics to keep only timestamped lines"""
        lyrics = lyrics.replace("&apos;", "'")
        lines = [line for line in lyrics.split('\n') if self.ACCEPTED_REGEX.match(line)]
        
        # Remove useless info from beginning
        head_cut_line = 0
        for i in range(min(self.HEAD_CUT_LIMIT, len(lines)-1), -1, -1):
            if self.BANNED_REGEX.match(lines[i]):
                head_cut_line = i + 1
                break
        filtered_lines = lines[head_cut_line:]
        
        # Remove useless info from end
        tail_cut_line = 0
        for i in range(min(len(lines)-self.HEAD_CUT_LIMIT, len(lines)-1), -1, -1):
            if self.BANNED_REGEX.match(lines[len(lines)-1-i]):
                tail_cut_line = i + 1
                break
        final_lines = filtered_lines[:len(filtered_lines)-tail_cut_line] if tail_cut_line > 0 else filtered_lines
        
        return '\n'.join(final_lines)
    
    def search_songs(self, keyword: Dict[str, str]) -> Dict[str, Any]:
        """Search for songs on KuGou to get hash"""
        url = "https://mobileservice.kugou.com/api/v3/search/song"
        params = {
            'version': 9108,
            'plat': 0,
            'pagesize': self.PAGE_SIZE,
            'showtype': 0,
            'keyword': f"{keyword['title']} - {keyword['artist']}"
        }
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error searching songs: {e}")
            return {}
    
    def search_lyrics_by_keyword(self, keyword: Dict[str, str], duration: int = -1) -> Dict[str, Any]:
        """Search for lyrics by keyword"""
        url = "https://lyrics.kugou.com/search"
        params = {
            'ver': 1,
            'man': 'yes',
            'client': 'pc',
            'keyword': f"{keyword['title']} - {keyword['artist']}"
        }
        if duration != -1:
            params['duration'] = duration * 1000
        
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error searching lyrics by keyword: {e}")
            return {}
    
    def search_lyrics_by_hash(self, hash: str) -> Dict[str, Any]:
        """Search for lyrics by song hash"""
        url = "https://lyrics.kugou.com/search"
        params = {
            'ver': 1,
            'man': 'yes',
            'client': 'pc',
            'hash': hash
        }
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error searching lyrics by hash: {e}")
            return {}
    
    def download_lyrics(self, id: str, accesskey: str) -> Dict[str, Any]:
        """Download lyrics content"""
        url = "https://lyrics.kugou.com/download"
        params = {
            'fmt': 'lrc',
            'charset': 'utf8',
            'client': 'pc',
            'ver': 1,
            'id': id,
            'accesskey': accesskey
        }
        try:
            response = self.session.get(url, params=params, timeout=10)
            return response.json()
        except Exception as e:
            print(f"Error downloading lyrics: {e}")
            return {}
    
    def parse_lrc_timestamps(self, lyrics: str) -> List[Dict[str, Any]]:
        """Parse LRC format and convert to structured format for Flutter"""
        lines = []
        for line in lyrics.split('\n'):
            match = self.ACCEPTED_REGEX.match(line)
            if match:
                minutes = int(match.group(1))
                seconds = int(match.group(2))
                milliseconds = int(match.group(3).ljust(3, '0')[:3])  # Ensure 3 digits
                
                timestamp_ms = (minutes * 60 * 1000) + (seconds * 1000) + milliseconds
                text = line.split(']', 1)[1].strip() if ']' in line else ""
                
                if text:  # Only add non-empty lines
                    lines.append({
                        'timestamp': timestamp_ms,
                        'text': text,
                        'time_formatted': f"{minutes:02d}:{seconds:02d}.{milliseconds:03d}"
                    })
        
        return sorted(lines, key=lambda x: x['timestamp'])
    
    def fetch_lyrics(self, title: str, artist: str, duration: int = -1) -> Optional[Dict[str, Any]]:
        """
        Main method to fetch lyrics with timestamps.
        Returns simplified structured data suitable for Flutter/Kotlin integration.
        """
        print(f"Starting lyrics fetch for: {title} by {artist}")
        
        keyword = self.generate_keyword(title, artist)
        print(f"Generated keyword: {keyword}")

        # First try searching by song hash
        print("Searching songs by keyword...")
        songs = self.search_songs(keyword)
        print(f"Found {len(songs.get('data', {}).get('info', []))} song matches")

        for song in songs.get('data', {}).get('info', []):
            try:
                if duration == -1 or abs(song['duration'] - duration) <= self.DURATION_TOLERANCE:
                    print(f"Trying song hash: {song['hash']}")
                    lyrics_data = self.search_lyrics_by_hash(song['hash'])
                    print(f"Lyrics search result: {lyrics_data}")

                    if lyrics_data.get('candidates'):
                        candidate = lyrics_data['candidates'][0]
                        print(f"Downloading lyrics for candidate: {candidate}")
                        lyrics = self.download_lyrics(candidate['id'], candidate['accesskey'])
                        print(f"Downloaded lyrics content: {lyrics.get('content') is not None}")

                        if lyrics.get('content'):
                            try:
                                content = base64.b64decode(lyrics['content']).decode('utf-8')
                                normalized = self.normalize_lyrics(content)
                                print(f"Normalized lyrics length: {len(normalized)} chars")

                                if "纯音乐，请欣赏" in normalized or "酷狗音乐  就是歌多" in normalized:
                                    print("Skipping instrumental track")
                                    continue
                                
                                parsed_lyrics = self.parse_lrc_timestamps(normalized)
                                print(f"Parsed {len(parsed_lyrics)} lyrics lines")

                                if parsed_lyrics:
                                    return {
                                        'success': True,
                                        'lyrics': parsed_lyrics,
                                        'source': 'KuGou',
                                        'total_lines': len(parsed_lyrics)
                                    }
                            except Exception as e:
                                print(f"Error processing lyrics: {e}")
                                continue
            except Exception as e:
                print(f"Error processing song: {e}")
                continue

        # If not found, try searching by keyword
        print("Trying lyrics search by keyword...")
        lyrics_data = self.search_lyrics_by_keyword(keyword, duration)
        print(f"Keyword search result: {lyrics_data}")

        if lyrics_data.get('candidates'):
            candidate = lyrics_data['candidates'][0]
            print(f"Downloading lyrics for keyword candidate: {candidate}")
            lyrics = self.download_lyrics(candidate['id'], candidate['accesskey'])
            print(f"Downloaded lyrics content: {lyrics.get('content') is not None}")

            if lyrics.get('content'):
                try:
                    content = base64.b64decode(lyrics['content']).decode('utf-8')
                    normalized = self.normalize_lyrics(content)
                    print(f"Normalized lyrics length: {len(normalized)} chars")

                    if "纯音乐，请欣赏" in normalized or "酷狗音乐  就是歌多" in normalized:
                        print("Returning not found for instrumental track")
                        return {
                            'success': False,
                            'error': f'No lyrics found for {title} by {artist}'
                        }
                    
                    parsed_lyrics = self.parse_lrc_timestamps(normalized)
                    print(f"Parsed {len(parsed_lyrics)} lyrics lines")

                    if parsed_lyrics:
                        return {
                            'success': True,
                            'lyrics': parsed_lyrics,
                            'source': 'KuGou',
                            'total_lines': len(parsed_lyrics)
                        }
                except Exception as e:
                    print(f"Error processing lyrics: {e}")

        print("No lyrics found after all attempts")
        return {
            'success': False,
            'error': f'No lyrics found for {title} by {artist}'
        }

# Test examples
# if __name__ == "__main__":
# #     # Initialize both services
# #     print("Initializing services...")
# #     searcher = YTMusicSearcher(country="US")
# #     related_fetcher = YTMusicRelatedFetcher(country="US")
#     searcher = YTMusicSearcher(country="US")

#     # Single song lookup
#     # song_details = searcher.get_song_details(
#     #     songs=[{"song_name": "Blinding Lights", "artist_name": "The Weeknd"}],
#     #     mode="single"
#     # )

#     # if song_details:
#     #     print(f"Title: {song_details['title']}")
#     #     print(f"Artists: {song_details['artists']}")
#     # print("Single Mode: Results Ready")
    

#     # Batch processing
#     songs_to_lookup = [
#         {"song_name": "Viva La Vida", "artist_name": "Coldplay"},
#         {"song_name": "Shape of You", "artist_name": "Ed Sheeran"}
#     ]

#     for song in searcher.get_song_details(
#         songs=songs_to_lookup,
#         mode="batch"
#     ):
#         # print(f"\n{song['title']} by {song['artists']}")
#         print("Batch Mode: Results Ready")



#     # Test search functionality
#     print("\n=== Testing Search Functionality ===")
#     test_query = "Gale Lag Ja"
#     print(f"Searching for: {test_query}")
    
#     for i, song in enumerate(searcher.get_music_details(test_query, limit=3), 1):
#         print(f"\n{i}. {song['title']} by {song['artists']}")
#         print(f"Duration: {song.get('duration', 'N/A')}")
#         if 'albumArt' in song:
#             print(f"Album Art: {song['albumArt']}")
#         if 'audioUrl' in song:
#             print(f"Audio URL: {song['audioUrl'][:50]}...")  # Print first 50 chars of URL
    
#     # Test related songs functionality
#     print("\n=== Testing Related Songs Functionality ===")
#     test_song = "Viva La Vida"
#     test_artist = "Coldplay"
#     print(f"Finding related songs for: {test_song} by {test_artist}")
    
#     for i, song in enumerate(related_fetcher.getRelated(
#         song_name=test_song,
#         artist_name=test_artist,
#         limit=3,
#         include_audio_url=False  # Faster testing without audio URLs
#     ), 1):
#         print(f"\n{i}. {song['title']} by {song['artists']}")
#         print(f"Duration: {song.get('duration', 'N/A')}")
#         if 'albumArt' in song:
#             print(f"Album Art: {song['albumArt']}")
#         print(f"Is Original: {song.get('isOriginal', False)}")
    
#     print("\nTests completed successfully!")



    

