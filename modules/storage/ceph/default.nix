{ lib, config, pkgs, ... }:

# Import generated CRDs
let
  cephCsiCrds = import ./generated.nix;

  # Simple SOPS integration - decrypt secrets at build time
  decryptSOPS = secretsFile: path:
    let
      sopsCmd = "${pkgs.sops}/bin/sops";
      decryptedJSON = builtins.readFile (pkgs.runCommand "decrypt-sops-${builtins.baseNameOf secretsFile}" {
        buildInputs = [ pkgs.sops ];
      } ''
        ${sopsCmd} -d --extract '["${path}"]' --output-type json ${secretsFile} > $out
      '');
      pathParts = lib.splitString "/" path;
      content = builtins.fromJSON decryptedJSON;
    in content;

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
  };

  config = lib.mkIf cfg.enable {
    applications.ceph-csi = {
      inherit namespace;
      createNamespace = true;

      # Import generated CRDs
      imports = [cephCsiCrds];

      # Ceph CSI configuration
      resources = {
        # ConfigMap with cluster information
        configMaps.ceph-csi-config = {
          data = {
            "config.json" = builtins.toJSON [
              (if cfg.sops.enable then 
                let sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
                in {
                  clusterID = sopsData.clusterID;
                  monitors = sopsData.monitors;
                }
              else {
                clusterID = cfg.cluster.clusterID;
                monitors = cfg.cluster.monitors;
              })
            ];
          };
        };

        # RBD Secret
        secrets.csi-rbd-secret = lib.mkIf cfg.rbd.enable {
          stringData = 
            if cfg.sops.enable then 
              let sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
              in {
                userID = sopsData.userID;
                userKey = sopsData.userKey;
                adminID = sopsData.adminID;
                adminKey = sopsData.adminKey;
              }
            else {
              userID = cfg.secrets.userID;
              userKey = cfg.secrets.userKey;
              adminID = cfg.secrets.adminID;
              adminKey = cfg.secrets.adminKey;
            };
        };

        # CephFS Secret  
        secrets.csi-cephfs-secret = lib.mkIf cfg.cephfs.enable {
          stringData = 
            if cfg.sops.enable then 
              let sopsData = decryptSOPS cfg.sops.secretsFile "ceph";
              in {
                adminID = sopsData.adminID;
                adminKey = sopsData.adminKey;
              }
            else {
              adminID = cfg.secrets.adminID;
              adminKey = cfg.secrets.adminKey;
            };
        };

        # RBD StorageClass
        storageClasses.${cfg.rbd.storageClass.name} = lib.mkIf cfg.rbd.enable {
          provisioner = "rbd.csi.ceph.com";
          parameters = {
            "csi.storage.k8s.io/provisioner-secret-name" = "csi-rbd-secret";
            "csi.storage.k8s.io/provisioner-secret-namespace" = namespace;
            "csi.storage.k8s.io/controller-expand-secret-name" = "csi-rbd-secret";
            "csi.storage.k8s.io/controller-expand-secret-namespace" = namespace;
            "csi.storage.k8s.io/node-stage-secret-name" = "csi-rbd-secret";
            "csi.storage.k8s.io/node-stage-secret-namespace" = namespace;
            "clusterID" = if cfg.sops.enable then 
              (decryptSOPS cfg.sops.secretsFile "ceph").clusterID
              else cfg.cluster.clusterID;
            "pool" = cfg.rbd.storageClass.pool;
            "imageFormat" = "2";
            "imageFeatures" = "layering";
          };
          reclaimPolicy = cfg.rbd.storageClass.reclaimPolicy;
          allowVolumeExpansion = cfg.rbd.storageClass.allowVolumeExpansion;
          volumeBindingMode = "Immediate";
        };

        # CephFS StorageClass
        storageClasses.${cfg.cephfs.storageClass.name} = lib.mkIf cfg.cephfs.enable {
          provisioner = "cephfs.csi.ceph.com";
          parameters = {
            "csi.storage.k8s.io/provisioner-secret-name" = "csi-cephfs-secret";
            "csi.storage.k8s.io/provisioner-secret-namespace" = namespace;
            "csi.storage.k8s.io/controller-expand-secret-name" = "csi-cephfs-secret";
            "csi.storage.k8s.io/controller-expand-secret-namespace" = namespace;
            "csi.storage.k8s.io/node-stage-secret-name" = "csi-cephfs-secret";
            "csi.storage.k8s.io/node-stage-secret-namespace" = namespace;
            "clusterID" = if cfg.sops.enable then 
              (decryptSOPS cfg.sops.secretsFile "ceph").clusterID
              else cfg.cluster.clusterID;
            "fsName" = cfg.cephfs.storageClass.fsName;
            "pool" = cfg.cephfs.storageClass.pool;
          };
          reclaimPolicy = cfg.cephfs.storageClass.reclaimPolicy;
          allowVolumeExpansion = cfg.cephfs.storageClass.allowVolumeExpansion;
          volumeBindingMode = "Immediate";
        };

        # CSI Driver deployments (simplified version)
        deployments.csi-rbd-provisioner = lib.mkIf cfg.rbd.enable {
          spec = {
            replicas = 3;
            selector.matchLabels."app" = "csi-rbd-provisioner";
            template.metadata.labels."app" = "csi-rbd-provisioner";
            template.spec = {
              serviceAccountName = "rbd-csi-provisioner";
              containers = [
                {
                  name = "csi-rbd-provisioner";
                  image = "quay.io/cephcsi/cephcsi:${cfg.version}";
                  args = [
                    "--nodeid=$(NODE_ID)"
                    "--endpoint=$(CSI_ENDPOINT)"
                    "--v=5"
                    "--drivername=rbd.csi.ceph.com"
                    "--pidlimit=-1"
                  ];
                  env = [
                    { name = "NODE_ID"; valueFrom.fieldRef.fieldPath = "spec.nodeName"; }
                    { name = "CSI_ENDPOINT"; value = "unix:///csi/csi-provisioner.sock"; }
                  ];
                  volumeMounts = [
                    { name = "socket-dir"; mountPath = "/csi"; }
                    { name = "host-mount"; mountPath = "/var/lib/kubelet/pods"; mountPropagation = "Bidirectional"; }
                    { name = "ceph-csi-config"; mountPath = "/etc/ceph-csi-config/"; readOnly = true; }
                  ];
                }
              ];
              volumes = [
                { name = "socket-dir"; emptyDir = {}; }
                { name = "host-mount"; hostPath.path = "/var/lib/kubelet/pods"; }
                { name = "ceph-csi-config"; configMap.name = "ceph-csi-config"; }
              ];
            };
          };
        };

        # Service accounts and RBAC
        serviceAccounts = {
          rbd-csi-provisioner = lib.mkIf cfg.rbd.enable {};
          rbd-csi-nodeplugin = lib.mkIf cfg.rbd.enable {};
          cephfs-csi-provisioner = lib.mkIf cfg.cephfs.enable {};
          cephfs-csi-nodeplugin = lib.mkIf cfg.cephfs.enable {};
        };

        # Cluster roles for the provisioner
        clusterRoles.rbd-external-provisioner-runner = lib.mkIf cfg.rbd.enable {
          rules = [
            {
              apiGroups = [""];
              resources = ["secrets"];
              verbs = ["get" "list"];
            }
            {
              apiGroups = [""];
              resources = ["persistentvolumes"];
              verbs = ["get" "list" "watch" "create" "delete"];
            }
            {
              apiGroups = [""];
              resources = ["persistentvolumeclaims"];
              verbs = ["get" "list" "watch" "update"];
            }
            {
              apiGroups = ["storage.k8s.io"];
              resources = ["storageclasses"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = [""];
              resources = ["events"];
              verbs = ["list" "watch" "create" "update" "patch"];
            }
            {
              apiGroups = ["snapshot.storage.k8s.io"];
              resources = ["volumesnapshots"];
              verbs = ["get" "list"];
            }
            {
              apiGroups = ["snapshot.storage.k8s.io"];
              resources = ["volumesnapshotcontents"];
              verbs = ["create" "get" "list" "watch" "update" "delete"];
            }
            {
              apiGroups = ["snapshot.storage.k8s.io"];
              resources = ["volumesnapshotclasses"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = ["storage.k8s.io"];
              resources = ["volumeattachments"];
              verbs = ["get" "list" "watch" "update" "patch"];
            }
            {
              apiGroups = ["storage.k8s.io"];
              resources = ["volumeattachments/status"];
              verbs = ["patch"];
            }
            {
              apiGroups = ["storage.k8s.io"];
              resources = ["csinodes"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = [""];
              resources = ["nodes"];
              verbs = ["get" "list" "watch"];
            }
            {
              apiGroups = ["coordination.k8s.io"];
              resources = ["leases"];
              verbs = ["get" "watch" "list" "delete" "update" "create"];
            }
          ];
        };
      };
    };
  };
}