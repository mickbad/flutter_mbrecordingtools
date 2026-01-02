#!/bin/bash

# Script de build automatisé pour mbrecordingtools_sample Android
# Usage: ./run_android.sh [debug|release]

set -e

# usage
echo
echo "Usage: ./run_android.sh [debug|release]"
echo "Exemple: ./run_android.sh debug"
echo
echo

BUILD_TYPE=${1:-"release"}
echo "🚀 Build Android $BUILD_TYPE pour mbrecordingtools_sample"

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Erreur: Ce script doit être exécuté depuis le répertoire example/"
    echo "Usage: cd example && ../run_android.sh"
    exit 1
fi

echo "📦 Nettoyage complet des builds précédents..."
flutter clean
rm -rf build/
rm -rf .dart_tool/
rm -f pubspec.lock

echo "📥 Téléchargement des dépendances..."
flutter pub get

echo "🔧 Génération du code natif..."
flutter packages pub run build_runner build --delete-conflicting-outputs || true

echo "📱 Build Android $BUILD_TYPE..."
if [ "$BUILD_TYPE" = "debug" ]; then
    flutter run --debug --verbose
else
    flutter run --release --verbose
fi

echo "✅ Build terminé!"
