#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/UsageBoard.app"
PLIST="$APP_BUNDLE/Contents/Info.plist"
TAP_DIR="$PROJECT_DIR/../homebrew-usageboard"

# --- Prerequisites ---
if ! command -v gh &>/dev/null; then
    echo "需要 gh CLI。安装: brew install gh"
    exit 1
fi
if ! gh auth status &>/dev/null; then
    echo "gh 未登录。运行: gh auth login"
    exit 1
fi

# --- Version from latest git tag ---
git fetch --tags -q 2>/dev/null || true
LAST_TAG=$(git tag --sort=-version:refname | head -1)
CURRENT_VERSION="${LAST_TAG#v}"  # strip "v" prefix
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="0.0.0"
fi

if [ $# -gt 0 ]; then
    NEW_VERSION="$1"
else
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
fi

echo "版本: $CURRENT_VERSION → $NEW_VERSION"

# --- Release notes ---
if [ -n "$LAST_TAG" ]; then
    NOTES=$(git log "${LAST_TAG}..HEAD" --format="- %s" 2>/dev/null || echo "")
else
    NOTES=""
fi

# --- Build ---
echo "构建 release..."
mkdir -p "$APP_BUNDLE/Contents"

if [ ! -f "$PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string zh_CN" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string UsageBoard" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string UsageBoard" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ltd.may.UsageBoard" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleInfoDictionaryVersion string 6.0" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleName string UsageBoard" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $NEW_VERSION" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string 1" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :LSApplicationCategoryType string 'public.app-category.productivity'" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 13.0" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :LSUIElement string true" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string NSApplication" "$PLIST"
else
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $NEW_VERSION" "$PLIST"
fi

swift build -c release

# --- Copy binary & plugins ---
echo "打包 app..."
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources/Plugins"
cp .build/release/UsageBoard "$APP_BUNDLE/Contents/MacOS/UsageBoard"
rm -f "$APP_BUNDLE/Contents/Resources/Plugins/"*.py
cp "$PROJECT_DIR/Resources/UsageBoard.icns" "$APP_BUNDLE/Contents/Resources/UsageBoard.icns"
cp "$PROJECT_DIR/Resources/PluginAuthoringGuide.html" "$APP_BUNDLE/Contents/Resources/PluginAuthoringGuide.html"
cp "$PROJECT_DIR/Resources/BundledPlugins/"*.py "$APP_BUNDLE/Contents/Resources/Plugins/"

codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" 2>&1 | tail -1

# --- Zip ---
ZIP_NAME="UsageBoard-${NEW_VERSION}.zip"
cd "$DIST_DIR"
rm -f UsageBoard-*.zip
ditto -c -k --sequesterRsrc --keepParent "UsageBoard.app" "$ZIP_NAME"
cd "$PROJECT_DIR"
echo "已生成: $DIST_DIR/$ZIP_NAME"

# --- Tag & push ---
echo "打 tag v${NEW_VERSION}..."
git tag "v${NEW_VERSION}"
git push origin "v${NEW_VERSION}"

# --- Create GitHub Release ---
echo "创建 GitHub Release..."
gh release create "v${NEW_VERSION}" \
    --title "v${NEW_VERSION}" \
    --notes "$NOTES" \
    "$DIST_DIR/$ZIP_NAME"

echo "GitHub Release 已创建: https://github.com/dennisokko/UsageBoard/releases/tag/v${NEW_VERSION}"

# --- Update Homebrew cask ---
ZIP_SHA=$(shasum -a 256 "$DIST_DIR/$ZIP_NAME" | cut -d' ' -f1)

if [ -d "$TAP_DIR" ]; then
    echo "更新 cask..."
    cd "$TAP_DIR"
    sed -i '' "s/version \".*\"/version \"${NEW_VERSION}\"/" Casks/usageboard.rb
    sed -i '' "s/sha256 \".*\"/sha256 \"${ZIP_SHA}\"/" Casks/usageboard.rb
    git add Casks/usageboard.rb
    git commit -m "Update UsageBoard to v${NEW_VERSION}"
    git push
    echo "Cask 已更新: $(git rev-parse HEAD)"
fi

echo ""
echo "发布完成: v${NEW_VERSION}"
echo "SHA256: $ZIP_SHA"
