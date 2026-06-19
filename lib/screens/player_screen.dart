import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final Channel channel;

  const PlayerScreen({super.key, required this.channel});

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

  // Gesture Feedback Overlay State
  IconData _overlayIcon = Icons.play_arrow;
  String _overlayText = "";
  double _overlayOpacity = 0.0;
  Timer? _overlayTimer;

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
        await StorageService.addToHistory(account, widget.channel);
      }

      // 2. Inicializar VideoPlayer
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.channel.url));
      
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

  void _triggerOverlay(IconData icon, String text) {
    _overlayTimer?.cancel();
    setState(() {
      _overlayIcon = icon;
      _overlayText = text;
      _overlayOpacity = 1.0;
    });
    _overlayTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _overlayOpacity = 0.0;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    if (!_videoPlayerController.value.isInitialized) return;
    final currentPos = _videoPlayerController.value.position;
    final duration = _videoPlayerController.value.duration;
    
    var newPos = currentPos + Duration(seconds: seconds);
    if (newPos < Duration.zero) {
      newPos = Duration.zero;
    } else if (newPos > duration) {
      newPos = duration;
    }
    
    _videoPlayerController.seekTo(newPos);
    _triggerOverlay(
      seconds < 0 ? Icons.fast_rewind : Icons.fast_forward, 
      seconds < 0 ? "-10s" : "+10s"
    );
  }

  void _togglePlayPause() {
    if (!_videoPlayerController.value.isInitialized) return;
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
        _triggerOverlay(Icons.pause, "Pausa");
      } else {
        _videoPlayerController.play();
        _triggerOverlay(Icons.play_arrow, "Reproducir");
      }
    });
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
    _overlayTimer?.cancel();
    _chewieController?.dispose();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.channel.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Chewie(controller: _chewieController!),
                          
                          // Custom Gesture Overlay (covers top 80% to avoid overlapping bottom timeline controls)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: 80,
                            child: Row(
                              children: [
                                // Left 50%: Double tap to rewind 10s
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onDoubleTap: () => _seekRelative(-10),
                                    onTap: _togglePlayPause,
                                  ),
                                ),
                                // Right 50%: Double tap to fast forward 10s
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onDoubleTap: () => _seekRelative(10),
                                    onTap: _togglePlayPause,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Center Feedback Overlay
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: _overlayOpacity,
                              duration: const Duration(milliseconds: 150),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.black70,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.3), width: 1.5),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _overlayIcon,
                                      color: const Color(0xFFFFB703),
                                      size: 48,
                                    ),
                                    if (_overlayText.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _overlayText,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(color: Color(0xFFFFB703)))),
      ),
    );
  }
}
