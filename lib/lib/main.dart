import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { cameras = await availableCameras(); } catch (e) {}
  runApp(const UnicharmQCApp());
}

class UnicharmQCApp extends StatelessWidget {
  const UnicharmQCApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LiveQCScanner(),
    );
  }
}

class LiveQCScanner extends StatefulWidget {
  const LiveQCScanner({Key? key}) : super(key: key);

  @override
  State<LiveQCScanner> createState() => _LiveQCScannerState();
}

class _LiveQCScannerState extends State<LiveQCScanner> {
  CameraController? _controller;
  GenerativeModel? _aiModel;

  // حط هنا الـ API Key اللي استخرجته من Google AI Studio
  final String _apiKey = "AQ.Ab8RN6I7_GRw9nTWuHlbK_IxraOIwsFmbXuV-VncwuLPI_Tu2w"; 

  bool _isAnalyzing = false;
  String _status = "توجيه الكاميرا نحو الخامة...";
  Color _color = Colors.blue;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initScanner();
  }

  Future<void> _initScanner() async {
    _aiModel = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      systemInstruction: Content.system('''
        Examine the non-woven camera frame for ANY anomaly or defect.
        Strict Output:
        - [PASS] Normal Material
        - [REJECT: ANOMALY] Anomaly Detected
      '''),
    );

    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.medium);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() {});
      _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _inspect());
    }
  }

  Future<void> _inspect() async {
    if (_controller == null || !_controller!.value.isInitialized || _isAnalyzing) return;
    _isAnalyzing = true;
    try {
      final photo = await _controller!.takePicture();
      final bytes = await File(photo.path).readAsBytes();
      final response = await _aiModel!.generateContent([
        Content.multi([TextPart("Inspect frame:"), DataPart('image/jpeg', bytes)])
      ]);
      final res = response.text ?? "";
      setState(() {
        if (res.contains("[REJECT")) {
          _status = "مرفوض (REJECT) - تم كشف عيب أو انحراف";
          _color = Colors.red;
        } else if (res.contains("[PASS]")) {
          _status = "سليم (PASS) - الخامة مطابقة للمواصفات";
          _color = Colors.green;
        }
      });
    } catch (e) {} finally { _isAnalyzing = false; }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unicharm AI QC Scanner")),
      body: Stack(
        children: [
          _controller != null && _controller!.value.isInitialized
              ? CameraPreview(_controller!)
              : const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(10)),
              child: Text(
                _status, 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), 
                textAlign: TextAlign.center
              ),
            ),
          )
        ],
      ),
    );
  }
}
