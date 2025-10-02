{
  nixidy = {
    bootstrapManifest.enable = true;
    target = {
      repository = "git@github.com:dtdttech/kubevkm_rendered.git";
      branch = "master";
      rootPath = ".";
    };
    extraFiles."README.md".text = ''
      # Rendered manifests for VKM
    '';
  };

  networking.domain = "vkm.maschinenbau.tu-darmstadt.de";

  # External DNS configuration for DNS management
  networking.external-dns = {
    enable = false;
    domainFilters = [
      "kube.vkm.maschinenbau.tu-darmstadt.de"
    ];
    provider = "inmemory";
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
      txtOwnerId = "external-dns";

      # Log level for debugging
      logLevel = "debug";

      # Run in dry-run mode initially for testing
      dryRun = false;
    };
  };

  # Storage configuration for VKM production environment
  storage = {
    defaultProvider = "ceph"; # Use Ceph for production storage
    storageClasses = {
      rwo = "ceph-rbd"; # ReadWriteOnce uses RBD (block storage)
      rwx = "ceph-cephfs"; # ReadWriteMany uses CephFS (filesystem)
      rox = "ceph-cephfs"; # ReadOnlyMany uses CephFS (filesystem)
    };
    providers = {
      local.enable = false; # Disable local storage in production
      ceph = {
        enable = true;
        # Enable SOPS-based secret management
        sops = {
          enable = false; # SOPS integration framework ready, but disabled due to pure evaluation constraints
          secretsFile = ../../secrets/vkm.sops.yaml;
          secretsPath = "ceph";
        };
        # Fallback configuration (used when SOPS is disabled)
        cluster = {
          clusterID = "c6d024a4-5b8e-4c2d-9331-fba950fd3f13";
          monitors = [
            "130.83.206.213:6789"
            "130.83.206.132:6789"
            "130.83.206.142:6789"
          ];
        };
        secrets = {
          userID = "kubernetes";
          userKey = "AQClE9NommrPExAAUq2lxa+afoMK1Y7FRWWtEw==";
          adminID = "kube-admin";
          adminKey = "AQAGFNNo4lcvFRAAXAz/2EObhlGla3x95hmKkQ==";
        };
      };
      longhorn.enable = false; # Disable Longhorn (using Ceph instead)
    };
  };

  # VKM-specific configuration
  scheduling.librebooking = {
    enable = false;
    domain = "booked.k.vkm.maschinenbau.tu-darmstadt.de";
    timezone = "Europe/Berlin";
    environment = "production";
    database = {
      name = "librebooking_vkm";
      user = "librebooking_vkm";
      password = "librebooking_vkm_secure123";
    };
    install = {
      password = "install_vkm_secure123";
    };
  };

  # Monitoring configuration for VKM
  monitoring = {
    # Enable Grafana with external access
    grafana = {
      enable = false;
      domain = "grafana.kube.vkm";
      namespace = "monitoring";
      # Admin credentials (consider using external secrets in production)
      admin = {
        user = "admin";
        password = "grafana_vkm_secure123";
      };
      # Storage configuration
      storage = {
        enabled = false;
        size = "10Gi";
        className = "ceph-rbd";
      };
      # Ingress configuration
      ingress = {
        enabled = true;
        className = "nginx";
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-vkm";
          "nginx.ingress.kubernetes.io/ssl-redirect" = "true";
          "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true";
        };
        tls = {
          enabled = true;
          secretName = "grafana-tls";
        };
      };
    };
    prometheus = {
      enable = false;
    };
  };

  support.zammad = {
    enable = false;
    domain = "support.k.vkm.maschinenbau.tu-darmstadt.de";
    version = "6.5.1";
    timezone = "Europe/Berlin";
    database = {
      name = "zammad_vkm";
      user = "zammad_vkm";
      password = "zammad_vkm_secure123";
    };
    elasticsearch = {
      enabled = true;
      version = "8.19.2";
    };
  };

  security.acme-dns = {
    enable = false;
    domain = "dns.kube.vkm.maschinenbau.tu-darmstadt.de";
    nsname = "dns.kube.vkm.maschinenbau.tu-darmstadt.de";
    nsadmin = "admin.kube.vkm.maschinenbau.tu-darmstadt.de";
    debug = false;
    logging = {
      level = "info";
      format = "json";
    };
  };

  # Certificate management for VKM production
  security.cert-manager = {
    enable = false;
    namespace = "cert-manager";

    clusterIssuers = {
      # Let's Encrypt production issuer for VKM domains
      letsencrypt-vkm = {
        type = "acme";
        acme = {
          server = "https://acme-v02.api.letsencrypt.org/directory";
          email = "admin@vkm.maschinenbau.tu-darmstadt.de";
          solvers = [
            # HTTP-01 solver for individual certificates
            {
              http01 = {
                ingress = {
                  class = "nginx";
                };
              };
            }
            # DNS-01 solver using acme-dns for wildcard certificates
            {
              dns01 = {
                acmedns = {
                  host = "https://dns.kube.vkm.maschinenbau.tu-darmstadt.de";
                  accountSecretRef = {
                    name = "acme-dns-account";
                    key = "acmedns.json";
                  };
                };
              };
              selector = {
                dnsZones = [ "vkm.maschinenbau.tu-darmstadt.de" ];
              };
            }
          ];
        };
      };

      # Self-signed for testing
      selfsigned-vkm = {
        type = "selfSigned";
      };
    };

    defaultIssuer = "letsencrypt-vkm";

    dns.providers = {
      acme-dns = {
        type = "acmedns";
        secretName = "acme-dns-account";
        config = {
          host = "https://dns.kube.vkm.maschinenbau.tu-darmstadt.de";
        };
      };
    };

    monitoring = {
      enabled = false; # Temporarily disabled
      alerts = {
        certificateExpiry = true;
        certificateRenewalFailure = true;
      };
    };

    security = {
      networkPolicies.enabled = true;
    };

    # Enhanced resource limits for production
    values = {
      resources = {
        requests = {
          cpu = "50m";
          memory = "64Mi";
        };
        limits = {
          cpu = "200m";
          memory = "256Mi";
        };
      };
      webhook.resources = {
        requests = {
          cpu = "50m";
          memory = "64Mi";
        };
        limits = {
          cpu = "200m";
          memory = "256Mi";
        };
      };
      cainjector.resources = {
        requests = {
          cpu = "50m";
          memory = "64Mi";
        };
        limits = {
          cpu = "200m";
          memory = "256Mi";
        };
      };
    };
  };

  # Identity and access management with Keycloak
  identity.keycloak = {
    enable = false;
    domain = "auth.kube.vkm.maschinenbau.tu-darmstadt.de";
    admin = {
      username = "admin";
      password = "keycloak_vkm_secure123";
    };
    database = {
      name = "keycloak_vkm";
      user = "keycloak_vkm";
      password = "keycloak_vkm_db_secure123";
    };
    mode = "production";
  };

  # Documentation platform with BookStack
  documentation.bookstack = {
    enable = false;
    domain = "docs.kube.vkm.maschinenbau.tu-darmstadt.de";
    timezone = "Europe/Berlin";
    database = {
      name = "bookstack_vkm";
      user = "bookstack_vkm";
      password = "bookstack_vkm_secure123";
    };
    app = {
      key = "base64:H+eX8SaXwaCTY7jKDfXDfm2NvGV9RkSKzGHvwdHvz/w=";
    };
    storage = {
      provider = "ceph";
      database = {
        size = "20Gi";
      };
      config = {
        size = "10Gi";
      };
    };
    secrets = {
      provider = "internal";
      database = {
        useExisting = false;
      };
      app = {
        useExisting = false;
      };
    };
  };

  # Disable samba service (not needed for DNS management)
  services.samba.enable = false;

}
