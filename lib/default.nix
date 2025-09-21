{ lib }:

{
  storage = import ./storage.nix { inherit lib; };
}