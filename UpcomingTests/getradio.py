from ytmusicapi import YTMusic
import json

def search_and_play_radio():
    """Search for a song and auto-generate a radio playlist from the top result."""
    ytmusic = YTMusic()
    
    # Ask user for search query (title + artist improves accuracy)
    title = input("Enter song title: ").strip()
    artist = input("Enter artist (optional): ").strip()
    
    # Ask user for playlist limit
    while True:
        try:
            limit = int(input("Enter number of tracks for radio playlist (1-100, default 25): ").strip() or "25")
            if 1 <= limit <= 100:
                break
            else:
                print("Please enter a number between 1 and 100.")
        except ValueError:
            print("Please enter a valid number.")
    
    query = f"{title} {artist}" if artist else title
    
    # Search for the song (limit=1 to get only the top result)
    search_results = ytmusic.search(query, filter="songs", limit=1)
    
    if not search_results:
        print("No results found. Try another query.")
        return
    
    selected_track = search_results[0]
    video_id = selected_track["videoId"]
    
    print(f"\n🎧 Generating radio playlist based on: {selected_track['title']} - {', '.join([a['name'] for a in selected_track['artists']])}")
    
    # Get radio playlist (limited to user-specified number of tracks)
    try:
        radio_playlist = ytmusic.get_watch_playlist(
            videoId=video_id,
            radio=True,
            limit=limit  # User-specified limit
        )
    except Exception as e:
        print(f"Error generating radio playlist: {e}")
        return
    
    # Check if tracks exist in the playlist
    if not radio_playlist.get("tracks"):
        print("No tracks found in radio playlist.")
        return
    
    # Filter out the original search track from the playlist
    filtered_tracks = [track for track in radio_playlist["tracks"] if track["videoId"] != video_id]
    
    # Take only the requested number of tracks
    final_tracks = filtered_tracks[:limit]
    
    # Print radio playlist tracks
    print(f"\n🔊 Radio Playlist ({len(final_tracks)} Tracks - Original track excluded):")
    
    for i, track in enumerate(final_tracks, 1):
        # Safely get thumbnail URL
        thumbnail_url = "No HQ art"
        if track.get("thumbnail"):
            for thumb in track["thumbnail"]:
                if thumb.get("width") == 544 and thumb.get("height") == 544:
                    thumbnail_url = thumb["url"]
                    break
        
        # Safely get artist names
        artists = ', '.join([a['name'] for a in track.get('artists', [])])
        
        print(f"\n{i}. {track['title']} - {artists}")
        print(f"   🎵 Video ID: {track['videoId']}")
        print(f"   🖼️ Album Art: {thumbnail_url}")

if __name__ == "__main__":
    print("🎵 YouTube Music Radio Playlist Generator 🎵")
    search_and_play_radio()