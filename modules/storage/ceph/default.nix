{
  lib,
  config,
  pkgs,
  charts,
  ...
}:

let

  # Simple SOPS integration - decrypt secrets at build time
  decryptSOPS =
    secretsFile: path:
    let
      sopsCmd = "${pkgs.sops}/bin/sops";
      decryptedJSON = builtins.readFile (
        pkgs.runCommand "decrypt-sops-${builtins.baseNameOf secretsFile}"
          {
            buildInputs = [ pkgs.sops ];
          }
          ''
            ${sopsCmd} -d --extract '["${path}"]' --output-type json ${secretsFile} > $out
          ''
      );
      pathParts = lib.splitString "/" path;
      content = builtins.fromJSON decryptedJSON;
    in
    content;

  cfg = config.storage.providers.ceph;

  namespace = "ceph-csi-system";
in
{
  options.storage.providers.ceph = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Ceph CSI storage driver";
    };

    version = mkOption {
      type = types.str;
      default = "v3.12.0";
      description = "Ceph CSI version to deploy";
    };

    rbd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable RBD (block storage) support";
      };

      storageClass = {
        name = mkOption {
          type = types.str;
          default = "ceph-rbd";
          description = "Name of the RBD StorageClass";
        };

        reclaimPolicy = mkOption {
          type = types.str;
          default = "Delete";
          description = "Reclaim policy for RBD volumes";
        };

        allowVolumeExpansion = mkOption {
          type = types.bool;
          default = true;
          description = "Allow volume expansion for RBD volumes";
        };

        pool = mkOption {
          type = types.str;
          default = "kube-data";
          description = "Ceph pool name for RBD volumes";
        };
      };
    };

    cephfs = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable CephFS (file storage) support";
      };

      storageClass = {
        name = mkOption {
          type = types.str;
          default = "ceph-cephfs";
          description = "Name of the CephFS StorageClass";
        };

        reclaimPolicy = mkOption {
          type = types.str;
          default = "Delete";
          description = "Reclaim policy for CephFS volumes";
        };

        allowVolumeExpansion = mkOption {
          type = types.bool;
          default = true;
          description = "Allow volume expansion for CephFS volumes";
        };

        pool = mkOption {
          type = types.str;
          default = "kube-data";
          description = "Ceph pool name for CephFS volumes";
        };

        fsName = mkOption {
          type = types.str;
          default = "kube-data-fs";
          description = "CephFS filesystem name";
        };

        volumeBindingMode = mkOption {
          type = types.str;
          default = "Immediate";
          description = "Volume binding mode for CephFS volumes";
        };
      };
    };

    sops = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable SOPS-based secret management";
      };

      secretsFile = mkOption {
        type = types.path;
        description = "Path to SOPS secrets file";
      };

      secretsPath = mkOption {
        type = types.str;
        default = "ceph";
        description = "Path to secrets within SOPS file";
      };
    };

    cluster = {
      clusterID = mkOption {
        type = types.str;
        description = "Ceph cluster ID";
      };

      monitors = mkOption {
        type = types.listOf types.str;
        description = "List of Ceph monitor addresses";
      };
    };

    secrets = {
      userID = mkOption {
        type = types.str;
        description = "Ceph user ID for Kubernetes operations";
      };

      userKey = mkOption {
        type = types.str;
        description = "Ceph user key for Kubernetes operations";
      };

      adminID = mkOption {
        type = types.str;
        description = "Ceph admin user ID for CSI operations";
      };

      adminKey = mkOption {
        type = types.str;
        description = "Ceph admin key for CSI operations";
      };
    };

    metrics = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable metrics collection";
      };
      port = mkOption {
        type = types.int;
        default = 8080;
        description = "Port for metrics endpoint";
      };
    };

    topology = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable topology awareness";
      };
      domainLabels = mkOption {
        type = types.listOf types.str;
        default = [ "kubernetes.io/hostname" ];
        description = "Domain labels for topology";
      };
    };

    deployment = {
      replicaCount = mkOption {
        type = types.int;
        default = 3;
        description = "Number of replicas for CSI deployments";
      };

      resources = {
        requests = {
          memory = mkOption {
            type = types.str;
            default = "128Mi";
            description = "Memory request for CSI pods";
          };
          cpu = mkOption {
            type = types.str;
            default = "100m";
            description = "CPU request for CSI pods";
          };
        };
        limits = {
          memory = mkOption {
            type = types.str;
            default = "512Mi";
            description = "Memory limit for CSI pods";
          };
          cpu = mkOption {
            type = types.str;
            default = "500m";
            description = "CPU limit for CSI pods";
          };
        };
      };

      affinity = mkOption {
        type = types.attrs;
        default = { };
        description = "Affinity rules for CSI pods";
      };

      tolerations = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = "Tolerations for CSI pods";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.ceph-csi = {
      inherit namespace;
      createNamespace = true;

      # Use Helm chart for Ceph CSI - install both RBD and CephFS separately
      helm.releases = {
        # RBD CSI Driver
        ceph-csi-rbd = lib.mkIf cfg.rbd.enable {
          chart = charts.ceph-csi-rbd;

          values = {
            # Basic configuration
            fullnameOverride = "ceph-csi-rbd";

            # Ceph cluster configuration
            csiConfig =
              if cfg.sops.enable then
                let
                  sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
                in
                [
                  {
                    clusterID = sopsData.clusterID;
                    monitors = sopsData.monitors;
                  }
                ]
              else
                [
                  {
                    clusterID = cfg.cluster.clusterID;
                    monitors = cfg.cluster.monitors;
                  }
                ];

            # Secret management
            secret =
              if cfg.sops.enable then
                let
                  sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
                in
                {
                  userID = sopsData.userID;
                  userKey = sopsData.userKey;
                  adminID = sopsData.adminID;
                  adminKey = sopsData.adminKey;
                }
              else
                {
                  userID = cfg.secrets.userID;
                  userKey = cfg.secrets.userKey;
                  adminID = cfg.secrets.adminID;
                  adminKey = cfg.secrets.adminKey;
                };

            # Driver configuration
            provisioner = {
              replicaCount = 3;
              image = "quay.io/cephcsi/cephcsi:${cfg.version}";
            };
            nodePlugin = {
              replicaCount = 3;
              image = "quay.io/cephcsi/cephcsi:${cfg.version}";
            };

            # StorageClass
            storageClass = {
              create = true;
              name = cfg.rbd.storageClass.name;
              pool = cfg.rbd.storageClass.pool;
              reclaimPolicy = cfg.rbd.storageClass.reclaimPolicy;
              allowVolumeExpansion = cfg.rbd.storageClass.allowVolumeExpansion;
              parameters = {
                "imageFormat" = "2";
                "imageFeatures" = "layering";
              };
            };

            # RBAC
            rbac.create = true;
            serviceAccounts.nodeplugin.create = true;
            serviceAccounts.provisioner.create = true;
          };
        };

        # CephFS CSI Driver
        ceph-csi-cephfs = lib.mkIf cfg.cephfs.enable {
          chart = charts.ceph-csi-cephfs;

          values = {
            # Basic configuration
            fullnameOverride = "ceph-csi-cephfs";

            # Ceph cluster configuration
            csiConfig =
              if cfg.sops.enable then
                let
                  sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
                in
                [
                  {
                    clusterID = sopsData.clusterID;
                    monitors = sopsData.monitors;
                  }
                ]
              else
                [
                  {
                    clusterID = cfg.cluster.clusterID;
                    monitors = cfg.cluster.monitors;
                  }
                ];

            # Secret management
            secret =
              if cfg.sops.enable then
                let
                  sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
                in
                {
                  adminID = sopsData.adminID;
                  adminKey = sopsData.adminKey;
                }
              else
                {
                  adminID = cfg.secrets.adminID;
                  adminKey = cfg.secrets.adminKey;
                };

            # Driver configuration
            provisioner = {
              replicaCount = 3;
              image = "quay.io/cephcsi/cephcsi:${cfg.version}";
            };
            nodePlugin = {
              replicaCount = 3;
              image = "quay.io/cephcsi/cephcsi:${cfg.version}";
            };

            # StorageClass
            storageClass = {
              create = true;
              name = cfg.cephfs.storageClass.name;
              pool = cfg.cephfs.storageClass.pool;
              fsName = cfg.cephfs.storageClass.fsName;
              reclaimPolicy = cfg.cephfs.storageClass.reclaimPolicy;
              allowVolumeExpansion = cfg.cephfs.storageClass.allowVolumeExpansion;
            };

            # RBAC
            rbac.create = true;
            serviceAccounts.nodeplugin.create = true;
            serviceAccounts.provisioner.create = true;
          };
        };
      };
    };
  };
}
