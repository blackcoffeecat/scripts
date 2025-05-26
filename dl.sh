#!/bin/bash

# dl.sh - A script to update GitHub releases
# Usage: curl -s https://blackcoffeecat.github.io/scripts/dl.sh | bash -s -- <owner/repo> [download_dir] [--debug]
# Example: curl -s https://blackcoffeecat.github.io/scripts/dl.sh | bash -s -- octocat/Hello-World ./downloads --debug

set -e

# GitHub repository information
REPO="$1"
DOWNLOAD_DIR="${2:-$(pwd)}"
DEBUG=false
SCRIPT_CDN="${SCRIPT_CDN:-"https://blackcoffeecat.github.io/scripts"}"
GITHUB_API="${GITHUB_API:-"https://api.github.com"}"
VERSION_FILE="version"
arch=""
# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --debug) DEBUG=true; shift ;;
        *) shift ;;
    esac
done

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate input
if [ -z "$REPO" ]; then
    echo "Error: Repository not specified."
    echo "Usage: curl -s $SCRIPT_CDN/dl.sh | bash -s -- <owner/repo> [download_dir] [--debug]"
    exit 1
fi

debug "Repository: $REPO"
debug "Download directory: $DOWNLOAD_DIR"

# Function to download file
download_file() {
    local url="$1"
    local output="$2"
    debug "Downloading file from $url to $output"
    curl -L -o "$output" "$url"
    debug "Download completed"
}

# Function to get latest release version and assets
get_latest_release() {
    debug "Fetching latest release information"
    curl -s "$GITHUB_API/repos/$REPO/releases/latest"
}

# Get current version
current_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0")
debug "Current version: $current_version"

# Get latest release information
release_info=$(get_latest_release)
echo "$release_info" > "$DOWNLOAD_DIR/release_info.json"
debug "Fetched release information"

# Extract latest version
latest_version=$(echo "$release_info" | jq -r .tag_name)
debug "Latest version: $latest_version"

# Compare versions
if [[ "$latest_version" == "$current_version" ]]; then
    echo "Already up to date."
    exit 0
fi

echo "New version available: $latest_version"
debug "New version detected"

# Create download directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"
debug "Created download directory: $DOWNLOAD_DIR"

# Function to determine platform and architecture from filename
get_platform_arch() {
    local filename="$1"
    local platform=""
    local arch=""
    local ext=""

    # Determine platform
    if [[ "$filename" =~ mac|macos|darwin ]]; then
        platform="mac"
    elif [[ "$filename" =~ win|windows || "$filename" =~ \.exe$ ]]; then
        platform="win"
    else
        platform="linux"
    fi

    # Determine architecture
    if [[ "$filename" =~ arm64|armv8 ]]; then
        arch="arm64"
    elif [[ "$filename" =~ amd64|x64|64 ]]; then
        arch="x64"
    else
        arch="unknown"
    fi

    # Get file extension
    ext="${filename##*.}"
    if [[ "$ext" == "$filename" ]]; then
        ext=""
    else
        ext=".$ext"
    fi

    debug "Detected platform: $platform, architecture: $arch, extension: $ext"
    echo "$platform $arch $ext"
}

# Download assets
debug "Starting asset download"
echo "$release_info" | jq -r '.assets[].browser_download_url' | while read -r url; do
    filename=$(basename "$url")
    debug "Processing asset: $filename"
    read -r platform arch ext < <(get_platform_arch "$filename")

    if [[ "$filename" =~ compatible|go120|go123|tar ]]; then
        echo "Skipping $filename (unknown platform or architecture)"
        debug "Skipped $filename due to unknown platform or architecture"
    elif [[ "$platform" != "unknown" && "$arch" != "unknown" ]]; then
        output_file="$DOWNLOAD_DIR/${platform}_${arch}${ext}"
        echo "Downloading $filename as $output_file"
        download_file "$url" "$output_file"
    else
        echo "Skipping $filename (unknown platform or architecture)"
        debug "Skipped $filename due to unknown platform or architecture"
    fi
done

# Update version file
echo "$latest_version" > "$VERSION_FILE"
echo "Updated version file to $latest_version"
debug "Version file updated"
