{
  lib,
  config,
  charts,
  ...
}:
let
in
{
  options = with lib; {
    kconf.core.baseDomainX = mkOption {
      type = types.str;
    };
  };

  config = { };
}
