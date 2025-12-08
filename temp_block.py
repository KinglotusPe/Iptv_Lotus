    # --- VOD Logic ---
    def load_vod(account_data):
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
            vod_streams = client.get_vod_streams()
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
    def load_series(account_data):
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
            
            series = client.get_series()
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

    # --- Settings Logic ---
    def show_settings_view(account_data):
        page.clean()
        
        def clear_cache(e):
             page.client_storage.clear()
             show_info("Caché borrada. Reinicia la app.")
        
        page.add(
            ft.Column([
                ft.Row([
                     ft.IconButton("arrow_back", on_click=lambda _: show_dashboard(account_data)),
                     ft.Text("Ajustes", size=24, weight=ft.FontWeight.BOLD)
                ]),
                ft.Container(height=20),
                ft.ListTile(leading=ft.Icon("cleaning_services"), title=ft.Text("Borrar Datos y Caché"), on_click=clear_cache),
                ft.ListTile(leading=ft.Icon("logout", color="red"), title=ft.Text("Cerrar Sesión (Volver al Inicio)", color="red"), on_click=lambda _: show_profiles_view()),
                ft.ListTile(leading=ft.Icon("info"), title=ft.Text("Versión"), subtitle=ft.Text("1.0.0 LotusPlay Premium")),
            ], padding=20)
        )
