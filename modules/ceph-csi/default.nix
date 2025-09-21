{ lib, config, ... }:

# Import generated CRDs
let
  cephCsiCrds = import ./generated.nix;
in

let
  cfg = config.storage.ceph-csi;

  namespace = "ceph-csi-system";
in
{
  options.storage.ceph-csi = with lib; {
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
          description = "Name of the RBD storage class";
        };

        pool = mkOption {
          type = types.str;
          default = "kubernetes";
          description = "Ceph RBD pool name";
        };

        imageFeatures = mkOption {
          type = types.str;
          default = "layering";
          description = "RBD image features";
        };

        reclaimPolicy = mkOption {
          type = types.enum [ "Delete" "Retain" ];
          default = "Delete";
          description = "Volume reclaim policy";
        };

        allowVolumeExpansion = mkOption {
          type = types.bool;
          default = true;
          description = "Allow volume expansion";
        };
      };
    };

    cephfs = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable CephFS (shared filesystem) support";
      };

      storageClass = {
        name = mkOption {
          type = types.str;
          default = "ceph-cephfs";
          description = "Name of the CephFS storage class";
        };

        fsName = mkOption {
          type = types.str;
          default = "cephfs";
          description = "CephFS filesystem name";
        };

        reclaimPolicy = mkOption {
          type = types.enum [ "Delete" "Retain" ];
          default = "Delete";
          description = "Volume reclaim policy";
        };

        allowVolumeExpansion = mkOption {
          type = types.bool;
          default = true;
          description = "Allow volume expansion";
        };
      };
    };

    cluster = {
      clusterID = mkOption {
        type = types.str;
        default = "ceph-cluster";
        description = "Unique identifier for the Ceph cluster";
      };

      monitors = mkOption {
        type = types.listOf types.str;
        default = [ "10.0.0.1:6789" "10.0.0.2:6789" "10.0.0.3:6789" ];
        description = "List of Ceph monitor addresses";
      };
    };

    secrets = {
      userID = mkOption {
        type = types.str;
        default = "admin";
        description = "Ceph user ID for authentication";
      };

      userKey = mkOption {
        type = types.str;
        default = "AQBLvLZjJc5cERAAm+8qIW8jYy9bL2UfQ1Q6Jw==";
        description = "Ceph user key for authentication";
      };

      adminID = mkOption {
        type = types.str;
        default = "admin";
        description = "Ceph admin user ID";
      };

      adminKey = mkOption {
        type = types.str;
        default = "AQBLvLZjJc5cERAAm+8qIW8jYy9bL2UfQ1Q6Jw==";
        description = "Ceph admin user key";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.ceph-csi = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # Ceph CSI Config Map
        configMaps.ceph-csi-config = {
          data = {
            "config.json" = builtins.toJSON [
              {
                clusterID = cfg.cluster.clusterID;
                monitors = cfg.cluster.monitors;
              }
            ];
          };
        };

        # Ceph CSI Encryption Config Map
        configMaps.ceph-csi-encryption-kms-config = {
          data = {
            "config.json" = builtins.toJSON {};
          };
        };

        # RBD Secret
        secrets.csi-rbd-secret = lib.mkIf cfg.rbd.enable {
          stringData = {
            userID = cfg.secrets.userID;
            userKey = cfg.secrets.userKey;
          };
        };

        # CephFS Secret
        secrets.csi-cephfs-secret = lib.mkIf cfg.cephfs.enable {
          stringData = {
            adminID = cfg.secrets.adminID;
            adminKey = cfg.secrets.adminKey;
          };
        };

        # RBD Provisioner RBAC
        serviceAccounts.rbd-csi-provisioner = lib.mkIf cfg.rbd.enable {};

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

        clusterRoleBindings.rbd-csi-provisioner-role = lib.mkIf cfg.rbd.enable {
          subjects = [{
            kind = "ServiceAccount";
            name = "rbd-csi-provisioner";
            namespace = namespace;
          }];
          roleRef = {
            kind = "ClusterRole";
            name = "rbd-external-provisioner-runner";
            apiGroup = "rbac.authorization.k8s.io";
          };
        };

        # RBD Node Plugin RBAC
        serviceAccounts.rbd-csi-nodeplugin = lib.mkIf cfg.rbd.enable {};

        clusterRoles.rbd-csi-nodeplugin = lib.mkIf cfg.rbd.enable {
          rules = [
            {
              apiGroups = [""];
              resources = ["nodes"];
              verbs = ["get"];
            }
          ];
        };

        clusterRoleBindings.rbd-csi-nodeplugin = lib.mkIf cfg.rbd.enable {
          subjects = [{
            kind = "ServiceAccount";
            name = "rbd-csi-nodeplugin";
            namespace = namespace;
          }];
          roleRef = {
            kind = "ClusterRole";
            name = "rbd-csi-nodeplugin";
            apiGroup = "rbac.authorization.k8s.io";
          };
        };

        # RBD Provisioner Deployment
        deployments.csi-rbdplugin-provisioner = lib.mkIf cfg.rbd.enable {
          spec = {
            replicas = 3;
            selector.matchLabels = {
              app = "csi-rbdplugin-provisioner";
            };
            template = {
              metadata.labels = {
                app = "csi-rbdplugin-provisioner";
              };
              spec = {
                serviceAccountName = "rbd-csi-provisioner";
                containers = [
                  {
                    name = "csi-provisioner";
                    image = "registry.k8s.io/sig-storage/csi-provisioner:v5.0.1";
                    args = [
                      "--csi-address=$(ADDRESS)"
                      "--v=2"
                      "--timeout=150s"
                      "--retry-interval-start=500ms"
                      "--leader-election=true"
                      "--default-fstype=ext4"
                      "--extra-create-metadata=true"
                    ];
                    env = [{
                      name = "ADDRESS";
                      value = "unix:///csi/csi-provisioner.sock";
                    }];
                    volumeMounts = [{
                      name = "socket-dir";
                      mountPath = "/csi";
                    }];
                  }
                  {
                    name = "csi-resizer";
                    image = "registry.k8s.io/sig-storage/csi-resizer:v1.12.0";
                    args = [
                      "--csi-address=$(ADDRESS)"
                      "--v=2"
                      "--timeout=150s"
                      "--leader-election"
                      "--retry-interval-start=500ms"
                      "--handle-volume-inuse-error=false"
                      "--feature-gates=RecoverVolumeExpansionFailure=true"
                    ];
                    env = [{
                      name = "ADDRESS";
                      value = "unix:///csi/csi-provisioner.sock";
                    }];
                    volumeMounts = [{
                      name = "socket-dir";
                      mountPath = "/csi";
                    }];
                  }
                  {
                    name = "csi-attacher";
                    image = "registry.k8s.io/sig-storage/csi-attacher:v4.7.0";
                    args = [
                      "--v=2"
                      "--csi-address=$(ADDRESS)"
                      "--timeout=150s"
                      "--leader-election=true"
                      "--retry-interval-start=500ms"
                    ];
                    env = [{
                      name = "ADDRESS";
                      value = "unix:///csi/csi-provisioner.sock";
                    }];
                    volumeMounts = [{
                      name = "socket-dir";
                      mountPath = "/csi";
                    }];
                  }
                  {
                    name = "csi-snapshotter";
                    image = "registry.k8s.io/sig-storage/csi-snapshotter:v8.1.0";
                    args = [
                      "--csi-address=$(ADDRESS)"
                      "--v=2"
                      "--timeout=150s"
                      "--leader-election=true"
                      "--extra-create-metadata=true"
                    ];
                    env = [{
                      name = "ADDRESS";
                      value = "unix:///csi/csi-provisioner.sock";
                    }];
                    volumeMounts = [{
                      name = "socket-dir";
                      mountPath = "/csi";
                    }];
                  }
                  {
                    name = "csi-rbdplugin";
                    image = "quay.io/cephcsi/cephcsi:${cfg.version}";
                    args = [
                      "--nodeid=$(NODE_ID)"
                      "--type=rbd"
                      "--controllerserver=true"
                      "--endpoint=$(CSI_ENDPOINT)"
                      "--csi-addons-endpoint=$(CSI_ADDONS_ENDPOINT)"
                      "--v=2"
                      "--drivername=rbd.csi.ceph.com"
                      "--pidlimit=-1"
                      "--rbdhardmaxclonedepth=8"
                      "--rbdsoftmaxclonedepth=4"
                      "--enableprofiling=false"
                    ];
                    env = [
                      {
                        name = "NODE_ID";
                        valueFrom.fieldRef.fieldPath = "spec.nodeName";
                      }
                      {
                        name = "CSI_ENDPOINT";
                        value = "unix:///csi/csi-provisioner.sock";
                      }
                      {
                        name = "CSI_ADDONS_ENDPOINT";
                        value = "unix:///csi/csi-addons.sock";
                      }
                      {
                        name = "POD_IP";
                        valueFrom.fieldRef.fieldPath = "status.podIP";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "socket-dir";
                        mountPath = "/csi";
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
                        name = "ceph-csi-config";
                        mountPath = "/etc/ceph-csi-config/";
                      }
                      {
                        name = "ceph-csi-encryption-kms-config";
                        mountPath = "/etc/ceph-csi-encryption-kms-config/";
                      }
                      {
                        name = "keys-tmp-dir";
                        mountPath = "/tmp/csi/keys";
                      }
                      {
                        name = "ceph-config";
                        mountPath = "/etc/ceph/";
                      }
                    ];
                  }
                  {
                    name = "liveness-prometheus";
                    image = "quay.io/cephcsi/cephcsi:${cfg.version}";
                    args = [
                      "--type=liveness"
                      "--endpoint=$(CSI_ENDPOINT)"
                      "--metricsport=8080"
                      "--metricspath=/metrics"
                      "--polltime=60s"
                      "--timeout=3s"
                    ];
                    env = [{
                      name = "CSI_ENDPOINT";
                      value = "unix:///csi/csi-provisioner.sock";
                    }];
                    volumeMounts = [{
                      name = "socket-dir";
                      mountPath = "/csi";
                    }];
                    ports = [{
                      name = "http-metrics";
                      containerPort = 8080;
                      protocol = "TCP";
                    }];
                  }
                ];
                volumes = [
                  {
                    name = "socket-dir";
                    emptyDir = {
                      medium = "Memory";
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
                    name = "ceph-csi-config";
                    configMap.name = "ceph-csi-config";
                  }
                  {
                    name = "ceph-csi-encryption-kms-config";
                    configMap.name = "ceph-csi-encryption-kms-config";
                  }
                  {
                    name = "keys-tmp-dir";
                    emptyDir = {
                      medium = "Memory";
                    };
                  }
                  {
                    name = "ceph-config";
                    emptyDir = {};
                  }
                ];
              };
            };
          };
        };

        # RBD Node Plugin DaemonSet
        daemonSets.csi-rbdplugin = lib.mkIf cfg.rbd.enable {
          spec = {
            selector.matchLabels = {
              app = "csi-rbdplugin";
            };
            template = {
              metadata.labels = {
                app = "csi-rbdplugin";
              };
              spec = {
                serviceAccountName = "rbd-csi-nodeplugin";
                hostNetwork = true;
                hostPID = true;
                priorityClassName = "system-node-critical";
                containers = [
                  {
                    name = "driver-registrar";
                    image = "registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.12.0";
                    args = [
                      "--v=2"
                      "--csi-address=/csi/csi.sock"
                      "--kubelet-registration-path=/var/lib/kubelet/plugins/rbd.csi.ceph.com/csi.sock"
                    ];
                    env = [{
                      name = "KUBE_NODE_NAME";
                      valueFrom.fieldRef.fieldPath = "spec.nodeName";
                    }];
                    volumeMounts = [
                      {
                        name = "plugin-dir";
                        mountPath = "/csi";
                      }
                      {
                        name = "registration-dir";
                        mountPath = "/registration";
                      }
                    ];
                  }
                  {
                    name = "csi-rbdplugin";
                    image = "quay.io/cephcsi/cephcsi:${cfg.version}";
                    args = [
                      "--nodeid=$(NODE_ID)"
                      "--type=rbd"
                      "--nodeserver=true"
                      "--endpoint=$(CSI_ENDPOINT)"
                      "--csi-addons-endpoint=$(CSI_ADDONS_ENDPOINT)"
                      "--v=2"
                      "--drivername=rbd.csi.ceph.com"
                      "--enableprofiling=false"
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
                      {
                        name = "CSI_ADDONS_ENDPOINT";
                        value = "unix:///csi/csi-addons.sock";
                      }
                      {
                        name = "POD_IP";
                        valueFrom.fieldRef.fieldPath = "status.podIP";
                      }
                    ];
                    securityContext = {
                      privileged = true;
                      capabilities = {
                        add = ["SYS_ADMIN"];
                      };
                      allowPrivilegeEscalation = true;
                    };
                    volumeMounts = [
                      {
                        name = "plugin-dir";
                        mountPath = "/csi";
                      }
                      {
                        name = "csi-plugins-dir";
                        mountPath = "/var/lib/kubelet/plugins";
                        mountPropagation = "Bidirectional";
                      }
                      {
                        name = "pods-mount-dir";
                        mountPath = "/var/lib/kubelet/pods";
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
                        name = "ceph-csi-config";
                        mountPath = "/etc/ceph-csi-config/";
                      }
                      {
                        name = "ceph-csi-encryption-kms-config";
                        mountPath = "/etc/ceph-csi-encryption-kms-config/";
                      }
                      {
                        name = "keys-tmp-dir";
                        mountPath = "/tmp/csi/keys";
                      }
                      {
                        name = "ceph-config";
                        mountPath = "/etc/ceph/";
                      }
                    ];
                  }
                  {
                    name = "liveness-prometheus";
                    image = "quay.io/cephcsi/cephcsi:${cfg.version}";
                    args = [
                      "--type=liveness"
                      "--endpoint=$(CSI_ENDPOINT)"
                      "--metricsport=8080"
                      "--metricspath=/metrics"
                      "--polltime=60s"
                      "--timeout=3s"
                    ];
                    env = [{
                      name = "CSI_ENDPOINT";
                      value = "unix:///csi/csi.sock";
                    }];
                    volumeMounts = [{
                      name = "plugin-dir";
                      mountPath = "/csi";
                    }];
                    ports = [{
                      name = "http-metrics";
                      containerPort = 8080;
                      protocol = "TCP";
                    }];
                  }
                ];
                volumes = [
                  {
                    name = "plugin-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/plugins/rbd.csi.ceph.com";
                      type = "DirectoryOrCreate";
                    };
                  }
                  {
                    name = "csi-plugins-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/plugins";
                      type = "Directory";
                    };
                  }
                  {
                    name = "registration-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/plugins_registry";
                      type = "Directory";
                    };
                  }
                  {
                    name = "pods-mount-dir";
                    hostPath = {
                      path = "/var/lib/kubelet/pods";
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
                    name = "ceph-csi-config";
                    configMap.name = "ceph-csi-config";
                  }
                  {
                    name = "ceph-csi-encryption-kms-config";
                    configMap.name = "ceph-csi-encryption-kms-config";
                  }
                  {
                    name = "keys-tmp-dir";
                    emptyDir = {
                      medium = "Memory";
                    };
                  }
                  {
                    name = "ceph-config";
                    emptyDir = {};
                  }
                ];
              };
            };
          };
        };

        # RBD Storage Class
        storageClasses.${cfg.rbd.storageClass.name} = lib.mkIf cfg.rbd.enable {
          provisioner = "rbd.csi.ceph.com";
          parameters = {
            clusterID = cfg.cluster.clusterID;
            pool = cfg.rbd.storageClass.pool;
            imageFeatures = cfg.rbd.storageClass.imageFeatures;
            "csi.storage.k8s.io/provisioner-secret-name" = "csi-rbd-secret";
            "csi.storage.k8s.io/provisioner-secret-namespace" = namespace;
            "csi.storage.k8s.io/controller-expand-secret-name" = "csi-rbd-secret";
            "csi.storage.k8s.io/controller-expand-secret-namespace" = namespace;
            "csi.storage.k8s.io/node-stage-secret-name" = "csi-rbd-secret";
            "csi.storage.k8s.io/node-stage-secret-namespace" = namespace;
          };
          reclaimPolicy = cfg.rbd.storageClass.reclaimPolicy;
          allowVolumeExpansion = cfg.rbd.storageClass.allowVolumeExpansion;
          mountOptions = [ "discard" ];
        };

        # CephFS Storage Class
        storageClasses.${cfg.cephfs.storageClass.name} = lib.mkIf cfg.cephfs.enable {
          provisioner = "cephfs.csi.ceph.com";
          parameters = {
            clusterID = cfg.cluster.clusterID;
            fsName = cfg.cephfs.storageClass.fsName;
            "csi.storage.k8s.io/provisioner-secret-name" = "csi-cephfs-secret";
            "csi.storage.k8s.io/provisioner-secret-namespace" = namespace;
            "csi.storage.k8s.io/controller-expand-secret-name" = "csi-cephfs-secret";
            "csi.storage.k8s.io/controller-expand-secret-namespace" = namespace;
            "csi.storage.k8s.io/node-stage-secret-name" = "csi-cephfs-secret";
            "csi.storage.k8s.io/node-stage-secret-namespace" = namespace;
          };
          reclaimPolicy = cfg.cephfs.storageClass.reclaimPolicy;
          allowVolumeExpansion = cfg.cephfs.storageClass.allowVolumeExpansion;
        };

      };
    };
  };
}