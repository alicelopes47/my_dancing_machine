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
      _initializeVideo(file);
    }
  }

  void _initializeVideo(File file) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(file);

    await _controller!.initialize();
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
    } else {
      _toggleFullscreen();
    }
  }

  void _toggleFullscreen() {
    setState(() {
      isFullscreen = !isFullscreen;
    });
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
                        Center(
                          // <-- Adicione este Center
                          child: AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
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
                        Positioned(
                          bottom: 30,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _controller!.value.isPlaying
                                      ? Icons.loop
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 30,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _controller!.value.isPlaying
                                        ? _controller!.pause()
                                        : _controller!.play();
                                  });
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.replay_10,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  final pos = _controller!.value.position;
                                  _controller!.seekTo(
                                    pos - const Duration(seconds: 10),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.forward_10,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  final pos = _controller!.value.position;
                                  _controller!.seekTo(
                                    pos + const Duration(seconds: 10),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Center(child: Text("Nenhum vídeo selecionado")),
            ),
          ),
          if (!isFullscreen) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _pickVideo,
                  child: const Text("Selecionar vídeo"),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _toggleLoop,
                  child: const Text("Loop"),
                ),
              ],
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
                ],
              )
            : null,
      ),
    );
  }
}
