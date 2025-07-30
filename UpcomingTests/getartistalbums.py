import threading
from ytmusicapi import YTMusic

def get_artist_albums_and_singles():
    # Initialize YTMusic API
    ytmusic = YTMusic()
    
    # Ask for artist name
    artist_name = input("Enter artist name: ").strip()
    if not artist_name:
        print("Artist name cannot be empty!")
        return
    
    # Ask for limit
    try:
        limit = int(input("Enter limit (number of items to show): ").strip())
    except ValueError:
        print("Invalid limit! Using default 5")
        limit = 5
    
    # Search for the artist to get channel ID
    search_results = ytmusic.search(artist_name, filter="artists")
    if not search_results:
        print(f"No artist found with name: {artist_name}")
        return
    
    # Get the first artist result
    artist = search_results[0]
    channel_id = artist['browseId']
    print(f"\nFound artist: {artist['artist']}")
    
    # Ask for mode
    mode = input("Choose mode (1: Albums, 2: Singles/EPs, 3: Both): ").strip()
    if mode not in ['1', '2', '3']:
        print("Invalid mode selection!")
        return
    
    # Get artist details
    artist_info = ytmusic.get_artist(channel_id)
    
    def process_albums():
        if 'albums' not in artist_info or not artist_info['albums'].get('results'):
            print("\nNo albums found for this artist.")
            return
        
        print(f"\n=== Albums (showing {limit}) ===")
        albums = ytmusic.get_artist_albums(
            artist_info['albums']['browseId'],
            artist_info['albums']['params'],
            limit=limit
        )
        
        for album in albums[:limit]:  # Ensure we only show the requested limit
            print(f"\nAlbum: {album['title']}")
            print(f"Year: {album.get('year', 'N/A')}")
            if album.get('thumbnails'):
                print(f"Album Art: {album['thumbnails'][-1]['url']}")
            
            # Get album songs
            if 'browseId' in album and album['browseId'].startswith('MPRE'):
                album_details = ytmusic.get_album(album['browseId'])
                print(f"\nSongs ({min(5, len(album_details['tracks']))} of {len(album_details['tracks'])}):")
                for track in album_details['tracks'][:5]:  # Show first 5 songs max
                    print(f"- {track['title']} (Video ID: {track['videoId']})")
                    if track.get('artists'):
                        artists = ", ".join([a['name'] for a in track['artists']])
                        print(f"  Artists: {artists}")
    
    def process_singles():
        if 'singles' not in artist_info or not artist_info['singles'].get('results'):
            print("\nNo singles/EPs found for this artist.")
            return
        
        print(f"\n=== Singles/EPs (showing {limit}) ===")
        singles = ytmusic.get_artist_albums(
            artist_info['singles']['browseId'],
            artist_info['singles']['params'],
            limit=limit
        )
        
        for single in singles[:limit]:  # Ensure we only show the requested limit
            print(f"\nSingle/EP: {single['title']}")
            print(f"Year: {single.get('year', 'N/A')}")
            if single.get('thumbnails'):
                print(f"Album Art: {single['thumbnails'][-1]['url']}")
            
            # Get single songs
            if 'browseId' in single and single['browseId'].startswith('MPRE'):
                single_details = ytmusic.get_album(single['browseId'])
                print(f"\nTracks ({min(5, len(single_details['tracks']))} of {len(single_details['tracks'])}):")
                for track in single_details['tracks'][:5]:  # Show first 5 songs max
                    print(f"- {track['title']} (Video ID: {track['videoId']})")
                    if track.get('artists'):
                        artists = ", ".join([a['name'] for a in track['artists']])
                        print(f"  Artists: {artists}")
    
    # Process based on mode
    if mode == '1':
        process_albums()
    elif mode == '2':
        process_singles()
    elif mode == '3':
        # Use threads to process both simultaneously
        t1 = threading.Thread(target=process_albums)
        t2 = threading.Thread(target=process_singles)
        
        t1.start()
        t2.start()
        
        t1.join()
        t2.join()

# Test with Eminem
if __name__ == "__main__":
    get_artist_albums_and_singles()