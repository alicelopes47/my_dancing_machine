import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My dance machine',
      theme: ThemeData.dark(),
      home: const VideoPlayerScreen(),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  VideoCropSettings? _cropSettings;
  final List<double> _speedSteps = [0.35, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  double _playbackSpeed = 1.0;
  int _speedStepIndex = -1;
  bool isFullscreen = false;

  bool isLoopActive = false;
  bool selectingLoop = false;
  int loopClicks = 0;
  Duration loopStart = Duration.zero;
  Duration loopEnd = Duration.zero;
  Timer? loopTimer;

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final cropSettings = await Navigator.push<VideoCropSettings>(
        context,
        MaterialPageRoute(builder: (_) => VideoCropEditorScreen(file: file)),
      );

      if (cropSettings != null) {
        _initializeVideo(file, cropSettings);
      }
    }
  }

  void _initializeVideo(File file, VideoCropSettings cropSettings) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(file);
    _cropSettings = cropSettings;
    _playbackSpeed = 1.0;
    _speedStepIndex = -1;

    await _controller!.initialize();
    await _controller!.setPlaybackSpeed(_playbackSpeed);
    setState(() {});

    _controller!.play();

    loopTimer?.cancel();
    loopTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_controller != null && isLoopActive && loopEnd > loopStart) {
        final pos = _controller!.value.position;
        if (pos >= loopEnd) {
          _controller!.seekTo(loopStart);
        }
      }
    });
  }

  void _toggleLoop() {
    if (!isLoopActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Clique no vídeo 2 vezes para marcar início e fim do loop",
          ),
        ),
      );
      setState(() {
        selectingLoop = true;
        loopClicks = 0;
        isLoopActive = true;
      });
    } else {
      setState(() {
        isLoopActive = false;
        selectingLoop = false;
        loopStart = Duration.zero;
        loopEnd = Duration.zero;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Loop desativado")));
    }
  }

  void _onVideoTap() {
    if (selectingLoop && _controller != null) {
      setState(() {
        loopClicks++;
        final currentPos = _controller!.value.position;

        if (loopClicks == 1) {
          loopStart = currentPos;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Início do loop definido: ${currentPos.inMilliseconds}ms",
              ),
            ),
          );
        } else if (loopClicks == 2) {
          loopEnd = currentPos;
          selectingLoop = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Fim do loop definido: ${currentPos.inMilliseconds}ms",
              ),
            ),
          );
        }
      });
    }
  }

  void _toggleFullscreen() {
    setState(() {
      isFullscreen = !isFullscreen;
    });
  }

  Future<void> _cyclePlaybackSpeed() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    final nextIndex = (_speedStepIndex + 1) % _speedSteps.length;
    final nextSpeed = _speedSteps[nextIndex];

    await _controller!.setPlaybackSpeed(nextSpeed);

    setState(() {
      _speedStepIndex = nextIndex;
      _playbackSpeed = nextSpeed;
    });
  }

  double _maxOffsetFactorForScale(double scale) {
    return (scale - 1) / 2;
  }

  Widget _buildVideoViewport() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: Text("Nenhum video selecionado"));
    }

    final settings =
        _cropSettings ??
        VideoCropSettings(
          scale: 1,
          offsetXFactor: 0,
          offsetYFactor: 0,
          aspectRatio: _controller!.value.aspectRatio,
        );

    final safeScale = settings.scale.clamp(1.0, 5.0);
    final maxOffsetFactor = _maxOffsetFactorForScale(safeScale);
    final safeOffsetX = settings.offsetXFactor.clamp(
      -maxOffsetFactor,
      maxOffsetFactor,
    );
    final safeOffsetY = settings.offsetYFactor.clamp(
      -maxOffsetFactor,
      maxOffsetFactor,
    );
    final screenAspectRatio =
        MediaQuery.of(context).size.width / MediaQuery.of(context).size.height;
    final viewportAspectRatio = isFullscreen
        ? screenAspectRatio
        : settings.aspectRatio;

    return Center(
      child: AspectRatio(
        aspectRatio: viewportAspectRatio,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final matrix = Matrix4.identity()
                ..translate(
                  safeOffsetX * constraints.maxWidth,
                  safeOffsetY * constraints.maxHeight,
                )
                ..scale(safeScale);

              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    loopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isFullscreen ? null : AppBar(title: const Text("Dance Machine")),
      body: Column(
        children: [
          GestureDetector(
            onTap: _onVideoTap,
            child: Container(
              height: isFullscreen ? MediaQuery.of(context).size.height : 200,
              width: MediaQuery.of(context).size.width,
              color: Colors.black,
              child: _controller != null && _controller!.value.isInitialized
                  ? Stack(
                      children: [
                        _buildVideoViewport(),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: ElevatedButton(
                            onPressed: _cyclePlaybackSpeed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: Text(
                              '${_playbackSpeed.toStringAsFixed(2)}x',
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: Icon(
                              isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                            ),
                            tooltip: isFullscreen
                                ? 'Sair da tela cheia'
                                : 'Tela cheia',
                            onPressed: _toggleFullscreen,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            colors: VideoProgressColors(
                              playedColor: Colors.purple,
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.black26,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(child: Text("Nenhum video selecionado")),
            ),
          ),
          if (!isFullscreen) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 3.2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ElevatedButton(
                    onPressed: _pickVideo,
                    child: const Text("Selecionar video"),
                  ),
                  ElevatedButton(
                    onPressed: _toggleLoop,
                    child: const Text("Loop"),
                  ),
                  ElevatedButton(
                    onPressed: _cyclePlaybackSpeed,
                    child: Text(
                      "Velocidade ${_playbackSpeed.toStringAsFixed(2)}x",
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _toggleFullscreen,
                    child: const Text("Tela cheia"),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 55.0,
        ), // Ajuste a margem lateral

        child: _controller != null && _controller!.value.isInitialized
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    onPressed: _toggleLoop,
                    backgroundColor: isLoopActive ? Colors.red : Colors.purple,
                    child: !selectingLoop
                        ? Icon(Icons.loop)
                        : loopStart != Duration.zero
                        ? Text("2")
                        : Text("1"),
                  ),
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _controller!.value.isPlaying
                            ? _controller!.pause()
                            : _controller!.play();
                      });
                    },
                    child: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  FloatingActionButton(
                    onPressed: _toggleFullscreen,
                    heroTag: 'fullscreen_button',
                    child: Icon(
                      isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class VideoCropSettings {
  const VideoCropSettings({
    required this.scale,
    required this.offsetXFactor,
    required this.offsetYFactor,
    required this.aspectRatio,
  });

  final double scale;
  final double offsetXFactor;
  final double offsetYFactor;
  final double aspectRatio;
}

class VideoCropEditorScreen extends StatefulWidget {
  const VideoCropEditorScreen({super.key, required this.file});

  final File file;

  @override
  State<VideoCropEditorScreen> createState() => _VideoCropEditorScreenState();
}

class _VideoCropEditorScreenState extends State<VideoCropEditorScreen> {
  late final VideoPlayerController _previewController;
  final TransformationController _transformController =
      TransformationController();

  double _selectedAspectRatio = 9 / 16;
  double _currentScale = 1;
  Size _viewportSize = Size.zero;

  List<_AspectRatioOption> get _aspectRatioOptions {
    final originalAspect = _previewController.value.aspectRatio;
    return [
      _AspectRatioOption(label: 'Original', ratio: originalAspect),
      const _AspectRatioOption(label: '9:16', ratio: 9 / 16),
      const _AspectRatioOption(label: '1:1', ratio: 1),
      const _AspectRatioOption(label: '4:5', ratio: 4 / 5),
      const _AspectRatioOption(label: '16:9', ratio: 16 / 9),
    ];
  }

  @override
  void initState() {
    super.initState();
    _previewController = VideoPlayerController.file(widget.file)
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _selectedAspectRatio = _previewController.value.aspectRatio;
        });
        _previewController.play();
      });
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final newScale = _transformController.value.getMaxScaleOnAxis().clamp(
      1.0,
      5.0,
    );
    if ((newScale - _currentScale).abs() > 0.01) {
      setState(() {
        _currentScale = newScale;
      });
    }
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1;
    });
  }

  double _maxOffsetFactorForScale(double scale) {
    return (scale - 1) / 2;
  }

  void _setScale(double newScale) {
    final matrix = _transformController.value;
    var translationX = matrix.storage[12];
    var translationY = matrix.storage[13];
    final maxOffsetFactor = _maxOffsetFactorForScale(newScale);

    if (_viewportSize != Size.zero) {
      final maxTranslateX = _viewportSize.width * maxOffsetFactor;
      final maxTranslateY = _viewportSize.height * maxOffsetFactor;
      translationX = translationX.clamp(-maxTranslateX, maxTranslateX);
      translationY = translationY.clamp(-maxTranslateY, maxTranslateY);
    }

    _transformController.value = Matrix4.identity()
      ..translate(translationX, translationY)
      ..scale(newScale);

    setState(() {
      _currentScale = newScale;
    });
  }

  void _confirmCrop() {
    if (_viewportSize == Size.zero) {
      Navigator.pop(context);
      return;
    }

    final matrix = _transformController.value;
    final scale = matrix.getMaxScaleOnAxis().clamp(1.0, 5.0);
    final maxOffsetFactor = _maxOffsetFactorForScale(scale);
    final offsetXFactor = (matrix.storage[12] / _viewportSize.width).clamp(
      -maxOffsetFactor,
      maxOffsetFactor,
    );
    final offsetYFactor = (matrix.storage[13] / _viewportSize.height).clamp(
      -maxOffsetFactor,
      maxOffsetFactor,
    );

    final settings = VideoCropSettings(
      scale: scale,
      offsetXFactor: offsetXFactor,
      offsetYFactor: offsetYFactor,
      aspectRatio: _selectedAspectRatio,
    );

    Navigator.pop(context, settings);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar enquadramento')),
      body: _previewController.value.isInitialized
          ? SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AspectRatio(
                          aspectRatio: _selectedAspectRatio,
                          child: ClipRect(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                _viewportSize = Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );

                                return InteractiveViewer(
                                  transformationController:
                                      _transformController,
                                  minScale: 1,
                                  maxScale: 5,
                                  boundaryMargin: const EdgeInsets.all(
                                    double.infinity,
                                  ),
                                  child: SizedBox.expand(
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width:
                                            _previewController.value.size.width,
                                        height: _previewController
                                            .value
                                            .size
                                            .height,
                                        child: VideoPlayer(_previewController),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in _aspectRatioOptions)
                                ChoiceChip(
                                  label: Text(option.label),
                                  selected:
                                      (_selectedAspectRatio - option.ratio)
                                          .abs() <
                                      0.001,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedAspectRatio = option.ratio;
                                    });
                                    _resetTransform();
                                  },
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const Text('Zoom'),
                              Expanded(
                                child: Slider(
                                  value: _currentScale,
                                  min: 1,
                                  max: 5,
                                  onChanged: _setScale,
                                ),
                              ),
                              IconButton(
                                onPressed: _resetTransform,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Resetar',
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _confirmCrop,
                                  child: const Text('Usar enquadramento'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class _AspectRatioOption {
  const _AspectRatioOption({required this.label, required this.ratio});

  final String label;
  final double ratio;
}
