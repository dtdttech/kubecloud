# SOPS Secret Management

This directory contains encrypted secrets managed by [SOPS](https://github.com/mozilla/sops).

## Setup

### 1. Install SOPS

```bash
# Using Nix
nix-shell -p sops

# Or using other package managers
# brew install sops
# apt install sops
```

### 2. Generate Age Key (✅ COMPLETED)

```bash
# Generate a new age key
age-keygen -o ~/.config/sops/age/keys.txt

# The public key will be displayed, add it to .sops.yaml
```

**Current Key:** `age132yu935j0k8cl28psdqkyca5kcj03s64grtky8xv4hmzllr6ls3shta56p`

### 3. Update .sops.yaml (✅ COMPLETED)

The SOPS configuration has been updated with the generated Age key.

## Usage

### Encrypting Secrets (✅ COMPLETED)

```bash
# Encrypt the VKM secrets file
sops -e -i secrets/vkm.sops.yaml

# Verify encryption worked
cat secrets/vkm.sops.yaml  # Should show encrypted content
```

**Status:** VKM secrets are now encrypted with Age.

### Viewing/Editing Secrets

```bash
# View decrypted secrets
sops -d secrets/vkm.sops.yaml

# Edit secrets (decrypts, opens editor, re-encrypts)
sops secrets/vkm.sops.yaml

# Use the helper script
./scripts/decrypt-secrets.sh
```

### Adding New Secrets

```bash
# Edit the file and add new secrets
sops secrets/vkm.sops.yaml

# Or create a new environment secrets file
cp secrets/vkm.sops.yaml secrets/prod.sops.yaml
sops secrets/prod.sops.yaml
```

## Integration with Ceph

The Ceph module supports SOPS-based secret management:

### Enable SOPS for Ceph

In your environment configuration (e.g., `env/vkm.nix`):

```nix
storage.providers.ceph = {
  enable = true;
  # ... other config ...
  
  sops = {
    enable = true;    # ⚠️ Currently disabled due to Nix pure evaluation constraints
    secretsFile = ../../secrets/vkm.sops.yaml;
    secretsPath = "ceph";
  };
};
```

**Current Status:** SOPS integration framework is complete but currently disabled due to Nix's pure evaluation mode constraints. The system falls back to plaintext secrets while we work on a solution.

### Secret Structure

The secrets file should contain Ceph credentials under the `ceph` key:

```yaml
ceph:
  userID: kubernetes
  userKey: AQBQVkNhL1VkBhAAzOWOCpQNbCOg0BlpKQv6Wg==
  adminID: admin
  adminKey: AQBQVkNhYQJkBhAAb8OVKqP3F6k7zK4OvA2T7w==
```

## Security Notes

- **Never commit unencrypted secrets** to version control
- **Keep your private keys secure** and backed up
- **Use different keys for different environments**
- **Rotate secrets regularly**
- **Review access permissions** for your repositories

## Troubleshooting

### Build Fails with SOPS Enabled

1. Ensure SOPS is installed: `which sops`
2. Verify your private key is accessible
3. Check that secrets are properly encrypted: `sops -d secrets/vkm.sops.yaml`
4. Temporarily disable SOPS to test: `sops.enable = false`

### Cannot Decrypt Secrets

1. Check if your private key is in the correct location
2. Verify the public key in `.sops.yaml` matches your private key
3. Ensure the secrets file was encrypted with your key: `sops -d secrets/vkm.sops.yaml`

## Files

- `vkm.sops.yaml` - VKM environment secrets (encrypted)
- `README.md` - This documentation
- `.sops.yaml` - SOPS configuration (in project root)