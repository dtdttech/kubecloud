{ lib, config, ... }:

let
  storageLib = import ../../lib/storage.nix { inherit lib; };
in
{
  imports = [
    ./local
    ./ceph
    ./longhorn
  ];

  options.storage = with lib; {
    # Default storage provider for the environment
    defaultProvider = mkOption {
      type = types.enum [
        "local"
        "ceph"
        "longhorn"
      ];
      default = "local";
      description = ''
        Default storage provider to use for volumes when not explicitly specified.
        - local: Use local-path-provisioner (good for development)
        - ceph: Use Ceph RBD/CephFS (good for production)
        - longhorn: Use Longhorn distributed storage (good for production)
      '';
    };

    # Global storage class mappings
    storageClasses = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        rwo = "ceph-rbd";
        rwx = "ceph-cephfs";
        rox = "ceph-cephfs";
      };
      description = ''
        Override storage class mappings for different access modes.
        Keys are access modes (rwo, rwx, rox), values are storage class names.
      '';
    };

    # Provider-specific configurations are defined by individual provider modules
  };

  config = {
    # Make storage utilities available to all modules
    _module.args.storageLib = storageLib;

    # Expose storage configuration to all modules
    _module.args.storageConfig = {
      defaultProvider = config.storage.defaultProvider;
      storageClasses = config.storage.storageClasses;
    };
  };
}
