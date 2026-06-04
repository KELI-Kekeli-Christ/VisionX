import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service singleton qui gère l'accès caméra et le flux d'images.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isStreaming = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isStreaming => _isStreaming;

  // ── Initialisation ─────────────────────────────────────────

  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;
    await _startCamera(_cameras.first);
  }

  Future<void> _startCamera(CameraDescription camera) async {
    _controller?.dispose();
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );
    await _controller!.initialize();
  }

  // ── Flux d'images pour l'inférence ─────────────────────────

  /// Lance le stream d'images caméra.
  /// [onFrame] est appelé à chaque frame ; doit être léger.
  Future<void> startStream(void Function(CameraImage) onFrame) async {
    if (_controller == null || !isInitialized || _isStreaming) return;
    _isStreaming = true;
    await _controller!.startImageStream(onFrame);
  }

  Future<void> stopStream() async {
    if (!_isStreaming) return;
    await _controller?.stopImageStream();
    _isStreaming = false;
  }

  // ── Flip caméra ────────────────────────────────────────────

  Future<void> flipCamera() async {
    if (_cameras.length < 2) return;
    final isBack = _controller?.description.lensDirection ==
        CameraLensDirection.back;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection ==
          (isBack ? CameraLensDirection.front : CameraLensDirection.back),
      orElse: () => _cameras.first,
    );
    await stopStream();
    await _startCamera(next);
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isStreaming = false;
  }
}
