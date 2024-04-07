// ignore_for_file: discarded_futures

import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:ogg_opus_player/ogg_opus_player.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:share_plus/share_plus.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Directory tempDir = await getTemporaryDirectory();
  final String workDir = p.join(tempDir.path, "ogg_opus_player");
  debugPrint("workDir: $workDir");
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Plugin example app"),
        ),
        body: Column(
          children: <Widget>[
            _PlayAsset(directory: workDir),
            const SizedBox(height: 20),
            _RecorderExample(dir: workDir),
          ],
        ),
      ),
    ),
  );
}

class _PlayAsset extends StatefulWidget {
  const _PlayAsset({required this.directory});

  final String directory;

  @override
  _PlayAssetState createState() => _PlayAssetState();
}

class _PlayAssetState extends State<_PlayAsset> {
  bool _copyCompleted = false;

  String _path = "";

  @override
  void initState() {
    super.initState();
    _copyAssets();
  }

  Future<void> _copyAssets() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File dest = File(p.join(dir.path, "test.ogg"));
    _path = dest.path;
    if (await dest.exists()) {
      setState(() {
        _copyCompleted = true;
      });
      return;
    }

    final ByteData bytes = await rootBundle.load("audios/test.ogg");
    await dest.writeAsBytes(bytes.buffer.asUint8List());
    setState(() {
      _copyCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) => _copyCompleted
      ? _OpusOggPlayerWidget(
          path: _path,
          key: ValueKey<String>(_path),
        )
      : const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(),
          ),
        );
}

class _OpusOggPlayerWidget extends StatefulWidget {
  const _OpusOggPlayerWidget({super.key, required this.path});

  final String path;

  @override
  State<_OpusOggPlayerWidget> createState() => _OpusOggPlayerWidgetState();
}

class _OpusOggPlayerWidgetState extends State<_OpusOggPlayerWidget> {
  OggOpusPlayer? _player;

  Timer? timer;

  double _playingPosition = 0;
  double _playingDuration = 0;
  PlayerState state = PlayerState.idle;

  static const List<double> _kPlaybackSpeedSteps = <double>[0.5, 1, 1.5, 2];

  int _speedIndex = 1;

  @override
  void initState() {
    super.initState();
    _player = OggOpusPlayer(widget.path);
    _player?.state.addListener(
      () async {
        state = _player?.state.value ?? PlayerState.idle;
        setState(() {});
        if (_player?.state.value == PlayerState.paused) {
          _playingDuration = await _player?.getDuration() ?? 0;
          setState(() {});
        }
      },
    );
    timer = Timer.periodic(const Duration(milliseconds: 50), (Timer timer) {
      setState(() {
        _playingPosition = _player?.currentPosition ?? 0;
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text("P: ${_playingPosition.toStringAsFixed(2)}"),
          Text("D: ${_playingDuration.toStringAsFixed(2)}"),
          const SizedBox(height: 8),
          if (state == PlayerState.playing)
            IconButton(
              onPressed: () {
                _player?.pause();
              },
              icon: const Icon(Icons.pause),
            )
          else
            IconButton(
              onPressed: () async {
                _player?.play();
              },
              icon: const Icon(Icons.play_arrow),
            ),
          IconButton(
            onPressed: () {
              setState(() {
                _player?.dispose();
                _player = null;
              });
            },
            icon: const Icon(Icons.stop),
          ),
          IconButton(
            onPressed: () {
              Share.shareXFiles(<XFile>[XFile(widget.path)]);
            },
            icon: const Icon(Icons.share),
          ),
          if (_player != null)
            TextButton(
              onPressed: () {
                _speedIndex++;
                if (_speedIndex >= _kPlaybackSpeedSteps.length) {
                  _speedIndex = 0;
                }
                _player?.setPlaybackRate(_kPlaybackSpeedSteps[_speedIndex]);
              },
              child: Text("X${_kPlaybackSpeedSteps[_speedIndex]}"),
            ),
        ],
      );
}

class _RecorderExample extends StatefulWidget {
  const _RecorderExample({
    required this.dir,
  });

  final String dir;

  @override
  State<_RecorderExample> createState() => _RecorderExampleState();
}

class _RecorderExampleState extends State<_RecorderExample> {
  late String _recordedPath;

  OggOpusRecorder? _recorder;

  @override
  void initState() {
    super.initState();
    _recordedPath = p.join(widget.dir, "test_recorded.ogg");
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 8),
          if (_recorder == null)
            IconButton(
              onPressed: () {
                final File file = File(_recordedPath);
                if (file.existsSync()) {
                  File(_recordedPath).deleteSync();
                }
                File(_recordedPath).createSync(recursive: true);
                final OggOpusRecorder recorder = OggOpusRecorder(_recordedPath)
                  ..start();
                setState(() {
                  _recorder = recorder;
                });
              },
              icon: const Icon(Icons.keyboard_voice_outlined),
            )
          else
            IconButton(
              onPressed: () async {
                await _recorder?.stop();
                debugPrint("recording stopped");
                debugPrint("duration: ${await _recorder?.duration()}");
                debugPrint("waveform: ${await _recorder?.getWaveformData()}");
                _recorder?.dispose();
                setState(() {
                  _recorder = null;
                });
              },
              icon: const Icon(Icons.stop),
            ),
          const SizedBox(height: 8),
          if (_recorder == null && File(_recordedPath).existsSync())
            _OpusOggPlayerWidget(path: _recordedPath),
        ],
      );
}
