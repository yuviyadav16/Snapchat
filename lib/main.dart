import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';
import 'dart:async';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera error: $e");
  }
  runApp(const OfflineSnapApp());
}

class OfflineSnapApp extends StatelessWidget {
  const OfflineSnapApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Snapchat',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  bool isCameraInitialized = false;
  int selectedCameraIdx = 0;
  FlashMode flashMode = FlashMode.off;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    if (cameras.isNotEmpty) {
      initCamera(selectedCameraIdx);
    }
  }

  Future<void> initCamera(int cameraIdx) async {
    if (cameras.isEmpty) return;
    
    final CameraController cameraController = CameraController(
      cameras[cameraIdx],
      ResolutionPreset.high,
      enableAudio: false,
    );

    controller = cameraController;

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(flashMode);
      if (!mounted) return;
      setState(() {
        isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  void switchCamera() {
    if (cameras.length < 2) return;
    selectedCameraIdx = (selectedCameraIdx + 1) % cameras.length;
    initCamera(selectedCameraIdx);
  }

  Future<void> toggleFlash() async {
    if (controller == null) return;
    flashMode = flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await controller!.setFlashMode(flashMode);
    setState(() {});
  }

  Future<void> takePicture() async {
    if (controller == null || !controller!.value.isInitialized || isCapturing) return;

    setState(() {
      isCapturing = true;
    });

    try {
      final image = await controller!.takePicture();
      
      // Wapas modern 'Gal' package use kar rahe hain
      await Gal.putImage(image.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snap saved to Gallery securely! 📸'),
          backgroundColor: Color(0xFF222222),
          duration: Duration(milliseconds: 1200),
        ),
      );
    } catch (e) {
      debugPrint("Error taking picture: $e");
    } finally {
      if (mounted) {
        setState(() {
          isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isCameraInitialized || controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(controller!),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: toggleFlash,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 28),
                    onPressed: switchCamera,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 45,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isCapturing ? null : takePicture,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCapturing ? Colors.yellow : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
