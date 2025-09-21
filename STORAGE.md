# Storage Abstraction System

This document describes the unified storage abstraction system that provides flexible, provider-agnostic volume management across different environments.

## Overview

The storage system provides:
- **Unified Interface**: Consistent volume creation across all modules
- **Multiple Backends**: Support for local, Ceph, and Longhorn storage
- **Environment Flexibility**: Different storage per environment (dev/staging/prod)
- **Provider Abstraction**: Easy switching between storage backends

## Storage Providers

### Local Storage (`local`)
- **Use Case**: Development and testing environments
- **Provider**: local-path-provisioner (Rancher)
- **Storage Class**: `local-path`
- **Features**: Simple, fast setup, node-local storage

### Ceph Storage (`ceph`)
- **Use Case**: Production environments requiring distributed storage
- **Provider**: Ceph CSI (RBD + CephFS)
- **Storage Classes**: 
  - `ceph-rbd` for ReadWriteOnce (block storage)
  - `ceph-cephfs` for ReadWriteMany/ReadOnlyMany (filesystem)
- **Features**: High availability, replication, snapshots

### Longhorn Storage (`longhorn`)
- **Use Case**: Production environments requiring simple distributed storage
- **Provider**: Longhorn distributed block storage
- **Storage Class**: `longhorn`
- **Features**: Built-in replication, backup, UI management

## Configuration

### Global Storage Configuration

Configure storage at the environment level in `env/*.nix`:

```nix
storage = {
  # Default provider for all applications
  defaultProvider = "ceph";  # local, ceph, or longhorn
  
  # Override storage class mappings
  storageClasses = {
    rwo = "ceph-rbd";        # ReadWriteOnce
    rwx = "ceph-cephfs";     # ReadWriteMany  
    rox = "ceph-cephfs";     # ReadOnlyMany
  };
  
  # Provider-specific settings
  providers = {
    local = {
      enable = false;
      storageClass.isDefault = false;
    };
    ceph = {
      enable = true;
      cluster = {
        clusterID = "production-cluster";
        monitors = ["10.0.1.10:6789" "10.0.1.11:6789"];
      };
      secrets = {
        userID = "kubernetes";
        userKey = "AQBQVkNh...";
      };
    };
    longhorn = {
      enable = false;
      ui.domain = "longhorn.example.com";
    };
  };
};
```

### Application-Specific Storage

Override storage settings per application:

```nix
documentation.bookstack = {
  enable = true;
  domain = "wiki.example.com";
  
  storage = {
    provider = "ceph";           # Override global default
    database.size = "50Gi";      # Larger database
    config.size = "10Gi";        # Larger config storage
  };
};
```

## Usage in Modules

### Using Storage Abstraction

When creating a new module, use the storage library:

```nix
{ lib, config, storageLib, storageConfig, ... }:

let
  cfg = config.myapp.example;
in
{
  options.myapp.example = with lib; {
    # ... other options ...
    
    storage = {
      provider = mkOption {
        type = types.enum [ "local" "ceph" "longhorn" ];
        default = storageConfig.defaultProvider;
        description = "Storage provider for this application";
      };
      
      data.size = mkOption {
        type = types.str;
        default = "10Gi";
        description = "Size of data volume";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create volumes using storage abstraction
    storage.volumes = {
      database = storageLib.commonVolumes.database {
        name = "myapp-db";
        size = cfg.storage.database.size;
        provider = cfg.storage.provider;
      };
      
      uploads = storageLib.commonVolumes.uploads {
        name = "myapp-uploads";
        size = cfg.storage.uploads.size;
        provider = cfg.storage.provider;
      };
    };

    applications.myapp = {
      namespace = "myapp";
      createNamespace = true;

      resources = {
        # Use generated PVCs
        persistentVolumeClaims = config.storage.volumes;
        
        # Reference volumes in deployments
        deployments.myapp = {
          spec.template.spec = {
            volumes = [
              (storageLib.createPodVolume { name = "myapp-db"; })
              (storageLib.createPodVolume { name = "myapp-uploads"; })
            ];
            
            containers = [{
              volumeMounts = [
                (storageLib.createVolumeMount { 
                  name = "myapp-db"; 
                  mountPath = "/var/lib/database"; 
                })
                (storageLib.createVolumeMount { 
                  name = "myapp-uploads"; 
                  mountPath = "/var/uploads"; 
                })
              ];
            }];
          };
        };
      };
    };
  };
}
```

### Storage Library Functions

#### Volume Creation

```nix
# Create custom volume
storageLib.createVolume {
  name = "custom-volume";
  size = "20Gi";
  accessMode = "rwo";  # rwo, rwx, rox
  provider = "ceph";
}

# Use common volume types
storageLib.commonVolumes.database { name = "db"; size = "50Gi"; }
storageLib.commonVolumes.config { name = "config"; size = "1Gi"; }
storageLib.commonVolumes.uploads { name = "uploads"; size = "10Gi"; }
storageLib.commonVolumes.shared { name = "shared"; size = "100Gi"; }
storageLib.commonVolumes.cache { name = "cache"; size = "5Gi"; }
```

#### Volume Mounting

```nix
# Pod volume definition
storageLib.createPodVolume { 
  name = "data"; 
  pvcName = "data-pvc";  # Optional, defaults to "${name}-pvc"
}

# Container volume mount
storageLib.createVolumeMount {
  name = "data";
  mountPath = "/var/data";
  subPath = "app";       # Optional
  readOnly = false;      # Optional
}
```

## Environment Examples

### Development Environment

```nix
# env/dev.nix
storage = {
  defaultProvider = "local";
  providers.local = {
    enable = true;
    storageClass.isDefault = true;
  };
};
```

### Production Environment

```nix
# env/prod.nix
storage = {
  defaultProvider = "ceph";
  providers = {
    local.enable = false;
    ceph = {
      enable = true;
      cluster.clusterID = "prod-cluster";
      # ... Ceph configuration
    };
  };
};
```

## Migration Guide

### From Manual PVCs

**Before:**
```nix
persistentVolumeClaims.app-data-pvc = {
  spec = {
    accessModes = ["ReadWriteOnce"];
    resources.requests.storage = "10Gi";
  };
};
```

**After:**
```nix
# In module options
storage.data.size = mkOption { default = "10Gi"; };

# In config
storage.volumes.app-data = storageLib.commonVolumes.config {
  name = "app-data";
  size = cfg.storage.data.size;
  provider = cfg.storage.provider;
};

# In resources
persistentVolumeClaims = config.storage.volumes;
```

## Benefits

1. **Consistency**: All modules use the same storage patterns
2. **Flexibility**: Easy to change storage backends per environment
3. **Maintenance**: Centralized storage configuration and logic
4. **Scalability**: Support for different storage needs (dev vs prod)
5. **Provider Independence**: Abstract away storage implementation details