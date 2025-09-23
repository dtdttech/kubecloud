# SOPS utilities for nixidy
{ lib, pkgs }:

let
  # Read a SOPS encrypted file and return decrypted content
  readSOPSFile = secretsFile: 
    let
      sopsCmd = "${pkgs.sops}/bin/sops";
      decryptedContent = builtins.readFile (pkgs.runCommand "decrypt-sops" {
        buildInputs = [ pkgs.sops ];
      } ''
        ${sopsCmd} -d ${secretsFile} > $out
      '');
    in
      builtins.fromJSON decryptedContent;

  # Get a specific secret from SOPS file by path
  getSecret = secretsFile: path:
    let
      content = readSOPSFile secretsFile;
      pathParts = lib.splitString "/" path;
    in
      lib.attrByPath pathParts null content;

  # Create a function to get secrets with fallback
  withSOPS = { secretsFile, enable ? true }: 
    if enable then {
      getSecret = getSecret secretsFile;
      secretsFile = secretsFile;
    } else {
      getSecret = _: null;
      secretsFile = null;
    };
in
{
  inherit readSOPSFile getSecret withSOPS;
}