# Iptv_Lotus (LotusPlay)

[![Build Flutter APK](https://github.com/KinglotusPe/Iptv_Lotus/actions/workflows/build_flutter.yaml/badge.svg)](https://github.com/KinglotusPe/Iptv_Lotus/actions)

**LotusPlay** es un reproductor de IPTV de alto rendimiento y diseño premium desarrollado en **Flutter**. Está optimizado para ofrecer una interfaz ultra fluida, rápida y adaptada tanto a dispositivos móviles y tablets Android como a pantallas grandes como **Android TV / Fire TV Boxes** mediante navegación interactiva con control remoto (D-Pad).

---

## 🚀 Características Principales

* **Doble Compatibilidad de Listas:** Soporta carga de listas mediante **API de Xtream Codes** (con separación automática de TV, Películas y Series) y enlaces de listas de reproducción **M3U estándar**.
* **Caché Local de Canales (Instant Load):** Los canales y categorías se guardan localmente por cuenta para un inicio instantáneo (en menos de 100ms), reduciendo el consumo de datos y eliminando esperas de red.
* **Historial de Reproducción ("Recientes"):** Sección dinámica en la barra lateral que almacena las últimas 15 transmisiones vistas de forma aislada para cada perfil de cuenta.
* **Relación de Aspecto Ajustable en Caliente:** Permite alternar la relación de aspecto directamente desde el reproductor entre *Original, 16:9, 4:3 y Estirado (pantalla completa)* sin interrumpir la transmisión.
* **Optimizado para Android TV (D-Pad Focus):** Soporte de foco de control remoto en todas las tarjetas y categorías, las cuales se expanden y encienden con bordes dorados iluminados al ser seleccionadas.
* **Sistema Multicuenta (Perfiles):** Interfaz al estilo Netflix que permite guardar, seleccionar y administrar múltiples cuentas de IPTV de forma totalmente independiente y segura.
* **Procesamiento Eficiente (Isolates):** Parseo asíncrono en segundo plano para procesar archivos M3U gigantescos sin congelar la pantalla de carga.

---

## 🛠️ Cómo Compilar y Ejecutar

Este proyecto está limpio de archivos temporales e incluye únicamente el código fuente y las herramientas de automatización necesarias para construir la aplicación.

### Prerrequisitos
* Tener instalado [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión `>=3.0.0 <4.0.0`).
* Un emulador Android o dispositivo físico con depuración USB activa.

### Instalación de dependencias
1. Clona este repositorio:
   ```bash
   git clone https://github.com/KinglotusPe/Iptv_Lotus.git
   cd Iptv_Lotus
   ```
2. Descarga los paquetes de Flutter necesarios:
   ```bash
   flutter pub get
   ```

### Ejecución en modo desarrollo (Debug)
Genera los archivos de la plataforma de Android e inicia la aplicación:
```bash
flutter create . --platforms android --project-name lotusplay
flutter run
```

### Compilación local del APK de producción (Release)
Construye el APK optimizado:
```bash
flutter build apk --release --no-tree-shake-icons
```
El archivo resultante se generará en: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📦 Descarga del APK Compilado (GitHub Actions)

No necesitas compilar el proyecto en tu computadora. Este repositorio cuenta con una integración de **GitHub Actions** automatizada:

1. Ve a la pestaña **[Actions](https://github.com/KinglotusPe/Iptv_Lotus/actions)** de este repositorio en GitHub.
2. Selecciona la última ejecución del flujo de trabajo **"Build Flutter APK"**.
3. Baja hasta la sección de **Artifacts** (al final de la página) y haz clic en **`Lotusplay`** para descargar el archivo **`Lotusplay.apk`** listo para instalar en tu celular o TV Box.

---

## 👥 Créditos y Licencia

* Desarrollado por **[@Kinglotusp](https://github.com/KinglotusPe)**.
* Proyecto LotusPlay IPTV Player para Android y Android TV.
