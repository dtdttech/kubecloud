#!/usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p bash cacert curl rsync

# Script to copy result/ to kubevkm_rendered folder
# Resolves symlinks and sets permissions to 0777 for copied files

set -e

SOURCE_DIR="result"
TARGET_DIR="kubevkm_rendered"

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