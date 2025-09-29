{
  lib,
  config,
  ...
}:

let
  cfg = config.networking.etcd;
  
  namespace = "etcd";
in
{
  options.networking.etcd = with lib; {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable etcd for DNS backend storage";
    };
    
    clusterDomain = mkOption {
      type = types.str;
      default = "etcd-cluster";
      description = "Cluster domain name for etcd";
    };
    
    replicas = mkOption {
      type = types.int;
      default = 1;
      description = "Number of etcd replicas";
    };
    
    storage = {
      size = mkOption {
        type = types.str;
        default = "5Gi";
        description = "Storage size for etcd data";
      };
      
      className = mkOption {
        type = types.str;
        default = "ceph-rbd";
        description = "Storage class for etcd persistent volume";
      };
    };
    
    resources = {
      requests = {
        cpu = mkOption {
          type = types.str;
          default = "100m";
          description = "CPU request for etcd";
        };
        
        memory = mkOption {
          type = types.str;
          default = "128Mi";
          description = "Memory request for etcd";
        };
      };
      
      limits = {
        cpu = mkOption {
          type = types.str;
          default = "500m";
          description = "CPU limit for etcd";
        };
        
        memory = mkOption {
          type = types.str;
          default = "512Mi";
          description = "Memory limit for etcd";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.etcd = {
      inherit namespace;
      createNamespace = true;

      resources = {
        # etcd StatefulSet
        statefulSets.etcd = {
          spec = {
            serviceName = "etcd";
            replicas = cfg.replicas;
            selector.matchLabels = {
              app = "etcd";
            };
            template = {
              metadata.labels = {
                app = "etcd";
              };
              spec = {
                containers = [
                  {
                    name = "etcd";
                    image = "quay.io/coreos/etcd:v3.5.9";
                    ports = [
                      {
                        name = "client";
                        containerPort = 2379;
                      }
                      {
                        name = "peer";
                        containerPort = 2380;
                      }
                    ];
                    env = [
                      {
                        name = "ETCD_NAME";
                        valueFrom.fieldRef.fieldPath = "metadata.name";
                      }
                      {
                        name = "ETCD_INITIAL_ADVERTISE_PEER_URLS";
                        value = "http://$(ETCD_NAME).etcd:2380";
                      }
                      {
                        name = "ETCD_LISTEN_PEER_URLS";
                        value = "http://0.0.0.0:2380";
                      }
                      {
                        name = "ETCD_LISTEN_CLIENT_URLS";
                        value = "http://0.0.0.0:2379";
                      }
                      {
                        name = "ETCD_ADVERTISE_CLIENT_URLS";
                        value = "http://$(ETCD_NAME).etcd:2379";
                      }
                      {
                        name = "ETCD_INITIAL_CLUSTER";
                        value = "etcd-0=http://etcd-0.etcd:2380";
                      }
                      {
                        name = "ETCD_INITIAL_CLUSTER_STATE";
                        value = "new";
                      }
                      {
                        name = "ETCD_INITIAL_CLUSTER_TOKEN";
                        value = "etcd-cluster-1";
                      }
                      {
                        name = "ETCD_DATA_DIR";
                        value = "/var/lib/etcd";
                      }
                    ];
                    volumeMounts = [
                      {
                        name = "data";
                        mountPath = "/var/lib/etcd";
                      }
                    ];
                    resources = {
                      requests = {
                        cpu = cfg.resources.requests.cpu;
                        memory = cfg.resources.requests.memory;
                      };
                      limits = {
                        cpu = cfg.resources.limits.cpu;
                        memory = cfg.resources.limits.memory;
                      };
                    };
                    livenessProbe = {
                      exec.command = [ "/bin/sh" "-c" "etcdctl endpoint health" ];
                      initialDelaySeconds = 30;
                      periodSeconds = 10;
                    };
                    readinessProbe = {
                      exec.command = [ "/bin/sh" "-c" "etcdctl endpoint health" ];
                      initialDelaySeconds = 5;
                      periodSeconds = 5;
                    };
                  }
                ];
              };
            };
            volumeClaimTemplates = [
              {
                metadata.name = "data";
                spec = {
                  accessModes = [ "ReadWriteOnce" ];
                  storageClassName = cfg.storage.className;
                  resources.requests.storage = cfg.storage.size;
                };
              }
            ];
          };
        };

        # etcd Service
        services.etcd = {
          spec = {
            selector = {
              app = "etcd";
            };
            ports = [
              {
                name = "client";
                port = 2379;
                targetPort = 2379;
              }
              {
                name = "peer";
                port = 2380;
                targetPort = 2380;
              }
            ];
            clusterIP = "None"; # Headless service
          };
        };

        # Network policy for etcd
        networkPolicies.etcd.spec = {
          podSelector.matchLabels.app = "etcd";
          policyTypes = [ "Ingress" "Egress" ];
          
          ingress = [
            # Allow external-dns to access etcd
            {
              from = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "external-dns";
                }
              ];
              ports = [
                {
                  protocol = "TCP";
                  port = 2379;
                }
              ];
            }
          ];
          
          egress = [
            # Allow etcd to communicate with peers
            {
              ports = [
                {
                  protocol = "TCP";
                  port = 2380;
                }
              ];
              from = [
                {
                  podSelector.matchLabels.app = "etcd";
                }
              ];
            }
          ];
        };
      };
    };
  };
}