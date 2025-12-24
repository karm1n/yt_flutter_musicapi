from ytmusicapi import YTMusic

def fetch_ytmusic_lyrics(title, artist):
    try:
        ytmusic = YTMusic()
        
        # Search for songs
        results = ytmusic.search(f"{title} {artist}", filter="songs")
        print(f"Found {len(results)} search results")
        
        if not results:
            return {"success": False, "error": f"No search results found for {title} by {artist}"}
        
        # Track if we found any matches
        found_matches = False
        
        for item in results:
            item_title = item.get("title", "").lower()
            item_artists = item.get("artists", [])
            
            # Check title match - more flexible matching
            title_match = (
                title.lower() in item_title or 
                item_title in title.lower() or
                title.lower().replace(" ", "") in item_title.replace(" ", "")
            )
            
            # Check artist match - improved logic
            artist_match = False
            if item_artists:
                for a in item_artists:
                    if isinstance(a, dict) and "name" in a:
                        artist_name = a.get("name", "").lower()
                        if (artist.lower() in artist_name or 
                            artist_name in artist.lower() or
                            artist.lower().replace(" ", "") in artist_name.replace(" ", "")):
                            artist_match = True
                            break
            
            if title_match and artist_match:
                found_matches = True
                video_id = item.get("videoId")
                if not video_id:
                    print(f"No video ID for: {item.get('title', 'Unknown')}")
                    continue
                
                print(f"Checking: {item.get('title', 'Unknown')} by {[a.get('name', '') for a in item_artists if isinstance(a, dict)]}")
                
                try:
                    # Get song details
                    song = ytmusic.get_song(video_id)
                    
                    # Debug: Print song structure
                    print(f"Song keys available: {list(song.keys()) if song else 'None'}")
                    
                    # Check for lyrics in multiple ways
                    lyrics_browse_id = None
                    
                    # Method 1: Direct lyrics key
                    if song and "lyrics" in song and song["lyrics"]:
                        lyrics_browse_id = song["lyrics"]
                        print(f"Found lyrics ID (method 1): {lyrics_browse_id}")
                    
                    # Method 2: Check in microformat or other locations
                    elif song and "microformat" in song:
                        microformat = song["microformat"]
                        if "lyrics" in microformat:
                            lyrics_browse_id = microformat["lyrics"]
                            print(f"Found lyrics ID (method 2): {lyrics_browse_id}")
                    
                    # Method 3: Look for any browse ID that might be lyrics
                    elif song:
                        for key, value in song.items():
                            if key.lower().find('lyric') != -1 and value:
                                lyrics_browse_id = value
                                print(f"Found lyrics ID (method 3, key: {key}): {lyrics_browse_id}")
                                break
                    
                    if lyrics_browse_id:
                        try:
                            # Get lyrics - try both with and without timestamps
                            lyrics_data = ytmusic.get_lyrics(lyrics_browse_id, timestamps=False)
                            print(f"Lyrics data received: {lyrics_data is not None}")
                            
                            if lyrics_data:
                                print(f"Lyrics data type: {type(lyrics_data)}")
                                if hasattr(lyrics_data, '__dict__'):
                                    print(f"Lyrics data attributes: {list(lyrics_data.__dict__.keys())}")
                                elif isinstance(lyrics_data, dict):
                                    print(f"Lyrics data keys: {list(lyrics_data.keys())}")
                                
                                # Handle the new API response format
                                lyrics_text = None
                                source = "YTMusic"
                                
                                # Check if it's a dictionary (old format)
                                if isinstance(lyrics_data, dict):
                                    if "lyrics" in lyrics_data and lyrics_data["lyrics"]:
                                        lyrics_text = lyrics_data["lyrics"]
                                    source = lyrics_data.get("source", "YTMusic")
                                
                                # Check if it's a Lyrics object (new format)
                                elif hasattr(lyrics_data, 'lyrics'):
                                    lyrics_text = lyrics_data.lyrics
                                    if hasattr(lyrics_data, 'source'):
                                        source = lyrics_data.source
                                
                                # If we got the text, process it
                                if lyrics_text and lyrics_text.strip():
                                    lines = []
                                    
                                    for line_text in lyrics_text.split('\n'):
                                        if line_text.strip():
                                            lines.append({
                                                "text": line_text.strip(),
                                                "timestamp": -1,
                                                "time_formatted": ""
                                            })
                                    
                                    if lines:  # Only return if we actually have lyrics
                                        return {
                                            "success": True,
                                            "lyrics": lines,
                                            "source": source,
                                            "total_lines": len(lines),
                                            "song_title": item.get("title", ""),
                                            "song_artist": [a.get("name", "") for a in item_artists if isinstance(a, dict)]
                                        }
                                else:
                                    print(f"No lyrics text found in response")
                            else:
                                print(f"get_lyrics returned None")
                                
                        except Exception as lyrics_error:
                            print(f"Error getting lyrics: {lyrics_error}")
                    
                    print(f"No lyrics available for: {item.get('title', 'Unknown')}")
                        
                except Exception as song_error:
                    print(f"Error getting song details for {video_id}: {song_error}")
                    continue
        
        if not found_matches:
            return {"success": False, "error": f"No matching songs found for '{title}' by '{artist}'"}
        else:
            return {"success": False, "error": f"Found matching songs for '{title}' by '{artist}' but no lyrics available"}
            
    except Exception as e:
        return {"success": False, "error": f"API Error: {str(e)}"}

