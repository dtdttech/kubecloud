{ lib, config, ... }:

let
  cfg = config.storage.providers.longhorn;
in
{
  options.storage.providers.longhorn = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Longhorn distributed storage system";
    };

    version = mkOption {
      type = types.str;
      default = "v1.7.1";
      description = "Longhorn version to deploy";
    };

    storageClass = {
      name = mkOption {
        type = types.str;
        default = "longhorn";
        description = "Name of the Longhorn storage class";
      };

      isDefault = mkOption {
        type = types.bool;
        default = false;
        description = "Set this storage class as the default";
      };

      numberOfReplicas = mkOption {
        type = types.int;
        default = 3;
        description = "Number of replicas for Longhorn volumes";
      };

      reclaimPolicy = mkOption {
        type = types.enum [
          "Delete"
          "Retain"
        ];
        default = "Delete";
        description = "Reclaim policy for Longhorn volumes";
      };

      allowVolumeExpansion = mkOption {
        type = types.bool;
        default = true;
        description = "Allow volume expansion";
      };
    };

    settings = {
      defaultDataPath = mkOption {
        type = types.str;
        default = "/var/lib/longhorn/";
        description = "Default data path for Longhorn on each node";
      };

      replicaSoftAntiAffinity = mkOption {
        type = types.bool;
        default = false;
        description = "Enable replica soft anti-affinity";
      };

      storageOverProvisioningPercentage = mkOption {
        type = types.int;
        default = 100;
        description = "Storage over-provisioning percentage";
      };

      storageMinimalAvailablePercentage = mkOption {
        type = types.int;
        default = 25;
        description = "Minimal available storage percentage";
      };

      upgradeChecker = mkOption {
        type = types.bool;
        default = false;
        description = "Enable upgrade checker";
      };

      defaultReplicaCount = mkOption {
        type = types.int;
        default = 3;
        description = "Default replica count for new volumes";
      };
    };

    ui = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Longhorn UI";
      };

      domain = mkOption {
        type = types.str;
        default = "longhorn.local";
        description = "Domain for Longhorn UI";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.longhorn-system = {
      namespace = "longhorn-system";
      createNamespace = true;

      resources = {
        # Longhorn Manager DaemonSet
        daemonSets.longhorn-manager = {
          spec = {
            selector.matchLabels = {
              app = "longhorn-manager";
            };
            template = {
              metadata.labels = {
                app = "longhorn-manager";
              };
              spec = {
                serviceAccountName = "longhorn-service-account";
                containers = [
                  {
                    name = "longhorn-manager";
                    image = "longhornio/longhorn-manager:${cfg.version}";
                    imagePullPolicy = "IfNotPresent";
                    securityContext = {
                      privileged = true;
                    };
                    command = [
                      "longhorn-manager"
                      "-d"
                      "daemon"
                      "--engine-image"
                      "longhornio/longhorn-engine:${cfg.version}"
                      "--instance-manager-image"
                      "longhornio/longhorn-instance-manager:${cfg.version}"
                      "--share-manager-image"
                      "longhornio/longhorn-share-manager:${cfg.version}"
                      "--backing-image-manager-image"
                      "longhornio/backing-image-manager:${cfg.version}"
                      "--support-bundle-manager-image"
                      "longhornio/support-bundle-kit:${cfg.version}"
                      "--manager-image"
                      "longhornio/longhorn-manager:${cfg.version}"
                    ];
                    ports = [
                      {
                        containerPort = 9500;
                        name = "manager";
                      }
                    ];
                    env = [
                      {
                        name = "POD_NAMESPACE";
                        valueFrom.fieldRef.fieldPath = "metadata.namespace";
                      }
                      {
                        name = "POD_IP";
                        valueFrom.fieldRef.fieldPath = "status.podIP";
                      }
                      {
                        name = "NODE_NAME";
                        valueFrom.fieldRef.fieldPath = "spec.nodeName";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "dev";
                        mountPath = "/host/dev/";
                      }
                      {
                        name = "proc";
                        mountPath = "/host/proc/";
                      }
                      {
                        name = "longhorn";
                        mountPath = "/var/lib/longhorn/";
                        mountPropagation = "Bidirectional";
                      }
                    ];
                    resources = {
                      requests = {
                        cpu = "250m";
                        memory = "512Mi";
                      };
                      limits = {
                        cpu = "1000m";
                        memory = "1Gi";
                      };
                    };
                  }
                ];
                hostNetwork = true;
                hostPID = true;
                tolerations = [
                  {
                    key = "kubevirt.io/drain";
                    operator = "Exists";
                    effect = "NoSchedule";
                  }
                ];
                volumes = [
                  {
                    name = "dev";
                    hostPath.path = "/dev/";
                  }
                  {
                    name = "proc";
                    hostPath.path = "/proc/";
                  }
                  {
                    name = "longhorn";
                    hostPath.path = cfg.settings.defaultDataPath;
                  }
                ];
              };
            };
          };
        };

        # Longhorn Driver DaemonSet
        daemonSets.longhorn-csi-plugin = {
          spec = {
            selector.matchLabels = {
              app = "longhorn-csi-plugin";
            };
            template = {
              metadata.labels = {
                app = "longhorn-csi-plugin";
              };
              spec = {
                serviceAccountName = "longhorn-service-account";
                containers = [
                  {
                    name = "driver-registrar";
                    image = "registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.11.1";
                    args = [
                      "--v=2"
                      "--csi-address=$(ADDRESS)"
                      "--kubelet-registration-path=$(DRIVER_REG_SOCK_PATH)"
                    ];
                    env = [
                      {
                        name = "ADDRESS";
                        value = "/csi/csi.sock";
                      }
                      {
                        name = "DRIVER_REG_SOCK_PATH";
                        value = "/var/lib/kubelet/plugins/driver.longhorn.io/csi.sock";
                      }
                      {
                        name = "KUBE_NODE_NAME";
                        valueFrom.fieldRef.fieldPath = "spec.nodeName";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/csi/";
                      }
                      {
                        name = "registration-dir";
                        mountPath = "/registration";
                      }
                    ];
                  }
                  {
                    name = "longhorn-csi-plugin";
                    image = "longhornio/longhorn-manager:${cfg.version}";
                    args = [
                      "--nodeid=$(NODE_ID)"
                      "--endpoint=$(CSI_ENDPOINT)"
                      "--drivername=driver.longhorn.io"
                    ];
                    env = [
                      {
                        name = "NODE_ID";
                        valueFrom.fieldRef.fieldPath = "spec.nodeName";
                      }
                      {
                        name = "CSI_ENDPOINT";
                        value = "unix:///csi/csi.sock";
                      }
                    ];
                    securityContext = {
                      privileged = true;
                      capabilities.add = [ "SYS_ADMIN" ];
                      allowPrivilegeEscalation = true;
                    };
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/csi/";
                      }
                      {
                        name = "pods-mount-dir";
                        mountPath = "/var/lib/kubelet/";
                        mountPropagation = "Bidirectional";
                      }
                      {
                        name = "host-dev";
                        mountPath = "/dev";
                      }
                      {
                        name = "host-sys";
                        mountPath = "/sys";
                      }
                      {
                        name = "lib-modules";
                        mountPath = "/lib/modules";
                        readOnly = true;
                      }
                      {
                        name = "longhorn";
                        mountPath = "/var/lib/longhorn/";
                        mountPropagation = "Bidirectional";
                      }
                    ];
                  }
                ];
                hostNetwork = true;
                hostPID = true;
                tolerations = [
                  {
                    key = "kubevirt.io/drain";
                    operator = "Exists";
                    effect = "NoSchedule";
                  }
                ];
                volumes = [
                  {
                    name = "socket-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/plugins/driver.longhorn.io";
                      type = "DirectoryOrCreate";
                    };
                  }
                  {
                    name = "registration-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/plugins_registry/";
                      type = "Directory";
                    };
                  }
                  {
                    name = "pods-mount-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/";
                      type = "Directory";
                    };
                  }
                  {
                    name = "host-dev";
                    hostPath.path = "/dev";
                  }
                  {
                    name = "host-sys";
                    hostPath.path = "/sys";
                  }
                  {
                    name = "lib-modules";
                    hostPath.path = "/lib/modules";
                  }
                  {
                    name = "longhorn";
                    hostPath.path = cfg.settings.defaultDataPath;
                  }
                ];
              };
            };
          };
        };

        # Longhorn CSI Controller Deployment
        deployments.csi-provisioner = {
          spec = {
            replicas = 3;
            selector.matchLabels = {
              app = "csi-provisioner";
            };
            template = {
              metadata.labels = {
                app = "csi-provisioner";
              };
              spec = {
                serviceAccountName = "longhorn-service-account";
                containers = [
                  {
                    name = "csi-provisioner";
                    image = "registry.k8s.io/sig-storage/csi-provisioner:v5.0.1";
                    args = [
                      "--volume-name-prefix=longhorn"
                      "--volume-name-uuid-length=16"
                      "--csi-address=$(ADDRESS)"
                      "--v=2"
                      "--feature-gates=Topology=true"
                      "--strict-topology"
                    ];
                    env = [
                      {
                        name = "ADDRESS";
                        value = "/var/lib/csi/sockets/pluginproxy/csi.sock";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/var/lib/csi/sockets/pluginproxy/";
                      }
                    ];
                  }
                  {
                    name = "csi-attacher";
                    image = "registry.k8s.io/sig-storage/csi-attacher:v4.6.1";
                    args = [
                      "--v=2"
                      "--csi-address=$(ADDRESS)"
                    ];
                    env = [
                      {
                        name = "ADDRESS";
                        value = "/var/lib/csi/sockets/pluginproxy/csi.sock";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/var/lib/csi/sockets/pluginproxy/";
                      }
                    ];
                  }
                  {
                    name = "csi-resizer";
                    image = "registry.k8s.io/sig-storage/csi-resizer:v1.11.1";
                    args = [
                      "--v=2"
                      "--csi-address=$(ADDRESS)"
                    ];
                    env = [
                      {
                        name = "ADDRESS";
                        value = "/var/lib/csi/sockets/pluginproxy/csi.sock";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/var/lib/csi/sockets/pluginproxy/";
                      }
                    ];
                  }
                  {
                    name = "longhorn-csi-plugin";
                    image = "longhornio/longhorn-manager:${cfg.version}";
                    args = [
                      "--nodeid=$(NODE_ID)"
                      "--endpoint=$(CSI_ENDPOINT)"
                      "--drivername=driver.longhorn.io"
                    ];
                    env = [
                      {
                        name = "NODE_ID";
                        valueFrom.fieldRef.fieldPath = "spec.nodeName";
                      }
                      {
                        name = "CSI_ENDPOINT";
                        value = "unix:///var/lib/csi/sockets/pluginproxy/csi.sock";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/var/lib/csi/sockets/pluginproxy/";
                      }
                    ];
                  }
                ];
                volumes = [
                  {
                    name = "socket-dir";
                    emptyDir = { };
                  }
                ];
              };
            };
          };
        };

        # Service Account and RBAC
        serviceAccounts.longhorn-service-account = { };

        clusterRoles.longhorn-role = {
          rules = [
            {
              apiGroups = [ "apiextensions.k8s.io" ];
              resources = [ "customresourcedefinitions" ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "longhorn.io" ];
              resources = [ "*" ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "" ];
              resources = [
                "pods"
                "events"
                "persistentvolumes"
                "persistentvolumeclaims"
                "persistentvolumeclaims/status"
                "nodes"
                "proxy/nodes"
                "pods/log"
                "secrets"
                "services"
                "endpoints"
                "configmaps"
              ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "apps" ];
              resources = [
                "daemonsets"
                "statefulsets"
                "replicasets"
                "deployments"
              ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "batch" ];
              resources = [
                "jobs"
                "cronjobs"
              ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "storage.k8s.io" ];
              resources = [
                "storageclasses"
                "volumeattachments"
                "volumeattachments/status"
                "csinodes"
                "csidrivers"
              ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "snapshot.storage.k8s.io" ];
              resources = [
                "volumesnapshotclasses"
                "volumesnapshots"
                "volumesnapshotcontents"
                "volumesnapshotcontents/status"
              ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "coordination.k8s.io" ];
              resources = [ "leases" ];
              verbs = [ "*" ];
            }
            {
              apiGroups = [ "metrics.k8s.io" ];
              resources = [
                "pods"
                "nodes"
              ];
              verbs = [
                "get"
                "list"
              ];
            }
            {
              apiGroups = [ "" ];
              resources = [ "namespaces" ];
              verbs = [
                "get"
                "list"
              ];
            }
          ];
        };

        clusterRoleBindings.longhorn-bind = {
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "longhorn-role";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "longhorn-service-account";
              namespace = "longhorn-system";
            }
          ];
        };

        # Longhorn Manager Service
        services.longhorn-backend = {
          spec = {
            type = "ClusterIP";
            sessionAffinity = "ClientIP";
            selector.app = "longhorn-manager";
            ports = [
              {
                name = "manager";
                port = 9500;
                targetPort = "manager";
              }
            ];
          };
        };

        # Storage Class
        storageClasses.${cfg.storageClass.name} = {
          provisioner = "driver.longhorn.io";
          allowVolumeExpansion = cfg.storageClass.allowVolumeExpansion;
          reclaimPolicy = cfg.storageClass.reclaimPolicy;
          volumeBindingMode = "Immediate";
          parameters = {
            numberOfReplicas = toString cfg.storageClass.numberOfReplicas;
            staleReplicaTimeout = "2880";
            fromBackup = "";
            fsType = "ext4";
          };
          metadata = lib.mkIf cfg.storageClass.isDefault {
            annotations."storageclass.kubernetes.io/is-default-class" = "true";
          };
        };

        # Longhorn UI
        deployments.longhorn-ui = lib.mkIf cfg.ui.enable {
          spec = {
            replicas = 2;
            selector.matchLabels = {
              app = "longhorn-ui";
            };
            template = {
              metadata.labels = {
                app = "longhorn-ui";
              };
              spec = {
                containers = [
                  {
                    name = "longhorn-ui";
                    image = "longhornio/longhorn-ui:${cfg.version}";
                    imagePullPolicy = "IfNotPresent";
                    securityContext = {
                      runAsUser = 1000;
                      runAsGroup = 1000;
                      runAsNonRoot = true;
                    };
                    ports = [
                      {
                        containerPort = 8000;
                        name = "http";
                      }
                    ];
                    env = [
                      {
                        name = "LONGHORN_MANAGER_IP";
                        value = "http://longhorn-backend:9500";
                      }
                    ];
                    resources = {
                      requests = {
                        cpu = "100m";
                        memory = "64Mi";
                      };
                      limits = {
                        cpu = "200m";
                        memory = "128Mi";
                      };
                    };
                  }
                ];
              };
            };
          };
        };

        services.longhorn-frontend = lib.mkIf cfg.ui.enable {
          spec = {
            type = "ClusterIP";
            selector.app = "longhorn-ui";
            ports = [
              {
                name = "http";
                port = 80;
                targetPort = 8000;
              }
            ];
          };
        };

        # Ingress for Longhorn UI
        ingresses.longhorn-ui = lib.mkIf cfg.ui.enable {
          metadata.annotations = {
            "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true";
          };
          spec = {
            ingressClassName = "nginx";
            tls = [
              {
                secretName = "longhorn-ui-tls";
                hosts = [ cfg.ui.domain ];
              }
            ];
            rules = [
              {
                host = cfg.ui.domain;
                http.paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend.service = {
                      name = "longhorn-frontend";
                      port.number = 80;
                    };
                  }
                ];
              }
            ];
          };
        };
      };
    };
  };
}
