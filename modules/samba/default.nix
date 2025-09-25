{
  lib,
  config,
  charts,
  ...
}:
let
  cfg = config.services.samba;

  namespace = "samba";
  values = lib.attrsets.recursiveUpdate {
    # Basic Samba configuration
    globalConfig = ''
      [global]
      workgroup = cfg.workgroup
      realm = cfg.realm
      netbios name = ${cfg.netbiosName}
      security = ads
      server role = member server
      encrypt passwords = yes
      idmap config * : backend = tdb
      idmap config * : range = 3000-7999
      idmap config ${cfg.workgroup} : backend = rid
      idmap config ${cfg.workgroup} : range = 10000-999999
      template shell = /bin/bash
      winbind use default domain = yes
      winbind offline logon = false
      winbind refresh tickets = yes
      winbind enum users = yes
      winbind enum groups = yes
      vfs objects = acl_xattr
      map acl inherit = yes
      store dos attributes = yes
    '';

    # Default share configuration
    shares = cfg.shares;

    # Enable metrics and monitoring
    metrics.enabled = true;
    metrics.serviceMonitor.enabled = true;

    # Persistent storage configuration
    persistence = {
      enabled = true;
      storageClass = cfg.storageClass;
      size = cfg.storageSize;
    };

    # Resource configuration
    resources = {
      requests = {
        memory = "256Mi";
        cpu = "100m";
      };
      limits = {
        memory = "512Mi";
        cpu = "500m";
      };
    };

    # Health checks
    livenessProbe = {
      enabled = true;
      initialDelaySeconds = 30;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
    };

    readinessProbe = {
      enabled = true;
      initialDelaySeconds = 5;
      periodSeconds = 10;
      timeoutSeconds = 5;
      failureThreshold = 3;
    };
  } cfg.values;
in
{
  options.services.samba = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
    };
    workgroup = mkOption {
      type = types.str;
      default = "EXAMPLE";
      description = "Windows domain workgroup name";
    };
    realm = mkOption {
      type = types.str;
      default = "example.com";
      description = "Kerberos realm (AD domain)";
    };
    netbiosName = mkOption {
      type = types.str;
      default = "samba";
      description = "NetBIOS name of the Samba server";
    };
    storageClass = mkOption {
      type = types.str;
      default = "local-path";
      description = "Storage class for persistent storage";
    };
    storageSize = mkOption {
      type = types.str;
      default = "10Gi";
      description = "Size of persistent storage";
    };
    shares = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            path = mkOption {
              type = types.str;
              description = "Path to share directory";
            };
            comment = mkOption {
              type = types.str;
              description = "Share description";
              default = "";
            };
            browseable = mkOption {
              type = types.bool;
              default = true;
            };
            writable = mkOption {
              type = types.bool;
              default = true;
            };
            guestOk = mkOption {
              type = types.bool;
              default = false;
            };
            validUsers = mkOption {
              type = types.listOf types.str;
              default = [ ];
            };
            readOnly = mkOption {
              type = types.bool;
              default = false;
            };
          };
        }
      );
      default = {
        share1 = {
          path = "/data/share1";
          comment = "Shared Files";
        };
      };
    };
    values = mkOption {
      type = types.attrsOf types.anything;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    applications.samba = {
      inherit namespace;
      createNamespace = true;

      helm.releases.samba = {
        inherit values;
        chart = charts.samba.samba;
      };

      resources = {
        # Network policy allowing access to Samba ports
        networkPolicies.allow-samba-ports.spec = {
          podSelector.matchLabels."app.kubernetes.io/name" = "samba";
          policyTypes = [ "Ingress" ];
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
                  port = 139;
                }
                {
                  protocol = "TCP";
                  port = 445;
                }
                {
                  protocol = "UDP";
                  port = 137;
                }
                {
                  protocol = "UDP";
                  port = 138;
                }
              ];
            }
          ];
        };

        # Allow Samba to connect to Active Directory
        ciliumNetworkPolicies.allow-ad-egress.spec = {
          endpointSelector.matchLabels."app.kubernetes.io/name" = "samba";
          egress = [
            {
              toFQDNs = [
                { matchName = cfg.realm; }
                { matchPattern = "*.${cfg.realm}"; }
              ];
              toPorts = [
                {
                  ports = [
                    {
                      port = "88";
                      protocol = "UDP";
                    }
                    {
                      port = "88";
                      protocol = "TCP";
                    }
                    {
                      port = "445";
                      protocol = "TCP";
                    }
                    {
                      port = "389";
                      protocol = "TCP";
                    }
                    {
                      port = "389";
                      protocol = "UDP";
                    }
                    {
                      port = "636";
                      protocol = "TCP";
                    }
                    {
                      port = "53";
                      protocol = "UDP";
                    }
                    {
                      port = "53";
                      protocol = "TCP";
                    }
                  ];
                }
              ];
            }
          ];
        };
      };
    };
  };
}
