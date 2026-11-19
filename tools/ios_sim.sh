#!/usr/bin/env bash
# Exports the iOS project, puts the arm64 simulator engine into it, builds it and installs it on a simulator.
#   tools/ios_sim.sh [simulator UDID] [-- game args...]
# Then run it: xcrun simctl launch <UDID> com.fernandocorreia.lastlight.gdspike -- --menu factions
#
# The official 4.7.2 templates ship an x86_64-only simulator libgodot.a, which the iOS 26 simulator on
# Apple Silicon refuses. Build the arm64 one once (about 2 minutes) from the tag that matches the editor:
#   git clone --depth 1 --branch 4.7.2-stable https://github.com/godotengine/godot.git
#   scons platform=ios target=template_release arch=arm64 ios_simulator=yes generate_bundle=no
# and point SIM_LIB at bin/libgodot.ios.template_release.arm64.simulator.a.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
SIM_LIB=${SIM_LIB:-/Volumes/PortableSSD/Work/godot-build/godot/bin/libgodot.ios.template_release.arm64.simulator.a}
DERIVED=${DERIVED:-/Volumes/PortableSSD/Work/godot-build/dd-sim}
UDID=${1:-$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)}
[[ -n "$UDID" ]] || { echo "No booted simulator; pass a UDID." >&2; exit 1; }
[[ -f "$SIM_LIB" ]] || { echo "Missing $SIM_LIB; see the comment at the top." >&2; exit 1; }

mkdir -p build/ios
"$GODOT" --headless --path . --export-release "iOS" build/ios/TheLastLight.ipa
slice=build/ios/TheLastLight.xcframework/ios-arm64_x86_64-simulator/libgodot.a
if ! lipo -archs "$slice" | grep -qw arm64; then
	tmp=$(mktemp -d)
	lipo -thin x86_64 "$slice" -output "$tmp/x86.a" 2>/dev/null || cp "$slice" "$tmp/x86.a"
	lipo -create "$tmp/x86.a" "$SIM_LIB" -output "$slice"
	rm -r "$tmp"
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcodebuild -project build/ios/TheLastLight.xcodeproj -scheme TheLastLight -configuration Release \
	-destination "id=$UDID" -derivedDataPath "$DERIVED" -allowProvisioningUpdates \
	DEVELOPMENT_TEAM=84X9WYBF36 CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY="Apple Development" build -quiet
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Release-iphonesimulator/TheLastLight.app"
echo "Installed on $UDID."
