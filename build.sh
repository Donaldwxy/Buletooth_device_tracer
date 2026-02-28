#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Path to the GitHub CLI executable
GH_CLI_PATH="./gh_2.50.0_linux_amd64/bin/gh"
# --- End Configuration ---

echo "🚀 Starting the release process..."

# 1. Determine the next version
echo "🔎 Fetching the latest release version from GitHub..."
# Get the latest tag name from GitHub, e.g., "v1.0.0"
LATEST_TAG=$($GH_CLI_PATH release view --json tagName -q .tagName 2>/dev/null || echo "v0.0.0")

# Strip the 'v' prefix, e.g., "1.0.0"
VERSION_STRING=${LATEST_TAG#v}

# Split into major, minor, patch
IFS='.' read -r -a VERSION_PARTS <<< "$VERSION_STRING"
MAJOR=${VERSION_PARTS[0]}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment the patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION_TAG="v${MAJOR}.${MINOR}.${NEW_PATCH}"

echo "✅ New version will be: ${NEW_VERSION_TAG}"

# 2. Commit all current changes
echo "💾 Committing all changes to Git..."
git add .
# Use 'git diff-index' to check if there are staged changes
if ! git diff-index --quiet HEAD --; then
    git commit -m "chore: Prepare for release ${NEW_VERSION_TAG}"
else
    echo "No changes to commit."
fi
git push

# 3. Build the release APK
echo "📦 Building the Flutter release APK..."
flutter build apk --release

# 4. Create the new GitHub Release
echo "🎉 Creating new GitHub release ${NEW_VERSION_TAG}..."
$GH_CLI_PATH release create "$NEW_VERSION_TAG" "build/app/outputs/flutter-apk/app-release.apk" --title "$NEW_VERSION_TAG" --notes "New release: ${NEW_VERSION_TAG}"

echo "✨ All done! Release ${NEW_VERSION_TAG} is live on GitHub."
