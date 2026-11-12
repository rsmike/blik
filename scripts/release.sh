#!/bin/bash
# Builds, installs and publishes Blik.
#
#   scripts/release.sh build [version]    Release build and a zip of it, in build/
#   scripts/release.sh install            Release build, copied to /Applications and launched
#   scripts/release.sh publish <version>  Release build, GitHub release v<version> with the zip,
#                                         and the Homebrew cask updated to match
#
# The app is signed to run locally and is not notarized. A copy you build yourself opens
# normally; one downloaded from the release is quarantined by macOS, which is why the cask
# removes the quarantine flag after installing.

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Blik"
BUNDLE_ID="com.rsmike.Blik"
REPO="rsmike/blik"
TAP_REPO="rsmike/homebrew-tap"
CASK_PATH="Casks/blik.rb"
BUILT_APP="build/Build/Products/Release/$APP_NAME.app"

die() {
    echo "error: $*" >&2
    exit 1
}

# The version to build when none is given: the latest release tag, or the project's own.
default_version() {
    local tag
    if tag=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null); then
        echo "${tag#v}"
    else
        sed -n 's/.*MARKETING_VERSION = \(.*\);/\1/p' "$APP_NAME.xcodeproj/project.pbxproj" | head -1
    fi
}

# build <version>: a Release build stamped with that version, and build/Blik-<version>.zip.
build() {
    local version="$1"
    local log="build/release.log"
    mkdir -p build
    echo "Building $APP_NAME $version (Release)..."
    if ! xcodebuild -project "$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
        -derivedDataPath build \
        MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
        build > "$log" 2>&1; then
        grep -E "error:" "$log" >&2 || tail -20 "$log" >&2
        die "the build failed; the full log is in $log"
    fi
    local built
    built=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$BUILT_APP/Contents/Info.plist")
    [ "$built" = "$version" ] || die "built version is $built, expected $version"

    ZIP="build/$APP_NAME-$version.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$BUILT_APP" "$ZIP"
    echo "Built $BUILT_APP"
    echo "Zipped $ZIP"
}

install() {
    build "$(default_version)"
    echo "Installing to /Applications..."
    pkill -x "$APP_NAME" 2>/dev/null && sleep 1 || true
    rm -rf "/Applications/$APP_NAME.app"
    ditto "$BUILT_APP" "/Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
    echo "Installed and launched /Applications/$APP_NAME.app"
}

publish() {
    local version="${1:-}"
    [ -n "$version" ] || die "usage: scripts/release.sh publish <version>, for example 1.1"
    local tag="v$version"

    [ -z "$(git status --porcelain)" ] || die "the working tree has uncommitted changes"
    git fetch --quiet origin
    [ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "HEAD is not what is on origin/main; push first"
    if gh release view "$tag" --repo "$REPO" > /dev/null 2>&1; then
        die "release $tag already exists"
    fi

    build "$version"
    local sha
    sha=$(shasum -a 256 "$ZIP" | cut -d' ' -f1)

    echo "Publishing $tag on $REPO..."
    gh release create "$tag" "$ZIP" --repo "$REPO" --target "$(git rev-parse HEAD)" \
        --title "$APP_NAME $version" --generate-notes
    git fetch --quiet --tags origin

    echo "Updating the Homebrew cask in $TAP_REPO..."
    local cask existing
    cask=$(sed -e "s/{{VERSION}}/$version/" -e "s/{{SHA256}}/$sha/" packaging/blik.rb.template)
    existing=$(gh api "repos/$TAP_REPO/contents/$CASK_PATH" --jq .sha 2>/dev/null || true)
    gh api --method PUT "repos/$TAP_REPO/contents/$CASK_PATH" \
        -f message="blik $version" \
        -f content="$(printf '%s\n' "$cask" | base64)" \
        ${existing:+-f sha="$existing"} > /dev/null

    echo "Published $APP_NAME $version."
    echo "Install:  brew tap ${TAP_REPO/homebrew-/} && brew trust --cask ${TAP_REPO/homebrew-/}/blik && brew install --cask ${TAP_REPO/homebrew-/}/blik"
    echo "Update:   brew upgrade --cask blik"
}

case "${1:-}" in
    build) build "${2:-$(default_version)}" ;;
    install) install ;;
    publish) publish "${2:-}" ;;
    *) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
