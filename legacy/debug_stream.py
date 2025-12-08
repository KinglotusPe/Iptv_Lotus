import requests
import re

def parse_m3u(content):
    channels = []
    lines = content.splitlines()
    for line in lines:
        line = line.strip()
        if line and not line.startswith("#"):
            return line # Return first URL found
    return None

url = "http://odenfull.co:2086/get.php?username=Yhq2GMZ5BV&password=Z8AEPMUgE3&type=m3u_plus&output=ts"
headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

print(f"Fetching playlist from {url}...")
try:
    response = requests.get(url, headers=headers, timeout=10)
    response.raise_for_status()
    print("Playlist fetched successfully.")
    
    stream_url = parse_m3u(response.text)
    if stream_url:
        print(f"First stream URL found: {stream_url}")
        print("Testing stream connectivity...")
        
        # Test stream
        stream_response = requests.get(stream_url, headers=headers, stream=True, timeout=10)
        print(f"Stream headers: {stream_response.headers}")
        print(f"Stream status code: {stream_response.status_code}")
        
    else:
        print("No stream URL found in playlist.")

except Exception as e:
    print(f"Error: {e}")
