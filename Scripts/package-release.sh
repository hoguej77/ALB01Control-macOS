#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
cd "$root_dir"
release_version="${1:-v0.4.0-beta.2}"
if [[ ! "$release_version" =~ '^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$' ]]; then
  print -u2 "Expected a version such as v0.3.0-beta.1."
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  print -u2 "Commit or preserve outstanding source changes before packaging."
  exit 1
fi
zsh Scripts/build-app.sh
release_dir="$root_dir/release-artifacts/$release_version"
if [[ -e "$release_dir" ]]; then
  print -u2 "Release directory already exists; refusing to overwrite it: $release_dir"
  exit 1
fi
mkdir -p "$release_dir"
release_arch="$(lipo -archs dist/ALB01Control.app/Contents/MacOS/ALB01Control | tr ' ' '-')"
app_archive="ALB01Control-$release_version-macos-$release_arch.zip"
source_archive="ALB01Control-$release_version-source.zip"
ditto -c -k --sequesterRsrc --keepParent dist/ALB01Control.app "$release_dir/$app_archive"
git archive --format=zip --prefix="ALB01Control-$release_version/" HEAD -o "$release_dir/$source_archive"
cp RELEASE_NOTES.md "$release_dir/RELEASE_NOTES.md"
(
  cd "$release_dir"
  shasum -a 256 "$app_archive" "$source_archive" > SHA256SUMS.txt
  shasum -a 256 -c SHA256SUMS.txt
)
print "Release assets: $release_dir"
