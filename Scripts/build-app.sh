#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
cd "$root_dir"

# Native Xcode packaging is required for App Intents metadata extraction.
# Copying a SwiftPM executable into a hand-made bundle omits that metadata.
build_dir="$root_dir/.build/xcode-release"
build_arch="${ALB01_BUILD_ARCH:-$(uname -m)}"
xcodebuild -project ALB01Control.xcodeproj -scheme ALB01Control \
  -configuration Release -destination "generic/platform=macOS" \
  -derivedDataPath "$build_dir" ARCHS="$build_arch" ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO SWIFT_OPTIMIZATION_LEVEL=-O build -quiet

built_app="$build_dir/Build/Products/Release/ALB01Control.app"
app_path="$root_dir/dist/ALB01Control.app"
if [[ ! -d "$built_app/Contents/Resources/Metadata.appintents" ]]; then
  print -u2 "App Intents metadata is missing; refusing to package an incomplete app."
  exit 1
fi
mkdir -p "$root_dir/dist"
ditto "$built_app" "$app_path"
sign_identity="${ALB01_SIGN_IDENTITY:--}"
codesign --force --sign "$sign_identity" --timestamp=none "$app_path"
codesign --verify --deep --strict "$app_path"
if [[ "$sign_identity" == "-" ]]; then
  print "Ad-hoc preview: App Intents discovery is available, but execution requires Apple team signing on the tested Mac."
fi
plutil -lint "$app_path/Contents/Info.plist"
print "Built native optimized app with App Intents metadata: $app_path"
