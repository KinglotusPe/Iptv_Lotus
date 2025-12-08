import flet as ft
import qrcode
import io
import base64
import requests
import asyncio
from client import XtreamClient
from utils import parse_m3u, Channel
import flet_video as fv

# Configuration
TELEGRAM_LINK = "https://t.me/LotusIptvFREE"
APP_TITLE = "LotusPlay"
DEVELOPER_TAG = "@Kinglotusp"

async def main(page: ft.Page):
    page.title = APP_TITLE
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 0
    page.window_width = 400
    page.window_height = 700
    page.window_resizable = True
    
    # --- Theme Colors ---
    primary_color = "amber"
    background_color = "#1a1a1a"
    surface_color = "#2d2d2d"

    page.bgcolor = background_color
    
    # --- State ---
    current_channels = []
    current_filtered_channels = []
    
    def async_bind(func, *args, **kwargs):
        async def handler(e):
            await func(*args, **kwargs)
        return handler
    
    # --- Account Manager ---
    # --- Account Manager ---
    async def get_accounts():
        return await page.client_storage.get_async("iptv_accounts") or []

    async def save_account(account_data):
        accounts = await get_accounts()
        accounts.append(account_data)
        await page.client_storage.set_async("iptv_accounts", accounts)

    async def delete_account(index):
        accounts = await get_accounts()
        if 0 <= index < len(accounts):
            accounts.pop(index)
            await page.client_storage.set_async("iptv_accounts", accounts)
            await show_profiles_view()

    # --- Favorites Manager ---
    # --- Favorites Manager ---
    async def get_favorites():
        return await page.client_storage.get_async("iptv_favorites") or []

    async def toggle_favorite(channel_url, channel_name):
        favs = await get_favorites()
        # Simple check by URL (or name if URL is dynamic/temporary, but URL is safer for consistent streams)
        exists = next((f for f in favs if f["url"] == channel_url), None)
        
        if exists:
            favs.remove(exists)
            show_info(f"Removido de favoritos: {channel_name}")
        else:
            favs.append({"url": channel_url, "name": channel_name})
            show_info(f"Añadido a favoritos: {channel_name}")
            
        await page.client_storage.set_async("iptv_favorites", favs)
        # Visual update will happen on list refresh or we can try to update icon directly 
        # For simplicity, we might reload current list view if "Favorites" category is verified
        
    async def is_favorite(channel_url):
        favs = await get_favorites()
        return any(f["url"] == channel_url for f in favs)

    # --- Helper: Generate QR Code ---
    def generate_qr_base64(data):
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        buffered = io.BytesIO()
        img.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode("utf-8")
        return img_str

    # --- Logic ---
    def show_error(message):
        page.snack_bar = ft.SnackBar(ft.Text(message, color="white"), bgcolor="red")
        page.snack_bar.open = True
        page.update()

    def show_info(message):
        page.snack_bar = ft.SnackBar(ft.Text(message, color="white"), bgcolor="green")
        page.snack_bar.open = True
        page.update()

    def start_url_type(url):
         return url.split("?")[0]

    # --- Caching ---
    # --- Caching ---
    async def get_cached_channels(url):
        try:
            data = await page.client_storage.get_async(f"cache_{url}")
            if data:
                return [Channel(**d) for d in data]
        except Exception as e:
            print(f"Cache error: {e}")
            await page.client_storage.remove_async(f"cache_{url}") # Clear corrupt cache
        return None

    async def cache_channels(url, channels):
        # Convert objects to dicts for storage
        data = [c.__dict__ for c in channels]
        await page.client_storage.set_async(f"cache_{url}", data)

    async def load_channels(url, force_refresh=False):
        # Try Cache First
        if not force_refresh:
            cached = await get_cached_channels(url)
            if cached:
                show_info("Cargado desde caché (Rápido)")
                await show_channel_list(cached, url) # Pass URL to allows refresh later
                return

        try:
            loading_dlg = ft.AlertDialog(
                content=ft.Row([ft.ProgressRing(), ft.Text("Descargando lista actualizada...")], 
                alignment=ft.MainAxisAlignment.CENTER), 
                modal=True
            )
            page.open(loading_dlg)
            
            # Auto-correction
            if "player_api.php" in url and "get.php" not in url:
                url = url.replace("player_api.php", "get.php")

            headers = {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            }
            
            # Async request
            response = await asyncio.to_thread(requests.get, url, timeout=15, headers=headers)
            response.raise_for_status()
            
            channels = parse_m3u(response.text)
            page.close(loading_dlg)
            
            if not channels:
                show_error("No se encontraron canales en la lista.")
                return

            cache_channels(url, channels) # Save to cache
            show_channel_list(channels, url)

        except Exception as e:
            try: page.close(loading_dlg) 
            except: pass
            
            # Fallback to cache if network fails?
            cached = await get_cached_channels(url)
            if cached:
                show_error(f"Error de red. Mostrando caché offline.")
                await show_channel_list(cached, url)
            else:
                show_error(f"Error al cargar lista: {str(e)}")



    async def show_video_player(channel):
        page.clean()
        
        # Video Control
        # Anti-blocking headers for the stream
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        }
        
        video_player = fv.Video(
            playlist=[fv.VideoMedia(channel.url, http_headers=headers)],
            playlist_mode=fv.PlaylistMode.SINGLE,
            fill_color="black",
            aspect_ratio=16/9,
            autoplay=True,
            volume=100,
            expand=True,
        )
        
        page.add(
            ft.Column([
                ft.Container(
                    content=ft.Row([
                        # Best effort back button
                        ft.IconButton("arrow_back", on_click=async_bind(show_channel_list, current_channels, channel.url.split("/get.php")[0] if "get.php" in channel.url else None)),
                        ft.Text(channel.name, size=16, weight=ft.FontWeight.BOLD, no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS, expand=True)
                    ]),
                    padding=10,
                    bgcolor=surface_color
                ),
                ft.Container(
                    content=video_player,
                    expand=True,
                    bgcolor="black",
                    alignment=ft.alignment.center
                ),
            ], expand=True)
        )

    async def show_channel_list(channels, list_url=None):
        page.clean()
        current_channels[:] = channels
        current_filtered_channels[:] = channels
        
        # --- Filters ---
        categories = sorted(list(set(c.category for c in channels)))
        if "General" in categories: categories.remove("General"); categories.insert(0, "General")
        
        # Insert Favorites Category
        categories.insert(0, "★ Favoritos")
        
        selected_category = ["All"] # List ref for mutability

        async def update_list():
            # Filter Logic
            filtered = []
            search_query = txt_search.value.lower()
            cat = selected_category[0]
            
            fav_urls = {f["url"] for f in await get_favorites()} # Optimize lookup
            
            for c in channels:
                matches_search = search_query in c.name.lower()
                
                # Cat Logic
                if cat == "★ Favoritos":
                    matches_cat = c.url in fav_urls
                elif cat == "All":
                    matches_cat = True
                else:
                    matches_cat = (c.category == cat)
                
                if matches_search and matches_cat:
                    filtered.append(c)
            
            current_filtered_channels[:] = filtered
            
            # Rebuild List Control
            lv.controls.clear()
            if not filtered:
                lv.controls.append(ft.Text("LotusPlay no encontró canales.", color="grey", italic=True))
            else:
                 for c in filtered[:100]: # Limit render for performance initially
                    
                    is_fav = await is_favorite(c.url)
                    fav_icon = "favorite" if is_fav else "favorite_border"
                    fav_color = "red" if is_fav else "white"

                    async def on_fav_click(e, chan=c):
                         await toggle_favorite(chan.url, chan.name)
                         # Refresh list if we are in Favorites tab to remove it dynamically
                         if selected_category[0] == "★ Favoritos":
                             await update_list()
                         else:
                             # Visual update: force refresh list to update icon
                             await update_list()

                    lv.controls.append(
                        ft.Container(
                            content=ft.Row([
                                ft.Icon("tv", color=primary_color),
                                ft.Column([
                                    ft.Text(c.name, weight=ft.FontWeight.BOLD, no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS),
                                    ft.Text(c.category, size=12, color="grey")
                                ], expand=True),
                                # Favorites Button
                                ft.IconButton(fav_icon, icon_color=fav_color, on_click=on_fav_click),
                                ft.IconButton("play_circle", icon_color="white", on_click=async_bind(show_video_player, c))
                            ]),
                            bgcolor=surface_color,
                            padding=10,
                            border_radius=5,
                            ink=True,
                            on_click=async_bind(show_video_player, c)
                        )
                    )
            page.update()

        async def on_search(e):
            await update_list()

        # --- UI Elements ---
        txt_search = ft.TextField(
            hint_text="Buscar en LotusPlay...", 
            prefix_icon="search", 
            border_radius=20, 
            height=40, 
            content_padding=10, 
            text_size=14,
            on_change=on_search,
            expand=True
        )

        # Categories - Horizontal Scroll
        cat_row = ft.Row(scroll=ft.ScrollMode.HIDDEN)
        
        async def check_parental_pin(category, on_success):
            keywords = ["adult", "xxx", "+18", "porn", "xv", "sex", "18+"]
            if not any(k in category.lower() for k in keywords):
                await on_success()
                return

            saved_pin = await page.client_storage.get_async("parental_pin")
            
            async def verify_pin(e):
                if txt_pin.value == saved_pin:
                    page.close(dlg_pin)
                    await on_success()
                else:
                    txt_pin.error_text = "PIN Incorrecto"
                    txt_pin.update()

            async def create_pin(e):
                if len(txt_create.value) == 4 and txt_create.value.isdigit():
                    await page.client_storage.set_async("parental_pin", txt_create.value)
                    page.close(dlg_create)
                    show_info("PIN Creado. Selecciona la categoría nuevamente.")
                else:
                    txt_create.error_text = "Debe ser de 4 dígitos"
                    txt_create.update()

            if not saved_pin:
                txt_create = ft.TextField(label="Crea un PIN de 4 dígitos", password=True, max_length=4, text_align=ft.TextAlign.CENTER)
                dlg_create = ft.AlertDialog(
                    title=ft.Text("Control Parental"),
                    content=ft.Column([ft.Text("Para acceder a contenido para adultos, crea un PIN de seguridad."), txt_create], tight=True),
                    actions=[ft.TextButton("Guardar PIN", on_click=create_pin)]
                )
                page.open(dlg_create)
            else:
                txt_pin = ft.TextField(label="Ingresa tu PIN", password=True, max_length=4, text_align=ft.TextAlign.CENTER, autofocus=True)
                dlg_pin = ft.AlertDialog(
                    title=ft.Text("Contenido Bloqueado"),
                    content=txt_pin,
                    actions=[ft.TextButton("Entrar", on_click=verify_pin)]
                )
                page.open(dlg_pin)

        async def set_cat(category_name):
            async def _apply():
                selected_category[0] = category_name
                await update_list()
            
            await check_parental_pin(category_name, _apply)

        # Add "All" button
        cat_row.controls.append(ft.OutlinedButton("Todos", on_click=async_bind(set_cat, "All"), height=30))
        for cat in categories:
            # Highlight 'Favorites' specially?
            btn_style = ft.ButtonStyle(color="amber") if cat == "★ Favoritos" else None
            display_text = cat if cat and cat.strip() else "Otros"
            cat_row.controls.append(ft.OutlinedButton(display_text, on_click=async_bind(set_cat, cat), height=30, style=btn_style))

        lv = ft.ListView(expand=1, spacing=10, padding=10)
        
        # Initial Build
        asyncio.create_task(update_list())
            
        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Container(
                        content=ft.Row([
                            ft.IconButton("arrow_back", on_click=async_bind(show_profiles_view)), 
                            # Quick fix: The `load_channels` function doesn't receive `account_data` yet, only URL.
                            # We need to look up owner of this URL to return to dashboard properly.
                            # For now: return to Profile Selection is safer if we don't know the dash.
                            txt_search,
                            ft.IconButton("refresh", tooltip="Actualizar Lista", icon_color="white", on_click=async_bind(load_channels, list_url, force_refresh=True)) if list_url else ft.Container()
                        ]),
                        padding=10
                    ),
                    ft.Text(f"{len(channels)} Canales", size=12, text_align=ft.TextAlign.CENTER),
                    ft.Container(content=cat_row, padding=ft.padding.only(left=10, right=10, bottom=10), height=50),
                    lv
                ]),
                expand=True
            )
        )
        
    # --- VOD Logic ---
    async def load_vod(account_data):
        if account_data["type"] != "xtream":
            def close_dlg(e):
                page.close(dlg)
            
            dlg = ft.AlertDialog(
                title=ft.Text("Función No Disponible"), 
                content=ft.Text("El catálogo de películas (VOD) solo funciona con cuentas Xtream Codes, no con listas M3U simples."), 
                actions=[ft.TextButton("Entendido", on_click=close_dlg)]
            )
            page.open(dlg)
            return
            
        loading_dlg = ft.AlertDialog(content=ft.Row([ft.ProgressRing(), ft.Text("Cargando Películas...")], alignment=ft.MainAxisAlignment.CENTER), modal=True)
        page.open(loading_dlg)
        
        try:
            data = account_data["data"]
            client = XtreamClient(data["server"], data["port"], data["user"], data["pass"])
            
            # Fetch content
            # TODO: Pagination?
            vod_streams = await client.get_vod_streams()
            page.close(loading_dlg)
            
            if not vod_streams:
                show_error("No se encontraron películas.")
                return
                
            show_vod_grid(vod_streams, account_data)

        except Exception as e:
            try: page.close(loading_dlg) 
            except: pass
            show_error(f"Error cargando VOD: {str(e)}")

    def show_vod_grid(streams, account_data):
        page.clean()
        
        # Grid
        grid = ft.GridView(
            expand=True,
            runs_count=3,
            max_extent=150,
            child_aspect_ratio=0.67, # Poster ratio
            spacing=10,
            run_spacing=10,
            padding=10
        )
        
        # Limit to first 50 for now or implement lazy load
        for s in streams[:50]:
            name = s.get("name", "Sin Título")
            img = s.get("stream_icon")
            stream_id = s.get("stream_id")
            ext = s.get("container_extension", "mp4")
            
            # Click to play? Xtream VOD url
            # http://domain:port/movie/user/pass/id.ext
            data = account_data["data"]
            stream_url = f"{data['server']}:{data['port']}/movie/{data['user']}/{data['pass']}/{stream_id}.{ext}"
            
            # Use Channel object for existing player
            vod_channel = Channel(name, stream_url, img, "VOD", stream_id)
            
            card = ft.Container(
                content=ft.Column([
                    ft.Image(src=img, fit=ft.ImageFit.COVER, error_content=ft.Icon("movie", size=50), border_radius=5, expand=True),
                    ft.Text(name, size=12, no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS)
                ]),
                bgcolor="#1f1f1f",
                border_radius=5,
                padding=5,
                ink=True,
                on_click=lambda e, c=vod_channel: show_video_player(c)
            )
            grid.controls.append(card)
            
        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.IconButton("arrow_back", on_click=lambda _: show_dashboard(account_data)),
                        ft.Text("Películas", size=20, weight=ft.FontWeight.BOLD),
                    ], alignment=ft.MainAxisAlignment.START),
                    grid
                ], expand=True),
                expand=True
            )
        )

    # --- Series Logic ---
    async def load_series(account_data):
        if account_data["type"] != "xtream":
             def close_dlg_s(e): page.close(dlg_s)
             dlg_s = ft.AlertDialog(title=ft.Text("No Disponible"), content=ft.Text("Solo cuentas Xtream."), actions=[ft.TextButton("OK", on_click=close_dlg_s)])
             page.open(dlg_s)
             return

        loading_dlg = ft.AlertDialog(content=ft.Row([ft.ProgressRing(), ft.Text("Cargando Series...")], alignment=ft.MainAxisAlignment.CENTER), modal=True)
        page.open(loading_dlg)

        try:
            data = account_data["data"]
            client = XtreamClient(data["server"], data["port"], data["user"], data["pass"])
            
            series = await client.get_series()
            page.close(loading_dlg)
            
            if not series:
                show_error("No se encontraron series.")
                return
            
            show_series_grid(series, account_data)
            
        except Exception as e:
            try: page.close(loading_dlg) 
            except: pass
            show_error(f"Error: {e}")

    def show_series_grid(series_list, account_data):
        page.clean()
        
        grid = ft.GridView(
            expand=True,
            runs_count=3,
            max_extent=150,
            child_aspect_ratio=0.67,
            spacing=10,
            run_spacing=10,
            padding=10
        )
        
        for s in series_list[:50]:
            name = s.get("name", "Sin Título")
            img = s.get("cover")
            
            card = ft.Container(
                content=ft.Column([
                    ft.Image(src=img, fit=ft.ImageFit.COVER, error_content=ft.Icon("tv", size=50), border_radius=5, expand=True),
                    ft.Text(name, size=12, no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS)
                ]),
                bgcolor="#1f1f1f",
                border_radius=5,
                padding=5,
                ink=True,
                on_click=lambda e: show_info("Reproducción de episodios próximamente") 
            )
            grid.controls.append(card)

        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.IconButton("arrow_back", on_click=lambda _: show_dashboard(account_data)),
                        ft.Text("Series", size=20, weight=ft.FontWeight.BOLD),
                    ]),
                    grid
                ], expand=True),
                expand=True
            )
        )

    async def show_settings_view(account_data):
        page.clean()
        
        async def clear_cache(e):
             await page.client_storage.clear_async()
             show_info("Caché borrada. Reinicia la app.")
             
        def change_pin(e):
            async def save_new_pin(e):
                if len(txt_new_pin.value) == 4 and txt_new_pin.value.isdigit():
                    await page.client_storage.set_async("parental_pin", txt_new_pin.value)
                    page.close(dlg_pin)
                    show_info("PIN Actualizado")
                else:
                    txt_new_pin.error_text = "Debe ser de 4 dígitos"
                    txt_new_pin.update()

            txt_new_pin = ft.TextField(label="Nuevo PIN", max_length=4, text_align=ft.TextAlign.CENTER)
            dlg_pin = ft.AlertDialog(
                title=ft.Text("Cambiar PIN Parental"),
                content=txt_new_pin,
                actions=[ft.TextButton("Guardar", on_click=save_new_pin)]
            )
            page.open(dlg_pin)

        def toggle_theme(e):
            page.theme_mode = ft.ThemeMode.LIGHT if page.theme_mode == ft.ThemeMode.DARK else ft.ThemeMode.DARK
            page.update()

        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Row([
                         ft.IconButton("arrow_back", on_click=async_bind(show_dashboard, account_data)),
                         ft.Text("Ajustes", size=24, weight=ft.FontWeight.BOLD)
                    ]),
                    ft.Container(height=20),
                    ft.Text("General", color="amber", weight=ft.FontWeight.BOLD),
                    ft.ListTile(leading=ft.Icon("cleaning_services"), title=ft.Text("Borrar Datos y Caché"), on_click=clear_cache),
                    ft.ListTile(leading=ft.Icon("palette"), title=ft.Text("Cambiar Tema"), trailing=ft.Switch(value=page.theme_mode==ft.ThemeMode.DARK, on_change=toggle_theme)),
                    
                    ft.Divider(),
                    ft.Text("Seguridad", color="amber", weight=ft.FontWeight.BOLD),
                    ft.ListTile(leading=ft.Icon("lock"), title=ft.Text("Cambiar PIN Parental"), on_click=change_pin),
                    
                    ft.Divider(),
                    ft.Text("Cuenta", color="amber", weight=ft.FontWeight.BOLD),
                    ft.ListTile(leading=ft.Icon("logout", color="red"), title=ft.Text("Cerrar Sesión", color="red"), on_click=async_bind(show_profiles_view)),
                    
                    ft.Divider(),
                    ft.ListTile(leading=ft.Icon("info"), title=ft.Text("Versión 1.0.0"), subtitle=ft.Text("Desarrollado por @Kinglotusp")),
                ], scroll=ft.ScrollMode.AUTO),
                expand=True,
                padding=20
            )
        )

    # --- Dashboard (Home) ---
    async def show_dashboard(account_data):
        page.clean()
        
        def dash_card(icon_name, title, subtitle, color, on_click):
             return ft.Container(
                content=ft.Column([
                    ft.Icon(icon_name, size=40, color="white"),
                    ft.Text(title, size=16, weight=ft.FontWeight.BOLD),
                    ft.Text(subtitle, size=12, color="white70")
                ], alignment=ft.MainAxisAlignment.CENTER, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                bgcolor=color,
                # Simplified gradient avoiding opacity issues
                # gradient=ft.LinearGradient(colors=[color, ft.colors.with_opacity(0.8, color)]), 
                width=150, height=150,
                border_radius=15,
                ink=True,
                on_click=on_click,
                alignment=ft.alignment.center
            )

        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Container(
                        content=ft.Row([
                            ft.IconButton("arrow_back", on_click=async_bind(show_profiles_view)),
                            ft.Text(account_data["name"], size=20, weight=ft.FontWeight.BOLD)
                        ]),
                        padding=10
                    ),
                    ft.Container(height=20),
                    ft.Text("Bienvenido a LotusPlay", size=30, weight=ft.FontWeight.BOLD, color="amber"),
                    ft.Text("¿Qué deseas ver hoy?", size=14, color="grey"),
                    ft.Container(height=40),
                    ft.Row([
                        dash_card("live_tv", "Live TV", "Canales en Vivo", "blue", async_bind(load_channels, account_data["url"])),
                        dash_card("movie", "Películas", "Catálogo VOD", "red", async_bind(load_vod, account_data))
                    ], alignment=ft.MainAxisAlignment.CENTER, spacing=20),
                    ft.Container(height=20),
                    ft.Row([

                         dash_card("tv", "Series", "Próximamente", "purple", async_bind(load_series, account_data)),
                         dash_card("settings", "Ajustes", "Opciones", "grey", async_bind(show_settings_view, account_data))
                    ], alignment=ft.MainAxisAlignment.CENTER, spacing=20),
                    ft.Container(height=20),
                    ft.Text("Desarrollado por @Kinglotusp", size=12, color="grey")
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                expand=True
            )
        )

    # --- Views ---
    async def show_profiles_view():
        page.clean()
        
        accounts = await get_accounts()
        
        lv = ft.ListView(expand=True, spacing=15, padding=20)
        
        for idx, acc in enumerate(accounts):
            # Determine account status info
            user_info = acc.get("user_info", {})
            exp_timestamp = user_info.get("exp_date")
            is_active = user_info.get("status") == "Active" or not exp_timestamp
            
            # Format Date
            exp_text = "Desconocido"
            if exp_timestamp and str(exp_timestamp).isdigit():
                import datetime
                try:
                    dt = datetime.datetime.fromtimestamp(int(exp_timestamp))
                    exp_text = dt.strftime("%d/%m/%Y")
                except: pass
            elif exp_timestamp:
                exp_text = str(exp_timestamp)
                if exp_text.lower() == "unlimited":
                    exp_text = "Ilimitado"

            # Card Color Status
            status_color = "green" if is_active else "red"
            status_text = "ACTIVO" if is_active else "VENCIDO"

            lv.controls.append(
                ft.Container(
                    content=ft.Row([
                        ft.Container(
                            content=ft.Icon("person", size=40, color="black"),
                            bgcolor="amber",
                            border_radius=50,
                            padding=10
                        ),
                        ft.Column([
                            ft.Text(acc.get("name", "Cuenta"), size=18, weight=ft.FontWeight.BOLD),
                            ft.Row([
                                ft.Icon("circle", size=10, color=status_color),
                                ft.Text(f"{status_text} • Vence: {exp_text}", size=12, color="grey")
                            ])
                        ], expand=True),
                        ft.IconButton("arrow_forward_ios", icon_color="white", on_click=async_bind(show_dashboard, acc)),
                        # FIX: Pass index to delete_account
                        ft.IconButton("delete", icon_color="red", on_click=async_bind(delete_account, idx))
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    bgcolor="#1f1f1f", # Darker card background
                    padding=20,
                    border_radius=15,
                    border=ft.border.all(1, "#333333"),
                    ink=True,
                    on_click=async_bind(show_dashboard, acc)
                )
            )

        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Container(height=20),
                    # Generic logo icon if image not available
                    ft.Icon("live_tv", size=80, color="amber"), 
                    ft.Text("Cuentas LotusPlay", size=24, weight=ft.FontWeight.BOLD),
                    ft.Text("Selecciona una cuenta para continuar", color="grey"),
                    ft.Container(height=20),
                    lv if accounts else ft.Container(
                        content=ft.Text("No tienes cuentas guardadas.", italic=True),
                        alignment=ft.alignment.center,
                        padding=20
                    ),
                    ft.Container(height=20),
                    ft.ElevatedButton(
                        "Agregar Nueva Cuenta", 
                        icon="add", 
                        on_click=lambda _: show_login_view(),
                        style=ft.ButtonStyle(
                            bgcolor="amber",
                            color="black",
                            shape=ft.RoundedRectangleBorder(radius=10),
                            padding=15
                        )
                    ),
                    ft.Container(height=20),
                    ft.Text("Desarrollado por @Kinglotusp", size=12, color="grey")
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                expand=True,
                gradient=ft.LinearGradient(
                    begin=ft.alignment.top_center, # Replaced named alignment (if any error, use straight values)
                    end=ft.alignment.bottom_center,
                    colors=["#111111", "#000000"]
                )
            )
        )

    # --- Login View ---
    def show_login_view():
        page.clean()
        
        # Tabs for Login Method
        # Defined controls here for closure access
        txt_server = ft.TextField(label="Servidor / URL", prefix_icon="link", hint_text="http://ejemplo.com", bgcolor=surface_color, border_radius=10)
        txt_port = ft.TextField(label="Puerto (Opcional)", prefix_icon="numbers", width=150, bgcolor=surface_color, border_radius=10)
        txt_user = ft.TextField(label="Usuario", prefix_icon="person", bgcolor=surface_color, border_radius=10)
        txt_pass = ft.TextField(label="Contraseña", prefix_icon="lock", password=True, can_reveal_password=True, bgcolor=surface_color, border_radius=10)
        txt_name_xtream = ft.TextField(label="Nombre del Perfil (Opcional)", prefix_icon="edit", bgcolor=surface_color, border_radius=10)
        
        txt_m3u = ft.TextField(label="URL de la Lista M3U", prefix_icon="link", hint_text="http://...", bgcolor=surface_color, border_radius=10)
        txt_name_m3u = ft.TextField(label="Nombre del Perfil", prefix_icon="edit", bgcolor=surface_color, border_radius=10)

        async def login_click(e):
            if tabs.selected_index == 0: # Xtream
                server = txt_server.value
                port = txt_port.value
                user = txt_user.value
                password = txt_pass.value
                name = txt_name_xtream.value or server

                if not all([server, user, password]):
                    show_error("Completa servidor, usuario y contraseña")
                    return

                loading_dlg = ft.AlertDialog(content=ft.Row([ft.ProgressRing(), ft.Text("Validando...")]), modal=True)
                page.open(loading_dlg)

                try:
                    client = XtreamClient(server, port, user, password)
                    is_valid, result = await client.validate_login()
                    page.close(loading_dlg)

                    if is_valid:
                        account = {
                            "name": name,
                            "type": "xtream",
                            "url": client.get_m3u_url(),
                            "data": {"server": server, "port": port, "user": user, "pass": password},
                            "user_info": result.get("user_info", {}) if isinstance(result, dict) else {}
                        }
                        await save_account(account)
                        show_info("Cuenta guardada correctamente")
                        await show_dashboard(account)
                    else:
                        show_error(f"Error: {result}")
                except Exception as ex:
                    try: page.close(loading_dlg) 
                    except: pass
                    show_error(f"Error de conexión: {ex}")

            else: # M3U
                url = txt_m3u.value
                name = txt_name_m3u.value or "Mi Lista"
                
                if not url:
                    show_error("Ingresa una URL")
                    return
                
                account = {
                    "name": name,
                    "type": "m3u",
                    "url": url,
                    "data": {"url": url},
                    "user_info": {"status": "Active", "exp_date": "Unlimited"} # Pseudo info for M3U
                }
                await save_account(account)
                show_info("Lista guardada")
                await show_dashboard(account)

        tabs = ft.Tabs(
            selected_index=0,
            animation_duration=300,
            tabs=[
                ft.Tab(
                    text="Xtream Codes",
                    icon="dns",
                    content=ft.Container(
                        content=ft.Column([
                            txt_server,
                            txt_port,
                            txt_user,
                            txt_pass,
                            txt_name_xtream,
                            ft.ElevatedButton("Conectar", icon="login", on_click=login_click, style=ft.ButtonStyle(bgcolor="amber", color="black", padding=15, shape=ft.RoundedRectangleBorder(radius=10)))
                        ], spacing=15, scroll=ft.ScrollMode.AUTO),
                        padding=20
                    )
                ),
                ft.Tab(
                    text="Lista M3U",
                    icon="list",
                    content=ft.Container(
                        content=ft.Column([
                            txt_m3u,
                            txt_name_m3u,
                            ft.ElevatedButton("Cargar Lista", icon="cloud_download", on_click=login_click, style=ft.ButtonStyle(bgcolor="amber", color="black", padding=15, shape=ft.RoundedRectangleBorder(radius=10)))
                        ], spacing=15),
                        padding=20
                    )
                )
            ],
            expand=True
        )

        page.add(
            ft.Container(
                content=ft.Column([
                    ft.Container(height=20),
                    # Use Icon instead of Image to be safe if logo.png missing
                    ft.Icon("tv", size=60, color="amber"),
                    ft.Text("Acceso LotusPlay", size=24, weight=ft.FontWeight.BOLD),
                    ft.Container(
                        content=tabs,
                        expand=True,
                        bgcolor=background_color,
                        border_radius=10
                    ),
                    ft.Row([
                        ft.TextButton("Obtener Listas Gratis", icon="telegram", style=ft.ButtonStyle(color="blue"), on_click=show_telegram_dialog)
                    ], alignment=ft.MainAxisAlignment.CENTER),
                    ft.Text("Desarrollado por @Kinglotusp", size=12, color="grey")
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                expand=True,
                padding=20,
                 gradient=ft.LinearGradient(
                    begin=ft.alignment.top_center, 
                    end=ft.alignment.bottom_center,
                    colors=["#111111", "#080808"]
                )
            )
        )

    def show_telegram_dialog(e):
        qr_base64 = generate_qr_base64(TELEGRAM_LINK)
        dlg = ft.AlertDialog(
            title=ft.Text("Únete a nuestro canal", text_align=ft.TextAlign.CENTER),
            content=ft.Column([
                ft.Image(src_base64=qr_base64, width=200, height=200),
                ft.Text("Escanea para obtener listas GRATIS", size=12, text_align=ft.TextAlign.CENTER),
                ft.TextButton("Abrir en Telegram", on_click=lambda _: page.launch_url(TELEGRAM_LINK))
            ], tight=True, alignment=ft.MainAxisAlignment.CENTER),
            actions=[ft.TextButton("Cerrar", on_click=lambda _: page.close(dlg))],
            actions_alignment=ft.MainAxisAlignment.CENTER,
        )
        page.open(dlg)

    # --- UI Components Instances ---

    # Init - Determine start screen
    if await get_accounts():
        await show_profiles_view()
    else:
        show_login_view()

ft.app(target=main)
