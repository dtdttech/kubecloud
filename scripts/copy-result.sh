#!/usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p bash cacert curl rsync


set -e

# Check if arguments are provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 SOURCE_DIR [TARGET_DIR]"
    echo "Example: $0 result kubevkm_rendered"
    exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="${2:-$(basename "$SOURCE_DIR")}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory $SOURCE_DIR does not exist"
    exit 1
fi

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

echo "Copying $SOURCE_DIR to $TARGET_DIR..."

# Use rsync to copy files, resolving symlinks and setting permissions
rsync -avL --chmod=0777 "$SOURCE_DIR/" "$TARGET_DIR/"

echo "Copy completed successfully!"
echo "Contents of $TARGET_DIR:"
ls -la "$TARGET_DIR"
