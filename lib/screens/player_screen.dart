import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../services/storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const PlayerScreen({super.key, required this.url, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  
  bool _isLoading = true;
  String? _errorMessage;

  // Aspect Ratio Settings
  double? _customAspectRatio;
  String _aspectRatioName = "Original";

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Registrar canal en el historial por perfil
      final account = await StorageService.getActiveAccount();
      if (account != null) {
        await StorageService.addToHistory(account, widget.url);
      }

      // 2. Inicializar VideoPlayer
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      
      // Timeout de inicialización de 15 segundos para evitar pantallas de carga infinitas
      await _videoPlayerController.initialize().timeout(const Duration(seconds: 15));
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _customAspectRatio,
        allowFullScreen: true,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error en la reproducción: $errorMessage",
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "No se pudo conectar al canal. Asegúrate de tener conexión a Internet y que la transmisión esté activa.\n\nDetalle: ${e.toString()}";
      });
    }
  }

  void _cycleAspectRatio() {
    if (_isLoading || _errorMessage != null || !_videoPlayerController.value.isInitialized) return;
    
    setState(() {
      if (_customAspectRatio == null) {
        _customAspectRatio = 16 / 9;
        _aspectRatioName = "16:9";
      } else if (_customAspectRatio == 16 / 9) {
        _customAspectRatio = 4 / 3;
        _aspectRatioName = "4:3";
      } else if (_customAspectRatio == 4 / 3) {
        // Estirar usando la proporción de la pantalla del dispositivo
        final Size size = MediaQuery.of(context).size;
        _customAspectRatio = size.width / size.height;
        _aspectRatioName = "Estirado";
      } else {
        _customAspectRatio = null;
        _aspectRatioName = "Original";
      }

      // Recrear ChewieController con el nuevo aspecto
      final isPlaying = _videoPlayerController.value.isPlaying;
      _chewieController?.dispose();
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: isPlaying,
        looping: false,
        aspectRatio: _customAspectRatio,
        allowFullScreen: true,
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Error en la reproducción: $errorMessage",
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      );
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Relación de aspecto: $_aspectRatioName"),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF151F32),
      ),
    );
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black54, 
        elevation: 0,
        actions: [
          if (!_isLoading && _errorMessage == null)
            IconButton(
              icon: const Icon(Icons.aspect_ratio, color: Color(0xFFFFB703)),
              tooltip: "Relación de Aspecto",
              onPressed: _cycleAspectRatio,
            ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFFFB703)),
                  const SizedBox(height: 16),
                  Text(
                    "Conectando al canal...", 
                    style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
                  ),
                ],
              )
            : (_errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 64, color: Color(0xFFFFB703)),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _initializePlayer,
                              icon: const Icon(Icons.refresh),
                              label: const Text("Reintentar"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB703),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              label: const Text("Volver", style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                : (_chewieController != null && _videoPlayerController.value.isInitialized
                    ? Chewie(controller: _chewieController!)
                    : const CircularProgressIndicator(color: Color(0xFFFFB703)))),
      ),
    );
  }
}
