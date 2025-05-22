#!/bin/bash

# dl.sh - A script to update GitHub releases
# Usage: curl -s https://blackcoffeecat.github.io/scripts/dl.sh | bash -s -- <owner/repo> [download_dir]
# Example: curl -s https://blackcoffeecat.github.io/scripts/dl.sh | bash -s -- octocat/Hello-World ./downloads

set -e

# GitHub repository information
REPO="$1"
DOWNLOAD_DIR="${2:-$(pwd)}"
SCRIPT_CDN="${SCRIPT_CDN:-"https://blackcoffeecat.github.io/scripts"}" # https://cdn.jsdelivr.net/gh/blackcoffeecat/scripts
GITHUB_API="${GITHUB_API:-"https://api.github.com"}"
VERSION_FILE="version"

# Validate input
if [ -z "$REPO" ]; then
    echo "Error: Repository not specified."
    echo "Usage: curl -s $SCRIPT_CDN/dl.sh | bash -s -- <owner/repo> [download_dir]"
    exit 1
fi

# Function to download file
download_file() {
    local url="$1"
    local output="$2"
    curl -L -o "$output" "$url"
}

# Function to get latest release version and assets
get_latest_release() {
    curl -s "$GITHUB_API/repos/$REPO/releases/latest" | \
    curl -s $SCRIPT_CDN/bjq.sh | bash -s -- .
}

# Get current version
current_version=$(cat "$VERSION_FILE" 2>/dev/null || echo "0.0.0")

# Get latest release information
release_info=$(get_latest_release)

# Extract latest version
latest_version=$(echo "$release_info" | curl -s $SCRIPT_CDN/bjq.sh | bash -s -- .tag_name)

# Compare versions
if [[ "$latest_version" == "$current_version" ]]; then
    echo "Already up to date."
    exit 0
fi

echo "New version available: $latest_version"

# Create download directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

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
    if [[ "$filename" =~ amd64|x64|64 ]]; then
        arch="x64"
    elif [[ "$filename" =~ arm64|armv8 ]]; then
        arch="arm64"
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

    echo "$platform $arch $ext"
}

# Download assets
echo "$release_info" | curl -s $SCRIPT_CDN/bjq.sh | bash -s -- '.assets[].browser_download_url' | while read -r url; do
    filename=$(basename "$url")
    read -r platform arch ext < <(get_platform_arch "$filename")
    
    if [[ "$platform" != "unknown" && "$arch" != "unknown" ]]; then
        output_file="$DOWNLOAD_DIR/${platform}_${arch}${ext}"
        echo "Downloading $filename as $output_file"
        download_file "$url" "$output_file"
    else
        echo "Skipping $filename (unknown platform or architecture)"
    fi
done

# Update version file
echo "$latest_version" > "$VERSION_FILE"
echo "Updated version file to $latest_version"
