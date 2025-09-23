#!/usr/bin/env bash
# Script to decrypt SOPS secrets and update configuration
# Usage: ./scripts/decrypt-secrets.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔓 Decrypting SOPS secrets for kubecloud..."

# Check if SOPS is available
if ! command -v sops &> /dev/null; then
    echo "❌ SOPS not found. Installing with nix-shell..."
    nix-shell -p sops --run "$0 $*"
    exit 0
fi

# Check if age key exists
if [[ ! -f ~/.config/sops/age/keys.txt ]]; then
    echo "❌ Age key not found at ~/.config/sops/age/keys.txt"
    echo "Run: age-keygen -o ~/.config/sops/age/keys.txt"
    exit 1
fi

# Decrypt VKM secrets
echo "🔑 Decrypting VKM secrets..."
sops -d "$PROJECT_ROOT/secrets/vkm.sops.yaml" > "$PROJECT_ROOT/secrets/vkm.decrypted.yaml"

echo "✅ Secrets decrypted successfully!"
echo "📝 Decrypted secrets available at: secrets/vkm.decrypted.yaml"
echo ""
echo "📋 Ceph secrets:"
grep -A 5 "ceph:" "$PROJECT_ROOT/secrets/vkm.decrypted.yaml" || true
echo ""
echo "⚠️  Remember to add secrets/vkm.decrypted.yaml to .gitignore"