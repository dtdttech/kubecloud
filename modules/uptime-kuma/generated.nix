# This file was generated with nixidy CRD generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:
{
  options.applications.uptime-kuma = lib.mkOption {
    type = lib.types.anything;
    default = { };
    description = "Uptime Kuma application configuration";
  };
}
