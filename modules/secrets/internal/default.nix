{ lib, config, ... }:

let
  cfg = config.secrets.providers.internal;
in
{
  options.secrets.providers.internal = with lib; {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable internal Kubernetes secrets provider";
    };

    encryptionAtRest = mkOption {
      type = types.bool;
      default = false;
      description = "Whether etcd encryption at rest is enabled (informational)";
    };

    validation = {
      enforceLabels = mkOption {
        type = types.bool;
        default = true;
        description = "Enforce required labels on secrets";
      };

      requiredLabels = mkOption {
        type = types.listOf types.str;
        default = [ "app.kubernetes.io/name" ];
        description = "Required labels for secrets validation";
      };

      enforceAnnotations = mkOption {
        type = types.bool;
        default = true;
        description = "Enforce required annotations on secrets";
      };

      requiredAnnotations = mkOption {
        type = types.listOf types.str;
        default = [ "secrets.kubecloud.io/provider" "secrets.kubecloud.io/type" ];
        description = "Required annotations for secrets validation";
      };
    };

    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable monitoring of internal secrets";
      };

      alerts = {
        secretsNearExpiry = mkOption {
          type = types.bool;
          default = true;
          description = "Alert when certificates in secrets are near expiry";
        };

        unusedSecrets = mkOption {
          type = types.bool;
          default = false;
          description = "Alert on secrets that haven't been accessed recently";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Internal secrets provider doesn't deploy anything - it's just configuration
    # The actual secret creation happens through the secrets library functions
    
    # Add validation webhook if requested (optional future enhancement)
    applications.secrets-validation = lib.mkIf cfg.validation.enforceLabels {
      namespace = "kube-system";
      
      resources = {
        # Placeholder for future validation webhook
        # This could be a ValidatingAdmissionWebhook that enforces
        # the required labels and annotations on secrets
      };
    };

    # Monitoring configuration for internal secrets
    monitoring.prometheus.rules = lib.mkIf cfg.monitoring.enable [
      {
        name = "internal-secrets";
        rules = [
          ({
            alert = "SecretNearExpiry";
            expr = ''
              (
                cert_exporter_cert_expires_in_seconds < 604800
                and on(secret_name, secret_namespace) 
                kube_secret_info{type="kubernetes.io/tls"}
              )
            '';
            for = "1h";
            labels.severity = "warning";
            annotations = {
              summary = "TLS certificate in secret {{ $labels.secret_name }} expires in less than 7 days";
              description = "Certificate in secret {{ $labels.secret_name }} in namespace {{ $labels.secret_namespace }} expires in {{ $value | humanizeDuration }}";
            };
          } // lib.optionalAttrs cfg.monitoring.alerts.secretsNearExpiry {})
          
          ({
            alert = "UnusedSecret";
            expr = ''
              (
                time() - kube_secret_info{type!="kubernetes.io/service-account-token"} 
                > 2592000
                and on(secret_name, secret_namespace)
                kube_secret_info unless on(secret_name, secret_namespace)
                kube_pod_spec_volumes_secret_items
              )
            '';
            for = "24h";
            labels.severity = "info";
            annotations = {
              summary = "Secret {{ $labels.secret_name }} has not been used for 30 days";
              description = "Secret {{ $labels.secret_name }} in namespace {{ $labels.secret_namespace }} has not been mounted by any pod for 30 days and may be safe to remove";
            };
          } // lib.optionalAttrs cfg.monitoring.alerts.unusedSecrets {})
        ];
      }
    ];
  };
}