# Alternative function that tries different search strategies
def fetch_ytmusic_lyrics_alternative(title, artist):
    """Alternative approach with different search strategies"""
    try:
        ytmusic = YTMusic()
        
        # Try multiple search queries
        search_queries = [
            f"{title} {artist}",
            f"{title} {artist} lyrics",
            f"{artist} {title}",
            f'"{title}" "{artist}"',
            title  # Sometimes just the title works better
        ]
        
        for query in search_queries:
            print(f"\n--- Trying search: {query} ---")
            
            # Try both songs and videos
            for filter_type in ["songs", "videos"]:
                try:
                    results = ytmusic.search(query, filter=filter_type)
                    print(f"Found {len(results)} {filter_type} results")
                    
                    if not results:
                        continue
                    
                    for item in results[:5]:  # Check top 5 results
                        item_title = item.get("title", "").lower()
                        
                        # More lenient matching for alternative approach
                        title_words = title.lower().split()
                        if any(word in item_title for word in title_words if len(word) > 2):
                            
                            video_id = item.get("videoId")
                            if not video_id:
                                continue
                            
                            print(f"Testing: {item.get('title', 'Unknown')}")
                            
                            try:
                                song = ytmusic.get_song(video_id)
                                if song and "lyrics" in song and song["lyrics"]:
                                    lyrics_data = ytmusic.get_lyrics(song["lyrics"], timestamps=False)
                                    
                                    if lyrics_data:
                                        lyrics_text = None
                                        
                                        # Handle both dict and object formats
                                        if isinstance(lyrics_data, dict):
                                            lyrics_text = lyrics_data.get("lyrics")
                                        elif hasattr(lyrics_data, 'lyrics'):
                                            lyrics_text = lyrics_data.lyrics
                                        
                                        if lyrics_text and lyrics_text.strip():
                                            lines = []
                                            for line_text in lyrics_text.split('\n'):
                                                if line_text.strip():
                                                    lines.append({
                                                        "text": line_text.strip(),
                                                        "timestamp": -1,
                                                        "time_formatted": ""
                                                    })
                                            
                                            if lines:
                                                source = "YTMusic"
                                                if isinstance(lyrics_data, dict):
                                                    source = lyrics_data.get("source", "YTMusic")
                                                elif hasattr(lyrics_data, 'source'):
                                                    source = lyrics_data.source
                                                
                                                return {
                                                    "success": True,
                                                    "lyrics": lines,
                                                    "source": source,
                                                    "total_lines": len(lines),
                                                    "song_title": item.get("title", ""),
                                                    "search_query": query,
                                                    "filter_type": filter_type
                                                }
                            except Exception as e:
                                print(f"Error with video {video_id}: {e}")
                                continue
                                
                except Exception as e:
                    print(f"Error searching with query '{query}' and filter '{filter_type}': {e}")
                    continue
        
        return {"success": False, "error": f"No lyrics found after trying multiple search strategies"}
        
    except Exception as e:
        return {"success": False, "error": f"API Error: {str(e)}"}


# Test function with both approaches
def test_both_approaches():
    test_cases = [
        ("Perfect", "Ed Sheeran"),
        ("Shape of You", "Ed Sheeran"),
        ("Thinking Out Loud", "Ed Sheeran")
    ]
    
    for title, artist in test_cases:
        print(f"\n{'='*50}")
        print(f"Testing: {title} by {artist}")
        print(f"{'='*50}")
        
        # Try original approach
        print("--- Original Approach ---")
        result1 = fetch_ytmusic_lyrics(title, artist)
        
        if result1["success"]:
            print(f"SUCCESS with original approach!")
            break
        else:
            print(f"Original failed: {result1['error']}")
        
        # Try alternative approach
        print("\n--- Alternative Approach ---")
        result2 = fetch_ytmusic_lyrics_alternative(title, artist)
        
        if result2["success"]:
            print(f"SUCCESS with alternative approach!")
            print(f"Found via search: '{result2.get('search_query', 'Unknown')}' using filter: {result2.get('filter_type', 'Unknown')}")
            break
        else:
            print(f"Alternative failed: {result2['error']}")


if __name__ == "__main__":
    # First try the original approach with debug info
    print("=== Testing Original Approach with Debug ===")
    result = fetch_ytmusic_lyrics("Perfect", "Ed Sheeran")
    
    if result["success"]:
        print(f"SUCCESS! Found lyrics from {result['source']}")
        print(f"Total lines: {result['total_lines']}")
        print("Note: Lyrics content not displayed due to copyright restrictions")
    else:
        print(f"Original approach failed: {result['error']}")
        
        # Try alternative approach
        print("\n=== Trying Alternative Approach ===")
        result2 = fetch_ytmusic_lyrics_alternative("Perfect", "Ed Sheeran")
        
        if result2["success"]:
            print(f"SUCCESS with alternative approach!")
            print(f"Found via: {result2.get('search_query', 'Unknown')}")
            print(f"Total lines: {result2['total_lines']}")
        else:
            print(f"Alternative approach also failed: {result2['error']}")
            print("\nThis might be due to:")
            print("1. Regional restrictions on lyrics")
            print("2. YouTube Music API limitations") 
            print("3. The specific song not having lyrics available via API")
            print("4. Changes in YouTube Music's API structure")