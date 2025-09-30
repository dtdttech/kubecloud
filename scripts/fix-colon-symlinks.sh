#!/usr/bin/env bash
set -euo pipefail

# Fix symlinks with colons in their names by replacing colons with dashes
# This is needed for GitHub Actions artifact uploads which don't support colons

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDERED_DIR="$SCRIPT_DIR/../kubevkm_rendered"

if [ ! -d "$RENDERED_DIR" ]; then
    echo "Error: $RENDERED_DIR does not exist"
    exit 1
fi

echo "Fixing symlinks with colons in $RENDERED_DIR..."

# First, handle directory symlinks with colons
echo "Processing directory symlinks..."
/usr/bin/find "$RENDERED_DIR" -maxdepth 1 -type l -name "*:*" | while read -r symlink; do
    echo "Processing directory symlink: $symlink"
    
    # Get the target of the symlink
    target=$(readlink "$symlink")
    
    # Get the directory of the symlink
    symlink_dir=$(dirname "$symlink")
    
    # Get the filename with colon replaced by dash
    new_name=$(basename "$symlink" | tr ':' '-')
    new_path="$symlink_dir/$new_name"
    
    # Remove the old symlink
    rm "$symlink"
    
    # Create new symlink with clean name
    ln -s "$target" "$new_path"
    
    echo "  Fixed: $symlink -> $new_path"
done

# Then, handle files within symlinks (directories that are symlinks)
echo "Processing files within symlinked directories..."
/usr/bin/find "$RENDERED_DIR" -mindepth 2 -type f -name "*:*" | while read -r file; do
    echo "Processing file with colon: $file"
    
    # Get the directory and filename
    file_dir=$(dirname "$file")
    file_name=$(basename "$file")
    
    # Get new filename with colon replaced by dash
    new_name=$(echo "$file_name" | tr ':' '-')
    new_path="$file_dir/$new_name"
    
    # Since these are files in nix store, we need to create symlinks with clean names
    # Remove the old file (which is actually a symlink to nix store)
    rm "$file"
    
    # Create new symlink with clean name pointing to the nix store path
    # Get the nix store path from the original file name
    nix_path="/nix/store/$(echo "$file_name" | tr ':' '-')"
    
    # Actually, let's create a new symlink with the cleaned name
    # The actual nix store file has the colon replaced with dash
    store_name=$(echo "$file_name" | tr ':' '-')
    ln -s "/nix/store/$(/usr/bin/find /nix/store -name "*$store_name" 2>/dev/null | head -1)" "$new_path" 2>/dev/null || {
        # If we can't find it, just copy the file if it exists
        if [ -f "/nix/store/$store_name" ]; then
            ln -s "/nix/store/$store_name" "$new_path"
        else
            echo "  Warning: Could not find nix store file for $file"
        fi
    }
    
    echo "  Fixed: $file -> $new_path"
done

echo "Done fixing symlinks!"