{ lib }:

rec {
  # Storage access mode types
  accessModes = {
    rwo = "ReadWriteOnce";     # Single node read-write (databases, single-pod apps)
    rwx = "ReadWriteMany";     # Multi-node read-write (shared storage, multi-pod apps)
    rox = "ReadOnlyMany";      # Multi-node read-only (config, static assets)
  };

  # Storage provider types
  providers = {
    local = "local-path";
    ceph-rbd = "ceph-rbd";
    ceph-cephfs = "ceph-cephfs";
    longhorn = "longhorn";
  };

  # Default storage class mapping based on access mode and provider preference
  getStorageClass = { provider ? "local", accessMode ? "rwo", storageClasses ? {} }:
    let
      # Custom storage class mappings from configuration
      customClass = storageClasses.${accessMode} or null;
      
      # Default mappings based on provider and access mode
      defaultMappings = {
        local = {
          rwo = providers.local;
          rwx = providers.local;  # local-path supports RWX in some configurations
          rox = providers.local;
        };
        ceph = {
          rwo = providers.ceph-rbd;    # RBD is optimal for RWO
          rwx = providers.ceph-cephfs; # CephFS for RWX
          rox = providers.ceph-cephfs; # CephFS for ROX
        };
        longhorn = {
          rwo = providers.longhorn;
          rwx = providers.longhorn;
          rox = providers.longhorn;
        };
      };
    in
    if customClass != null then customClass
    else defaultMappings.${provider}.${accessMode} or providers.local;

  # Create a PVC definition
  createVolume = {
    name,                    # Volume name (will be used as PVC name)
    size,                    # Storage size (e.g., "20Gi", "1Ti")
    accessMode ? "rwo",      # Access mode: rwo, rwx, rox
    provider ? "local",      # Storage provider: local, ceph, longhorn
    storageClass ? null,     # Explicit storage class override
    storageClasses ? {},     # Custom storage class mappings from config
    annotations ? {},        # Additional annotations
    labels ? {}              # Additional labels
  }:
    let
      resolvedStorageClass = 
        if storageClass != null then storageClass
        else getStorageClass { 
          inherit provider accessMode storageClasses; 
        };
      
      resolvedAccessMode = accessModes.${accessMode} or accessModes.rwo;
    in
    {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "${name}-pvc";
        inherit labels;
        annotations = annotations // {
          "storage.kubecloud.io/provider" = provider;
          "storage.kubecloud.io/access-mode" = accessMode;
        };
      };
      spec = {
        accessModes = [ resolvedAccessMode ];
        storageClassName = resolvedStorageClass;
        resources.requests.storage = size;
      };
    };

  # Create multiple volumes at once
  createVolumes = volumeSpecs: { provider ? "local", storageClasses ? {} }:
    lib.listToAttrs (map (spec: {
      name = "${spec.name}-pvc";
      value = createVolume (spec // { 
        inherit provider storageClasses; 
      });
    }) volumeSpecs);

  # Helper function to create volume mount configurations
  createVolumeMount = {
    name,                    # Volume name (matches PVC name without -pvc suffix)
    mountPath,               # Container mount path
    subPath ? null,          # Optional subPath
    readOnly ? false         # Mount as read-only
  }: {
    name = name;
    inherit mountPath readOnly;
  } // lib.optionalAttrs (subPath != null) { inherit subPath; };

  # Helper function to create volume configurations for pods
  createPodVolume = {
    name,                    # Volume name (matches PVC name without -pvc suffix)
    pvcName ? "${name}-pvc"  # PVC name (defaults to name-pvc)
  }: {
    name = name;
    persistentVolumeClaim.claimName = pvcName;
  };

  # Common volume configurations for different use cases
  commonVolumes = {
    # Database storage (RWO, typically larger)
    database = { name, size ? "20Gi", provider ? "local" }: 
      createVolume {
        inherit name size provider;
        accessMode = "rwo";
      };

    # Application config (RWO, smaller)
    config = { name, size ? "1Gi", provider ? "local" }:
      createVolume {
        inherit name size provider;
        accessMode = "rwo";
      };

    # File uploads/user data (RWO, medium)
    uploads = { name, size ? "5Gi", provider ? "local" }:
      createVolume {
        inherit name size provider;
        accessMode = "rwo";
      };

    # Shared storage (RWX, configurable)
    shared = { name, size ? "10Gi", provider ? "ceph" }:
      createVolume {
        inherit name size provider;
        accessMode = "rwx";
      };

    # Cache/temporary storage (RWO, smaller, local preferred)
    cache = { name, size ? "2Gi", provider ? "local" }:
      createVolume {
        inherit name size provider;
        accessMode = "rwo";
      };
  };
}