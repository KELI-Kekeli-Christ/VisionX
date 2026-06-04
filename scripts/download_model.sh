#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# VisionX — Téléchargement du modèle TFLite SSD MobileNet V1 COCO (EN)
#
# Usage (depuis la racine du projet) :
#   bash scripts/download_model.sh
#
# Le fichier résultant est placé dans assets/models/detect_en.tflite
# et sera bundlé dans l'APK/IPA lors du build Flutter.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

ASSETS_DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/models"
TMP=$(mktemp -d)

# URLs de téléchargement (première qui fonctionne est utilisée)
URLS=(
  "https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip"
  "https://tfhub.dev/tensorflow/lite-model/ssd_mobilenet_v1/1/metadata/2?lite-format=tflite"
)

# ─── Couleurs ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}▶ VisionX — Model Downloader${NC}"
echo "  Target: $ASSETS_DIR/detect_en.tflite"
echo ""

# Vérifie si le fichier existe déjà
if [ -f "$ASSETS_DIR/detect_en.tflite" ]; then
  SIZE=$(du -sh "$ASSETS_DIR/detect_en.tflite" | cut -f1)
  echo -e "${GREEN}✓ Model already exists ($SIZE). Delete it to re-download.${NC}"
  exit 0
fi

mkdir -p "$ASSETS_DIR"

# ─── Essai avec la première URL (zip Google Storage) ─────────────────────────
URL="${URLS[0]}"
echo -e "  Downloading from Google Storage (quantized SSD MobileNet V1)…"
if curl -L --progress-bar --fail -o "$TMP/model.zip" "$URL"; then
  echo ""
  echo -e "  Extracting…"
  unzip -q "$TMP/model.zip" -d "$TMP/extracted/"
  # Le zip contient detect.tflite à la racine
  if [ -f "$TMP/extracted/detect.tflite" ]; then
    cp "$TMP/extracted/detect.tflite" "$ASSETS_DIR/detect_en.tflite"
    echo -e "${GREEN}✓ Saved: $ASSETS_DIR/detect_en.tflite${NC}"
    rm -rf "$TMP"
    exit 0
  fi
fi

echo -e "  ${RED}First URL failed. Trying TFHub…${NC}"

# ─── Essai avec TFHub ─────────────────────────────────────────────────────────
URL="${URLS[1]}"
if curl -L --progress-bar --fail -o "$TMP/detect_en.tflite" "$URL"; then
  echo ""
  cp "$TMP/detect_en.tflite" "$ASSETS_DIR/detect_en.tflite"
  echo -e "${GREEN}✓ Saved: $ASSETS_DIR/detect_en.tflite${NC}"
  rm -rf "$TMP"
  exit 0
fi

echo ""
echo -e "${RED}✗ All download sources failed.${NC}"
echo "  Please manually download a SSD MobileNet V1 COCO .tflite"
echo "  and copy it to: $ASSETS_DIR/detect_en.tflite"
rm -rf "$TMP"
exit 1
