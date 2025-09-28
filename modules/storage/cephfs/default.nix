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

  cfg = config.storage.providers.cephfs;

  namespace = "cephfs-csi-system";
in
{
  options.storage.providers.cephfs = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable CephFS CSI storage driver";
    };

    version = mkOption {
      type = types.str;
      default = "v3.12.0";
      description = "Ceph CSI version to deploy";
    };

    storageClass = {
      name = mkOption {
        type = types.str;
        default = "cephfs";
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

      volumeBindingMode = mkOption {
        type = types.str;
        default = "Immediate";
        description = "Volume binding mode for CephFS volumes";
      };

      parameters = mkOption {
        type = types.attrsOf types.str;
        default = {
          "csi.storage.k8s.io/provisioner-secret-name" = "cephfs-secret";
          "csi.storage.k8s.io/provisioner-secret-namespace" = namespace;
          "csi.storage.k8s.io/node-stage-secret-name" = "cephfs-secret";
          "csi.storage.k8s.io/node-stage-secret-namespace" = namespace;
          "fsName" = "cephfs";
          "pool" = "cephfs_data";
          "clusterID" = "cephfs";
        };
        description = "Additional parameters for CephFS StorageClass";
      };
    };

    filesystem = {
      name = mkOption {
        type = types.str;
        default = "cephfs";
        description = "CephFS filesystem name";
      };

      dataPool = mkOption {
        type = types.str;
        default = "cephfs_data";
        description = "Ceph pool for data";
      };

      metadataPool = mkOption {
        type = types.str;
        default = "cephfs_metadata";
        description = "Ceph pool for metadata";
      };
    };

    cluster = {
      id = mkOption {
        type = types.str;
        default = "cephfs";
        description = "Ceph cluster ID";
      };

      monitors = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of Ceph monitor addresses";
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
        default = "cephfs";
        description = "Path to secrets within SOPS file";
      };
    };

    secrets = {
      adminID = mkOption {
        type = types.str;
        default = "admin";
        description = "Ceph admin user ID for CSI operations";
      };

      adminKey = mkOption {
        type = types.str;
        description = "Ceph admin key for CSI operations";
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
        default = {};
        description = "Affinity rules for CSI pods";
      };

      tolerations = mkOption {
        type = types.listOf types.attrs;
        default = [];
        description = "Tolerations for CSI pods";
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
  };

  config = lib.mkIf cfg.enable {
    applications.cephfs-csi = {
      inherit namespace;
      createNamespace = true;

      helm.releases.cephfs-csi = {
        chart = "${../../../../charts/cephfs-csi}";

        values = {
          # Basic configuration
          fullnameOverride = "cephfs-csi";
          namespace = namespace;

          # CSI configuration
          driver = {
            name = "cephfs.csi.ceph.com";
            image = "quay.io/cephcsi/cephcsi:${cfg.version}";
          };

          # Cluster configuration
          csiConfig =
            if cfg.sops.enable then
              let
                sopsData = decryptSOPS cfg.sops.secretsFile cfg.sops.secretsPath;
              in
              [
                {
                  clusterID = cfg.cluster.id;
                  monitors = sopsData.monitors;
                }
              ]
            else
              [
                {
                  clusterID = cfg.cluster.id;
                  monitors = cfg.cluster.monitors;
                }
              ];

          # Secret management
          secret =
            if cfg.sops.enable then
              let
                sopsData = decryptSOPS cfg.sops.secretsFile cfg.sops.secretsPath;
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

          # Provisioner configuration
          provisioner = {
            replicaCount = cfg.deployment.replicaCount;
            name = "csi-provisioner";
            image = "registry.k8s.io/sig-storage/csi-provisioner:${cfg.version}";
            resources = cfg.deployment.resources;
            affinity = cfg.deployment.affinity;
            tolerations = cfg.deployment.tolerations;
          };

          # Node plugin configuration
          nodePlugin = {
            replicaCount = cfg.deployment.replicaCount;
            name = "csi-nodeplugin";
            resources = cfg.deployment.resources;
            affinity = cfg.deployment.affinity;
            tolerations = cfg.deployment.tolerations;
          };

          # StorageClass configuration
          storageClass = {
            create = true;
            name = cfg.storageClass.name;
            reclaimPolicy = cfg.storageClass.reclaimPolicy;
            allowVolumeExpansion = cfg.storageClass.allowVolumeExpansion;
            volumeBindingMode = cfg.storageClass.volumeBindingMode;
            parameters = cfg.storageClass.parameters // {
              "fsName" = cfg.filesystem.name;
              "pool" = cfg.filesystem.dataPool;
              "clusterID" = cfg.cluster.id;
            };
          };

          # RBAC configuration
          rbac = {
            create = true;
          };

          # Service accounts
          serviceAccounts = {
            provisioner = {
              create = true;
              name = "cephfs-csi-provisioner";
            };
            nodeplugin = {
              create = true;
              name = "cephfs-csi-nodeplugin";
            };
          };

          # Metrics configuration
          metrics = lib.mkIf cfg.metrics.enable {
            enabled = true;
            port = cfg.metrics.port;
            serviceMonitor = {
              enabled = true;
              interval = "30s";
              scrapeTimeout = "10s";
            };
          };

          # Topology configuration
          topology = lib.mkIf cfg.topology.enable {
            enabled = true;
            domainLabels = cfg.topology.domainLabels;
          };

          # Additional security context
          securityContext = {
            privileged = true;
            runAsUser = 0;
            allowPrivilegeEscalation = true;
          };

          # Enable snapshots
          snapshotter = {
            enabled = true;
            image = "registry.k8s.io/sig-storage/csi-snapshotter:${cfg.version}";
          };

          # Enable resizer
          resizer = {
            enabled = true;
            image = "registry.k8s.io/sig-storage/csi-resizer:${cfg.version}";
          };
        };
      };

      # Create Kubernetes secret for CephFS
      resources.kubernetesSecrets.cephfs-secret = {
        metadata.name = "cephfs-secret";
        metadata.namespace = namespace;
        stringData =
          if cfg.sops.enable then
            let
              sopsData = decryptSOPS cfg.sops.secretsFile cfg.sops.secretsPath;
            in
            {
              adminID = sopsData.adminID;
              adminKey = sopsData.adminKey;
              userID = sopsData.adminID;
              userKey = sopsData.adminKey;
            }
          else
            {
              adminID = cfg.secrets.adminID;
              adminKey = cfg.secrets.adminKey;
              userID = cfg.secrets.adminID;
              userKey = cfg.secrets.adminKey;
            };
      };

      # Network policies for security
      resources.networkPolicies.cephfs-csi.spec = {
        podSelector.matchLabels."app" = "cephfs-csi";
        policyTypes = [ "Ingress" "Egress" ];
        ingress = [
          {
            from = [
              {
                namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "default";
              }
            ];
            ports = [
              {
                protocol = "TCP";
                port = 9089;
              }
              {
                protocol = "TCP";
                port = 9088;
              }
            ];
          }
        ];
        egress = [
          {
            to = [
              {
                ipBlock.cidr = "10.0.0.0/8";
              }
            ];
            ports = [
              {
                protocol = "TCP";
                port = 6789;
              }
              {
                protocol = "TCP";
                port = 3300;
              }
            ];
          }
        ];
      };
    };
  };
}