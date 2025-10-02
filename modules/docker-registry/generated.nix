# This file was generated with nixidy CRD generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:
{
  options.applications.docker-registry = lib.mkOption {
    type = lib.types.anything;
    default = { };
    description = "Docker Registry application configuration";
  };
}