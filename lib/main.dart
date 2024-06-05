import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:voice_message_package/voice_message_package.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
            ),
            SizedBox(height: 2.h),
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
