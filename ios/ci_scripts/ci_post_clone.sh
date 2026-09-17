#!/bin/sh

# Xcode Cloud post-clone script for a Flutter app.
# Xcode Cloud clones the repo and then runs this BEFORE resolving
# dependencies, so this is where Flutter itself gets installed and
# where the iOS ephemeral files (Generated.xcconfig, Podfile, Pods)
# are produced -- none of those are committed to the repo.

set -e

FLUTTER_VERSION="3.41.1"
FLUTTER_CHANNEL="stable"

echo "--- Installing Flutter $FLUTTER_VERSION ---"
git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    "$HOME/flutter"

export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter config --no-analytics
flutter precache --ios

# CI_PRIMARY_REPOSITORY_PATH is set by Xcode Cloud to the repo root.
# The Flutter project lives at the repo root here.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "--- Fetching packages ---"
flutter pub get

echo "--- Generating iOS build files ---"
# Produces ios/Flutter/Generated.xcconfig and the ephemeral Podfile
# inputs that CocoaPods needs. --config-only skips the actual compile.
flutter build ios --release --no-codesign --config-only

echo "--- Installing pods ---"
cd ios
pod install --repo-update

echo "--- ci_post_clone complete ---"
