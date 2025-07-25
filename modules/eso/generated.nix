{ lib, ... }:

with lib;

{
  options.resources.externalSecrets = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        # Accept anything inside the ExternalSecret definition
        apiVersion = mkOption {
          type = types.str;
        };
        kind = mkOption {
          type = types.str;
        };
        metadata = mkOption {
          type = types.attrsOf types.anything;
        };
        spec = mkOption {
          type = types.anything;  # <-- the important part: allow anything in spec
        };
      };
    });
    default = {};
    description = "Stub CRD definition for ExternalSecrets.";
  };
}
