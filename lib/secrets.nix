{ lib }:

rec {
  # Secret provider types
  providers = {
    internal = "internal"; # Standard Kubernetes secrets
    external = "external"; # External Secrets Operator
    vault = "vault"; # HashiCorp Vault via ESO
    aws = "aws-secrets-manager"; # AWS Secrets Manager via ESO
    azure = "azure-key-vault"; # Azure Key Vault via ESO
    gcp = "gcp-secret-manager"; # GCP Secret Manager via ESO
  };

  # Secret data types for validation and organization
  secretTypes = {
    generic = "Opaque";
    tls = "kubernetes.io/tls";
    dockerconfigjson = "kubernetes.io/dockerconfigjson";
    basic-auth = "kubernetes.io/basic-auth";
    ssh-auth = "kubernetes.io/ssh-auth";
    service-account-token = "kubernetes.io/service-account-token";
  };

  # Create an internal Kubernetes secret
  createInternalSecret =
    {
      name, # Secret name
      namespace ? null, # Optional namespace override
      type ? "generic", # Secret type (generic, tls, dockerconfigjson, etc.)
      data ? { }, # Secret data as key-value pairs
      stringData ? { }, # Secret string data (will be base64 encoded automatically)
      labels ? { }, # Additional labels
      annotations ? { }, # Additional annotations
    }:
    let
      resolvedType = secretTypes.${type} or secretTypes.generic;
    in
    {
      apiVersion = "v1";
      kind = "Secret";
      metadata = {
        name = "${name}-secret";
        inherit labels;
        annotations = annotations // {
          "secrets.kubecloud.io/provider" = "internal";
          "secrets.kubecloud.io/type" = type;
        };
      }
      // lib.optionalAttrs (namespace != null) { inherit namespace; };
      type = resolvedType;
    }
    // lib.optionalAttrs (data != { }) { inherit data; }
    // lib.optionalAttrs (stringData != { }) { inherit stringData; };

  # Create an external secret using External Secrets Operator
  createExternalSecret =
    {
      name, # Secret name
      namespace ? null, # Optional namespace override
      type ? "generic", # Secret type
      secretStore, # SecretStore reference name
      secretStoreKind ? "SecretStore", # SecretStore kind (SecretStore or ClusterSecretStore)
      refreshInterval ? "1h", # Refresh interval for the secret
      data ? [ ], # External secret data mapping
      labels ? { }, # Additional labels
      annotations ? { }, # Additional annotations
      template ? null, # Optional template for secret transformation
    }:
    let
      resolvedType = secretTypes.${type} or secretTypes.generic;
    in
    {
      apiVersion = "external-secrets.io/v1beta1";
      kind = "ExternalSecret";
      metadata = {
        name = "${name}-external-secret";
        inherit labels;
        annotations = annotations // {
          "secrets.kubecloud.io/provider" = "external";
          "secrets.kubecloud.io/type" = type;
        };
      }
      // lib.optionalAttrs (namespace != null) { inherit namespace; };
      spec = {
        inherit refreshInterval;
        secretStoreRef = {
          name = secretStore;
          kind = secretStoreKind;
        };
        target = {
          name = "${name}-secret";
          type = resolvedType;
        }
        // lib.optionalAttrs (template != null) { inherit template; };
        inherit data;
      };
    };

  # Create a secret based on provider configuration
  createSecret =
    {
      name, # Secret name
      provider ? "internal", # Provider: internal, external, vault, aws, azure, gcp
      namespace ? null, # Optional namespace override
      type ? "generic", # Secret type
      data ? { }, # For internal secrets: direct data
      stringData ? { }, # For internal secrets: string data
      externalData ? [ ], # For external secrets: data mapping
      secretStore ? null, # For external secrets: secret store name
      secretStoreKind ? "SecretStore", # Secret store kind
      refreshInterval ? "1h", # External secret refresh interval
      labels ? { }, # Additional labels
      annotations ? { }, # Additional annotations
      template ? null, # External secret template
    }:
    if provider == "internal" then
      createInternalSecret {
        inherit
          name
          namespace
          type
          data
          stringData
          labels
          annotations
          ;
      }
    else
      createExternalSecret {
        inherit
          name
          namespace
          type
          secretStore
          secretStoreKind
          refreshInterval
          labels
          annotations
          template
          ;
        data = externalData;
      };

  # Helper function to create common secret types
  commonSecrets = {
    # Database credentials
    database =
      {
        name,
        provider ? "internal",
        username,
        password,
        host ? null,
        port ? null,
        database ? null,
      }:
      let
        secretData = {
          username = username;
          password = password;
        }
        // lib.optionalAttrs (host != null) { inherit host; }
        // lib.optionalAttrs (port != null) { port = toString port; }
        // lib.optionalAttrs (database != null) { inherit database; };
      in
      createSecret {
        inherit name provider;
        type = "generic";
        stringData = if provider == "internal" then secretData else { };
        externalData =
          if provider != "internal" then
            [
              {
                secretKey = "username";
                key = "${name}-username";
              }
              {
                secretKey = "password";
                key = "${name}-password";
              }
            ]
            ++ lib.optionals (host != null) [
              {
                secretKey = "host";
                key = "${name}-host";
              }
            ]
            ++ lib.optionals (port != null) [
              {
                secretKey = "port";
                key = "${name}-port";
              }
            ]
            ++ lib.optionals (database != null) [
              {
                secretKey = "database";
                key = "${name}-database";
              }
            ]
          else
            [ ];
      };

    # API keys and tokens
    apiKey =
      {
        name,
        provider ? "internal",
        key,
        description ? null,
      }:
      createSecret {
        inherit name provider;
        type = "generic";
        stringData = if provider == "internal" then { api-key = key; } else { };
        externalData =
          if provider != "internal" then
            [
              {
                secretKey = "api-key";
                key = "${name}-api-key";
              }
            ]
          else
            [ ];
        annotations = lib.optionalAttrs (description != null) {
          "secrets.kubecloud.io/description" = description;
        };
      };

    # TLS certificates
    tls =
      {
        name,
        provider ? "internal",
        cert ? null,
        key ? null,
        ca ? null,
      }:
      createSecret {
        inherit name provider;
        type = "tls";
        stringData =
          if provider == "internal" then
            {
              "tls.crt" = cert;
              "tls.key" = key;
            }
            // lib.optionalAttrs (ca != null) { "ca.crt" = ca; }
          else
            { };
        externalData =
          if provider != "internal" then
            [
              {
                secretKey = "tls.crt";
                key = "${name}-tls-cert";
              }
              {
                secretKey = "tls.key";
                key = "${name}-tls-key";
              }
            ]
            ++ lib.optionals (ca != null) [
              {
                secretKey = "ca.crt";
                key = "${name}-ca-cert";
              }
            ]
          else
            [ ];
      };

    # Docker registry credentials
    dockerRegistry =
      {
        name,
        provider ? "internal",
        server,
        username,
        password,
        email ? null,
      }:
      let
        dockerConfig = {
          auths.${server} = {
            inherit username password;
          }
          // lib.optionalAttrs (email != null) { inherit email; };
        };
      in
      createSecret {
        inherit name provider;
        type = "dockerconfigjson";
        stringData =
          if provider == "internal" then
            {
              ".dockerconfigjson" = builtins.toJSON dockerConfig;
            }
          else
            { };
        externalData =
          if provider != "internal" then
            [
              {
                secretKey = ".dockerconfigjson";
                key = "${name}-dockerconfig";
              }
            ]
          else
            [ ];
      };

    # Basic authentication
    basicAuth =
      {
        name,
        provider ? "internal",
        username,
        password,
      }:
      createSecret {
        inherit name provider;
        type = "basic-auth";
        stringData =
          if provider == "internal" then
            {
              inherit username password;
            }
          else
            { };
        externalData =
          if provider != "internal" then
            [
              {
                secretKey = "username";
                key = "${name}-username";
              }
              {
                secretKey = "password";
                key = "${name}-password";
              }
            ]
          else
            [ ];
      };

    # SSH keys
    sshKey =
      {
        name,
        provider ? "internal",
        privateKey,
        publicKey ? null,
        knownHosts ? null,
      }:
      createSecret {
        inherit name provider;
        type = "ssh-auth";
        stringData =
          if provider == "internal" then
            {
              "ssh-privatekey" = privateKey;
            }
            // lib.optionalAttrs (publicKey != null) { "ssh-publickey" = publicKey; }
            // lib.optionalAttrs (knownHosts != null) { "known_hosts" = knownHosts; }
          else
            { };
        externalData =
          if provider != "internal" then
            [
              {
                secretKey = "ssh-privatekey";
                key = "${name}-ssh-private-key";
              }
            ]
            ++ lib.optionals (publicKey != null) [
              {
                secretKey = "ssh-publickey";
                key = "${name}-ssh-public-key";
              }
            ]
            ++ lib.optionals (knownHosts != null) [
              {
                secretKey = "known_hosts";
                key = "${name}-known-hosts";
              }
            ]
          else
            [ ];
      };

    # Generic application secrets
    application =
      {
        name,
        provider ? "internal",
        secrets,
      }:
      createSecret {
        inherit name provider;
        type = "generic";
        stringData = if provider == "internal" then secrets else { };
        externalData =
          if provider != "internal" then
            lib.mapAttrsToList (secretKey: key: {
              inherit secretKey;
              key = "${name}-${lib.replaceStrings [ "_" ] [ "-" ] (lib.toLower secretKey)}";
            }) secrets
          else
            [ ];
      };
  };

  # Helper function to create environment variables from secrets
  createSecretEnvVar =
    {
      name, # Environment variable name
      secretName, # Secret name (without -secret suffix)
      secretKey, # Key within the secret
      optional ? false, # Whether the secret is optional
    }:
    {
      name = name;
      valueFrom.secretKeyRef = {
        name = "${secretName}-secret";
        key = secretKey;
      }
      // lib.optionalAttrs optional { inherit optional; };
    };

  # Helper function to create volume mounts from secrets
  createSecretVolumeMount =
    {
      name, # Volume name
      secretName, # Secret name (without -secret suffix)
      mountPath, # Mount path in container
      defaultMode ? 420, # File permissions (0644 in decimal)
      readOnly ? true, # Mount as read-only
      items ? null, # Optional items to select specific keys
    }:
    {
      volumeMount = {
        inherit name mountPath readOnly;
      };
      volume = {
        inherit name;
        secret = {
          secretName = "${secretName}-secret";
          inherit defaultMode;
        }
        // lib.optionalAttrs (items != null) { inherit items; };
      };
    };

  # Helper function to create multiple secrets at once
  createSecrets =
    secretSpecs:
    {
      provider ? "internal",
      secretStore ? null,
    }:
    lib.listToAttrs (
      map (spec: {
        name = "${spec.name}-secret";
        value = createSecret (
          spec
          // {
            inherit provider;
          }
          // lib.optionalAttrs (provider != "internal" && secretStore != null) {
            inherit secretStore;
          }
        );
      }) secretSpecs
    );
}
