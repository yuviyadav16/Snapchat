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

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? controller;
  bool isCameraInitialized = false;
  int selectedCameraIdx = 0;
  FlashMode flashMode = FlashMode.off;
  bool isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (cameras.isNotEmpty) {
      initCamera(selectedCameraIdx);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      initCamera(selectedCameraIdx);
    }
  }

  Future<void> initCamera(int cameraIdx) async {
    if (cameras.isEmpty) return;
    final CameraController oldController = controller ?? CameraController(cameras[0], ResolutionPreset.high);
    await oldController.dispose();

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

  // Camera Switch (Front/Back)
  void switchCamera() {
    if (cameras.length < 2) return;
    selectedCameraIdx = (selectedCameraIdx + 1) % cameras.length;
    initCamera(selectedCameraIdx);
  }

  // Flash Toggle
  Future<void> toggleFlash() async {
    if (controller == null) return;
    if (flashMode == FlashMode.off) {
      flashMode = FlashMode.torch;
    } else {
      flashMode = FlashMode.off;
    }
    try {
      await controller!.setFlashMode(flashMode);
      setState(() {});
    } catch (e) {
      debugPrint("Error setting flash: $e");
    }
  }

  // Photo Capture & Gallery Save
  Future<void> takePicture() async {
    if (controller == null || !controller!.value.isInitialized || isCapturing) return;

    setState(() {
      isCapturing = true;
    });

    try {
      final image = await controller!.takePicture();
      
      // Save directly to device public gallery securely
      await Gal.putImage(image.path);

      if (!mounted) return;
      
      // Professional feedback dialog/snackbar
      ScaffoldMessenger.formatSnackBar(const SnackBar(content: Text('Saved to Gallery 📸')));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.yellow),
              SizedBox(width: 10),
              Text('Snap saved to Gallery securely!'),
            ],
          ),
          backgroundColor: Color(0xFF222222),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
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
        body: Center(
          child: CircularProgressIndicator(color: Colors.yellow),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview filling full screen
          Positioned.fill(
            child: CameraPreview(controller!),
          ),

          // Top Controls (Flash & Switch Camera)
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
                    icon: const Icon(
                      Icons.cameraswitch_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: switchCamera,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Capture Button (Snapchat Style)
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
