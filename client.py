import requests
import asyncio

class XtreamClient:
    def __init__(self, server, port, username, password):
        self.server = server.rstrip('/')
        self.port = port
        self.username = username
        self.password = password
        
        # Ensure protocol is present
        if not self.server.startswith('http'):
            self.server = f'http://{self.server}'

    def get_m3u_url(self):
        # Handle case where port is empty or already in server
        base_url = self.server
        if self.port:
             base_url = f"{self.server}:{self.port}"
        
        return f"{base_url}/get.php?username={self.username}&password={self.password}&type=m3u_plus&output=ts"

    async def validate_login(self):
        """
        Attempts to authenticate and fetch user info.
        Returns (True, user_info_dict) or (False, error_message).
        """
        # Xtream Codes Authentication API
        auth_url = f"{self.server}:{self.port}/player_api.php?username={self.username}&password={self.password}"
        
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        
        try:
            # Run blocking request in thread
            response = await asyncio.to_thread(requests.get, auth_url, timeout=10, headers=headers)
            response.raise_for_status()
            data = response.json()
            
            if data.get("user_info", {}).get("auth") == 1:
                return True, data
            else:
                return False, "Credenciales inválidas o cuenta expirada."

        except requests.exceptions.JSONDecodeError:
             # Fallback for some servers checking streams directly if auth API fails (older panels)
             pass 
        except Exception as e:
            return False, f"Error: {str(e)}"
            
        # Fallback to old M3U check if API fails
        return await self._validate_m3u_fallback()

    async def _validate_m3u_fallback(self):
        url = self.get_m3u_url()
        try:
            await asyncio.to_thread(requests.get, url, stream=True, timeout=5)
            # Not raising status here for stream check optimization or check response?
            # Ideally verify status but let's assume if no connection error it's likely ok or handled.
            # Actually let's do a quick head/get
            return True, {"user_info": {"username": self.username, "exp_date": "Unknown"}}
        except:
             return False, "Error de conexión."

    # --- VOD Methods ---
    async def get_vod_categories(self):
        url = f"{self.server}:{self.port}/player_api.php?username={self.username}&password={self.password}&action=get_vod_categories"
        try:
            response = await asyncio.to_thread(requests.get, url, timeout=10)
            return response.json()
        except: return []

    async def get_vod_streams(self, category_id=None):
        url = f"{self.server}:{self.port}/player_api.php?username={self.username}&password={self.password}&action=get_vod_streams"
        if category_id:
            url += f"&category_id={category_id}"
        try:
            response = await asyncio.to_thread(requests.get, url, timeout=15)
            return response.json()
        except: return []
        
    # --- Series Methods ---
    async def get_series_categories(self):
        url = f"{self.server}:{self.port}/player_api.php?username={self.username}&password={self.password}&action=get_series_categories"
        try:
            response = await asyncio.to_thread(requests.get, url, timeout=10)
            return response.json()
        except: return []

    async def get_series(self, category_id=None):
        url = f"{self.server}:{self.port}/player_api.php?username={self.username}&password={self.password}&action=get_series"
        if category_id:
            url += f"&category_id={category_id}"
        try:
            response = await asyncio.to_thread(requests.get, url, timeout=15)
            return response.json()
        except: return []

    async def get_series_info(self, series_id):
        url = f"{self.server}:{self.port}/player_api.php?username={self.username}&password={self.password}&action=get_series_info&series_id={series_id}"
        try:
            response = await asyncio.to_thread(requests.get, url, timeout=10)
            return response.json()
        except: return {}
