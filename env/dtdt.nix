{
  nixidy = {
    bootstrapManifest.enable = true;
    target = {
      repository = "https://github.com/dtdttech/kubecloud.git";
      branch = "master";
      rootPath = ".";
    };
    extraFiles."README.md".text = ''
      # Rendered manifests for DTDT Environment
    '';
  };

  networking.domain = "vkm.dtdt.tech";

  # External DNS configuration for delegating to our CoreDNS
  networking.external-dns = {
    enable = true;
    domainFilters = [
      "kube.dtdt.tech"
    ];
    provider = "cloudflare";
    values = {
      # Policy for how to handle DNS records
      policy = "sync";

      # Interval for checking DNS changes
      interval = "1m";

      # Sources to monitor
      sources = [
        "service"
        "ingress"
      ];

      # Don't process annotations on the same resource more than once
      txtOwnerId = "external-dns-dtdt";

      # Log level for debugging
      logLevel = "debug";

      # Run in dry-run mode initially for testing
      dryRun = false;

      # Cloudflare configuration - create NS delegation to our CoreDNS
      cloudflare = {
        email = "admin@dtdt.tech";
        apiTokenSecretRef = {
          name = "cloudflare-api-token";
          key = "api-token";
        };
      };

      # Use Cloudflare API for authentication
      providerName = "cloudflare";

      # Record filtering
      txtPrefix = "external-dns-";

      # Registry configuration
      registry = "txt";
    };
  };

  # Storage configuration for DTDT environment with Longhorn
  storage = {
    defaultProvider = "longhorn"; # Use Longhorn storage for production
    storageClasses = {
      rwo = "longhorn";
      rwx = "longhorn";
      rox = "longhorn";
    };
    providers = {
      local.enable = false; # Disable local storage
      ceph.enable = false; # Disable Ceph
      cephfs.enable = false; # Disable CephFS
      longhorn = {
        enable = true;
        storageClass = {
          isDefault = true;
          numberOfReplicas = 3;
          reclaimPolicy = "Delete";
          allowVolumeExpansion = true;
        };
        settings = {
          defaultDataPath = "/var/lib/longhorn/";
          defaultReplicaCount = 3;
          replicaSoftAntiAffinity = false;
        };
      };
    };
  };

  # Secrets configuration for DTDT environment
  secrets = {
    defaultProvider = "external"; # Use external secrets for production
    defaultSecretStore = "onepassword-store";
  };

  # Certificate management for DTDT
  security.cert-manager = {
    enable = true;
    namespace = "cert-manager";

    clusterIssuers = {
      # Let's Encrypt production issuer
      letsencrypt-prod = {
        type = "acme";
        acme = {
          server = "https://acme-v02.api.letsencrypt.org/directory";
          email = "admin@vkm.dtdt.tech";
          solvers = [
            {
              http01 = {
                ingress = {
                  class = "nginx";
                };
              };
            }
          ];
        };
      };
    };

    values = {
      prometheus = {
        enabled = true;
        servicemonitor = {
          enabled = true;
        };
      };
    };
  };

  # Disable Samba (not configured for DTDT)
  services.samba.enable = false;

  # CoreDNS authoritative DNS server for kube.dtdt.tech
  networking.coredns = {
    enable = true;
    values = {
      # CoreDNS configuration for authoritative DNS
      isClusterService = false; # Don't use as cluster DNS

      # Custom server configuration for kube.dtdt.tech
      servers = [
        {
          port = 53;
          zones = [
            {
              zone = "kube.dtdt.tech.";
              scheme = "";
              useTCP = true;
            }
          ];
          plugins = [
            {
              name = "errors";
            }
            {
              name = "health";
              config = {
                lameduck = "5s";
              };
            }
            {
              name = "ready";
            }
            {
              name = "prometheus";
              config = {
                port = 9153;
              };
            }
            {
              name = "file";
              config = {
                filename = "/etc/coredns/kube.dtdt.tech.zone";
                reload = "30s";
              };
            }
            {
              name = "auto";
              config = {
                directory = "/etc/coredns/auto";
                transferTo = [
                  "kube-public.svc.cluster.local"
                ];
              };
            }
            {
              name = "log";
            }
          ];
        }
        # Fallback server for other zones
        {
          port = 53;
          zones = [
            {
              zone = ".";
              scheme = "";
              useTCP = true;
            }
          ];
          plugins = [
            {
              name = "errors";
            }
            {
              name = "health";
              config = {
                lameduck = "5s";
              };
            }
            {
              name = "forward";
              config = {
                upstream = [
                  "1.1.1.1"
                  "8.8.8.8"
                ];
              };
            }
            {
              name = "cache";
              config = {
                ttl = 30;
              };
            }
            {
              name = "loop";
            }
            {
              name = "reload";
            }
            {
              name = "loadbalance";
            }
          ];
        }
      ];

      # Deployment configuration
      replicaCount = 3; # Run on 3 nodes for redundancy

      # Service configuration
      serviceType = "ClusterIP";
      clusterIP = "10.96.0.53"; # Fixed IP for authoritative DNS

      # Additional service annotations
      serviceAnnotations = {
        "prometheus.io/port" = "9153";
        "prometheus.io/scrape" = "true";
      };

      # Resource limits
      resources = {
        requests = {
          cpu = "100m";
          memory = "70Mi";
        };
        limits = {
          cpu = "1000m";
          memory = "170Mi";
        };
      };

      # Node selector - run on all nodes by default
      nodeSelector = {
        "kubernetes.io/os" = "linux";
      };

      # Tolerations to allow running on all nodes
      tolerations = [
        {
          key = "CriticalAddonsOnly";
          operator = "Exists";
        }
        {
          key = "node-role.kubernetes.io/control-plane";
          effect = "NoSchedule";
        }
        {
          key = "node-role.kubernetes.io/master";
          effect = "NoSchedule";
        }
      ];

      # Anti-affinity to spread pods across nodes
      affinity = {
        podAntiAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100;
              podAffinityTerm = {
                labelSelector = {
                  matchExpressions = [
                    {
                      key = "app.kubernetes.io/name";
                      operator = "In";
                      values = [ "coredns" ];
                    }
                  ];
                };
                topologyKey = "kubernetes.io/hostname";
              };
            }
          ];
        };
      };

      # Zone file configuration (mounted from ConfigMap)
      extraConfigmapMounts = [
        {
          name = "kube-zone-config";
          mountPath = "/etc/coredns";
          configMap = "kube-zone-files";
          readOnly = true;
        }
      ];
    };
  };

  # ConfigMap for DNS zone files
  applications.kube-zone-files = {
    namespace = "coredns";
    resources.configMaps."kube-zone-files" = {
      metadata.name = "kube-zone-files";
      data = {
        "kube.dtdt.tech.zone" = ''
          $ORIGIN kube.dtdt.tech.
          $TTL 300
          @   IN  SOA ns.kube.dtdt.tech. admin.kube.dtdt.tech. (
              2024100101  ; Serial number (YYYYMMDDNN)
              3600        ; Refresh (1 hour)
              1800        ; Retry (30 minutes)
              604800      ; Expire (1 week)
              300         ; Minimum TTL (5 minutes)
          )

          ; Nameservers
          @       IN  NS  ns.kube.dtdt.tech.

          ; A records for nameservers (use any cluster node IP)
          ns      IN  A   10.0.0.1  ; Will be updated with actual node IP

          ; Initial A record for the domain
          @       IN  A   10.0.0.1  ; Will be updated with actual service IP

          ; Wildcard for services
          *.      IN  A   10.0.0.1  ; Will be updated dynamically
        '';
        "setup-node-dns.sh" = ''
          #!/bin/bash

          # This script updates the zone file with node IPs
          # CoreDNS runs on all nodes as a DaemonSet

          # Get the first node IP (any node can respond since DaemonSet)
          NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

          if [[ -n "$NODE_IP" ]]; then
            echo "Updating zone file with node IP: $NODE_IP"
            sed -i "s/10.0.0.1/$NODE_IP/g" /etc/coredns/kube.dtdt.tech.zone
            
            # Reload CoreDNS
            kill -HUP 1
            
            echo "Zone file updated with node IP: $NODE_IP"
            echo "DNS is now available on all cluster nodes via port 53"
          else
            echo "Could not determine node IP"
          fi
        '';
      };
    };
  };

  # DNS zone management sidecar
  applications.dns-zone-manager = {
    namespace = "coredns";
    resources.deployments.dns-zone-manager = {
      spec = {
        replicas = 1;
        selector.matchLabels = {
          app = "dns-zone-manager";
        };
        template = {
          metadata.labels = {
            app = "dns-zone-manager";
          };
          spec = {
            containers = [
              {
                name = "dns-zone-manager";
                image = "alpine:latest";
                command = [
                  "sh"
                  "-c"
                  ''
                    apk add --no-cache bind-tools curl

                    # Update zone file with cluster IPs on startup
                    echo "Updating DNS zone file..."

                    # Get node IPs for better DNS resolution
                    NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' ',')

                    # Get CoreDNS service IP
                    COREDNS_SVC_IP="10.96.0.53"

                    if [[ -n "$NODE_IPS" ]]; then
                      echo "Setting zone file with node IPs: $NODE_IPS"
                      # Use first node IP as primary nameserver
                      PRIMARY_NODE=$(echo $NODE_IPS | cut -d',' -f1)
                      sed -i "s/10.0.0.1/$PRIMARY_NODE/g" /etc/coredns/kube.dtdt.tech.zone
                      
                      echo "Primary DNS node: $PRIMARY_NODE"
                      echo "DNS available via service: $COREDNS_SVC_IP"
                    fi

                    # Keep container running and monitor for changes
                    while true; do
                      sleep 300
                      
                      # Check for node changes and update if needed
                      CURRENT_NODE_IPS=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' | tr ' ' ',')
                      if [[ -n "$CURRENT_NODE_IPS" && "$CURRENT_NODE_IPS" != "$NODE_IPS" ]]; then
                        echo "Node IPs changed, updating zone..."
                        PRIMARY_NODE=$(echo $CURRENT_NODE_IPS | cut -d',' -f1)
                        sed -i "s/$NODE_IPS/$PRIMARY_NODE/g" /etc/coredns/kube.dtdt.tech.zone
                        NODE_IPS=$CURRENT_NODE_IPS
                        echo "Updated primary DNS node: $PRIMARY_NODE"
                      fi
                    done
                  ''
                ];
                volumeMounts = [
                  {
                    name = "zone-files";
                    mountPath = "/etc/coredns";
                    readOnly = false;
                  }
                ];
                resources = {
                  requests = {
                    memory = "64Mi";
                    cpu = "50m";
                  };
                  limits = {
                    memory = "128Mi";
                    cpu = "100m";
                  };
                };
              }
            ];
            volumes = [
              {
                name = "zone-files";
                configMap.name = "kube-zone-files";
              }
            ];
          };
        };
      };
    };
  };

  # Bookstack configuration for DTDT (disabled for now due to secret module issues)
  documentation.bookstack = {
    enable = false;
  };

  # Zammad configuration for DTDT (disabled for now to get basic build working)
  support.zammad = {
    enable = false;
  };

  # Longhorn backup configuration
  applications.longhorn-backup-secret = {
    namespace = "longhorn-system";
    resources.secrets.longhorn-backup-secret = {
      metadata.name = "longhorn-backup-secret";
      type = "opaque";
      stringData = {
        AWS_ACCESS_KEY_ID = "your-aws-access-key";
        AWS_SECRET_ACCESS_KEY = "your-aws-secret-key";
        AWS_ENDPOINTS = "https://s3.us-east-1.amazonaws.com";
      };
    };
  };

  # Cloudflare API token for DNS challenges
  applications.cloudflare-api-token = {
    namespace = "cert-manager";
    resources.secrets.cloudflare-api-token = {
      metadata.name = "cloudflare-api-token";
      type = "opaque";
      stringData = {
        "api-token" = "your-cloudflare-api-token";
      };
    };
  };

  # Monitoring configuration for DTDT services
  monitoring.prometheus = {
    enable = true;
    values = {
      prometheus.prometheusSpec = {
        retention = "15d";
        storageSpec = {
          volumeClaimTemplate = {
            spec = {
              storageClassName = "longhorn";
              accessModes = [ "ReadWriteOnce" ];
              resources = {
                requests = {
                  storage = "50Gi";
                };
              };
            };
          };
        };
      };
    };
  };
}
