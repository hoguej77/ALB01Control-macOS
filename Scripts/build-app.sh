#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
cd "$root_dir"

build_args=(-c release --product ALB01Control)
[[ -n "${ALB01_SWIFT_SDK:-}" ]] && build_args+=(--sdk "$ALB01_SWIFT_SDK")
[[ -n "${ALB01_SWIFT_TRIPLE:-}" ]] && build_args+=(--triple "$ALB01_SWIFT_TRIPLE")
[[ "${ALB01_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]] && build_args+=(--disable-sandbox)
swift build "${build_args[@]}"

binary_dir="$(swift build "${build_args[@]}" --show-bin-path)"
binary_path="$binary_dir/ALB01Control"
if [[ ! -x "$binary_path" ]]; then
  print -u2 "Could not locate the release ALB01Control executable."
  exit 1
fi

app_path="$root_dir/dist/ALB01Control.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_path" "$app_path/Contents/MacOS/ALB01Control"
cp "$root_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
cp "$root_dir/README.md" "$root_dir/CHANGELOG.md" "$root_dir/LICENSE" "$root_dir/RESEARCH.md" "$root_dir/RELEASE_NOTES.md" "$root_dir/VALIDATION.md" "$app_path/Contents/Resources/"
codesign --force --sign - --timestamp=none "$app_path"
codesign --verify --deep --strict "$app_path"
plutil -lint "$app_path/Contents/Info.plist"
print "Built $app_path"
