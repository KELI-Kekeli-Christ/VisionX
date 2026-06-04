import 'dart:typed_data';
import 'package:camera/camera.dart';

/// Données brutes d'une frame extraites sur le thread principal,
/// sérialisables pour être passées à [compute()].
class CameraFrameData {
  const CameraFrameData({
    required this.width,
    required this.height,
    required this.inputSize,
    required this.isYuv,
    required this.bytes0,
    required this.rowStride0,
    // YUV uniquement
    this.bytes1,
    this.bytes2,
    this.rowStride1 = 0,
    this.pixelStride1 = 1,
  });

  final int width;
  final int height;
  final int inputSize;
  final bool isYuv;

  // Plan 0 : Y (YUV) ou BGRA entier (iOS)
  final Uint8List bytes0;
  final int rowStride0;

  // Plans 1 et 2 : U et V (YUV seulement)
  final Uint8List? bytes1;
  final Uint8List? bytes2;
  final int rowStride1;
  final int pixelStride1;

  /// Extrait les données brutes depuis un [CameraImage].
  /// À appeler sur le thread principal avant de passer à [compute].
  static CameraFrameData? fromCameraImage(CameraImage image, int inputSize) {
    final fmt = image.format.group;

    if (fmt == ImageFormatGroup.yuv420) {
      final p0 = image.planes[0];
      final p1 = image.planes[1];
      final p2 = image.planes[2];
      return CameraFrameData(
        width: image.width,
        height: image.height,
        inputSize: inputSize,
        isYuv: true,
        bytes0: p0.bytes,
        rowStride0: p0.bytesPerRow,
        bytes1: p1.bytes,
        bytes2: p2.bytes,
        rowStride1: p1.bytesPerRow,
        pixelStride1: p1.bytesPerPixel ?? 1,
      );
    }

    if (fmt == ImageFormatGroup.bgra8888) {
      final p0 = image.planes[0];
      return CameraFrameData(
        width: image.width,
        height: image.height,
        inputSize: inputSize,
        isYuv: false,
        bytes0: p0.bytes,
        rowStride0: p0.bytesPerRow,
      );
    }

    return null;
  }
}

/// Prétraitement d'une frame caméra en tenseur Float32 normalisé [0, 1].
///
/// Fonction top-level → utilisable directement avec [compute()].
/// Entrée  : [CameraFrameData] sérialisable.
/// Sortie  : [Float32List] de taille inputSize × inputSize × 3 (RGB).
Float32List preprocessFrameData(CameraFrameData d) {
  final out = Float32List(d.inputSize * d.inputSize * 3);
  if (d.isYuv) {
    _convertYuv420(d, out);
  } else {
    _convertBgra8888(d, out);
  }
  return out;
}

void _convertYuv420(CameraFrameData d, Float32List out) {
  final y = d.bytes0;
  final u = d.bytes1!;
  final v = d.bytes2!;
  final rs = d.rowStride0;
  final uvrs = d.rowStride1;
  final uvps = d.pixelStride1;
  final sz = d.inputSize;
  int idx = 0;

  for (int py = 0; py < sz; py++) {
    for (int px = 0; px < sz; px++) {
      // Coordonnées source (nearest-neighbor)
      final sx = ((px + 0.5) * d.width / sz).toInt().clamp(0, d.width - 1);
      final sy = ((py + 0.5) * d.height / sz).toInt().clamp(0, d.height - 1);

      final yv = y[sy * rs + sx] & 0xFF;
      final uvOff = (sy >> 1) * uvrs + (sx >> 1) * uvps;
      final uv = (u[uvOff] & 0xFF) - 128;
      final vv = (v[uvOff] & 0xFF) - 128;

      // Conversion BT.601 YCbCr → RGB, clamp, normalise
      out[idx++] = ((yv + 1.370705 * vv).clamp(0.0, 255.0)) / 255.0;
      out[idx++] = ((yv - 0.337633 * uv - 0.698001 * vv).clamp(0.0, 255.0)) / 255.0;
      out[idx++] = ((yv + 1.732446 * uv).clamp(0.0, 255.0)) / 255.0;
    }
  }
}

void _convertBgra8888(CameraFrameData d, Float32List out) {
  final b = d.bytes0;
  final rs = d.rowStride0;
  final sz = d.inputSize;
  int idx = 0;

  for (int py = 0; py < sz; py++) {
    for (int px = 0; px < sz; px++) {
      final sx = ((px + 0.5) * d.width / sz).toInt().clamp(0, d.width - 1);
      final sy = ((py + 0.5) * d.height / sz).toInt().clamp(0, d.height - 1);
      final pi = sy * rs + sx * 4;

      out[idx++] = (b[pi + 2] & 0xFF) / 255.0; // R
      out[idx++] = (b[pi + 1] & 0xFF) / 255.0; // G
      out[idx++] = (b[pi + 0] & 0xFF) / 255.0; // B
    }
  }
}
