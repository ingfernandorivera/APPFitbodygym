import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';

/// Mini reproductor en tarjeta que muestra el fotograma inicial (postura en máquina)
/// con el botón central para reproducir/pausar ahí mismo en pequeño.
class ExerciseMiniVideoPreview extends StatefulWidget {
  const ExerciseMiniVideoPreview({
    required this.url,
    required this.index,
    this.width = 88,
    this.height = 64,
    this.onExpand,
    super.key,
  });

  final String? url;
  final int index;
  final double width;
  final double height;
  final VoidCallback? onExpand;

  @override
  State<ExerciseMiniVideoPreview> createState() =>
      _ExerciseMiniVideoPreviewState();
}

class _ExerciseMiniVideoPreviewState extends State<ExerciseMiniVideoPreview> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant ExerciseMiniVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _initController();
    }
  }

  void _initController() {
    final rawUrl = widget.url;
    if (rawUrl == null || rawUrl.isEmpty) return;

    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(rawUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = ctrl;
      ctrl.initialize().then((_) async {
        if (!mounted || _controller != ctrl) return;
        await ctrl.setLooping(true);
        await ctrl.setVolume(0.0);
        // Posicionar en un fotograma donde se aprecie la postura inicial en la máquina
        final duration = ctrl.value.duration;
        final previewPos = duration > const Duration(milliseconds: 900)
            ? const Duration(milliseconds: 800)
            : Duration.zero;
        await ctrl.seekTo(previewPos);
        if (mounted && _controller == ctrl) {
          setState(() {
            _initialized = true;
            _hasError = false;
          });
        }
      }).catchError((_) {
        if (mounted && _controller == ctrl) {
          setState(() {
            _initialized = false;
            _hasError = true;
          });
        }
      });
    } catch (_) {
      _hasError = true;
    }
  }

  void _disposeController() {
    final old = _controller;
    _controller = null;
    _initialized = false;
    _hasError = false;
    old?.dispose();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl != null && _initialized && !_hasError) {
      setState(() {
        if (ctrl.value.isPlaying) {
          ctrl.pause();
        } else {
          ctrl.play();
        }
      });
    } else if (widget.onExpand != null) {
      widget.onExpand!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.url != null && widget.url!.isNotEmpty;
    final ctrl = _controller;
    final isPlaying = _initialized && ctrl != null && ctrl.value.isPlaying;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying
                ? AppColors.brand
                : (hasUrl
                      ? AppColors.brand.withValues(alpha: 0.45)
                      : const Color(0xFF32323A)),
            width: isPlaying ? 1.5 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Fotograma real del video (postura) o fondo estilizado mientras carga
              if (_initialized && ctrl != null && !_hasError)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: ctrl.value.size.width > 0
                        ? ctrl.value.size.width
                        : widget.width,
                    height: ctrl.value.size.height > 0
                        ? ctrl.value.size.height
                        : widget.height,
                    child: VideoPlayer(ctrl),
                  ),
                )
              else
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF282024), Color(0xFF19191D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

              // 2. Oscurecimiento suave cuando está en pausa para resaltar el botón central
              if (!isPlaying)
                Container(
                  color: Colors.black.withValues(
                    alpha: _initialized ? 0.25 : 0.15,
                  ),
                ),

              // 3. Botón central para reproducir / pausar
              Center(
                child: AnimatedOpacity(
                  opacity: isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      hasUrl
                          ? Icons.play_arrow_rounded
                          : Icons.fitness_center_rounded,
                      size: hasUrl ? 22 : 16,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),

              // 4. Insignia con el número de ejercicio arriba a la izquierda
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '${widget.index}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 5. Indicador discreto de pausa cuando está reproduciéndose
              if (isPlaying)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.pause_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExerciseVideoPlayer extends StatefulWidget {
  const ExerciseVideoPlayer({
    required this.url,
    this.autoPlay = false,
    this.startMuted = true,
    super.key,
  });

  final String url;
  final bool autoPlay;
  final bool startMuted;

  static void showVideoModal(
    BuildContext context, {
    required String title,
    required String videoUrl,
    String? instructions,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ExerciseVideoPlayer(
                url: videoUrl,
                autoPlay: true,
                startMuted: false,
              ),
              if (instructions != null && instructions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Instrucciones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instructions,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  late final VideoPlayerController controller;
  late final Future<void> initialization;
  bool isMuted = true;

  @override
  void initState() {
    super.initState();
    isMuted = widget.startMuted;
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    initialization = controller.initialize().then((_) {
      controller.setLooping(true);
      controller.setVolume(isMuted ? 0.0 : 1.0);
      if (widget.autoPlay) {
        controller.play();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void toggleMute() {
    setState(() {
      isMuted = !isMuted;
      controller.setVolume(isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined, size: 36),
                  SizedBox(height: 8),
                  Text('No se pudo cargar el video de demostración.'),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return Column(
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    VideoPlayer(controller),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          tooltip: isMuted ? 'Activar sonido' : 'Silenciar',
                          icon: Icon(
                            isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                          onPressed: toggleMute,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: controller.value.isPlaying ? 'Pausar' : 'Reproducir',
                  onPressed: () => setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  }),
                  icon: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
