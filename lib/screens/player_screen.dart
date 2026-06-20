import 'dart:async';
import 'dart:ui';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../models/data_models.dart';
import '../services/storage_service.dart';

class PlayerScreen extends StatefulWidget {
  final List<Channel> channels;
  final int initialIndex;

  PlayerScreen({
    super.key,
    List<Channel>? channels,
    int? initialIndex,
    Channel? channel,
  })  : channels = channels ?? (channel != null ? [channel] : const []),
        initialIndex = initialIndex ?? 0;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  
  bool _isLoading = true;
  String? _errorMessage;

  // Navigation State
  late int _currentIndex;
  int _currentLoadToken = 0;

  // Mini-Guide State
  bool _isMiniGuideOpen = false;
  final ScrollController _miniGuideScrollController = ScrollController();
  late FocusNode _activeChannelFocusNode;

  // Main Focus
  final FocusNode _focusNode = FocusNode();

  // Aspect Ratio Settings
  double? _customAspectRatio;
  String _aspectRatioName = "Original";

  // Gesture Controls Settings
  double _screenBrightness = 1.0; // 0.1 to 1.0 (1.0 = normal, 0.1 = dim)
  double _currentVolume = 1.0;     // 0.0 to 1.0
  double _lastNonMutedVolume = 1.0;

