{ lib, config, ... }:

let
  cfg = config.storage.providers.local;
in
{
  options.storage.providers.local = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable local storage provider (local-path-provisioner)";
    };

    storageClass = {
      name = mkOption {
        type = types.str;
        default = "local-path";
        description = "Name of the local storage class";
      };

      isDefault = mkOption {
        type = types.bool;
        default = false;
        description = "Set this storage class as the default";
      };

      reclaimPolicy = mkOption {
        type = types.enum [
          "Delete"
          "Retain"
        ];
        default = "Delete";
        description = "Reclaim policy for local volumes";
      };

      volumeBindingMode = mkOption {
        type = types.enum [
          "Immediate"
          "WaitForFirstConsumer"
        ];
        default = "WaitForFirstConsumer";
        description = "Volume binding mode";
      };
    };

    nodePathMap = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        "worker-1" = "/opt/local-path-provisioner";
        "worker-2" = "/mnt/storage";
      };
      description = "Node-specific storage paths for local volumes";
    };

    config = mkOption {
      type = types.attrs;
      default = {
        nodePathMap = cfg.nodePathMap;
        sharedFileSystemPath = "/opt/local-path-provisioner";
      };
      description = "Local path provisioner configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    applications.local-storage = {
      namespace = "local-path-storage";
      createNamespace = true;

      resources = {
        # Local Path Provisioner Configuration
        configMaps.local-path-config = {
          data = {
            "config.json" = builtins.toJSON cfg.config;
            "setup" = ''
              #!/bin/sh
              set -eu
              mkdir -m 0777 -p "$VOL_DIR"
            '';
            "teardown" = ''
              #!/bin/sh
              set -eu
              rm -rf "$VOL_DIR"
            '';
          };
        };

        # ServiceAccount for local-path-provisioner
        serviceAccounts.local-path-provisioner-service-account = { };

        # ClusterRole for local-path-provisioner
        clusterRoles.local-path-provisioner-role = {
          rules = [
            {
              apiGroups = [ "" ];
              resources = [
                "nodes"
                "persistentvolumeclaims"
                "configmaps"
              ];
              verbs = [
                "get"
                "list"
                "watch"
              ];
            }
            {
              apiGroups = [ "" ];
              resources = [
                "endpoints"
                "persistentvolumes"
                "pods"
              ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "" ];
              resources = [ "events" ];
              verbs = [
                "create"
                "patch"
              ];
            }
            {
              apiGroups = [ "storage.k8s.io" ];
              resources = [ "storageclasses" ];
              verbs = [
                "get"
                "list"
                "watch"
              ];
            }
          ];
        };

        # ClusterRoleBinding
        clusterRoleBindings.local-path-provisioner-bind = {
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "local-path-provisioner-role";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "local-path-provisioner-service-account";
              namespace = "local-path-storage";
            }
          ];
        };

        # Local Path Provisioner Deployment
        deployments.local-path-provisioner = {
          spec = {
            replicas = 1;
            selector.matchLabels = {
              app = "local-path-provisioner";
            };
            template = {
              metadata.labels = {
                app = "local-path-provisioner";
              };
              spec = {
                serviceAccountName = "local-path-provisioner-service-account";
                containers = [
                  {
                    name = "local-path-provisioner";
                    image = "rancher/local-path-provisioner:v0.0.28";
                    imagePullPolicy = "IfNotPresent";
                    command = [
                      "local-path-provisioner"
                      "--debug"
                      "start"
                      "--config"
                      "/etc/config/config.json"
                    ];
                    volumeMounts = [
                      {
                        name = "config-volume";
                        mountPath = "/etc/config/";
                      }
                    ];
                    env = [
                      {
                        name = "POD_NAMESPACE";
                        valueFrom.fieldRef.fieldPath = "metadata.namespace";
                      }
                    ];
                    resources = {
                      requests = {
                        cpu = "100m";
                        memory = "128Mi";
                      };
                      limits = {
                        cpu = "200m";
                        memory = "256Mi";
                      };
                    };
                  }
                ];
                volumes = [
                  {
                    name = "config-volume";
                    configMap.name = "local-path-config";
                  }
                ];
              };
            };
          };
        };

        # Storage Class
        storageClasses.${cfg.storageClass.name} = {
          provisioner = "rancher.io/local-path";
          volumeBindingMode = cfg.storageClass.volumeBindingMode;
          reclaimPolicy = cfg.storageClass.reclaimPolicy;
          metadata = lib.mkIf cfg.storageClass.isDefault {
            annotations."storageclass.kubernetes.io/is-default-class" = "true";
          };
        };
      };
    };
  };
}
