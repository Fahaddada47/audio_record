import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';
import 'package:voice_message_package/voice_message_package.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => Sizer(
    builder: (_, __, ___) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey.shade200,
        body: const VoiceRecorderScreen(),
      ),
    ),
  );
}

class VoiceRecorderScreen extends StatefulWidget {
  const VoiceRecorderScreen({Key? key}) : super(key: key);

  @override
  _VoiceRecorderScreenState createState() => _VoiceRecorderScreenState();
}

class _VoiceRecorderScreenState extends State<VoiceRecorderScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecording = false;
  bool _recorderIsInitialized = false;
  List<String> _recordedFiles = [];
  String? _playingFilePath;
  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    await _recorder.openRecorder();
    await _player.openPlayer();
    setState(() {
      _recorderIsInitialized = true;
    });
  }

  Future<void> _startRecording() async {
    if (!_recorderIsInitialized) {
      return;
    }

    Directory tempDir = await getTemporaryDirectory();
    String path = '${tempDir.path}/voice_message_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _recorder.startRecorder(toFile: path);
    setState(() {
      _isRecording = true;
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _duration = Duration(seconds: _duration.inSeconds + 1);
        });
      });
    });
  }

  Future<void> _stopRecording() async {
    if (!_recorderIsInitialized) {
      return;
    }

    String? filePath = await _recorder.stopRecorder();
    if (filePath != null) {
      setState(() {
        _isRecording = false;
        _recordedFiles.add(filePath);
        _timer?.cancel();
        _duration = Duration.zero;
      });
    }
  }

  Future<void> _playRecording(String filePath) async {
    if (_playingFilePath == filePath) {
      await _player.stopPlayer();
      setState(() {
        _playingFilePath = null;
      });
    } else {
      await _player.startPlayer(fromURI: filePath, whenFinished: () {
        setState(() {
          _playingFilePath = null;
        });
      });
      setState(() {
        _playingFilePath = filePath;
      });
    }
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 10.h),
            RecordButton(
              isRecording: _isRecording,
              onPressed: _isRecording ? _stopRecording : _startRecording,
              duration: _isRecording ? _duration : null,
            ),
            if (_recordedFiles.isNotEmpty)
              ..._recordedFiles.map((filePath) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: VoiceMessageView(
                  controller: VoiceController(
                    audioSrc: filePath,
                    maxDuration: const Duration(seconds: 10),
                    isFile: true,
                    onComplete: () {},
                    onPause: () {},
                    onPlaying: () {},
                    onError: (err) {},
                  ),
                  innerPadding: 12,
                  cornerRadius: 20,
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class RecordButton extends StatelessWidget {
  final bool isRecording;
  final Function() onPressed;
  final Duration? duration;

  const RecordButton({
    Key? key,
    required this.isRecording,
    required this.onPressed,
    this.duration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isRecording ? Icons.stop : Icons.mic,
        color: isRecording ? Colors.red : null,
      ),
      label: duration != null ? Text(durationToString(duration!)) : Text('Start Recording'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isRecording ? Colors.white : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  String durationToString(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