  // Gesture Feedback Overlay State
  IconData _overlayIcon = Icons.play_arrow;
  String _overlayText = "";
  double _overlayOpacity = 0.0;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _activeChannelFocusNode = FocusNode();
    _initializePlayer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _initializePlayer() async {
    final loadToken = ++_currentLoadToken;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.channels.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = "No hay canales disponibles para reproducir.";
      });
      return;
    }

    final channel = widget.channels[_currentIndex];

    // 1. Registrar canal en el historial por perfil
    try {
      final account = await StorageService.getActiveAccount();
      if (!mounted || loadToken != _currentLoadToken) return;
      if (account != null) {
        await StorageService.addToHistory(account, channel);
      }
    } catch (err) {
      debugPrint("Error saving to history: $err");
    }

    int retryCount = 0;
    const int maxRetries = 3;
    bool successfullyInitialized = false;
    dynamic lastException;

    while (retryCount < maxRetries && !successfullyInitialized) {
      if (!mounted || loadToken != _currentLoadToken) return;

      if (retryCount > 0) {
        // Mostrar aviso temporal de reconexión
        setState(() {
          _overlayText = "Reconectando... (Intento $retryCount de $maxRetries)";
          _overlayIcon = Icons.sync;
          _overlayOpacity = 1.0;
        });
        
        // Espera progresiva: 2s, 3s, 5s
        final int delaySeconds = retryCount == 1 ? 2 : (retryCount == 2 ? 3 : 5);
        await Future.delayed(Duration(seconds: delaySeconds));
        if (!mounted || loadToken != _currentLoadToken) return;
      }

      VideoPlayerController? newController;
      try {
        newController = VideoPlayerController.networkUrl(Uri.parse(channel.url));
        await newController.initialize().timeout(const Duration(seconds: 12));
        
        if (!mounted || loadToken != _currentLoadToken) {
          await newController.dispose();
          return;
        }

        _videoPlayerController = newController;
        await _videoPlayerController.setVolume(_currentVolume); // Aplicar volumen guardado
        
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
        
        successfullyInitialized = true;
      } catch (e) {
        lastException = e;
        retryCount++;
        if (newController != null) {
          try {
            await newController.dispose();
          } catch (_) {}
        }
        if (!mounted || loadToken != _currentLoadToken) {
          return;
        }
      }
    }

    // Ocultar overlay temporal de reconexión
    if (mounted && loadToken == _currentLoadToken) {
      setState(() {
        _overlayOpacity = 0.0;
      });
    }

    if (successfullyInitialized) {
      if (mounted && loadToken == _currentLoadToken) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      if (mounted && loadToken == _currentLoadToken) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No se pudo conectar a la transmisión después de $maxRetries intentos de reconexión automática.\n\nAsegúrate de tener conexión a Internet y que la transmisión esté activa.\n\nDetalle: ${lastException.toString()}";
        });
      }
    }
  }

  void _triggerOverlay(IconData icon, String text) {
    _overlayTimer?.cancel();
    setState(() {
      _overlayIcon = icon;
      _overlayText = text;
      _overlayOpacity = 1.0;
    });
    _overlayTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _overlayOpacity = 0.0;
        });
      }
    });
  }

  void _seekRelative(int seconds) {
    if (_isLoading || _errorMessage != null || !_videoPlayerController.value.isInitialized) return;
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
    if (_isLoading || _errorMessage != null || !_videoPlayerController.value.isInitialized) return;
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

  void _toggleMute() {
    if (_isLoading || _errorMessage != null || !_videoPlayerController.value.isInitialized) return;
    setState(() {
      if (_currentVolume > 0.0) {
        _lastNonMutedVolume = _currentVolume;
        _currentVolume = 0.0;
      } else {
        _currentVolume = _lastNonMutedVolume > 0.0 ? _lastNonMutedVolume : 1.0;
      }
      _videoPlayerController.setVolume(_currentVolume);
      _triggerOverlay(
        _currentVolume == 0.0 ? Icons.volume_off : Icons.volume_up,
        _currentVolume == 0.0 ? "Silencio" : "Volumen: ${(_currentVolume * 100).toInt()}%"
      );
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
        final Size size = MediaQuery.of(context).size;
        _customAspectRatio = size.width / size.height;
        _aspectRatioName = "Estirado";
      } else {
        _customAspectRatio = null;
        _aspectRatioName = "Original";
      }

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

  void _zapChannel(bool next) {
    if (widget.channels.isEmpty) return;
    int newIndex = _currentIndex;
    if (next) {
      newIndex = (_currentIndex + 1) % widget.channels.length;
    } else {
      newIndex = (_currentIndex - 1 + widget.channels.length) % widget.channels.length;
    }
    _changeChannel(newIndex);
  }

  Future<void> _changeChannel(int index) async {
    if (index < 0 || index >= widget.channels.length) return;
    
    _overlayTimer?.cancel();
    
    // Cerrar controladores antiguos
    try {
      _chewieController?.dispose();
      _chewieController = null;
    } catch (_) {}
    
    try {
      await _videoPlayerController.dispose();
    } catch (_) {}

    _activeChannelFocusNode.dispose();
    _activeChannelFocusNode = FocusNode();

    setState(() {
      _currentIndex = index;
      _isLoading = true;
      _errorMessage = null;
    });

    final nextChannel = widget.channels[_currentIndex];
    _triggerOverlay(Icons.tv, "Cambiando a:\n${nextChannel.name}");

    await _initializePlayer();
  }

  void _showMiniGuide() {
    if (widget.channels.isEmpty) return;
    setState(() {
      _isMiniGuideOpen = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_miniGuideScrollController.hasClients) {
        final double targetOffset = (_currentIndex * 56.0).clamp(
          0.0,
          _miniGuideScrollController.position.maxScrollExtent,
        );
        _miniGuideScrollController.jumpTo(targetOffset);
      }
      _activeChannelFocusNode.requestFocus();
    });
  }

  void _closeMiniGuide() {
    setState(() {
      _isMiniGuideOpen = false;
    });
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _activeChannelFocusNode.dispose();
    _miniGuideScrollController.dispose();
    _overlayTimer?.cancel();
    _chewieController?.dispose();
    try {
      _videoPlayerController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentChannel = widget.channels.isNotEmpty ? widget.channels[_currentIndex] : null;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (_isMiniGuideOpen) {
            if (key == LogicalKeyboardKey.arrowRight || 
                key == LogicalKeyboardKey.escape || 
                key == LogicalKeyboardKey.goBack) {
              _closeMiniGuide();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else {
            if (key == LogicalKeyboardKey.arrowUp) {
              _zapChannel(true); // Cambiar adelante
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowDown) {
              _zapChannel(false); // Cambiar atrás
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.arrowLeft) {
              _showMiniGuide();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: PopScope(
        canPop: !_isMiniGuideOpen,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_isMiniGuideOpen) {
            _closeMiniGuide();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(
              currentChannel?.name ?? "Reproductor",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.black54, 
            elevation: 0,
            actions: [
              if (!_isLoading && _errorMessage == null) ...[
                IconButton(
                  icon: Icon(_currentVolume == 0.0 ? Icons.volume_off : Icons.volume_up, color: const Color(0xFFFFB703)),
                  tooltip: "Silenciar",
                  onPressed: _toggleMute,
                ),
                IconButton(
                  icon: const Icon(Icons.aspect_ratio, color: Color(0xFFFFB703)),
                  tooltip: "Relación de Aspecto",
                  onPressed: _cycleAspectRatio,
                ),
              ],
            ],
          ),
          body: SizedBox.expand(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video o Estado de Carga / Error
                Positioned.fill(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFFFFB703)),
                              const SizedBox(height: 16),
                              Text(
                                "Conectando al canal...", 
                                style: GoogleFonts.inter(color: Colors.white60, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : (_errorMessage != null
                          ? Center(
                              child: Padding(
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
                              ),
                            )
                          : (_chewieController != null && _videoPlayerController.value.isInitialized
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(child: Chewie(controller: _chewieController!)),
                                    
                                    // Pure Flutter Screen Brightness Simulation Overlay
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 50),
                                          color: Colors.black.withOpacity((1.0 - _screenBrightness).clamp(0.0, 0.85)),
                                        ),
                                      ),
                                    ),

                                    // Custom Gesture Overlay (covers top 80% to avoid overlapping bottom timeline controls)
                                    Positioned(
                                      top: 0,
                                      left: 0,
                                      right: 0,
                                      bottom: 80,
                                      child: Row(
                                        children: [
                                          // Left half: Brightness Gestures
                                          Expanded(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onDoubleTap: () => _seekRelative(-10),
                                              onTap: _togglePlayPause,
                                              onVerticalDragUpdate: (details) {
                                                final screenHeight = MediaQuery.of(context).size.height;
                                                if (screenHeight > 0) {
                                                  final change = -details.primaryDelta! / screenHeight;
                                                  setState(() {
                                                    _screenBrightness = (_screenBrightness + change).clamp(0.1, 1.0);
                                                  });
                                                  _triggerOverlay(
                                                    Icons.brightness_6, 
                                                    "Brillo: ${(_screenBrightness * 100).toInt()}%"
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                          // Right half: Volume Gestures
                                          Expanded(
                                            child: GestureDetector(
                                              behavior: HitTestBehavior.translucent,
                                              onDoubleTap: () => _seekRelative(10),
                                              onTap: _togglePlayPause,
                                              onVerticalDragUpdate: (details) {
                                                final screenHeight = MediaQuery.of(context).size.height;
                                                if (screenHeight > 0) {
                                                  final change = -details.primaryDelta! / screenHeight;
                                                  setState(() {
                                                    _currentVolume = (_currentVolume + change).clamp(0.0, 1.0);
                                                  });
                                                  _videoPlayerController.setVolume(_currentVolume);
                                                  _triggerOverlay(
                                                    _currentVolume == 0.0 
                                                        ? Icons.volume_mute 
                                                        : (_currentVolume < 0.5 ? Icons.volume_down : Icons.volume_up),
                                                    "Volumen: ${(_currentVolume * 100).toInt()}%"
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : const Center(
                                  child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                                ))),
                ),

                // Floating Buttons Overlay
                if (!_isLoading && _errorMessage == null) ...[
                  // Floating Guide Button (Left)
                  Positioned(
                    left: 20,
                    child: AnimatedOpacity(
                      opacity: _isMiniGuideOpen ? 0.0 : 0.6,
                      duration: const Duration(milliseconds: 200),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showMiniGuide,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.4), width: 1.5),
                            ),
                            child: const Icon(Icons.menu_open, color: Color(0xFFFFB703), size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Floating Zapping Buttons (Right)
                  Positioned(
                    right: 20,
                    child: AnimatedOpacity(
                      opacity: _isMiniGuideOpen ? 0.0 : 0.6,
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _zapChannel(false), // Canal anterior (Up)
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.4), width: 1.5),
                                ),
                                child: const Icon(Icons.keyboard_arrow_up, color: Color(0xFFFFB703), size: 28),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _zapChannel(true), // Canal siguiente (Down)
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.4), width: 1.5),
                                ),
                                child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFFB703), size: 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Center Feedback Text/Icon Overlay
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _overlayOpacity,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black87,
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
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Mini-Guide Overlay Sidebar Panel (Left)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: _isMiniGuideOpen ? 0 : -320,
                  top: 0,
                  bottom: 0,
                  width: 300,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0C1322).withOpacity(0.9),
                              const Color(0xFF090D16).withOpacity(0.95),
                            ],
                          ),
                          border: const Border(
                            right: BorderSide(color: Color(0xFFFFB703), width: 1.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.tv, color: Color(0xFFFFB703)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "GUÍA DE CANALES",
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                                    onPressed: _closeMiniGuide,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Colors.white24, height: 1),
                            // List of Channels
                            Expanded(
                              child: ListView.builder(
                                controller: _miniGuideScrollController,
                                itemCount: widget.channels.length,
                                itemBuilder: (context, index) {
                                  final channel = widget.channels[index];
                                  final isCurrent = index == _currentIndex;
                                  
                                  return Focus(
                                    focusNode: isCurrent ? _activeChannelFocusNode : null,
                                    autofocus: isCurrent,
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        final key = event.logicalKey;
                                        if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter) {
                                          _changeChannel(index);
                                          _closeMiniGuide();
                                          return KeyEventResult.handled;
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Builder(
                                      builder: (context) {
                                        final hasFocus = Focus.of(context).hasFocus;
                                        return InkWell(
                                          onTap: () {
                                            _changeChannel(index);
                                            _closeMiniGuide();
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 150),
                                            color: hasFocus
                                                ? const Color(0xFFFFB703).withOpacity(0.2)
                                                : (isCurrent ? const Color(0xFFFFB703).withOpacity(0.1) : Colors.transparent),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: Colors.black38,
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isCurrent ? const Color(0xFFFFB703) : Colors.white10,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: channel.logo.isNotEmpty
                                                        ? Image.network(
                                                            channel.logo,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (_, __, ___) => const Icon(Icons.tv, color: Colors.white24, size: 18),
                                                          )
                                                        : const Icon(Icons.tv, color: Colors.white24, size: 18),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    channel.name,
                                                    style: GoogleFonts.inter(
                                                      color: isCurrent
                                                          ? const Color(0xFFFFB703)
                                                          : (hasFocus ? Colors.white : Colors.white70),
                                                      fontSize: 13,
                                                      fontWeight: isCurrent || hasFocus ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
