import 'package:flutter/material.dart';

/// Résultat de détection pour un objet dans une frame vidéo.
class DetectionResult {
  const DetectionResult({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.boundingBox,
  });

  final int classId;

  /// Label dans la langue active (EN / FR / EWE).
  final String label;

  /// Score de confiance entre 0.0 et 1.0.
  final double confidence;

  /// Coordonnées normalisées [0,1] : top-left + bottom-right.
  final Rect boundingBox;

  /// Représentation lisible du score, ex: "87%"
  String get confidencePercent =>
      '${(confidence * 100).toStringAsFixed(0)}%';

  @override
  String toString() =>
      'DetectionResult($label @ $confidencePercent, box=$boundingBox)';
}
