{ lib, config, ... }:

let
  secretsLib = import ../../lib/secrets.nix { inherit lib; };
in
{
  imports = [
    ./internal
    ./external
  ];

  options.secrets = with lib; {
    # Default secrets provider for the environment
    defaultProvider = mkOption {
      type = types.enum [
        "internal"
        "external"
      ];
      default = "internal";
      description = ''
        Default secrets provider to use when not explicitly specified.
        - internal: Use native Kubernetes secrets (good for development)
        - external: Use External Secrets Operator (good for production)
      '';
    };

    # Default secret store for external secrets
    defaultSecretStore = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Default secret store name to use for external secrets.
        Only applicable when defaultProvider is "external".
      '';
    };

    # Global secret naming conventions
    naming = {
      prefix = mkOption {
        type = types.str;
        default = "";
        description = "Global prefix for secret names";
      };

      suffix = mkOption {
        type = types.str;
        default = "";
        description = "Global suffix for secret names";
      };

      separator = mkOption {
        type = types.str;
        default = "-";
        description = "Separator used in secret names";
      };
    };

    # Global secret labels and annotations
    commonLabels = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Common labels to apply to all secrets";
    };

    commonAnnotations = mkOption {
      type = types.attrsOf types.str;
      default = {
        "secrets.kubecloud.io/managed-by" = "kubecloud";
      };
      description = "Common annotations to apply to all secrets";
    };

    # Secret lifecycle management
    lifecycle = {
      defaultRefreshInterval = mkOption {
        type = types.str;
        default = "1h";
        description = "Default refresh interval for external secrets";
      };

      enableRotation = mkOption {
        type = types.bool;
        default = false;
        description = "Enable automatic secret rotation";
      };

      rotationInterval = mkOption {
        type = types.str;
        default = "30d";
        description = "Default rotation interval for secrets";
      };
    };

    # Security policies
    security = {
      enforceEncryption = mkOption {
        type = types.bool;
        default = true;
        description = "Enforce encryption for sensitive secrets";
      };

      allowedNamespaces = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of namespaces allowed to use external secrets (empty = all)";
      };

      restrictedSecretTypes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of secret types that require special permissions";
      };
    };
  };

  config = {
    # Make secrets utilities available to all modules
    _module.args.secretsLib = secretsLib;

    # Expose secrets configuration to all modules
    _module.args.secretsConfig = {
      defaultProvider = config.secrets.defaultProvider;
      defaultSecretStore = config.secrets.defaultSecretStore;
      naming = config.secrets.naming;
      commonLabels = config.secrets.commonLabels;
      commonAnnotations = config.secrets.commonAnnotations;
      lifecycle = config.secrets.lifecycle;
      security = config.secrets.security;
    };

    # Set up RBAC for secret access
    applications.secrets-rbac = lib.mkIf (config.secrets.security.allowedNamespaces != [ ]) {
      namespace = "kube-system";

      resources = {
        # Create namespace-specific RBAC for external secrets
        clusterRoles.external-secrets-reader = {
          rules = [
            {
              apiGroups = [ "" ];
              resources = [ "secrets" ];
              verbs = [
                "get"
                "list"
                "watch"
              ];
            }
            {
              apiGroups = [ "external-secrets.io" ];
              resources = [
                "externalsecrets"
                "secretstores"
              ];
              verbs = [
                "get"
                "list"
                "watch"
                "create"
                "update"
                "patch"
              ];
            }
          ];
        };

        clusterRoleBindings.external-secrets-reader = {
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "external-secrets-reader";
          };
          subjects = map (ns: {
            kind = "ServiceAccount";
            name = "default";
            namespace = ns;
          }) config.secrets.security.allowedNamespaces;
        };
      };
    };
  };
}
