import re

class Channel:
    def __init__(self, name, url, logo, category, tvg_id):
        self.name = name
        self.url = url
        self.logo = logo
        self.category = category
        self.tvg_id = tvg_id

    def __repr__(self):
        return f"<Channel {self.name}>"

def parse_m3u(content):
    """
    Parses string content of an M3U file.
    Returns a list of Channel objects.
    """
    channels = []
    
    # Regex pattern to extract attributes
    # #EXTINF:-1 tvg-id="" tvg-name="" tvg-logo="" group-title="",Channel Name
    # matches key="value" pairs
    attr_pattern = re.compile(r'([a-zA-Z0-9-]+)="([^"]*)"')
    
    lines = content.splitlines()
    current_channel = {}
    
    for line in lines:
        line = line.strip()
        
        if line.startswith("#EXTINF"):
            # Improved Parsing: Handle attributes appearing before OR after comma
            # Strategy: Extract all attributes first, then what remains is the name/metadata
            
            # Find all attributes in the line
            attrs = dict(attr_pattern.findall(line))
            
            # Identify name
            # 1. Remove #EXTINF:xxx tag
            clean_line = re.sub(r'^#EXTINF:[-0-9\.]+', '', line)
            # 2. Remove all attributes found
            for key, val in attrs.items():
                clean_line = clean_line.replace(f'{key}="{val}"', '')
            # 3. Remove commas and whitespace
            name = clean_line.strip().lstrip(',').strip()
            
            # Fallback if name became empty (rare)
            if not name:
                parts = line.split(',', 1)
                name = parts[1].strip() if len(parts) > 1 else "Unknown"

            current_channel = {
                "name": name,
                "logo": attrs.get("tvg-logo", ""),
                "category": attrs.get("group-title", "General"),
                "tvg_id": attrs.get("tvg-id", "")
            }
            
        elif line and not line.startswith("#"):
            # This is the URL
            if current_channel:
                channels.append(Channel(
                    name=current_channel["name"],
                    url=line,
                    logo=current_channel["logo"],
                    category=current_channel["category"],
                    tvg_id=current_channel["tvg_id"]
                ))
                current_channel = {} # Reset
                
    return channels
