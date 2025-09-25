{ lib }:

{
  storage = import ./storage.nix { inherit lib; };
  secrets = import ./secrets.nix { inherit lib; };
}
