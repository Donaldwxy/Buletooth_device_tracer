#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Helper Functions ---
info() {
    echo "🚀 $1"
}

success() {
    echo "✅ $1"
}

error() {
    echo "❌ $1" >&2
    exit 1
}

# --- Main Script ---
info "Starting the robust release process..."

# 1. Fetch the latest release tag from GitHub to determine the next version.
info "Fetching the latest release version from GitHub..."
LATEST_TAG=$(gh release list --limit 1 --json tagName -q '.[0].tagName' || echo "v1.0.0")

if [[ -z "$LATEST_TAG" ]]; then
    LATEST_TAG="v1.0.0" # Start from v1.0.0 if no releases exist
fi

VERSION_PARTS=(${LATEST_TAG//./ })
MAJOR=${VERSION_PARTS[0]#v}
MINOR=${VERSION_PARTS[1]}
PATCH=${VERSION_PARTS[2]}

# Increment the patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="v$MAJOR.$MINOR.$NEW_PATCH"

success "New version will be: $NEW_VERSION"

# 2. Update pubspec.yaml locally.
info "Updating pubspec.yaml to version $MAJOR.$MINOR.$NEW_PATCH..."
# The build number will be patch number + 1 for simplicity and uniqueness
BUILD_NUMBER=$((NEW_PATCH + 1))

# Use sed to update the version and build number.
# This is safer than simple string replacement.
sed -i -E "s/version: .*/version: $MAJOR.$MINOR.$NEW_PATCH+$BUILD_NUMBER/" pubspec.yaml

# 3. Build the Flutter release APK. This is the critical validation step.
info "Building the Flutter release APK..."
flutter build apk --release

success "Flutter build completed successfully."

# --- If build is successful, proceed to commit and release ---

# 4. Commit all local changes.
info "Committing all changes to Git..."
git config --global user.email "gemini-ci@google.com"
git config --global user.name "Gemini CI"
git add .
git commit -m "chore: Prepare for release $NEW_VERSION"

# 5. Push the commit to the main branch.
info "Pushing commit to remote repository..."
git push origin main

# 6. Create the new GitHub release and upload the APK.
info "Creating new GitHub release $NEW_VERSION..."
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
gh release create "$NEW_VERSION" "$APK_PATH" --title "$NEW_VERSION" --notes "New release $NEW_VERSION"

success "All done! Release $NEW_VERSION is live on GitHub."
