{ lib, options, config, ... }:
with lib; {
  options = {
    resources = {
      "external-secrets.io"."v1"."ExternalSecret" = mkOption {
        description = "ExternalSecret is a type which declares how to fetch the secret data and how to transform it to a Kubernetes Secret.";
        type = types.attrsOf types.attrs; # You might want to use a proper submodule here
        default = {};
      };
    } // {
      "externalSecrets" = mkOption {
        description = "ExternalSecret is a type which declares how to fetch the secret data and how to transform it to a Kubernetes Secret.";
        type = types.attrsOf types.attrs; # You might want to use a proper submodule here
        default = {};
      };
    };
  };

  config = {
    types = [
      {
        name = "externalsecrets";
        group = "external-secrets.io";
        version = "v1";
        kind = "ExternalSecret";
        attrName = "externalSecrets";
      }
    ];

    resources = {
      "external-secrets.io"."v1"."ExternalSecret" = 
        mkAliasDefinitions options.resources."externalSecrets";
    };

    defaults = [
      {
        group = "external-secrets.io";
        version = "v1";
        kind = "ExternalSecret";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}