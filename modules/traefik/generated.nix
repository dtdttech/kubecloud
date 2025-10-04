# This file was generated with nixidy CRD generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:
with lib;
let
  hasAttrNotNull = attr: set: hasAttr attr set && set.${attr} != null;

  attrsToList =
    values:
    if values != null then
      sort (
        a: b:
        if (hasAttrNotNull "_priority" a && hasAttrNotNull "_priority" b) then
          a._priority < b._priority
        else
          false
      ) (mapAttrsToList (n: v: v) values)
    else
      values;

  getDefaults =
    resource: group: version: kind:
    catAttrs "default" (
      filter (
        default:
        (default.resource == null || default.resource == resource)
        && (default.group == null || default.group == group)
        && (default.version == null || default.version == version)
        && (default.kind == null || default.kind == kind)
      ) config.defaults
    );

  types = lib.types // rec {
    str = mkOptionType {
      name = "str";
      description = "string";
      check = isString;
      merge = mergeEqualOption;
    };

    # Either value of type `finalType` or `coercedType`, the latter is
    # converted to `finalType` using `coerceFunc`.
    coercedTo =
      coercedType: coerceFunc: finalType:
      mkOptionType rec {
        inherit (finalType) getSubOptions getSubModules;

        name = "coercedTo";
        description = "${finalType.description} or ${coercedType.description}";
        check = x: finalType.check x || coercedType.check x;
        merge =
          loc: defs:
          let
            coerceVal =
              val:
              if finalType.check val then
                val
              else
                let
                  coerced = coerceFunc val;
                in
                assert finalType.check coerced;
                coerced;
          in
          finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
        substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
        typeMerge = t1: t2: null;
        functor = (defaultFunctor name) // {
          wrapped = finalType;
        };
      };
  };

  mkOptionDefault = mkOverride 1001;

  mergeValuesByKey =
    attrMergeKey: listMergeKeys: values:
    listToAttrs (
      imap0 (
        i: value:
        nameValuePair (
          if hasAttr attrMergeKey value then
            if isAttrs value.${attrMergeKey} then
              toString value.${attrMergeKey}.content
            else
              (toString value.${attrMergeKey})
          else
            # generate merge key for list elements if it's not present
            "__kubenix_list_merge_key_"
            + (concatStringsSep "" (
              map (
                key: if isAttrs value.${key} then toString value.${key}.content else (toString value.${key})
              ) listMergeKeys
            ))
        ) (value // { _priority = i; })
      ) values
    );

  submoduleOf =
    ref:
    types.submodule (
      { name, ... }:
      {
        options = definitions."${ref}".options or { };
        config = definitions."${ref}".config or { };
      }
    );

  globalSubmoduleOf =
    ref:
    types.submodule (
      { name, ... }:
      {
        options = config.definitions."${ref}".options or { };
        config = config.definitions."${ref}".config or { };
      }
    );

  submoduleWithMergeOf =
    ref: mergeKey:
    types.submodule (
      { name, ... }:
      let
        convertName =
          name: if definitions."${ref}".options.${mergeKey}.type == types.int then toInt name else name;
      in
      {
        options = definitions."${ref}".options // {
          # position in original array
          _priority = mkOption {
            type = types.nullOr types.int;
            default = null;
          };
        };
        config = definitions."${ref}".config // {
          ${mergeKey} = mkOverride 1002 (
            # use name as mergeKey only if it is not coming from mergeValuesByKey
            if (!hasPrefix "__kubenix_list_merge_key_" name) then convertName name else null
          );
        };
      }
    );

  submoduleForDefinition =
    ref: resource: kind: group: version:
    let
      apiVersion = if group == "core" then version else "${group}/${version}";
    in
    types.submodule (
      { name, ... }:
      {
        inherit (definitions."${ref}") options;

        imports = getDefaults resource group version kind;
        config = mkMerge [
          definitions."${ref}".config
          {
            kind = mkOptionDefault kind;
            apiVersion = mkOptionDefault apiVersion;

            # metdata.name cannot use option default, due deep config
            metadata.name = mkOptionDefault name;
          }
        ];
      }
    );

  coerceAttrsOfSubmodulesToListByKey =
    ref: attrMergeKey: listMergeKeys:
    (types.coercedTo (types.listOf (submoduleOf ref)) (mergeValuesByKey attrMergeKey listMergeKeys) (
      types.attrsOf (submoduleWithMergeOf ref attrMergeKey)
    ));

  definitions = {
    "hub.traefik.io.v1alpha1.AIService" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this AIService.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpec" = {
      options = {
        "anthropic" = mkOption {
          description = "Anthropic configures Anthropic backend.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecAnthropic");
        };
        "azureOpenai" = mkOption {
          description = "AzureOpenAI configures AzureOpenAI.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecAzureOpenai");
        };
        "bedrock" = mkOption {
          description = "Bedrock configures Bedrock backend.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecBedrock");
        };
        "cohere" = mkOption {
          description = "Cohere configures Cohere backend.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecCohere");
        };
        "deepSeek" = mkOption {
          description = "DeepSeek configures DeepSeek.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecDeepSeek");
        };
        "gemini" = mkOption {
          description = "Gemini configures Gemini backend.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecGemini");
        };
        "mistral" = mkOption {
          description = "Mistral configures Mistral AI backend.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecMistral");
        };
        "ollama" = mkOption {
          description = "Ollama configures Ollama backend.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecOllama");
        };
        "openai" = mkOption {
          description = "OpenAI configures OpenAI.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecOpenai");
        };
        "qWen" = mkOption {
          description = "QWen configures QWen.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecQWen");
        };
      };

      config = {
        "anthropic" = mkOverride 1002 null;
        "azureOpenai" = mkOverride 1002 null;
        "bedrock" = mkOverride 1002 null;
        "cohere" = mkOverride 1002 null;
        "deepSeek" = mkOverride 1002 null;
        "gemini" = mkOverride 1002 null;
        "mistral" = mkOverride 1002 null;
        "ollama" = mkOverride 1002 null;
        "openai" = mkOverride 1002 null;
        "qWen" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecAnthropic" = {
      options = {
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecAnthropicParams");
        };
        "token" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecAnthropicToken");
        };
      };

      config = {
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
        "token" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecAnthropicParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecAnthropicToken" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecAzureOpenai" = {
      options = {
        "apiKeySecret" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecAzureOpenaiApiKeySecret");
        };
        "baseUrl" = mkOption {
          description = "";
          type = types.str;
        };
        "deploymentName" = mkOption {
          description = "";
          type = types.str;
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecAzureOpenaiParams");
        };
      };

      config = {
        "apiKeySecret" = mkOverride 1002 null;
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecAzureOpenaiApiKeySecret" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecAzureOpenaiParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecBedrock" = {
      options = {
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecBedrockParams");
        };
        "region" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "systemMessage" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
        "region" = mkOverride 1002 null;
        "systemMessage" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecBedrockParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecCohere" = {
      options = {
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecCohereParams");
        };
        "token" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecCohereToken");
        };
      };

      config = {
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
        "token" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecCohereParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecCohereToken" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecDeepSeek" = {
      options = {
        "baseUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecDeepSeekParams");
        };
        "token" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecDeepSeekToken");
        };
      };

      config = {
        "baseUrl" = mkOverride 1002 null;
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
        "token" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecDeepSeekParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecDeepSeekToken" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecGemini" = {
      options = {
        "apiKey" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecGeminiApiKey");
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecGeminiParams");
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecGeminiApiKey" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecGeminiParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecMistral" = {
      options = {
        "apiKey" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecMistralApiKey");
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecMistralParams");
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecMistralApiKey" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecMistralParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecOllama" = {
      options = {
        "baseUrl" = mkOption {
          description = "";
          type = types.str;
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecOllamaParams");
        };
      };

      config = {
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecOllamaParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecOpenai" = {
      options = {
        "baseUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecOpenaiParams");
        };
        "token" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecOpenaiToken");
        };
      };

      config = {
        "baseUrl" = mkOverride 1002 null;
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
        "token" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecOpenaiParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecOpenaiToken" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecQWen" = {
      options = {
        "baseUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "model" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "params" = mkOption {
          description = "Params holds the LLM hyperparameters.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecQWenParams");
        };
        "token" = mkOption {
          description = "SecretReference references a kubernetes secret.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AIServiceSpecQWenToken");
        };
      };

      config = {
        "baseUrl" = mkOverride 1002 null;
        "model" = mkOverride 1002 null;
        "params" = mkOverride 1002 null;
        "token" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecQWenParams" = {
      options = {
        "frequencyPenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxTokens" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "presencePenalty" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "temperature" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "topP" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "frequencyPenalty" = mkOverride 1002 null;
        "maxTokens" = mkOverride 1002 null;
        "presencePenalty" = mkOverride 1002 null;
        "temperature" = mkOverride 1002 null;
        "topP" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AIServiceSpecQWenToken" = {
      options = {
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.API" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "APISpec describes the API.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APISpec");
        };
        "status" = mkOption {
          description = "The current status of this API.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIBundle" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this APIBundle.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIBundleSpec");
        };
        "status" = mkOption {
          description = "The current status of this APIBundle.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIBundleStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIBundleSpec" = {
      options = {
        "apiSelector" = mkOption {
          description = "APISelector selects the APIs that will be accessible to the configured audience.\nMultiple APIBundles can select the same set of APIs.\nThis field is optional and follows standard label selector semantics.\nAn empty APISelector matches any API.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIBundleSpecApiSelector");
        };
        "apis" = mkOption {
          description = "APIs defines a set of APIs that will be accessible to the configured audience.\nMultiple APIBundles can select the same APIs.\nWhen combined with APISelector, this set of APIs is appended to the matching APIs.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APIBundleSpecApis" "name" [ ]
          );
          apply = attrsToList;
        };
        "title" = mkOption {
          description = "Title is the human-readable name of the APIBundle that will be used on the portal.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiSelector" = mkOverride 1002 null;
        "apis" = mkOverride 1002 null;
        "title" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIBundleSpecApiSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (
            types.listOf (submoduleOf "hub.traefik.io.v1alpha1.APIBundleSpecApiSelectorMatchExpressions")
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIBundleSpecApiSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIBundleSpecApis" = {
      options = {
        "name" = mkOption {
          description = "Name of the API.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APIBundleStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the APIBundle.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APICatalogItem" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this APICatalogItem.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APICatalogItemSpec");
        };
        "status" = mkOption {
          description = "The current status of this APICatalogItem.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APICatalogItemStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpec" = {
      options = {
        "apiBundles" = mkOption {
          description = "APIBundles defines a set of APIBundle that will be visible to the configured audience.\nMultiple APICatalogItem can select the same APIBundles.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APICatalogItemSpecApiBundles" "name" [ ]
          );
          apply = attrsToList;
        };
        "apiPlan" = mkOption {
          description = "APIPlan defines which APIPlan will be available.\nIf multiple APICatalogItem specify the same API with different APIPlan, the API consumer will be able to pick\na plan from this list.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APICatalogItemSpecApiPlan");
        };
        "apiSelector" = mkOption {
          description = "APISelector selects the APIs that will be visible to the configured audience.\nMultiple APICatalogItem can select the same set of APIs.\nThis field is optional and follows standard label selector semantics.\nAn empty APISelector matches any API.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APICatalogItemSpecApiSelector");
        };
        "apis" = mkOption {
          description = "APIs defines a set of APIs that will be visible to the configured audience.\nMultiple APICatalogItem can select the same APIs.\nWhen combined with APISelector, this set of APIs is appended to the matching APIs.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APICatalogItemSpecApis" "name" [ ]
          );
          apply = attrsToList;
        };
        "everyone" = mkOption {
          description = "Everyone indicates that all users will see these APIs.";
          type = types.nullOr types.bool;
        };
        "groups" = mkOption {
          description = "Groups are the consumer groups that will see the APIs.";
          type = types.nullOr (types.listOf types.str);
        };
        "operationFilter" = mkOption {
          description = "OperationFilter specifies the visible operations on APIs and APIVersions.\nIf not set, all operations are available.\nAn empty OperationFilter prohibits all operations.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APICatalogItemSpecOperationFilter");
        };
      };

      config = {
        "apiBundles" = mkOverride 1002 null;
        "apiPlan" = mkOverride 1002 null;
        "apiSelector" = mkOverride 1002 null;
        "apis" = mkOverride 1002 null;
        "everyone" = mkOverride 1002 null;
        "groups" = mkOverride 1002 null;
        "operationFilter" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpecApiBundles" = {
      options = {
        "name" = mkOption {
          description = "Name of the APIBundle.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpecApiPlan" = {
      options = {
        "name" = mkOption {
          description = "Name of the APIPlan.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpecApiSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (
            types.listOf (submoduleOf "hub.traefik.io.v1alpha1.APICatalogItemSpecApiSelectorMatchExpressions")
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpecApiSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpecApis" = {
      options = {
        "name" = mkOption {
          description = "Name of the API.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemSpecOperationFilter" = {
      options = {
        "include" = mkOption {
          description = "Include defines the names of OperationSets that will be accessible.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "include" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APICatalogItemStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the APICatalogItem.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPlan" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this APIPlan.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPlanSpec");
        };
        "status" = mkOption {
          description = "The current status of this APIPlan.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPlanStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPlanSpec" = {
      options = {
        "description" = mkOption {
          description = "Description describes the plan.";
          type = types.nullOr types.str;
        };
        "quota" = mkOption {
          description = "Quota defines the quota policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPlanSpecQuota");
        };
        "rateLimit" = mkOption {
          description = "RateLimit defines the rate limit policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPlanSpecRateLimit");
        };
        "title" = mkOption {
          description = "Title is the human-readable name of the plan.";
          type = types.str;
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "quota" = mkOverride 1002 null;
        "rateLimit" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPlanSpecQuota" = {
      options = {
        "limit" = mkOption {
          description = "Limit is the maximum number of token in the bucket.";
          type = types.int;
        };
        "period" = mkOption {
          description = "Period is the unit of time for the Limit.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "period" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPlanSpecRateLimit" = {
      options = {
        "limit" = mkOption {
          description = "Limit is the maximum number of token in the bucket.";
          type = types.int;
        };
        "period" = mkOption {
          description = "Period is the unit of time for the Limit.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "period" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPlanStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the APIPlan.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPortal" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this APIPortal.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPortalSpec");
        };
        "status" = mkOption {
          description = "The current status of this APIPortal.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPortalStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPortalSpec" = {
      options = {
        "description" = mkOption {
          description = "Description of the APIPortal.";
          type = types.nullOr types.str;
        };
        "title" = mkOption {
          description = "Title is the public facing name of the APIPortal.";
          type = types.nullOr types.str;
        };
        "trustedUrls" = mkOption {
          description = "TrustedURLs are the urls that are trusted by the OAuth 2.0 authorization server.";
          type = types.listOf types.str;
        };
        "ui" = mkOption {
          description = "UI holds the UI customization options.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPortalSpecUi");
        };
      };

      config = {
        "description" = mkOverride 1002 null;
        "title" = mkOverride 1002 null;
        "ui" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPortalSpecUi" = {
      options = {
        "logoUrl" = mkOption {
          description = "LogoURL is the public URL of the logo.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "logoUrl" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPortalStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the APIPortal.";
          type = types.nullOr types.str;
        };
        "oidc" = mkOption {
          description = "OIDC is the OIDC configuration for accessing the exposed APIPortal WebUI.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIPortalStatusOidc");
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "oidc" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIPortalStatusOidc" = {
      options = {
        "clientId" = mkOption {
          description = "ClientID is the OIDC ClientID for accessing the exposed APIPortal WebUI.";
          type = types.nullOr types.str;
        };
        "companyClaim" = mkOption {
          description = "CompanyClaim is the name of the JWT claim containing the user company.";
          type = types.nullOr types.str;
        };
        "emailClaim" = mkOption {
          description = "EmailClaim is the name of the JWT claim containing the user email.";
          type = types.nullOr types.str;
        };
        "firstnameClaim" = mkOption {
          description = "FirstnameClaim is the name of the JWT claim containing the user firstname.";
          type = types.nullOr types.str;
        };
        "generic" = mkOption {
          description = "Generic indicates whether or not the APIPortal authentication relies on Generic OIDC.";
          type = types.nullOr types.bool;
        };
        "groupsClaim" = mkOption {
          description = "GroupsClaim is the name of the JWT claim containing the user groups.";
          type = types.nullOr types.str;
        };
        "issuer" = mkOption {
          description = "Issuer is the OIDC issuer for accessing the exposed APIPortal WebUI.";
          type = types.nullOr types.str;
        };
        "lastnameClaim" = mkOption {
          description = "LastnameClaim is the name of the JWT claim containing the user lastname.";
          type = types.nullOr types.str;
        };
        "scopes" = mkOption {
          description = "Scopes is the OIDC scopes for getting user attributes during the authentication to the exposed APIPortal WebUI.";
          type = types.nullOr types.str;
        };
        "secretName" = mkOption {
          description = "SecretName is the name of the secret containing the OIDC ClientSecret for accessing the exposed APIPortal WebUI.";
          type = types.nullOr types.str;
        };
        "syncedAttributes" = mkOption {
          description = "SyncedAttributes configure the user attributes to sync.";
          type = types.nullOr (types.listOf types.str);
        };
        "userIdClaim" = mkOption {
          description = "UserIDClaim is the name of the JWT claim containing the user ID.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "clientId" = mkOverride 1002 null;
        "companyClaim" = mkOverride 1002 null;
        "emailClaim" = mkOverride 1002 null;
        "firstnameClaim" = mkOverride 1002 null;
        "generic" = mkOverride 1002 null;
        "groupsClaim" = mkOverride 1002 null;
        "issuer" = mkOverride 1002 null;
        "lastnameClaim" = mkOverride 1002 null;
        "scopes" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
        "syncedAttributes" = mkOverride 1002 null;
        "userIdClaim" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIRateLimit" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this APIRateLimit.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIRateLimitSpec");
        };
        "status" = mkOption {
          description = "The current status of this APIRateLimit.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIRateLimitStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIRateLimitSpec" = {
      options = {
        "apiSelector" = mkOption {
          description = "APISelector selects the APIs that will be rate limited.\nMultiple APIRateLimits can select the same set of APIs.\nThis field is optional and follows standard label selector semantics.\nAn empty APISelector matches any API.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIRateLimitSpecApiSelector");
        };
        "apis" = mkOption {
          description = "APIs defines a set of APIs that will be rate limited.\nMultiple APIRateLimits can select the same APIs.\nWhen combined with APISelector, this set of APIs is appended to the matching APIs.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APIRateLimitSpecApis" "name" [ ]
          );
          apply = attrsToList;
        };
        "everyone" = mkOption {
          description = "Everyone indicates that all users will, by default, be rate limited with this configuration.\nIf an APIRateLimit explicitly target a group, the default rate limit will be ignored.";
          type = types.nullOr types.bool;
        };
        "groups" = mkOption {
          description = "Groups are the consumer groups that will be rate limited.\nMultiple APIRateLimits can target the same set of consumer groups, the most restrictive one applies.\nWhen a consumer belongs to multiple groups, the least restrictive APIRateLimit applies.";
          type = types.nullOr (types.listOf types.str);
        };
        "limit" = mkOption {
          description = "Limit is the maximum number of token in the bucket.";
          type = types.int;
        };
        "period" = mkOption {
          description = "Period is the unit of time for the Limit.";
          type = types.nullOr types.str;
        };
        "strategy" = mkOption {
          description = "Strategy defines how the bucket state will be synchronized between the different Traefik Hub instances.\nIt can be, either \"local\" or \"distributed\".";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiSelector" = mkOverride 1002 null;
        "apis" = mkOverride 1002 null;
        "everyone" = mkOverride 1002 null;
        "groups" = mkOverride 1002 null;
        "period" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIRateLimitSpecApiSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (
            types.listOf (submoduleOf "hub.traefik.io.v1alpha1.APIRateLimitSpecApiSelectorMatchExpressions")
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIRateLimitSpecApiSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIRateLimitSpecApis" = {
      options = {
        "name" = mkOption {
          description = "Name of the API.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APIRateLimitStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the APIRateLimit.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APISpec" = {
      options = {
        "cors" = mkOption {
          description = "Cors defines the Cross-Origin Resource Sharing configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APISpecCors");
        };
        "description" = mkOption {
          description = "Description explains what the API does.";
          type = types.nullOr types.str;
        };
        "openApiSpec" = mkOption {
          description = "OpenAPISpec defines the API contract as an OpenAPI specification.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APISpecOpenApiSpec");
        };
        "title" = mkOption {
          description = "Title is the human-readable name of the API that will be used on the portal.";
          type = types.nullOr types.str;
        };
        "versions" = mkOption {
          description = "Versions are the different APIVersions available.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APISpecVersions" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "cors" = mkOverride 1002 null;
        "description" = mkOverride 1002 null;
        "openApiSpec" = mkOverride 1002 null;
        "title" = mkOverride 1002 null;
        "versions" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APISpecCors" = {
      options = {
        "addVaryHeader" = mkOption {
          description = "AddVaryHeader defines whether the Vary header is automatically added/updated when the AllowOriginsList is set.";
          type = types.nullOr types.bool;
        };
        "allowCredentials" = mkOption {
          description = "AllowCredentials defines whether the request can include user credentials.";
          type = types.nullOr types.bool;
        };
        "allowHeadersList" = mkOption {
          description = "AllowHeadersList defines the Access-Control-Request-Headers values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "allowMethodsList" = mkOption {
          description = "AllowMethodsList defines the Access-Control-Request-Method values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "allowOriginListRegex" = mkOption {
          description = "AllowOriginListRegex is a list of allowable origins written following the Regular Expression syntax (https://golang.org/pkg/regexp/).";
          type = types.nullOr (types.listOf types.str);
        };
        "allowOriginsList" = mkOption {
          description = "AllowOriginsList is a list of allowable origins. Can also be a wildcard origin \"*\".";
          type = types.nullOr (types.listOf types.str);
        };
        "exposeHeadersList" = mkOption {
          description = "ExposeHeadersList defines the Access-Control-Expose-Headers values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the time that a preflight request may be cached.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "addVaryHeader" = mkOverride 1002 null;
        "allowCredentials" = mkOverride 1002 null;
        "allowHeadersList" = mkOverride 1002 null;
        "allowMethodsList" = mkOverride 1002 null;
        "allowOriginListRegex" = mkOverride 1002 null;
        "allowOriginsList" = mkOverride 1002 null;
        "exposeHeadersList" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APISpecOpenApiSpec" = {
      options = {
        "operationSets" = mkOption {
          description = "OperationSets defines the sets of operations to be referenced for granular filtering in APICatalogItems or ManagedSubscriptions.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOperationSets" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "override" = mkOption {
          description = "Override holds data used to override OpenAPI specification.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOverride");
        };
        "path" = mkOption {
          description = "Path specifies the endpoint path within the Kubernetes Service where the OpenAPI specification can be obtained.\nThe Service queried is determined by the associated Ingress, IngressRoute, or HTTPRoute resource to which the API is attached.\nIt's important to note that this option is incompatible if the Ingress or IngressRoute specifies multiple backend services.\nThe Path must be accessible via a GET request method and should serve a YAML or JSON document containing the OpenAPI specification.";
          type = types.nullOr types.str;
        };
        "url" = mkOption {
          description = "URL is a Traefik Hub agent accessible URL for obtaining the OpenAPI specification.\nThe URL must be accessible via a GET request method and should serve a YAML or JSON document containing the OpenAPI specification.";
          type = types.nullOr types.str;
        };
        "validateRequestMethodAndPath" = mkOption {
          description = "ValidateRequestMethodAndPath validates that the path and method matches an operation defined in the OpenAPI specification.\nThis option overrides the default behavior configured in the static configuration.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "operationSets" = mkOverride 1002 null;
        "override" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "url" = mkOverride 1002 null;
        "validateRequestMethodAndPath" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOperationSets" = {
      options = {
        "matchers" = mkOption {
          description = "Matchers defines a list of alternative rules for matching OpenAPI operations.";
          type = types.listOf (submoduleOf "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOperationSetsMatchers");
        };
        "name" = mkOption {
          description = "Name is the name of the OperationSet to reference in APICatalogItems or ManagedSubscriptions.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOperationSetsMatchers" = {
      options = {
        "methods" = mkOption {
          description = "Methods specifies the HTTP methods to be included for selection.";
          type = types.nullOr (types.listOf types.str);
        };
        "path" = mkOption {
          description = "Path specifies the exact path of the operations to select.";
          type = types.nullOr types.str;
        };
        "pathPrefix" = mkOption {
          description = "PathPrefix specifies the path prefix of the operations to select.";
          type = types.nullOr types.str;
        };
        "pathRegex" = mkOption {
          description = "PathRegex specifies a regular expression pattern for matching operations based on their paths.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "methods" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "pathPrefix" = mkOverride 1002 null;
        "pathRegex" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOverride" = {
      options = {
        "servers" = mkOption {
          description = "";
          type = types.listOf (submoduleOf "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOverrideServers");
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APISpecOpenApiSpecOverrideServers" = {
      options = {
        "url" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APISpecVersions" = {
      options = {
        "name" = mkOption {
          description = "Name of the APIVersion.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APIStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the API.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIVersion" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this APIVersion.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIVersionSpec");
        };
        "status" = mkOption {
          description = "The current status of this APIVersion.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIVersionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpec" = {
      options = {
        "cors" = mkOption {
          description = "Cors defines the Cross-Origin Resource Sharing configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIVersionSpecCors");
        };
        "description" = mkOption {
          description = "Description explains what the APIVersion does.";
          type = types.nullOr types.str;
        };
        "openApiSpec" = mkOption {
          description = "OpenAPISpec defines the API contract as an OpenAPI specification.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpec");
        };
        "release" = mkOption {
          description = "Release is the version number of the API.\nThis value must follow the SemVer format: https://semver.org/";
          type = types.str;
        };
        "title" = mkOption {
          description = "Title is the public facing name of the APIVersion.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "cors" = mkOverride 1002 null;
        "description" = mkOverride 1002 null;
        "openApiSpec" = mkOverride 1002 null;
        "title" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpecCors" = {
      options = {
        "addVaryHeader" = mkOption {
          description = "AddVaryHeader defines whether the Vary header is automatically added/updated when the AllowOriginsList is set.";
          type = types.nullOr types.bool;
        };
        "allowCredentials" = mkOption {
          description = "AllowCredentials defines whether the request can include user credentials.";
          type = types.nullOr types.bool;
        };
        "allowHeadersList" = mkOption {
          description = "AllowHeadersList defines the Access-Control-Request-Headers values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "allowMethodsList" = mkOption {
          description = "AllowMethodsList defines the Access-Control-Request-Method values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "allowOriginListRegex" = mkOption {
          description = "AllowOriginListRegex is a list of allowable origins written following the Regular Expression syntax (https://golang.org/pkg/regexp/).";
          type = types.nullOr (types.listOf types.str);
        };
        "allowOriginsList" = mkOption {
          description = "AllowOriginsList is a list of allowable origins. Can also be a wildcard origin \"*\".";
          type = types.nullOr (types.listOf types.str);
        };
        "exposeHeadersList" = mkOption {
          description = "ExposeHeadersList defines the Access-Control-Expose-Headers values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the time that a preflight request may be cached.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "addVaryHeader" = mkOverride 1002 null;
        "allowCredentials" = mkOverride 1002 null;
        "allowHeadersList" = mkOverride 1002 null;
        "allowMethodsList" = mkOverride 1002 null;
        "allowOriginListRegex" = mkOverride 1002 null;
        "allowOriginsList" = mkOverride 1002 null;
        "exposeHeadersList" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpec" = {
      options = {
        "operationSets" = mkOption {
          description = "OperationSets defines the sets of operations to be referenced for granular filtering in APICatalogItems or ManagedSubscriptions.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOperationSets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "override" = mkOption {
          description = "Override holds data used to override OpenAPI specification.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOverride");
        };
        "path" = mkOption {
          description = "Path specifies the endpoint path within the Kubernetes Service where the OpenAPI specification can be obtained.\nThe Service queried is determined by the associated Ingress, IngressRoute, or HTTPRoute resource to which the API is attached.\nIt's important to note that this option is incompatible if the Ingress or IngressRoute specifies multiple backend services.\nThe Path must be accessible via a GET request method and should serve a YAML or JSON document containing the OpenAPI specification.";
          type = types.nullOr types.str;
        };
        "url" = mkOption {
          description = "URL is a Traefik Hub agent accessible URL for obtaining the OpenAPI specification.\nThe URL must be accessible via a GET request method and should serve a YAML or JSON document containing the OpenAPI specification.";
          type = types.nullOr types.str;
        };
        "validateRequestMethodAndPath" = mkOption {
          description = "ValidateRequestMethodAndPath validates that the path and method matches an operation defined in the OpenAPI specification.\nThis option overrides the default behavior configured in the static configuration.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "operationSets" = mkOverride 1002 null;
        "override" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "url" = mkOverride 1002 null;
        "validateRequestMethodAndPath" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOperationSets" = {
      options = {
        "matchers" = mkOption {
          description = "Matchers defines a list of alternative rules for matching OpenAPI operations.";
          type = types.listOf (
            submoduleOf "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOperationSetsMatchers"
          );
        };
        "name" = mkOption {
          description = "Name is the name of the OperationSet to reference in APICatalogItems or ManagedSubscriptions.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOperationSetsMatchers" = {
      options = {
        "methods" = mkOption {
          description = "Methods specifies the HTTP methods to be included for selection.";
          type = types.nullOr (types.listOf types.str);
        };
        "path" = mkOption {
          description = "Path specifies the exact path of the operations to select.";
          type = types.nullOr types.str;
        };
        "pathPrefix" = mkOption {
          description = "PathPrefix specifies the path prefix of the operations to select.";
          type = types.nullOr types.str;
        };
        "pathRegex" = mkOption {
          description = "PathRegex specifies a regular expression pattern for matching operations based on their paths.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "methods" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "pathPrefix" = mkOverride 1002 null;
        "pathRegex" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOverride" = {
      options = {
        "servers" = mkOption {
          description = "";
          type = types.listOf (
            submoduleOf "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOverrideServers"
          );
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APIVersionSpecOpenApiSpecOverrideServers" = {
      options = {
        "url" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.APIVersionStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the APIVersion.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicy" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "AccessControlPolicySpec configures an access control policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpec");
        };
        "status" = mkOption {
          description = "The current status of this access control policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicyStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpec" = {
      options = {
        "apiKey" = mkOption {
          description = "AccessControlPolicyAPIKey configure an APIKey control policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecApiKey");
        };
        "basicAuth" = mkOption {
          description = "AccessControlPolicyBasicAuth holds the HTTP basic authentication configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecBasicAuth");
        };
        "jwt" = mkOption {
          description = "AccessControlPolicyJWT configures a JWT access control policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecJwt");
        };
        "oAuthIntro" = mkOption {
          description = "AccessControlOAuthIntro configures an OAuth 2.0 Token Introspection access control policy.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntro");
        };
        "oidc" = mkOption {
          description = "AccessControlPolicyOIDC holds the OIDC authentication configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidc");
        };
        "oidcGoogle" = mkOption {
          description = "AccessControlPolicyOIDCGoogle holds the Google OIDC authentication configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogle");
        };
      };

      config = {
        "apiKey" = mkOverride 1002 null;
        "basicAuth" = mkOverride 1002 null;
        "jwt" = mkOverride 1002 null;
        "oAuthIntro" = mkOverride 1002 null;
        "oidc" = mkOverride 1002 null;
        "oidcGoogle" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecApiKey" = {
      options = {
        "forwardHeaders" = mkOption {
          description = "ForwardHeaders instructs the middleware to forward key metadata as header values upon successful authentication.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "keySource" = mkOption {
          description = "KeySource defines how to extract API keys from requests.";
          type = submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecApiKeyKeySource";
        };
        "keys" = mkOption {
          description = "Keys define the set of authorized keys to access a protected resource.";
          type = types.nullOr (
            types.listOf (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecApiKeyKeys")
          );
        };
      };

      config = {
        "forwardHeaders" = mkOverride 1002 null;
        "keys" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecApiKeyKeySource" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie is the name of a cookie.";
          type = types.nullOr types.str;
        };
        "header" = mkOption {
          description = "Header is the name of a header.";
          type = types.nullOr types.str;
        };
        "headerAuthScheme" = mkOption {
          description = "HeaderAuthScheme sets an optional auth scheme when Header is set to \"Authorization\".\nIf set, this scheme is removed from the token, and all requests not including it are dropped.";
          type = types.nullOr types.str;
        };
        "query" = mkOption {
          description = "Query is the name of a query parameter.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
        "header" = mkOverride 1002 null;
        "headerAuthScheme" = mkOverride 1002 null;
        "query" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecApiKeyKeys" = {
      options = {
        "id" = mkOption {
          description = "ID is the unique identifier of the key.";
          type = types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "value" = mkOption {
          description = "Value is the SHAKE-256 hash (using 64 bytes) of the API key.";
          type = types.str;
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecBasicAuth" = {
      options = {
        "forwardUsernameHeader" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "realm" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "stripAuthorizationHeader" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "users" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "forwardUsernameHeader" = mkOverride 1002 null;
        "realm" = mkOverride 1002 null;
        "stripAuthorizationHeader" = mkOverride 1002 null;
        "users" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecJwt" = {
      options = {
        "claims" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "forwardHeaders" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "jwksFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "jwksUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "publicKey" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "signingSecret" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "signingSecretBase64Encoded" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "stripAuthorizationHeader" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "tokenQueryKey" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "forwardHeaders" = mkOverride 1002 null;
        "jwksFile" = mkOverride 1002 null;
        "jwksUrl" = mkOverride 1002 null;
        "publicKey" = mkOverride 1002 null;
        "signingSecret" = mkOverride 1002 null;
        "signingSecretBase64Encoded" = mkOverride 1002 null;
        "stripAuthorizationHeader" = mkOverride 1002 null;
        "tokenQueryKey" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntro" = {
      options = {
        "claims" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "clientConfig" = mkOption {
          description = "AccessControlOAuthIntroClientConfig configures the OAuth 2.0 client for issuing token introspection requests.";
          type = submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntroClientConfig";
        };
        "forwardHeaders" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "tokenSource" = mkOption {
          description = "TokenSource describes how to extract tokens from HTTP requests.\nIf multiple sources are set, the order is the following: header > query > cookie.";
          type = submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntroTokenSource";
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "forwardHeaders" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntroClientConfig" = {
      options = {
        "headers" = mkOption {
          description = "Headers to set when sending requests to the Authorization Server.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "maxRetries" = mkOption {
          description = "MaxRetries defines the number of retries for introspection requests.";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "TimeoutSeconds configures the maximum amount of seconds to wait before giving up on requests.";
          type = types.nullOr types.int;
        };
        "tls" = mkOption {
          description = "TLS configures TLS communication with the Authorization Server.";
          type = types.nullOr (
            submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntroClientConfigTls"
          );
        };
        "tokenTypeHint" = mkOption {
          description = "TokenTypeHint is a hint to pass to the Authorization Server.\nSee https://tools.ietf.org/html/rfc7662#section-2.1 for more information.";
          type = types.nullOr types.str;
        };
        "url" = mkOption {
          description = "URL of the Authorization Server.";
          type = types.str;
        };
      };

      config = {
        "headers" = mkOverride 1002 null;
        "maxRetries" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
        "tokenTypeHint" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntroClientConfigTls" = {
      options = {
        "ca" = mkOption {
          description = "CA sets the CA bundle used to sign the Authorization Server certificate.";
          type = types.nullOr types.str;
        };
        "insecureSkipVerify" = mkOption {
          description = "InsecureSkipVerify skips the Authorization Server certificate validation.\nFor testing purposes only, do not use in production.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "ca" = mkOverride 1002 null;
        "insecureSkipVerify" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOAuthIntroTokenSource" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie is the name of a cookie.";
          type = types.nullOr types.str;
        };
        "header" = mkOption {
          description = "Header is the name of a header.";
          type = types.nullOr types.str;
        };
        "headerAuthScheme" = mkOption {
          description = "HeaderAuthScheme sets an optional auth scheme when Header is set to \"Authorization\".\nIf set, this scheme is removed from the token, and all requests not including it are dropped.";
          type = types.nullOr types.str;
        };
        "query" = mkOption {
          description = "Query is the name of a query parameter.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
        "header" = mkOverride 1002 null;
        "headerAuthScheme" = mkOverride 1002 null;
        "query" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidc" = {
      options = {
        "authParams" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "clientId" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "disableAuthRedirectionPaths" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "forwardHeaders" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "issuer" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "logoutUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "redirectUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "scopes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secret" = mkOption {
          description = "SecretReference represents a Secret Reference. It has enough information to retrieve secret\nin any namespace";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcSecret");
        };
        "session" = mkOption {
          description = "Session holds session configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcSession");
        };
        "stateCookie" = mkOption {
          description = "StateCookie holds state cookie configuration.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcStateCookie");
        };
      };

      config = {
        "authParams" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "clientId" = mkOverride 1002 null;
        "disableAuthRedirectionPaths" = mkOverride 1002 null;
        "forwardHeaders" = mkOverride 1002 null;
        "issuer" = mkOverride 1002 null;
        "logoutUrl" = mkOverride 1002 null;
        "redirectUrl" = mkOverride 1002 null;
        "scopes" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "session" = mkOverride 1002 null;
        "stateCookie" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogle" = {
      options = {
        "authParams" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clientId" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "emails" = mkOption {
          description = "Emails are the allowed emails to connect.";
          type = types.nullOr (types.listOf types.str);
        };
        "forwardHeaders" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "logoutUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "redirectUrl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secret" = mkOption {
          description = "SecretReference represents a Secret Reference. It has enough information to retrieve secret\nin any namespace";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogleSecret");
        };
        "session" = mkOption {
          description = "Session holds session configuration.";
          type = types.nullOr (
            submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogleSession"
          );
        };
        "stateCookie" = mkOption {
          description = "StateCookie holds state cookie configuration.";
          type = types.nullOr (
            submoduleOf "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogleStateCookie"
          );
        };
      };

      config = {
        "authParams" = mkOverride 1002 null;
        "clientId" = mkOverride 1002 null;
        "emails" = mkOverride 1002 null;
        "forwardHeaders" = mkOverride 1002 null;
        "logoutUrl" = mkOverride 1002 null;
        "redirectUrl" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "session" = mkOverride 1002 null;
        "stateCookie" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogleSecret" = {
      options = {
        "name" = mkOption {
          description = "name is unique within a namespace to reference a secret resource.";
          type = types.nullOr types.str;
        };
        "namespace" = mkOption {
          description = "namespace defines the space within which the secret name must be unique.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogleSession" = {
      options = {
        "domain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "refresh" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "sameSite" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "refresh" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcGoogleStateCookie" = {
      options = {
        "domain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcSecret" = {
      options = {
        "name" = mkOption {
          description = "name is unique within a namespace to reference a secret resource.";
          type = types.nullOr types.str;
        };
        "namespace" = mkOption {
          description = "namespace defines the space within which the secret name must be unique.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcSession" = {
      options = {
        "domain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "refresh" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "sameSite" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "refresh" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicySpecOidcStateCookie" = {
      options = {
        "domain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.AccessControlPolicyStatus" = {
      options = {
        "specHash" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "specHash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedApplication" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "ManagedApplicationSpec describes the ManagedApplication.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.ManagedApplicationSpec");
        };
        "status" = mkOption {
          description = "The current status of this ManagedApplication.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.ManagedApplicationStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedApplicationSpec" = {
      options = {
        "apiKeys" = mkOption {
          description = "APIKeys references the API keys used to authenticate the application when calling APIs.";
          type = types.nullOr (
            types.listOf (submoduleOf "hub.traefik.io.v1alpha1.ManagedApplicationSpecApiKeys")
          );
        };
        "appId" = mkOption {
          description = "AppID is the identifier of the ManagedApplication.\nIt should be unique.";
          type = types.str;
        };
        "notes" = mkOption {
          description = "Notes contains notes about application.";
          type = types.nullOr types.str;
        };
        "owner" = mkOption {
          description = "Owner represents the owner of the ManagedApplication.\nIt should be:\n- `sub` when using OIDC\n- `externalID` when using external IDP";
          type = types.str;
        };
      };

      config = {
        "apiKeys" = mkOverride 1002 null;
        "notes" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedApplicationSpecApiKeys" = {
      options = {
        "secretName" = mkOption {
          description = "SecretName references the name of the secret containing the API key.";
          type = types.nullOr types.str;
        };
        "suspended" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "title" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "value" = mkOption {
          description = "Value is the API key value.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "secretName" = mkOverride 1002 null;
        "suspended" = mkOverride 1002 null;
        "title" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedApplicationStatus" = {
      options = {
        "apiKeyVersions" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "hash" = mkOption {
          description = "Hash is a hash representing the ManagedApplication.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiKeyVersions" = mkOverride 1002 null;
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscription" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "The desired behavior of this ManagedSubscription.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionSpec");
        };
        "status" = mkOption {
          description = "The current status of this ManagedSubscription.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpec" = {
      options = {
        "apiBundles" = mkOption {
          description = "APIBundles defines a set of APIBundle that will be accessible.\nMultiple ManagedSubscriptions can select the same APIBundles.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiBundles"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "apiPlan" = mkOption {
          description = "APIPlan defines which APIPlan will be used.";
          type = submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiPlan";
        };
        "apiSelector" = mkOption {
          description = "APISelector selects the APIs that will be accessible.\nMultiple ManagedSubscriptions can select the same set of APIs.\nThis field is optional and follows standard label selector semantics.\nAn empty APISelector matches any API.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiSelector");
        };
        "apis" = mkOption {
          description = "APIs defines a set of APIs that will be accessible.\nMultiple ManagedSubscriptions can select the same APIs.\nWhen combined with APISelector, this set of APIs is appended to the matching APIs.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApis" "name" [ ]
          );
          apply = attrsToList;
        };
        "applications" = mkOption {
          description = "Applications references the Applications that will gain access to the specified APIs.\nMultiple ManagedSubscriptions can select the same AppID.\nDeprecated: Use ManagedApplications instead.";
          type = types.nullOr (
            types.listOf (submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApplications")
          );
        };
        "claims" = mkOption {
          description = "Claims specifies an expression that validate claims in order to authorize the request.";
          type = types.nullOr types.str;
        };
        "managedApplications" = mkOption {
          description = "ManagedApplications references the ManagedApplications that will gain access to the specified APIs.\nMultiple ManagedSubscriptions can select the same ManagedApplication.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecManagedApplications"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "operationFilter" = mkOption {
          description = "OperationFilter specifies the allowed operations on APIs and APIVersions.\nIf not set, all operations are available.\nAn empty OperationFilter prohibits all operations.";
          type = types.nullOr (submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecOperationFilter");
        };
        "weight" = mkOption {
          description = "Weight specifies the evaluation order of the APIPlan.\nWhen multiple ManagedSubscriptions targets the same API and Application with different APIPlan,\nthe APIPlan with the highest weight will be enforced. If weights are equal, alphabetical order is used.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "apiBundles" = mkOverride 1002 null;
        "apiSelector" = mkOverride 1002 null;
        "apis" = mkOverride 1002 null;
        "applications" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "managedApplications" = mkOverride 1002 null;
        "operationFilter" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiBundles" = {
      options = {
        "name" = mkOption {
          description = "Name of the APIBundle.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiPlan" = {
      options = {
        "name" = mkOption {
          description = "Name of the APIPlan.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiSelector" = {
      options = {
        "matchExpressions" = mkOption {
          description = "matchExpressions is a list of label selector requirements. The requirements are ANDed.";
          type = types.nullOr (
            types.listOf (
              submoduleOf "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "matchLabels is a map of {key,value} pairs. A single {key,value} in the matchLabels\nmap is equivalent to an element of matchExpressions, whose key field is \"key\", the\noperator is \"In\", and the values array contains only \"value\". The requirements are ANDed.";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApiSelectorMatchExpressions" = {
      options = {
        "key" = mkOption {
          description = "key is the label key that the selector applies to.";
          type = types.str;
        };
        "operator" = mkOption {
          description = "operator represents a key's relationship to a set of values.\nValid operators are In, NotIn, Exists and DoesNotExist.";
          type = types.str;
        };
        "values" = mkOption {
          description = "values is an array of string values. If the operator is In or NotIn,\nthe values array must be non-empty. If the operator is Exists or DoesNotExist,\nthe values array must be empty. This array is replaced during a strategic\nmerge patch.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApis" = {
      options = {
        "name" = mkOption {
          description = "Name of the API.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecApplications" = {
      options = {
        "appId" = mkOption {
          description = "AppID is the public identifier of the application.\nIn the case of OIDC, it corresponds to the clientId.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecManagedApplications" = {
      options = {
        "name" = mkOption {
          description = "Name is the name of the ManagedApplication.";
          type = types.str;
        };
      };

      config = { };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionSpecOperationFilter" = {
      options = {
        "include" = mkOption {
          description = "Include defines the names of OperationSets that will be accessible.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "include" = mkOverride 1002 null;
      };
    };
    "hub.traefik.io.v1alpha1.ManagedSubscriptionStatus" = {
      options = {
        "hash" = mkOption {
          description = "Hash is a hash representing the ManagedSubscription.";
          type = types.nullOr types.str;
        };
        "syncedAt" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hash" = mkOverride 1002 null;
        "syncedAt" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRoute" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "IngressRouteSpec defines the desired state of IngressRoute.";
          type = submoduleOf "traefik.io.v1alpha1.IngressRouteSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpec" = {
      options = {
        "entryPoints" = mkOption {
          description = "EntryPoints defines the list of entry point names to bind to.\nEntry points have to be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/entrypoints/\nDefault: all.";
          type = types.nullOr (types.listOf types.str);
        };
        "routes" = mkOption {
          description = "Routes defines the list of routes.";
          type = types.listOf (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecRoutes");
        };
        "tls" = mkOption {
          description = "TLS defines the TLS configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#tls";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecTls");
        };
      };

      config = {
        "entryPoints" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutes" = {
      options = {
        "kind" = mkOption {
          description = "Kind defines the kind of the route.\nRule is the only supported kind.\nIf not defined, defaults to Rule.";
          type = types.nullOr types.str;
        };
        "match" = mkOption {
          description = "Match defines the router's rule.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#rule";
          type = types.str;
        };
        "middlewares" = mkOption {
          description = "Middlewares defines the list of references to Middleware resources.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-middleware";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.IngressRouteSpecRoutesMiddlewares" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "observability" = mkOption {
          description = "Observability defines the observability configuration for a router.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#observability";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecRoutesObservability");
        };
        "priority" = mkOption {
          description = "Priority defines the router's priority.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#priority";
          type = types.nullOr types.int;
        };
        "services" = mkOption {
          description = "Services defines the list of Service.\nIt can contain any combination of TraefikService and/or reference to a Kubernetes Service.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.IngressRouteSpecRoutesServices" "name" [ ]
          );
          apply = attrsToList;
        };
        "syntax" = mkOption {
          description = "Syntax defines the router's rule syntax.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#rulesyntax\nDeprecated: Please do not use this field and rewrite the router rules to use the v3 syntax.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
        "middlewares" = mkOverride 1002 null;
        "observability" = mkOverride 1002 null;
        "priority" = mkOverride 1002 null;
        "services" = mkOverride 1002 null;
        "syntax" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesMiddlewares" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Middleware resource.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Middleware resource.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesObservability" = {
      options = {
        "accessLogs" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "metrics" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "tracing" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "accessLogs" = mkOverride 1002 null;
        "metrics" = mkOverride 1002 null;
        "tracing" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesServices" = {
      options = {
        "healthCheck" = mkOption {
          description = "Healthcheck defines health checks for ExternalName services.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesHealthCheck");
        };
        "kind" = mkOption {
          description = "Kind defines the kind of the Service.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service or TraefikService.\nThe differentiation between the two is specified in the Kind field.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service or TraefikService.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "passHostHeader" = mkOption {
          description = "PassHostHeader defines whether the client Host header is forwarded to the upstream Kubernetes Service.\nBy default, passHostHeader is true.";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseForwarding" = mkOption {
          description = "ResponseForwarding defines how Traefik forwards the response from the upstream Kubernetes Service to the client.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesResponseForwarding"
          );
        };
        "scheme" = mkOption {
          description = "Scheme defines the scheme to use for the request to the upstream Kubernetes Service.\nIt defaults to https when Kubernetes Service port is 443, http otherwise.";
          type = types.nullOr types.str;
        };
        "serversTransport" = mkOption {
          description = "ServersTransport defines the name of ServersTransport resource to use.\nIt allows to configure the transport between Traefik and your servers.\nCan only be used on a Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "sticky" = mkOption {
          description = "Sticky defines the sticky sessions configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#sticky-sessions";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesSticky");
        };
        "strategy" = mkOption {
          description = "Strategy defines the load balancing strategy between the servers.\nSupported values are: wrr (Weighed round-robin) and p2c (Power of two choices).\nRoundRobin value is deprecated and supported for backward compatibility.";
          type = types.nullOr types.str;
        };
        "weight" = mkOption {
          description = "Weight defines the weight and should only be specified when Name references a TraefikService object\n(and to be precise, one that embeds a Weighted Round Robin).";
          type = types.nullOr types.int;
        };
      };

      config = {
        "healthCheck" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "passHostHeader" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "responseForwarding" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "serversTransport" = mkOverride 1002 null;
        "sticky" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesHealthCheck" = {
      options = {
        "followRedirects" = mkOption {
          description = "FollowRedirects defines whether redirects should be followed during the health check calls.\nDefault: true";
          type = types.nullOr types.bool;
        };
        "headers" = mkOption {
          description = "Headers defines custom headers to be sent to the health check endpoint.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "hostname" = mkOption {
          description = "Hostname defines the value of hostname in the Host header of the health check request.";
          type = types.nullOr types.str;
        };
        "interval" = mkOption {
          description = "Interval defines the frequency of the health check calls.\nDefault: 30s";
          type = types.nullOr (types.either types.int types.str);
        };
        "method" = mkOption {
          description = "Method defines the healthcheck method.";
          type = types.nullOr types.str;
        };
        "mode" = mkOption {
          description = "Mode defines the health check mode.\nIf defined to grpc, will use the gRPC health check protocol to probe the server.\nDefault: http";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the server URL path for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Port defines the server URL port for the health check endpoint.";
          type = types.nullOr types.int;
        };
        "scheme" = mkOption {
          description = "Scheme replaces the server URL scheme for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "Status defines the expected HTTP status code of the response to the health check request.";
          type = types.nullOr types.int;
        };
        "timeout" = mkOption {
          description = "Timeout defines the maximum duration Traefik will wait for a health check request before considering the server unhealthy.\nDefault: 5s";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "followRedirects" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "interval" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "timeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesResponseForwarding" = {
      options = {
        "flushInterval" = mkOption {
          description = "FlushInterval defines the interval, in milliseconds, in between flushes to the client while copying the response body.\nA negative value means to flush immediately after each write to the client.\nThis configuration is ignored when ReverseProxy recognizes a response as a streaming response;\nfor such responses, writes are flushed to the client immediately.\nDefault: 100ms";
          type = types.nullOr types.str;
        };
      };

      config = {
        "flushInterval" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesSticky" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie defines the sticky cookie configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesStickyCookie");
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecRoutesServicesStickyCookie" = {
      options = {
        "domain" = mkOption {
          description = "Domain defines the host to which the cookie will be sent.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#domaindomain-value";
          type = types.nullOr types.str;
        };
        "httpOnly" = mkOption {
          description = "HTTPOnly defines whether the cookie can be accessed by client-side APIs, such as JavaScript.";
          type = types.nullOr types.bool;
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the number of seconds until the cookie expires.\nWhen set to a negative number, the cookie expires immediately.\nWhen set to zero, the cookie never expires.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "Name defines the Cookie name.";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the path that must exist in the requested URL for the browser to send the Cookie header.\nWhen not provided the cookie will be sent on every request to the domain.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#pathpath-value";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "SameSite defines the same site policy.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "Secure defines whether the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "httpOnly" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecTls" = {
      options = {
        "certResolver" = mkOption {
          description = "CertResolver defines the name of the certificate resolver to use.\nCert resolvers have to be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/https/acme/#certificate-resolvers";
          type = types.nullOr types.str;
        };
        "domains" = mkOption {
          description = "Domains defines the list of domains that will be used to issue certificates.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#domains";
          type = types.nullOr (types.listOf (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecTlsDomains"));
        };
        "options" = mkOption {
          description = "Options defines the reference to a TLSOption, that specifies the parameters of the TLS connection.\nIf not defined, the `default` TLSOption is used.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#tls-options";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecTlsOptions");
        };
        "secretName" = mkOption {
          description = "SecretName is the name of the referenced Kubernetes Secret to specify the certificate details.";
          type = types.nullOr types.str;
        };
        "store" = mkOption {
          description = "Store defines the reference to the TLSStore, that will be used to store certificates.\nPlease note that only `default` TLSStore can be used.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteSpecTlsStore");
        };
      };

      config = {
        "certResolver" = mkOverride 1002 null;
        "domains" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
        "store" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecTlsDomains" = {
      options = {
        "main" = mkOption {
          description = "Main defines the main domain name.";
          type = types.nullOr types.str;
        };
        "sans" = mkOption {
          description = "SANs defines the subject alternative domain names.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "main" = mkOverride 1002 null;
        "sans" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecTlsOptions" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced TLSOption.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-tlsoption";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced TLSOption.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-tlsoption";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteSpecTlsStore" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced TLSStore.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-tlsstore";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced TLSStore.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-tlsstore";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCP" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "IngressRouteTCPSpec defines the desired state of IngressRouteTCP.";
          type = submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpec" = {
      options = {
        "entryPoints" = mkOption {
          description = "EntryPoints defines the list of entry point names to bind to.\nEntry points have to be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/entrypoints/\nDefault: all.";
          type = types.nullOr (types.listOf types.str);
        };
        "routes" = mkOption {
          description = "Routes defines the list of routes.";
          type = types.listOf (submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpecRoutes");
        };
        "tls" = mkOption {
          description = "TLS defines the TLS configuration on a layer 4 / TCP Route.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#tls_1";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpecTls");
        };
      };

      config = {
        "entryPoints" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecRoutes" = {
      options = {
        "match" = mkOption {
          description = "Match defines the router's rule.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#rule_1";
          type = types.str;
        };
        "middlewares" = mkOption {
          description = "Middlewares defines the list of references to MiddlewareTCP resources.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.IngressRouteTCPSpecRoutesMiddlewares" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "priority" = mkOption {
          description = "Priority defines the router's priority.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#priority_1";
          type = types.nullOr types.int;
        };
        "services" = mkOption {
          description = "Services defines the list of TCP services.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.IngressRouteTCPSpecRoutesServices" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "syntax" = mkOption {
          description = "Syntax defines the router's rule syntax.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#rulesyntax_1\nDeprecated: Please do not use this field and rewrite the router rules to use the v3 syntax.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "middlewares" = mkOverride 1002 null;
        "priority" = mkOverride 1002 null;
        "services" = mkOverride 1002 null;
        "syntax" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecRoutesMiddlewares" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Traefik resource.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Traefik resource.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecRoutesServices" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.either types.int types.str;
        };
        "proxyProtocol" = mkOption {
          description = "ProxyProtocol defines the PROXY protocol configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#proxy-protocol";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpecRoutesServicesProxyProtocol"
          );
        };
        "serversTransport" = mkOption {
          description = "ServersTransport defines the name of ServersTransportTCP resource to use.\nIt allows to configure the transport between Traefik and your servers.\nCan only be used on a Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "terminationDelay" = mkOption {
          description = "TerminationDelay defines the deadline that the proxy sets, after one of its connected peers indicates\nit has closed the writing capability of its connection, to close the reading capability as well,\nhence fully terminating the connection.\nIt is a duration in milliseconds, defaulting to 100.\nA negative value means an infinite deadline (i.e. the reading capability is never closed).\nDeprecated: TerminationDelay will not be supported in future APIVersions, please use ServersTransport to configure the TerminationDelay instead.";
          type = types.nullOr types.int;
        };
        "tls" = mkOption {
          description = "TLS determines whether to use TLS when dialing with the backend.";
          type = types.nullOr types.bool;
        };
        "weight" = mkOption {
          description = "Weight defines the weight used when balancing requests between multiple Kubernetes Service.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "proxyProtocol" = mkOverride 1002 null;
        "serversTransport" = mkOverride 1002 null;
        "terminationDelay" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecRoutesServicesProxyProtocol" = {
      options = {
        "version" = mkOption {
          description = "Version defines the PROXY Protocol version to use.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "version" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecTls" = {
      options = {
        "certResolver" = mkOption {
          description = "CertResolver defines the name of the certificate resolver to use.\nCert resolvers have to be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/https/acme/#certificate-resolvers";
          type = types.nullOr types.str;
        };
        "domains" = mkOption {
          description = "Domains defines the list of domains that will be used to issue certificates.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/routers/#domains";
          type = types.nullOr (
            types.listOf (submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpecTlsDomains")
          );
        };
        "options" = mkOption {
          description = "Options defines the reference to a TLSOption, that specifies the parameters of the TLS connection.\nIf not defined, the `default` TLSOption is used.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#tls-options";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpecTlsOptions");
        };
        "passthrough" = mkOption {
          description = "Passthrough defines whether a TLS router will terminate the TLS connection.";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "SecretName is the name of the referenced Kubernetes Secret to specify the certificate details.";
          type = types.nullOr types.str;
        };
        "store" = mkOption {
          description = "Store defines the reference to the TLSStore, that will be used to store certificates.\nPlease note that only `default` TLSStore can be used.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.IngressRouteTCPSpecTlsStore");
        };
      };

      config = {
        "certResolver" = mkOverride 1002 null;
        "domains" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "passthrough" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
        "store" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecTlsDomains" = {
      options = {
        "main" = mkOption {
          description = "Main defines the main domain name.";
          type = types.nullOr types.str;
        };
        "sans" = mkOption {
          description = "SANs defines the subject alternative domain names.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "main" = mkOverride 1002 null;
        "sans" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecTlsOptions" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Traefik resource.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Traefik resource.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteTCPSpecTlsStore" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Traefik resource.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Traefik resource.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteUDP" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "IngressRouteUDPSpec defines the desired state of a IngressRouteUDP.";
          type = submoduleOf "traefik.io.v1alpha1.IngressRouteUDPSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteUDPSpec" = {
      options = {
        "entryPoints" = mkOption {
          description = "EntryPoints defines the list of entry point names to bind to.\nEntry points have to be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/entrypoints/\nDefault: all.";
          type = types.nullOr (types.listOf types.str);
        };
        "routes" = mkOption {
          description = "Routes defines the list of routes.";
          type = types.listOf (submoduleOf "traefik.io.v1alpha1.IngressRouteUDPSpecRoutes");
        };
      };

      config = {
        "entryPoints" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteUDPSpecRoutes" = {
      options = {
        "services" = mkOption {
          description = "Services defines the list of UDP services.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.IngressRouteUDPSpecRoutesServices" "name"
              [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "services" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.IngressRouteUDPSpecRoutesServices" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.either types.int types.str;
        };
        "weight" = mkOption {
          description = "Weight defines the weight used when balancing requests between multiple Kubernetes Service.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.Middleware" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "MiddlewareSpec defines the desired state of a Middleware.";
          type = submoduleOf "traefik.io.v1alpha1.MiddlewareSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpec" = {
      options = {
        "addPrefix" = mkOption {
          description = "AddPrefix holds the add prefix middleware configuration.\nThis middleware updates the path of a request before forwarding it.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/addprefix/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecAddPrefix");
        };
        "basicAuth" = mkOption {
          description = "BasicAuth holds the basic auth middleware configuration.\nThis middleware restricts access to your services to known users.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/basicauth/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecBasicAuth");
        };
        "buffering" = mkOption {
          description = "Buffering holds the buffering middleware configuration.\nThis middleware retries or limits the size of requests that can be forwarded to backends.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/buffering/#maxrequestbodybytes";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecBuffering");
        };
        "chain" = mkOption {
          description = "Chain holds the configuration of the chain middleware.\nThis middleware enables to define reusable combinations of other pieces of middleware.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/chain/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecChain");
        };
        "circuitBreaker" = mkOption {
          description = "CircuitBreaker holds the circuit breaker configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecCircuitBreaker");
        };
        "compress" = mkOption {
          description = "Compress holds the compress middleware configuration.\nThis middleware compresses responses before sending them to the client, using gzip, brotli, or zstd compression.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/compress/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecCompress");
        };
        "contentType" = mkOption {
          description = "ContentType holds the content-type middleware configuration.\nThis middleware exists to enable the correct behavior until at least the default one can be changed in a future version.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecContentType");
        };
        "digestAuth" = mkOption {
          description = "DigestAuth holds the digest auth middleware configuration.\nThis middleware restricts access to your services to known users.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/digestauth/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecDigestAuth");
        };
        "errors" = mkOption {
          description = "ErrorPage holds the custom error middleware configuration.\nThis middleware returns a custom page in lieu of the default, according to configured ranges of HTTP Status codes.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/errorpages/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecErrors");
        };
        "forwardAuth" = mkOption {
          description = "ForwardAuth holds the forward auth middleware configuration.\nThis middleware delegates the request authentication to a Service.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/forwardauth/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecForwardAuth");
        };
        "grpcWeb" = mkOption {
          description = "GrpcWeb holds the gRPC web middleware configuration.\nThis middleware converts a gRPC web request to an HTTP/2 gRPC request.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecGrpcWeb");
        };
        "headers" = mkOption {
          description = "Headers holds the headers middleware configuration.\nThis middleware manages the requests and responses headers.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/headers/#customrequestheaders";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecHeaders");
        };
        "inFlightReq" = mkOption {
          description = "InFlightReq holds the in-flight request middleware configuration.\nThis middleware limits the number of requests being processed and served concurrently.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/inflightreq/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecInFlightReq");
        };
        "ipAllowList" = mkOption {
          description = "IPAllowList holds the IP allowlist middleware configuration.\nThis middleware limits allowed requests based on the client IP.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/ipallowlist/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecIpAllowList");
        };
        "ipWhiteList" = mkOption {
          description = "Deprecated: please use IPAllowList instead.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecIpWhiteList");
        };
        "passTLSClientCert" = mkOption {
          description = "PassTLSClientCert holds the pass TLS client cert middleware configuration.\nThis middleware adds the selected data from the passed client TLS certificate to a header.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/passtlsclientcert/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCert");
        };
        "plugin" = mkOption {
          description = "Plugin defines the middleware plugin configuration.\nMore info: https://doc.traefik.io/traefik/plugins/";
          type = types.nullOr types.attrs;
        };
        "rateLimit" = mkOption {
          description = "RateLimit holds the rate limit configuration.\nThis middleware ensures that services will receive a fair amount of requests, and allows one to define what fair is.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/ratelimit/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRateLimit");
        };
        "redirectRegex" = mkOption {
          description = "RedirectRegex holds the redirect regex middleware configuration.\nThis middleware redirects a request using regex matching and replacement.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/redirectregex/#regex";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRedirectRegex");
        };
        "redirectScheme" = mkOption {
          description = "RedirectScheme holds the redirect scheme middleware configuration.\nThis middleware redirects requests from a scheme/port to another.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/redirectscheme/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRedirectScheme");
        };
        "replacePath" = mkOption {
          description = "ReplacePath holds the replace path middleware configuration.\nThis middleware replaces the path of the request URL and store the original path in an X-Replaced-Path header.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/replacepath/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecReplacePath");
        };
        "replacePathRegex" = mkOption {
          description = "ReplacePathRegex holds the replace path regex middleware configuration.\nThis middleware replaces the path of a URL using regex matching and replacement.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/replacepathregex/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecReplacePathRegex");
        };
        "retry" = mkOption {
          description = "Retry holds the retry middleware configuration.\nThis middleware reissues requests a given number of times to a backend server if that server does not reply.\nAs soon as the server answers, the middleware stops retrying, regardless of the response status.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/retry/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRetry");
        };
        "stripPrefix" = mkOption {
          description = "StripPrefix holds the strip prefix middleware configuration.\nThis middleware removes the specified prefixes from the URL path.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/stripprefix/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecStripPrefix");
        };
        "stripPrefixRegex" = mkOption {
          description = "StripPrefixRegex holds the strip prefix regex middleware configuration.\nThis middleware removes the matching prefixes from the URL path.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/stripprefixregex/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecStripPrefixRegex");
        };
      };

      config = {
        "addPrefix" = mkOverride 1002 null;
        "basicAuth" = mkOverride 1002 null;
        "buffering" = mkOverride 1002 null;
        "chain" = mkOverride 1002 null;
        "circuitBreaker" = mkOverride 1002 null;
        "compress" = mkOverride 1002 null;
        "contentType" = mkOverride 1002 null;
        "digestAuth" = mkOverride 1002 null;
        "errors" = mkOverride 1002 null;
        "forwardAuth" = mkOverride 1002 null;
        "grpcWeb" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "inFlightReq" = mkOverride 1002 null;
        "ipAllowList" = mkOverride 1002 null;
        "ipWhiteList" = mkOverride 1002 null;
        "passTLSClientCert" = mkOverride 1002 null;
        "plugin" = mkOverride 1002 null;
        "rateLimit" = mkOverride 1002 null;
        "redirectRegex" = mkOverride 1002 null;
        "redirectScheme" = mkOverride 1002 null;
        "replacePath" = mkOverride 1002 null;
        "replacePathRegex" = mkOverride 1002 null;
        "retry" = mkOverride 1002 null;
        "stripPrefix" = mkOverride 1002 null;
        "stripPrefixRegex" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecAddPrefix" = {
      options = {
        "prefix" = mkOption {
          description = "Prefix is the string to add before the current path in the requested URL.\nIt should include a leading slash (/).";
          type = types.nullOr types.str;
        };
      };

      config = {
        "prefix" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecBasicAuth" = {
      options = {
        "headerField" = mkOption {
          description = "HeaderField defines a header field to store the authenticated user.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/basicauth/#headerfield";
          type = types.nullOr types.str;
        };
        "realm" = mkOption {
          description = "Realm allows the protected resources on a server to be partitioned into a set of protection spaces, each with its own authentication scheme.\nDefault: traefik.";
          type = types.nullOr types.str;
        };
        "removeHeader" = mkOption {
          description = "RemoveHeader sets the removeHeader option to true to remove the authorization header before forwarding the request to your service.\nDefault: false.";
          type = types.nullOr types.bool;
        };
        "secret" = mkOption {
          description = "Secret is the name of the referenced Kubernetes Secret containing user credentials.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "headerField" = mkOverride 1002 null;
        "realm" = mkOverride 1002 null;
        "removeHeader" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecBuffering" = {
      options = {
        "maxRequestBodyBytes" = mkOption {
          description = "MaxRequestBodyBytes defines the maximum allowed body size for the request (in bytes).\nIf the request exceeds the allowed size, it is not forwarded to the service, and the client gets a 413 (Request Entity Too Large) response.\nDefault: 0 (no maximum).";
          type = types.nullOr types.int;
        };
        "maxResponseBodyBytes" = mkOption {
          description = "MaxResponseBodyBytes defines the maximum allowed response size from the service (in bytes).\nIf the response exceeds the allowed size, it is not forwarded to the client. The client gets a 500 (Internal Server Error) response instead.\nDefault: 0 (no maximum).";
          type = types.nullOr types.int;
        };
        "memRequestBodyBytes" = mkOption {
          description = "MemRequestBodyBytes defines the threshold (in bytes) from which the request will be buffered on disk instead of in memory.\nDefault: 1048576 (1Mi).";
          type = types.nullOr types.int;
        };
        "memResponseBodyBytes" = mkOption {
          description = "MemResponseBodyBytes defines the threshold (in bytes) from which the response will be buffered on disk instead of in memory.\nDefault: 1048576 (1Mi).";
          type = types.nullOr types.int;
        };
        "retryExpression" = mkOption {
          description = "RetryExpression defines the retry conditions.\nIt is a logical combination of functions with operators AND (&&) and OR (||).\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/buffering/#retryexpression";
          type = types.nullOr types.str;
        };
      };

      config = {
        "maxRequestBodyBytes" = mkOverride 1002 null;
        "maxResponseBodyBytes" = mkOverride 1002 null;
        "memRequestBodyBytes" = mkOverride 1002 null;
        "memResponseBodyBytes" = mkOverride 1002 null;
        "retryExpression" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecChain" = {
      options = {
        "middlewares" = mkOption {
          description = "Middlewares is the list of MiddlewareRef which composes the chain.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.MiddlewareSpecChainMiddlewares" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "middlewares" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecChainMiddlewares" = {
      options = {
        "name" = mkOption {
          description = "Name defines the name of the referenced Middleware resource.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Middleware resource.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecCircuitBreaker" = {
      options = {
        "checkPeriod" = mkOption {
          description = "CheckPeriod is the interval between successive checks of the circuit breaker condition (when in standby state).";
          type = types.nullOr (types.either types.int types.str);
        };
        "expression" = mkOption {
          description = "Expression is the condition that triggers the tripped state.";
          type = types.nullOr types.str;
        };
        "fallbackDuration" = mkOption {
          description = "FallbackDuration is the duration for which the circuit breaker will wait before trying to recover (from a tripped state).";
          type = types.nullOr (types.either types.int types.str);
        };
        "recoveryDuration" = mkOption {
          description = "RecoveryDuration is the duration for which the circuit breaker will try to recover (as soon as it is in recovering state).";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseCode" = mkOption {
          description = "ResponseCode is the status code that the circuit breaker will return while it is in the open state.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "checkPeriod" = mkOverride 1002 null;
        "expression" = mkOverride 1002 null;
        "fallbackDuration" = mkOverride 1002 null;
        "recoveryDuration" = mkOverride 1002 null;
        "responseCode" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecCompress" = {
      options = {
        "defaultEncoding" = mkOption {
          description = "DefaultEncoding specifies the default encoding if the `Accept-Encoding` header is not in the request or contains a wildcard (`*`).";
          type = types.nullOr types.str;
        };
        "encodings" = mkOption {
          description = "Encodings defines the list of supported compression algorithms.";
          type = types.nullOr (types.listOf types.str);
        };
        "excludedContentTypes" = mkOption {
          description = "ExcludedContentTypes defines the list of content types to compare the Content-Type header of the incoming requests and responses before compressing.\n`application/grpc` is always excluded.";
          type = types.nullOr (types.listOf types.str);
        };
        "includedContentTypes" = mkOption {
          description = "IncludedContentTypes defines the list of content types to compare the Content-Type header of the responses before compressing.";
          type = types.nullOr (types.listOf types.str);
        };
        "minResponseBodyBytes" = mkOption {
          description = "MinResponseBodyBytes defines the minimum amount of bytes a response body must have to be compressed.\nDefault: 1024.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "defaultEncoding" = mkOverride 1002 null;
        "encodings" = mkOverride 1002 null;
        "excludedContentTypes" = mkOverride 1002 null;
        "includedContentTypes" = mkOverride 1002 null;
        "minResponseBodyBytes" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecContentType" = {
      options = {
        "autoDetect" = mkOption {
          description = "AutoDetect specifies whether to let the `Content-Type` header, if it has not been set by the backend,\nbe automatically set to a value derived from the contents of the response.\nDeprecated: AutoDetect option is deprecated, Content-Type middleware is only meant to be used to enable the content-type detection, please remove any usage of this option.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "autoDetect" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecDigestAuth" = {
      options = {
        "headerField" = mkOption {
          description = "HeaderField defines a header field to store the authenticated user.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/basicauth/#headerfield";
          type = types.nullOr types.str;
        };
        "realm" = mkOption {
          description = "Realm allows the protected resources on a server to be partitioned into a set of protection spaces, each with its own authentication scheme.\nDefault: traefik.";
          type = types.nullOr types.str;
        };
        "removeHeader" = mkOption {
          description = "RemoveHeader defines whether to remove the authorization header before forwarding the request to the backend.";
          type = types.nullOr types.bool;
        };
        "secret" = mkOption {
          description = "Secret is the name of the referenced Kubernetes Secret containing user credentials.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "headerField" = mkOverride 1002 null;
        "realm" = mkOverride 1002 null;
        "removeHeader" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecErrors" = {
      options = {
        "query" = mkOption {
          description = "Query defines the URL for the error page (hosted by service).\nThe {status} variable can be used in order to insert the status code in the URL.\nThe {originalStatus} variable can be used in order to insert the upstream status code in the URL.\nThe {url} variable can be used in order to insert the escaped request URL.";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "Service defines the reference to a Kubernetes Service that will serve the error page.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/errorpages/#service";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecErrorsService");
        };
        "status" = mkOption {
          description = "Status defines which status or range of statuses should result in an error page.\nIt can be either a status code as a number (500),\nas multiple comma-separated numbers (500,502),\nas ranges by separating two codes with a dash (500-599),\nor a combination of the two (404,418,500-599).";
          type = types.nullOr (types.listOf types.str);
        };
        "statusRewrites" = mkOption {
          description = "StatusRewrites defines a mapping of status codes that should be returned instead of the original error status codes.\nFor example: \"418\": 404 or \"410-418\": 404";
          type = types.nullOr (types.attrsOf types.int);
        };
      };

      config = {
        "query" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "statusRewrites" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecErrorsService" = {
      options = {
        "healthCheck" = mkOption {
          description = "Healthcheck defines health checks for ExternalName services.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceHealthCheck");
        };
        "kind" = mkOption {
          description = "Kind defines the kind of the Service.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service or TraefikService.\nThe differentiation between the two is specified in the Kind field.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service or TraefikService.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "passHostHeader" = mkOption {
          description = "PassHostHeader defines whether the client Host header is forwarded to the upstream Kubernetes Service.\nBy default, passHostHeader is true.";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseForwarding" = mkOption {
          description = "ResponseForwarding defines how Traefik forwards the response from the upstream Kubernetes Service to the client.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceResponseForwarding"
          );
        };
        "scheme" = mkOption {
          description = "Scheme defines the scheme to use for the request to the upstream Kubernetes Service.\nIt defaults to https when Kubernetes Service port is 443, http otherwise.";
          type = types.nullOr types.str;
        };
        "serversTransport" = mkOption {
          description = "ServersTransport defines the name of ServersTransport resource to use.\nIt allows to configure the transport between Traefik and your servers.\nCan only be used on a Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "sticky" = mkOption {
          description = "Sticky defines the sticky sessions configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#sticky-sessions";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceSticky");
        };
        "strategy" = mkOption {
          description = "Strategy defines the load balancing strategy between the servers.\nSupported values are: wrr (Weighed round-robin) and p2c (Power of two choices).\nRoundRobin value is deprecated and supported for backward compatibility.";
          type = types.nullOr types.str;
        };
        "weight" = mkOption {
          description = "Weight defines the weight and should only be specified when Name references a TraefikService object\n(and to be precise, one that embeds a Weighted Round Robin).";
          type = types.nullOr types.int;
        };
      };

      config = {
        "healthCheck" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "passHostHeader" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "responseForwarding" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "serversTransport" = mkOverride 1002 null;
        "sticky" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceHealthCheck" = {
      options = {
        "followRedirects" = mkOption {
          description = "FollowRedirects defines whether redirects should be followed during the health check calls.\nDefault: true";
          type = types.nullOr types.bool;
        };
        "headers" = mkOption {
          description = "Headers defines custom headers to be sent to the health check endpoint.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "hostname" = mkOption {
          description = "Hostname defines the value of hostname in the Host header of the health check request.";
          type = types.nullOr types.str;
        };
        "interval" = mkOption {
          description = "Interval defines the frequency of the health check calls.\nDefault: 30s";
          type = types.nullOr (types.either types.int types.str);
        };
        "method" = mkOption {
          description = "Method defines the healthcheck method.";
          type = types.nullOr types.str;
        };
        "mode" = mkOption {
          description = "Mode defines the health check mode.\nIf defined to grpc, will use the gRPC health check protocol to probe the server.\nDefault: http";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the server URL path for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Port defines the server URL port for the health check endpoint.";
          type = types.nullOr types.int;
        };
        "scheme" = mkOption {
          description = "Scheme replaces the server URL scheme for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "Status defines the expected HTTP status code of the response to the health check request.";
          type = types.nullOr types.int;
        };
        "timeout" = mkOption {
          description = "Timeout defines the maximum duration Traefik will wait for a health check request before considering the server unhealthy.\nDefault: 5s";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "followRedirects" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "interval" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "timeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceResponseForwarding" = {
      options = {
        "flushInterval" = mkOption {
          description = "FlushInterval defines the interval, in milliseconds, in between flushes to the client while copying the response body.\nA negative value means to flush immediately after each write to the client.\nThis configuration is ignored when ReverseProxy recognizes a response as a streaming response;\nfor such responses, writes are flushed to the client immediately.\nDefault: 100ms";
          type = types.nullOr types.str;
        };
      };

      config = {
        "flushInterval" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceSticky" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie defines the sticky cookie configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceStickyCookie");
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecErrorsServiceStickyCookie" = {
      options = {
        "domain" = mkOption {
          description = "Domain defines the host to which the cookie will be sent.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#domaindomain-value";
          type = types.nullOr types.str;
        };
        "httpOnly" = mkOption {
          description = "HTTPOnly defines whether the cookie can be accessed by client-side APIs, such as JavaScript.";
          type = types.nullOr types.bool;
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the number of seconds until the cookie expires.\nWhen set to a negative number, the cookie expires immediately.\nWhen set to zero, the cookie never expires.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "Name defines the Cookie name.";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the path that must exist in the requested URL for the browser to send the Cookie header.\nWhen not provided the cookie will be sent on every request to the domain.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#pathpath-value";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "SameSite defines the same site policy.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "Secure defines whether the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "httpOnly" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecForwardAuth" = {
      options = {
        "addAuthCookiesToResponse" = mkOption {
          description = "AddAuthCookiesToResponse defines the list of cookies to copy from the authentication server response to the response.";
          type = types.nullOr (types.listOf types.str);
        };
        "address" = mkOption {
          description = "Address defines the authentication server address.";
          type = types.nullOr types.str;
        };
        "authRequestHeaders" = mkOption {
          description = "AuthRequestHeaders defines the list of the headers to copy from the request to the authentication server.\nIf not set or empty then all request headers are passed.";
          type = types.nullOr (types.listOf types.str);
        };
        "authResponseHeaders" = mkOption {
          description = "AuthResponseHeaders defines the list of headers to copy from the authentication server response and set on forwarded request, replacing any existing conflicting headers.";
          type = types.nullOr (types.listOf types.str);
        };
        "authResponseHeadersRegex" = mkOption {
          description = "AuthResponseHeadersRegex defines the regex to match headers to copy from the authentication server response and set on forwarded request, after stripping all headers that match the regex.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/forwardauth/#authresponseheadersregex";
          type = types.nullOr types.str;
        };
        "forwardBody" = mkOption {
          description = "ForwardBody defines whether to send the request body to the authentication server.";
          type = types.nullOr types.bool;
        };
        "headerField" = mkOption {
          description = "HeaderField defines a header field to store the authenticated user.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/forwardauth/#headerfield";
          type = types.nullOr types.str;
        };
        "maxBodySize" = mkOption {
          description = "MaxBodySize defines the maximum body size in bytes allowed to be forwarded to the authentication server.";
          type = types.nullOr types.int;
        };
        "preserveLocationHeader" = mkOption {
          description = "PreserveLocationHeader defines whether to forward the Location header to the client as is or prefix it with the domain name of the authentication server.";
          type = types.nullOr types.bool;
        };
        "preserveRequestMethod" = mkOption {
          description = "PreserveRequestMethod defines whether to preserve the original request method while forwarding the request to the authentication server.";
          type = types.nullOr types.bool;
        };
        "tls" = mkOption {
          description = "TLS defines the configuration used to secure the connection to the authentication server.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecForwardAuthTls");
        };
        "trustForwardHeader" = mkOption {
          description = "TrustForwardHeader defines whether to trust (ie: forward) all X-Forwarded-* headers.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "addAuthCookiesToResponse" = mkOverride 1002 null;
        "address" = mkOverride 1002 null;
        "authRequestHeaders" = mkOverride 1002 null;
        "authResponseHeaders" = mkOverride 1002 null;
        "authResponseHeadersRegex" = mkOverride 1002 null;
        "forwardBody" = mkOverride 1002 null;
        "headerField" = mkOverride 1002 null;
        "maxBodySize" = mkOverride 1002 null;
        "preserveLocationHeader" = mkOverride 1002 null;
        "preserveRequestMethod" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
        "trustForwardHeader" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecForwardAuthTls" = {
      options = {
        "caOptional" = mkOption {
          description = "Deprecated: TLS client authentication is a server side option (see https://github.com/golang/go/blob/740a490f71d026bb7d2d13cb8fa2d6d6e0572b70/src/crypto/tls/common.go#L634).";
          type = types.nullOr types.bool;
        };
        "caSecret" = mkOption {
          description = "CASecret is the name of the referenced Kubernetes Secret containing the CA to validate the server certificate.\nThe CA certificate is extracted from key `tls.ca` or `ca.crt`.";
          type = types.nullOr types.str;
        };
        "certSecret" = mkOption {
          description = "CertSecret is the name of the referenced Kubernetes Secret containing the client certificate.\nThe client certificate is extracted from the keys `tls.crt` and `tls.key`.";
          type = types.nullOr types.str;
        };
        "insecureSkipVerify" = mkOption {
          description = "InsecureSkipVerify defines whether the server certificates should be validated.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "caOptional" = mkOverride 1002 null;
        "caSecret" = mkOverride 1002 null;
        "certSecret" = mkOverride 1002 null;
        "insecureSkipVerify" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecGrpcWeb" = {
      options = {
        "allowOrigins" = mkOption {
          description = "AllowOrigins is a list of allowable origins.\nCan also be a wildcard origin \"*\".";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "allowOrigins" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecHeaders" = {
      options = {
        "accessControlAllowCredentials" = mkOption {
          description = "AccessControlAllowCredentials defines whether the request can include user credentials.";
          type = types.nullOr types.bool;
        };
        "accessControlAllowHeaders" = mkOption {
          description = "AccessControlAllowHeaders defines the Access-Control-Request-Headers values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "accessControlAllowMethods" = mkOption {
          description = "AccessControlAllowMethods defines the Access-Control-Request-Method values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "accessControlAllowOriginList" = mkOption {
          description = "AccessControlAllowOriginList is a list of allowable origins. Can also be a wildcard origin \"*\".";
          type = types.nullOr (types.listOf types.str);
        };
        "accessControlAllowOriginListRegex" = mkOption {
          description = "AccessControlAllowOriginListRegex is a list of allowable origins written following the Regular Expression syntax (https://golang.org/pkg/regexp/).";
          type = types.nullOr (types.listOf types.str);
        };
        "accessControlExposeHeaders" = mkOption {
          description = "AccessControlExposeHeaders defines the Access-Control-Expose-Headers values sent in preflight response.";
          type = types.nullOr (types.listOf types.str);
        };
        "accessControlMaxAge" = mkOption {
          description = "AccessControlMaxAge defines the time that a preflight request may be cached.";
          type = types.nullOr types.int;
        };
        "addVaryHeader" = mkOption {
          description = "AddVaryHeader defines whether the Vary header is automatically added/updated when the AccessControlAllowOriginList is set.";
          type = types.nullOr types.bool;
        };
        "allowedHosts" = mkOption {
          description = "AllowedHosts defines the fully qualified list of allowed domain names.";
          type = types.nullOr (types.listOf types.str);
        };
        "browserXssFilter" = mkOption {
          description = "BrowserXSSFilter defines whether to add the X-XSS-Protection header with the value 1; mode=block.";
          type = types.nullOr types.bool;
        };
        "contentSecurityPolicy" = mkOption {
          description = "ContentSecurityPolicy defines the Content-Security-Policy header value.";
          type = types.nullOr types.str;
        };
        "contentSecurityPolicyReportOnly" = mkOption {
          description = "ContentSecurityPolicyReportOnly defines the Content-Security-Policy-Report-Only header value.";
          type = types.nullOr types.str;
        };
        "contentTypeNosniff" = mkOption {
          description = "ContentTypeNosniff defines whether to add the X-Content-Type-Options header with the nosniff value.";
          type = types.nullOr types.bool;
        };
        "customBrowserXSSValue" = mkOption {
          description = "CustomBrowserXSSValue defines the X-XSS-Protection header value.\nThis overrides the BrowserXssFilter option.";
          type = types.nullOr types.str;
        };
        "customFrameOptionsValue" = mkOption {
          description = "CustomFrameOptionsValue defines the X-Frame-Options header value.\nThis overrides the FrameDeny option.";
          type = types.nullOr types.str;
        };
        "customRequestHeaders" = mkOption {
          description = "CustomRequestHeaders defines the header names and values to apply to the request.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "customResponseHeaders" = mkOption {
          description = "CustomResponseHeaders defines the header names and values to apply to the response.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "featurePolicy" = mkOption {
          description = "Deprecated: FeaturePolicy option is deprecated, please use PermissionsPolicy instead.";
          type = types.nullOr types.str;
        };
        "forceSTSHeader" = mkOption {
          description = "ForceSTSHeader defines whether to add the STS header even when the connection is HTTP.";
          type = types.nullOr types.bool;
        };
        "frameDeny" = mkOption {
          description = "FrameDeny defines whether to add the X-Frame-Options header with the DENY value.";
          type = types.nullOr types.bool;
        };
        "hostsProxyHeaders" = mkOption {
          description = "HostsProxyHeaders defines the header keys that may hold a proxied hostname value for the request.";
          type = types.nullOr (types.listOf types.str);
        };
        "isDevelopment" = mkOption {
          description = "IsDevelopment defines whether to mitigate the unwanted effects of the AllowedHosts, SSL, and STS options when developing.\nUsually testing takes place using HTTP, not HTTPS, and on localhost, not your production domain.\nIf you would like your development environment to mimic production with complete Host blocking, SSL redirects,\nand STS headers, leave this as false.";
          type = types.nullOr types.bool;
        };
        "permissionsPolicy" = mkOption {
          description = "PermissionsPolicy defines the Permissions-Policy header value.\nThis allows sites to control browser features.";
          type = types.nullOr types.str;
        };
        "publicKey" = mkOption {
          description = "PublicKey is the public key that implements HPKP to prevent MITM attacks with forged certificates.";
          type = types.nullOr types.str;
        };
        "referrerPolicy" = mkOption {
          description = "ReferrerPolicy defines the Referrer-Policy header value.\nThis allows sites to control whether browsers forward the Referer header to other sites.";
          type = types.nullOr types.str;
        };
        "sslForceHost" = mkOption {
          description = "Deprecated: SSLForceHost option is deprecated, please use RedirectRegex instead.";
          type = types.nullOr types.bool;
        };
        "sslHost" = mkOption {
          description = "Deprecated: SSLHost option is deprecated, please use RedirectRegex instead.";
          type = types.nullOr types.str;
        };
        "sslProxyHeaders" = mkOption {
          description = "SSLProxyHeaders defines the header keys with associated values that would indicate a valid HTTPS request.\nIt can be useful when using other proxies (example: \"X-Forwarded-Proto\": \"https\").";
          type = types.nullOr (types.attrsOf types.str);
        };
        "sslRedirect" = mkOption {
          description = "Deprecated: SSLRedirect option is deprecated, please use EntryPoint redirection or RedirectScheme instead.";
          type = types.nullOr types.bool;
        };
        "sslTemporaryRedirect" = mkOption {
          description = "Deprecated: SSLTemporaryRedirect option is deprecated, please use EntryPoint redirection or RedirectScheme instead.";
          type = types.nullOr types.bool;
        };
        "stsIncludeSubdomains" = mkOption {
          description = "STSIncludeSubdomains defines whether the includeSubDomains directive is appended to the Strict-Transport-Security header.";
          type = types.nullOr types.bool;
        };
        "stsPreload" = mkOption {
          description = "STSPreload defines whether the preload flag is appended to the Strict-Transport-Security header.";
          type = types.nullOr types.bool;
        };
        "stsSeconds" = mkOption {
          description = "STSSeconds defines the max-age of the Strict-Transport-Security header.\nIf set to 0, the header is not set.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "accessControlAllowCredentials" = mkOverride 1002 null;
        "accessControlAllowHeaders" = mkOverride 1002 null;
        "accessControlAllowMethods" = mkOverride 1002 null;
        "accessControlAllowOriginList" = mkOverride 1002 null;
        "accessControlAllowOriginListRegex" = mkOverride 1002 null;
        "accessControlExposeHeaders" = mkOverride 1002 null;
        "accessControlMaxAge" = mkOverride 1002 null;
        "addVaryHeader" = mkOverride 1002 null;
        "allowedHosts" = mkOverride 1002 null;
        "browserXssFilter" = mkOverride 1002 null;
        "contentSecurityPolicy" = mkOverride 1002 null;
        "contentSecurityPolicyReportOnly" = mkOverride 1002 null;
        "contentTypeNosniff" = mkOverride 1002 null;
        "customBrowserXSSValue" = mkOverride 1002 null;
        "customFrameOptionsValue" = mkOverride 1002 null;
        "customRequestHeaders" = mkOverride 1002 null;
        "customResponseHeaders" = mkOverride 1002 null;
        "featurePolicy" = mkOverride 1002 null;
        "forceSTSHeader" = mkOverride 1002 null;
        "frameDeny" = mkOverride 1002 null;
        "hostsProxyHeaders" = mkOverride 1002 null;
        "isDevelopment" = mkOverride 1002 null;
        "permissionsPolicy" = mkOverride 1002 null;
        "publicKey" = mkOverride 1002 null;
        "referrerPolicy" = mkOverride 1002 null;
        "sslForceHost" = mkOverride 1002 null;
        "sslHost" = mkOverride 1002 null;
        "sslProxyHeaders" = mkOverride 1002 null;
        "sslRedirect" = mkOverride 1002 null;
        "sslTemporaryRedirect" = mkOverride 1002 null;
        "stsIncludeSubdomains" = mkOverride 1002 null;
        "stsPreload" = mkOverride 1002 null;
        "stsSeconds" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecInFlightReq" = {
      options = {
        "amount" = mkOption {
          description = "Amount defines the maximum amount of allowed simultaneous in-flight request.\nThe middleware responds with HTTP 429 Too Many Requests if there are already amount requests in progress (based on the same sourceCriterion strategy).";
          type = types.nullOr types.int;
        };
        "sourceCriterion" = mkOption {
          description = "SourceCriterion defines what criterion is used to group requests as originating from a common source.\nIf several strategies are defined at the same time, an error will be raised.\nIf none are set, the default is to use the requestHost.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/inflightreq/#sourcecriterion";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecInFlightReqSourceCriterion");
        };
      };

      config = {
        "amount" = mkOverride 1002 null;
        "sourceCriterion" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecInFlightReqSourceCriterion" = {
      options = {
        "ipStrategy" = mkOption {
          description = "IPStrategy holds the IP strategy configuration used by Traefik to determine the client IP.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/ipallowlist/#ipstrategy";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.MiddlewareSpecInFlightReqSourceCriterionIpStrategy"
          );
        };
        "requestHeaderName" = mkOption {
          description = "RequestHeaderName defines the name of the header used to group incoming requests.";
          type = types.nullOr types.str;
        };
        "requestHost" = mkOption {
          description = "RequestHost defines whether to consider the request Host as the source.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "ipStrategy" = mkOverride 1002 null;
        "requestHeaderName" = mkOverride 1002 null;
        "requestHost" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecInFlightReqSourceCriterionIpStrategy" = {
      options = {
        "depth" = mkOption {
          description = "Depth tells Traefik to use the X-Forwarded-For header and take the IP located at the depth position (starting from the right).";
          type = types.nullOr types.int;
        };
        "excludedIPs" = mkOption {
          description = "ExcludedIPs configures Traefik to scan the X-Forwarded-For header and select the first IP not in the list.";
          type = types.nullOr (types.listOf types.str);
        };
        "ipv6Subnet" = mkOption {
          description = "IPv6Subnet configures Traefik to consider all IPv6 addresses from the defined subnet as originating from the same IP. Applies to RemoteAddrStrategy and DepthStrategy.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "depth" = mkOverride 1002 null;
        "excludedIPs" = mkOverride 1002 null;
        "ipv6Subnet" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecIpAllowList" = {
      options = {
        "ipStrategy" = mkOption {
          description = "IPStrategy holds the IP strategy configuration used by Traefik to determine the client IP.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/ipallowlist/#ipstrategy";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecIpAllowListIpStrategy");
        };
        "rejectStatusCode" = mkOption {
          description = "RejectStatusCode defines the HTTP status code used for refused requests.\nIf not set, the default is 403 (Forbidden).";
          type = types.nullOr types.int;
        };
        "sourceRange" = mkOption {
          description = "SourceRange defines the set of allowed IPs (or ranges of allowed IPs by using CIDR notation).";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "ipStrategy" = mkOverride 1002 null;
        "rejectStatusCode" = mkOverride 1002 null;
        "sourceRange" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecIpAllowListIpStrategy" = {
      options = {
        "depth" = mkOption {
          description = "Depth tells Traefik to use the X-Forwarded-For header and take the IP located at the depth position (starting from the right).";
          type = types.nullOr types.int;
        };
        "excludedIPs" = mkOption {
          description = "ExcludedIPs configures Traefik to scan the X-Forwarded-For header and select the first IP not in the list.";
          type = types.nullOr (types.listOf types.str);
        };
        "ipv6Subnet" = mkOption {
          description = "IPv6Subnet configures Traefik to consider all IPv6 addresses from the defined subnet as originating from the same IP. Applies to RemoteAddrStrategy and DepthStrategy.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "depth" = mkOverride 1002 null;
        "excludedIPs" = mkOverride 1002 null;
        "ipv6Subnet" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecIpWhiteList" = {
      options = {
        "ipStrategy" = mkOption {
          description = "IPStrategy holds the IP strategy configuration used by Traefik to determine the client IP.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/ipallowlist/#ipstrategy";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecIpWhiteListIpStrategy");
        };
        "sourceRange" = mkOption {
          description = "SourceRange defines the set of allowed IPs (or ranges of allowed IPs by using CIDR notation). Required.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "ipStrategy" = mkOverride 1002 null;
        "sourceRange" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecIpWhiteListIpStrategy" = {
      options = {
        "depth" = mkOption {
          description = "Depth tells Traefik to use the X-Forwarded-For header and take the IP located at the depth position (starting from the right).";
          type = types.nullOr types.int;
        };
        "excludedIPs" = mkOption {
          description = "ExcludedIPs configures Traefik to scan the X-Forwarded-For header and select the first IP not in the list.";
          type = types.nullOr (types.listOf types.str);
        };
        "ipv6Subnet" = mkOption {
          description = "IPv6Subnet configures Traefik to consider all IPv6 addresses from the defined subnet as originating from the same IP. Applies to RemoteAddrStrategy and DepthStrategy.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "depth" = mkOverride 1002 null;
        "excludedIPs" = mkOverride 1002 null;
        "ipv6Subnet" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCert" = {
      options = {
        "info" = mkOption {
          description = "Info selects the specific client certificate details you want to add to the X-Forwarded-Tls-Client-Cert-Info header.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCertInfo");
        };
        "pem" = mkOption {
          description = "PEM sets the X-Forwarded-Tls-Client-Cert header with the certificate.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "info" = mkOverride 1002 null;
        "pem" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCertInfo" = {
      options = {
        "issuer" = mkOption {
          description = "Issuer defines the client certificate issuer details to add to the X-Forwarded-Tls-Client-Cert-Info header.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCertInfoIssuer");
        };
        "notAfter" = mkOption {
          description = "NotAfter defines whether to add the Not After information from the Validity part.";
          type = types.nullOr types.bool;
        };
        "notBefore" = mkOption {
          description = "NotBefore defines whether to add the Not Before information from the Validity part.";
          type = types.nullOr types.bool;
        };
        "sans" = mkOption {
          description = "Sans defines whether to add the Subject Alternative Name information from the Subject Alternative Name part.";
          type = types.nullOr types.bool;
        };
        "serialNumber" = mkOption {
          description = "SerialNumber defines whether to add the client serialNumber information.";
          type = types.nullOr types.bool;
        };
        "subject" = mkOption {
          description = "Subject defines the client certificate subject details to add to the X-Forwarded-Tls-Client-Cert-Info header.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCertInfoSubject");
        };
      };

      config = {
        "issuer" = mkOverride 1002 null;
        "notAfter" = mkOverride 1002 null;
        "notBefore" = mkOverride 1002 null;
        "sans" = mkOverride 1002 null;
        "serialNumber" = mkOverride 1002 null;
        "subject" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCertInfoIssuer" = {
      options = {
        "commonName" = mkOption {
          description = "CommonName defines whether to add the organizationalUnit information into the issuer.";
          type = types.nullOr types.bool;
        };
        "country" = mkOption {
          description = "Country defines whether to add the country information into the issuer.";
          type = types.nullOr types.bool;
        };
        "domainComponent" = mkOption {
          description = "DomainComponent defines whether to add the domainComponent information into the issuer.";
          type = types.nullOr types.bool;
        };
        "locality" = mkOption {
          description = "Locality defines whether to add the locality information into the issuer.";
          type = types.nullOr types.bool;
        };
        "organization" = mkOption {
          description = "Organization defines whether to add the organization information into the issuer.";
          type = types.nullOr types.bool;
        };
        "province" = mkOption {
          description = "Province defines whether to add the province information into the issuer.";
          type = types.nullOr types.bool;
        };
        "serialNumber" = mkOption {
          description = "SerialNumber defines whether to add the serialNumber information into the issuer.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonName" = mkOverride 1002 null;
        "country" = mkOverride 1002 null;
        "domainComponent" = mkOverride 1002 null;
        "locality" = mkOverride 1002 null;
        "organization" = mkOverride 1002 null;
        "province" = mkOverride 1002 null;
        "serialNumber" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecPassTLSClientCertInfoSubject" = {
      options = {
        "commonName" = mkOption {
          description = "CommonName defines whether to add the organizationalUnit information into the subject.";
          type = types.nullOr types.bool;
        };
        "country" = mkOption {
          description = "Country defines whether to add the country information into the subject.";
          type = types.nullOr types.bool;
        };
        "domainComponent" = mkOption {
          description = "DomainComponent defines whether to add the domainComponent information into the subject.";
          type = types.nullOr types.bool;
        };
        "locality" = mkOption {
          description = "Locality defines whether to add the locality information into the subject.";
          type = types.nullOr types.bool;
        };
        "organization" = mkOption {
          description = "Organization defines whether to add the organization information into the subject.";
          type = types.nullOr types.bool;
        };
        "organizationalUnit" = mkOption {
          description = "OrganizationalUnit defines whether to add the organizationalUnit information into the subject.";
          type = types.nullOr types.bool;
        };
        "province" = mkOption {
          description = "Province defines whether to add the province information into the subject.";
          type = types.nullOr types.bool;
        };
        "serialNumber" = mkOption {
          description = "SerialNumber defines whether to add the serialNumber information into the subject.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "commonName" = mkOverride 1002 null;
        "country" = mkOverride 1002 null;
        "domainComponent" = mkOverride 1002 null;
        "locality" = mkOverride 1002 null;
        "organization" = mkOverride 1002 null;
        "organizationalUnit" = mkOverride 1002 null;
        "province" = mkOverride 1002 null;
        "serialNumber" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRateLimit" = {
      options = {
        "average" = mkOption {
          description = "Average is the maximum rate, by default in requests/s, allowed for the given source.\nIt defaults to 0, which means no rate limiting.\nThe rate is actually defined by dividing Average by Period. So for a rate below 1req/s,\none needs to define a Period larger than a second.";
          type = types.nullOr types.int;
        };
        "burst" = mkOption {
          description = "Burst is the maximum number of requests allowed to arrive in the same arbitrarily small period of time.\nIt defaults to 1.";
          type = types.nullOr types.int;
        };
        "period" = mkOption {
          description = "Period, in combination with Average, defines the actual maximum rate, such as:\nr = Average / Period. It defaults to a second.";
          type = types.nullOr (types.either types.int types.str);
        };
        "redis" = mkOption {
          description = "Redis hold the configs of Redis as bucket in rate limiter.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRateLimitRedis");
        };
        "sourceCriterion" = mkOption {
          description = "SourceCriterion defines what criterion is used to group requests as originating from a common source.\nIf several strategies are defined at the same time, an error will be raised.\nIf none are set, the default is to use the request's remote address field (as an ipStrategy).";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRateLimitSourceCriterion");
        };
      };

      config = {
        "average" = mkOverride 1002 null;
        "burst" = mkOverride 1002 null;
        "period" = mkOverride 1002 null;
        "redis" = mkOverride 1002 null;
        "sourceCriterion" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRateLimitRedis" = {
      options = {
        "db" = mkOption {
          description = "DB defines the Redis database that will be selected after connecting to the server.";
          type = types.nullOr types.int;
        };
        "dialTimeout" = mkOption {
          description = "DialTimeout sets the timeout for establishing new connections.\nDefault value is 5 seconds.";
          type = types.nullOr (types.either types.int types.str);
        };
        "endpoints" = mkOption {
          description = "Endpoints contains either a single address or a seed list of host:port addresses.\nDefault value is [\"localhost:6379\"].";
          type = types.nullOr (types.listOf types.str);
        };
        "maxActiveConns" = mkOption {
          description = "MaxActiveConns defines the maximum number of connections allocated by the pool at a given time.\nDefault value is 0, meaning there is no limit.";
          type = types.nullOr types.int;
        };
        "minIdleConns" = mkOption {
          description = "MinIdleConns defines the minimum number of idle connections.\nDefault value is 0, and idle connections are not closed by default.";
          type = types.nullOr types.int;
        };
        "poolSize" = mkOption {
          description = "PoolSize defines the initial number of socket connections.\nIf the pool runs out of available connections, additional ones will be created beyond PoolSize.\nThis can be limited using MaxActiveConns.\n// Default value is 0, meaning 10 connections per every available CPU as reported by runtime.GOMAXPROCS.";
          type = types.nullOr types.int;
        };
        "readTimeout" = mkOption {
          description = "ReadTimeout defines the timeout for socket read operations.\nDefault value is 3 seconds.";
          type = types.nullOr (types.either types.int types.str);
        };
        "secret" = mkOption {
          description = "Secret defines the name of the referenced Kubernetes Secret containing Redis credentials.";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "TLS defines TLS-specific configurations, including the CA, certificate, and key,\nwhich can be provided as a file path or file content.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRateLimitRedisTls");
        };
        "writeTimeout" = mkOption {
          description = "WriteTimeout defines the timeout for socket write operations.\nDefault value is 3 seconds.";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "db" = mkOverride 1002 null;
        "dialTimeout" = mkOverride 1002 null;
        "endpoints" = mkOverride 1002 null;
        "maxActiveConns" = mkOverride 1002 null;
        "minIdleConns" = mkOverride 1002 null;
        "poolSize" = mkOverride 1002 null;
        "readTimeout" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
        "writeTimeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRateLimitRedisTls" = {
      options = {
        "caSecret" = mkOption {
          description = "CASecret is the name of the referenced Kubernetes Secret containing the CA to validate the server certificate.\nThe CA certificate is extracted from key `tls.ca` or `ca.crt`.";
          type = types.nullOr types.str;
        };
        "certSecret" = mkOption {
          description = "CertSecret is the name of the referenced Kubernetes Secret containing the client certificate.\nThe client certificate is extracted from the keys `tls.crt` and `tls.key`.";
          type = types.nullOr types.str;
        };
        "insecureSkipVerify" = mkOption {
          description = "InsecureSkipVerify defines whether the server certificates should be validated.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "caSecret" = mkOverride 1002 null;
        "certSecret" = mkOverride 1002 null;
        "insecureSkipVerify" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRateLimitSourceCriterion" = {
      options = {
        "ipStrategy" = mkOption {
          description = "IPStrategy holds the IP strategy configuration used by Traefik to determine the client IP.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/ipallowlist/#ipstrategy";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.MiddlewareSpecRateLimitSourceCriterionIpStrategy"
          );
        };
        "requestHeaderName" = mkOption {
          description = "RequestHeaderName defines the name of the header used to group incoming requests.";
          type = types.nullOr types.str;
        };
        "requestHost" = mkOption {
          description = "RequestHost defines whether to consider the request Host as the source.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "ipStrategy" = mkOverride 1002 null;
        "requestHeaderName" = mkOverride 1002 null;
        "requestHost" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRateLimitSourceCriterionIpStrategy" = {
      options = {
        "depth" = mkOption {
          description = "Depth tells Traefik to use the X-Forwarded-For header and take the IP located at the depth position (starting from the right).";
          type = types.nullOr types.int;
        };
        "excludedIPs" = mkOption {
          description = "ExcludedIPs configures Traefik to scan the X-Forwarded-For header and select the first IP not in the list.";
          type = types.nullOr (types.listOf types.str);
        };
        "ipv6Subnet" = mkOption {
          description = "IPv6Subnet configures Traefik to consider all IPv6 addresses from the defined subnet as originating from the same IP. Applies to RemoteAddrStrategy and DepthStrategy.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "depth" = mkOverride 1002 null;
        "excludedIPs" = mkOverride 1002 null;
        "ipv6Subnet" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRedirectRegex" = {
      options = {
        "permanent" = mkOption {
          description = "Permanent defines whether the redirection is permanent (301).";
          type = types.nullOr types.bool;
        };
        "regex" = mkOption {
          description = "Regex defines the regex used to match and capture elements from the request URL.";
          type = types.nullOr types.str;
        };
        "replacement" = mkOption {
          description = "Replacement defines how to modify the URL to have the new target URL.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "permanent" = mkOverride 1002 null;
        "regex" = mkOverride 1002 null;
        "replacement" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRedirectScheme" = {
      options = {
        "permanent" = mkOption {
          description = "Permanent defines whether the redirection is permanent (301).";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of the new URL.";
          type = types.nullOr types.str;
        };
        "scheme" = mkOption {
          description = "Scheme defines the scheme of the new URL.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "permanent" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecReplacePath" = {
      options = {
        "path" = mkOption {
          description = "Path defines the path to use as replacement in the request URL.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecReplacePathRegex" = {
      options = {
        "regex" = mkOption {
          description = "Regex defines the regular expression used to match and capture the path from the request URL.";
          type = types.nullOr types.str;
        };
        "replacement" = mkOption {
          description = "Replacement defines the replacement path format, which can include captured variables.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "regex" = mkOverride 1002 null;
        "replacement" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecRetry" = {
      options = {
        "attempts" = mkOption {
          description = "Attempts defines how many times the request should be retried.";
          type = types.nullOr types.int;
        };
        "initialInterval" = mkOption {
          description = "InitialInterval defines the first wait time in the exponential backoff series.\nThe maximum interval is calculated as twice the initialInterval.\nIf unspecified, requests will be retried immediately.\nThe value of initialInterval should be provided in seconds or as a valid duration format,\nsee https://pkg.go.dev/time#ParseDuration.";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "attempts" = mkOverride 1002 null;
        "initialInterval" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecStripPrefix" = {
      options = {
        "forceSlash" = mkOption {
          description = "Deprecated: ForceSlash option is deprecated, please remove any usage of this option.\nForceSlash ensures that the resulting stripped path is not the empty string, by replacing it with / when necessary.\nDefault: true.";
          type = types.nullOr types.bool;
        };
        "prefixes" = mkOption {
          description = "Prefixes defines the prefixes to strip from the request URL.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "forceSlash" = mkOverride 1002 null;
        "prefixes" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareSpecStripPrefixRegex" = {
      options = {
        "regex" = mkOption {
          description = "Regex defines the regular expression to match the path prefix from the request URL.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "regex" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareTCP" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "MiddlewareTCPSpec defines the desired state of a MiddlewareTCP.";
          type = submoduleOf "traefik.io.v1alpha1.MiddlewareTCPSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareTCPSpec" = {
      options = {
        "inFlightConn" = mkOption {
          description = "InFlightConn defines the InFlightConn middleware configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareTCPSpecInFlightConn");
        };
        "ipAllowList" = mkOption {
          description = "IPAllowList defines the IPAllowList middleware configuration.\nThis middleware accepts/refuses connections based on the client IP.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/tcp/ipallowlist/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareTCPSpecIpAllowList");
        };
        "ipWhiteList" = mkOption {
          description = "IPWhiteList defines the IPWhiteList middleware configuration.\nThis middleware accepts/refuses connections based on the client IP.\nDeprecated: please use IPAllowList instead.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/tcp/ipwhitelist/";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.MiddlewareTCPSpecIpWhiteList");
        };
      };

      config = {
        "inFlightConn" = mkOverride 1002 null;
        "ipAllowList" = mkOverride 1002 null;
        "ipWhiteList" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareTCPSpecInFlightConn" = {
      options = {
        "amount" = mkOption {
          description = "Amount defines the maximum amount of allowed simultaneous connections.\nThe middleware closes the connection if there are already amount connections opened.";
          type = types.nullOr types.int;
        };
      };

      config = {
        "amount" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareTCPSpecIpAllowList" = {
      options = {
        "sourceRange" = mkOption {
          description = "SourceRange defines the allowed IPs (or ranges of allowed IPs by using CIDR notation).";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "sourceRange" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.MiddlewareTCPSpecIpWhiteList" = {
      options = {
        "sourceRange" = mkOption {
          description = "SourceRange defines the allowed IPs (or ranges of allowed IPs by using CIDR notation).";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "sourceRange" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransport" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "ServersTransportSpec defines the desired state of a ServersTransport.";
          type = submoduleOf "traefik.io.v1alpha1.ServersTransportSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportSpec" = {
      options = {
        "certificatesSecrets" = mkOption {
          description = "CertificatesSecrets defines a list of secret storing client certificates for mTLS.";
          type = types.nullOr (types.listOf types.str);
        };
        "disableHTTP2" = mkOption {
          description = "DisableHTTP2 disables HTTP/2 for connections with backend servers.";
          type = types.nullOr types.bool;
        };
        "forwardingTimeouts" = mkOption {
          description = "ForwardingTimeouts defines the timeouts for requests forwarded to the backend servers.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.ServersTransportSpecForwardingTimeouts");
        };
        "insecureSkipVerify" = mkOption {
          description = "InsecureSkipVerify disables SSL certificate verification.";
          type = types.nullOr types.bool;
        };
        "maxIdleConnsPerHost" = mkOption {
          description = "MaxIdleConnsPerHost controls the maximum idle (keep-alive) to keep per-host.";
          type = types.nullOr types.int;
        };
        "peerCertURI" = mkOption {
          description = "PeerCertURI defines the peer cert URI used to match against SAN URI during the peer certificate verification.";
          type = types.nullOr types.str;
        };
        "rootCAs" = mkOption {
          description = "RootCAs defines a list of CA certificate Secrets or ConfigMaps used to validate server certificates.";
          type = types.nullOr (types.listOf (submoduleOf "traefik.io.v1alpha1.ServersTransportSpecRootCAs"));
        };
        "rootCAsSecrets" = mkOption {
          description = "RootCAsSecrets defines a list of CA secret used to validate self-signed certificate.\nDeprecated: RootCAsSecrets is deprecated, please use the RootCAs option instead.";
          type = types.nullOr (types.listOf types.str);
        };
        "serverName" = mkOption {
          description = "ServerName defines the server name used to contact the server.";
          type = types.nullOr types.str;
        };
        "spiffe" = mkOption {
          description = "Spiffe defines the SPIFFE configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.ServersTransportSpecSpiffe");
        };
      };

      config = {
        "certificatesSecrets" = mkOverride 1002 null;
        "disableHTTP2" = mkOverride 1002 null;
        "forwardingTimeouts" = mkOverride 1002 null;
        "insecureSkipVerify" = mkOverride 1002 null;
        "maxIdleConnsPerHost" = mkOverride 1002 null;
        "peerCertURI" = mkOverride 1002 null;
        "rootCAs" = mkOverride 1002 null;
        "rootCAsSecrets" = mkOverride 1002 null;
        "serverName" = mkOverride 1002 null;
        "spiffe" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportSpecForwardingTimeouts" = {
      options = {
        "dialTimeout" = mkOption {
          description = "DialTimeout is the amount of time to wait until a connection to a backend server can be established.";
          type = types.nullOr (types.either types.int types.str);
        };
        "idleConnTimeout" = mkOption {
          description = "IdleConnTimeout is the maximum period for which an idle HTTP keep-alive connection will remain open before closing itself.";
          type = types.nullOr (types.either types.int types.str);
        };
        "pingTimeout" = mkOption {
          description = "PingTimeout is the timeout after which the HTTP/2 connection will be closed if a response to ping is not received.";
          type = types.nullOr (types.either types.int types.str);
        };
        "readIdleTimeout" = mkOption {
          description = "ReadIdleTimeout is the timeout after which a health check using ping frame will be carried out if no frame is received on the HTTP/2 connection.";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseHeaderTimeout" = mkOption {
          description = "ResponseHeaderTimeout is the amount of time to wait for a server's response headers after fully writing the request (including its body, if any).";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "dialTimeout" = mkOverride 1002 null;
        "idleConnTimeout" = mkOverride 1002 null;
        "pingTimeout" = mkOverride 1002 null;
        "readIdleTimeout" = mkOverride 1002 null;
        "responseHeaderTimeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportSpecRootCAs" = {
      options = {
        "configMap" = mkOption {
          description = "ConfigMap defines the name of a ConfigMap that holds a CA certificate.\nThe referenced ConfigMap must contain a certificate under either a tls.ca or a ca.crt key.";
          type = types.nullOr types.str;
        };
        "secret" = mkOption {
          description = "Secret defines the name of a Secret that holds a CA certificate.\nThe referenced Secret must contain a certificate under either a tls.ca or a ca.crt key.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "configMap" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportSpecSpiffe" = {
      options = {
        "ids" = mkOption {
          description = "IDs defines the allowed SPIFFE IDs (takes precedence over the SPIFFE TrustDomain).";
          type = types.nullOr (types.listOf types.str);
        };
        "trustDomain" = mkOption {
          description = "TrustDomain defines the allowed SPIFFE trust domain.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "ids" = mkOverride 1002 null;
        "trustDomain" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportTCP" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "ServersTransportTCPSpec defines the desired state of a ServersTransportTCP.";
          type = submoduleOf "traefik.io.v1alpha1.ServersTransportTCPSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportTCPSpec" = {
      options = {
        "dialKeepAlive" = mkOption {
          description = "DialKeepAlive is the interval between keep-alive probes for an active network connection. If zero, keep-alive probes are sent with a default value (currently 15 seconds), if supported by the protocol and operating system. Network protocols or operating systems that do not support keep-alives ignore this field. If negative, keep-alive probes are disabled.";
          type = types.nullOr (types.either types.int types.str);
        };
        "dialTimeout" = mkOption {
          description = "DialTimeout is the amount of time to wait until a connection to a backend server can be established.";
          type = types.nullOr (types.either types.int types.str);
        };
        "terminationDelay" = mkOption {
          description = "TerminationDelay defines the delay to wait before fully terminating the connection, after one connected peer has closed its writing capability.";
          type = types.nullOr (types.either types.int types.str);
        };
        "tls" = mkOption {
          description = "TLS defines the TLS configuration";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.ServersTransportTCPSpecTls");
        };
      };

      config = {
        "dialKeepAlive" = mkOverride 1002 null;
        "dialTimeout" = mkOverride 1002 null;
        "terminationDelay" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportTCPSpecTls" = {
      options = {
        "certificatesSecrets" = mkOption {
          description = "CertificatesSecrets defines a list of secret storing client certificates for mTLS.";
          type = types.nullOr (types.listOf types.str);
        };
        "insecureSkipVerify" = mkOption {
          description = "InsecureSkipVerify disables TLS certificate verification.";
          type = types.nullOr types.bool;
        };
        "peerCertURI" = mkOption {
          description = "MaxIdleConnsPerHost controls the maximum idle (keep-alive) to keep per-host.\nPeerCertURI defines the peer cert URI used to match against SAN URI during the peer certificate verification.";
          type = types.nullOr types.str;
        };
        "rootCAs" = mkOption {
          description = "RootCAs defines a list of CA certificate Secrets or ConfigMaps used to validate server certificates.";
          type = types.nullOr (
            types.listOf (submoduleOf "traefik.io.v1alpha1.ServersTransportTCPSpecTlsRootCAs")
          );
        };
        "rootCAsSecrets" = mkOption {
          description = "RootCAsSecrets defines a list of CA secret used to validate self-signed certificate.\nDeprecated: RootCAsSecrets is deprecated, please use the RootCAs option instead.";
          type = types.nullOr (types.listOf types.str);
        };
        "serverName" = mkOption {
          description = "ServerName defines the server name used to contact the server.";
          type = types.nullOr types.str;
        };
        "spiffe" = mkOption {
          description = "Spiffe defines the SPIFFE configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.ServersTransportTCPSpecTlsSpiffe");
        };
      };

      config = {
        "certificatesSecrets" = mkOverride 1002 null;
        "insecureSkipVerify" = mkOverride 1002 null;
        "peerCertURI" = mkOverride 1002 null;
        "rootCAs" = mkOverride 1002 null;
        "rootCAsSecrets" = mkOverride 1002 null;
        "serverName" = mkOverride 1002 null;
        "spiffe" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportTCPSpecTlsRootCAs" = {
      options = {
        "configMap" = mkOption {
          description = "ConfigMap defines the name of a ConfigMap that holds a CA certificate.\nThe referenced ConfigMap must contain a certificate under either a tls.ca or a ca.crt key.";
          type = types.nullOr types.str;
        };
        "secret" = mkOption {
          description = "Secret defines the name of a Secret that holds a CA certificate.\nThe referenced Secret must contain a certificate under either a tls.ca or a ca.crt key.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "configMap" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.ServersTransportTCPSpecTlsSpiffe" = {
      options = {
        "ids" = mkOption {
          description = "IDs defines the allowed SPIFFE IDs (takes precedence over the SPIFFE TrustDomain).";
          type = types.nullOr (types.listOf types.str);
        };
        "trustDomain" = mkOption {
          description = "TrustDomain defines the allowed SPIFFE trust domain.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "ids" = mkOverride 1002 null;
        "trustDomain" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSOption" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "TLSOptionSpec defines the desired state of a TLSOption.";
          type = submoduleOf "traefik.io.v1alpha1.TLSOptionSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSOptionSpec" = {
      options = {
        "alpnProtocols" = mkOption {
          description = "ALPNProtocols defines the list of supported application level protocols for the TLS handshake, in order of preference.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#alpn-protocols";
          type = types.nullOr (types.listOf types.str);
        };
        "cipherSuites" = mkOption {
          description = "CipherSuites defines the list of supported cipher suites for TLS versions up to TLS 1.2.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#cipher-suites";
          type = types.nullOr (types.listOf types.str);
        };
        "clientAuth" = mkOption {
          description = "ClientAuth defines the server's policy for TLS Client Authentication.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TLSOptionSpecClientAuth");
        };
        "curvePreferences" = mkOption {
          description = "CurvePreferences defines the preferred elliptic curves in a specific order.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#curve-preferences";
          type = types.nullOr (types.listOf types.str);
        };
        "disableSessionTickets" = mkOption {
          description = "DisableSessionTickets disables TLS session resumption via session tickets.";
          type = types.nullOr types.bool;
        };
        "maxVersion" = mkOption {
          description = "MaxVersion defines the maximum TLS version that Traefik will accept.\nPossible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13.\nDefault: None.";
          type = types.nullOr types.str;
        };
        "minVersion" = mkOption {
          description = "MinVersion defines the minimum TLS version that Traefik will accept.\nPossible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13.\nDefault: VersionTLS10.";
          type = types.nullOr types.str;
        };
        "preferServerCipherSuites" = mkOption {
          description = "PreferServerCipherSuites defines whether the server chooses a cipher suite among his own instead of among the client's.\nIt is enabled automatically when minVersion or maxVersion is set.\nDeprecated: https://github.com/golang/go/issues/45430";
          type = types.nullOr types.bool;
        };
        "sniStrict" = mkOption {
          description = "SniStrict defines whether Traefik allows connections from clients connections that do not specify a server_name extension.";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "alpnProtocols" = mkOverride 1002 null;
        "cipherSuites" = mkOverride 1002 null;
        "clientAuth" = mkOverride 1002 null;
        "curvePreferences" = mkOverride 1002 null;
        "disableSessionTickets" = mkOverride 1002 null;
        "maxVersion" = mkOverride 1002 null;
        "minVersion" = mkOverride 1002 null;
        "preferServerCipherSuites" = mkOverride 1002 null;
        "sniStrict" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSOptionSpecClientAuth" = {
      options = {
        "clientAuthType" = mkOption {
          description = "ClientAuthType defines the client authentication type to apply.";
          type = types.nullOr types.str;
        };
        "secretNames" = mkOption {
          description = "SecretNames defines the names of the referenced Kubernetes Secret storing certificate details.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "clientAuthType" = mkOverride 1002 null;
        "secretNames" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSStore" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "TLSStoreSpec defines the desired state of a TLSStore.";
          type = submoduleOf "traefik.io.v1alpha1.TLSStoreSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSStoreSpec" = {
      options = {
        "certificates" = mkOption {
          description = "Certificates is a list of secret names, each secret holding a key/certificate pair to add to the store.";
          type = types.nullOr (types.listOf (submoduleOf "traefik.io.v1alpha1.TLSStoreSpecCertificates"));
        };
        "defaultCertificate" = mkOption {
          description = "DefaultCertificate defines the default certificate configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TLSStoreSpecDefaultCertificate");
        };
        "defaultGeneratedCert" = mkOption {
          description = "DefaultGeneratedCert defines the default generated certificate configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TLSStoreSpecDefaultGeneratedCert");
        };
      };

      config = {
        "certificates" = mkOverride 1002 null;
        "defaultCertificate" = mkOverride 1002 null;
        "defaultGeneratedCert" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSStoreSpecCertificates" = {
      options = {
        "secretName" = mkOption {
          description = "SecretName is the name of the referenced Kubernetes Secret to specify the certificate details.";
          type = types.str;
        };
      };

      config = { };
    };
    "traefik.io.v1alpha1.TLSStoreSpecDefaultCertificate" = {
      options = {
        "secretName" = mkOption {
          description = "SecretName is the name of the referenced Kubernetes Secret to specify the certificate details.";
          type = types.str;
        };
      };

      config = { };
    };
    "traefik.io.v1alpha1.TLSStoreSpecDefaultGeneratedCert" = {
      options = {
        "domain" = mkOption {
          description = "Domain is the domain definition for the DefaultCertificate.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TLSStoreSpecDefaultGeneratedCertDomain");
        };
        "resolver" = mkOption {
          description = "Resolver is the name of the resolver that will be used to issue the DefaultCertificate.";
          type = types.nullOr types.str;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "resolver" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TLSStoreSpecDefaultGeneratedCertDomain" = {
      options = {
        "main" = mkOption {
          description = "Main defines the main domain name.";
          type = types.nullOr types.str;
        };
        "sans" = mkOption {
          description = "SANs defines the subject alternative domain names.";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "main" = mkOverride 1002 null;
        "sans" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikService" = {
      options = {
        "apiVersion" = mkOption {
          description = "APIVersion defines the versioned schema of this representation of an object.\nServers should convert recognized schemas to the latest internal value, and\nmay reject unrecognized values.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "Kind is a string value representing the REST resource this object represents.\nServers may infer this from the endpoint the client submits requests to.\nCannot be updated.\nIn CamelCase.\nMore info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta";
        };
        "spec" = mkOption {
          description = "TraefikServiceSpec defines the desired state of a TraefikService.";
          type = submoduleOf "traefik.io.v1alpha1.TraefikServiceSpec";
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpec" = {
      options = {
        "mirroring" = mkOption {
          description = "Mirroring defines the Mirroring service configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroring");
        };
        "weighted" = mkOption {
          description = "Weighted defines the Weighted Round Robin configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeighted");
        };
      };

      config = {
        "mirroring" = mkOverride 1002 null;
        "weighted" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroring" = {
      options = {
        "healthCheck" = mkOption {
          description = "Healthcheck defines health checks for ExternalName services.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringHealthCheck");
        };
        "kind" = mkOption {
          description = "Kind defines the kind of the Service.";
          type = types.nullOr types.str;
        };
        "maxBodySize" = mkOption {
          description = "MaxBodySize defines the maximum size allowed for the body of the request.\nIf the body is larger, the request is not mirrored.\nDefault value is -1, which means unlimited size.";
          type = types.nullOr types.int;
        };
        "mirrorBody" = mkOption {
          description = "MirrorBody defines whether the body of the request should be mirrored.\nDefault value is true.";
          type = types.nullOr types.bool;
        };
        "mirrors" = mkOption {
          description = "Mirrors defines the list of mirrors where Traefik will duplicate the traffic.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrors" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service or TraefikService.\nThe differentiation between the two is specified in the Kind field.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service or TraefikService.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "passHostHeader" = mkOption {
          description = "PassHostHeader defines whether the client Host header is forwarded to the upstream Kubernetes Service.\nBy default, passHostHeader is true.";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseForwarding" = mkOption {
          description = "ResponseForwarding defines how Traefik forwards the response from the upstream Kubernetes Service to the client.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringResponseForwarding"
          );
        };
        "scheme" = mkOption {
          description = "Scheme defines the scheme to use for the request to the upstream Kubernetes Service.\nIt defaults to https when Kubernetes Service port is 443, http otherwise.";
          type = types.nullOr types.str;
        };
        "serversTransport" = mkOption {
          description = "ServersTransport defines the name of ServersTransport resource to use.\nIt allows to configure the transport between Traefik and your servers.\nCan only be used on a Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "sticky" = mkOption {
          description = "Sticky defines the sticky sessions configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#sticky-sessions";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringSticky");
        };
        "strategy" = mkOption {
          description = "Strategy defines the load balancing strategy between the servers.\nSupported values are: wrr (Weighed round-robin) and p2c (Power of two choices).\nRoundRobin value is deprecated and supported for backward compatibility.";
          type = types.nullOr types.str;
        };
        "weight" = mkOption {
          description = "Weight defines the weight and should only be specified when Name references a TraefikService object\n(and to be precise, one that embeds a Weighted Round Robin).";
          type = types.nullOr types.int;
        };
      };

      config = {
        "healthCheck" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "maxBodySize" = mkOverride 1002 null;
        "mirrorBody" = mkOverride 1002 null;
        "mirrors" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "passHostHeader" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "responseForwarding" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "serversTransport" = mkOverride 1002 null;
        "sticky" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringHealthCheck" = {
      options = {
        "followRedirects" = mkOption {
          description = "FollowRedirects defines whether redirects should be followed during the health check calls.\nDefault: true";
          type = types.nullOr types.bool;
        };
        "headers" = mkOption {
          description = "Headers defines custom headers to be sent to the health check endpoint.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "hostname" = mkOption {
          description = "Hostname defines the value of hostname in the Host header of the health check request.";
          type = types.nullOr types.str;
        };
        "interval" = mkOption {
          description = "Interval defines the frequency of the health check calls.\nDefault: 30s";
          type = types.nullOr (types.either types.int types.str);
        };
        "method" = mkOption {
          description = "Method defines the healthcheck method.";
          type = types.nullOr types.str;
        };
        "mode" = mkOption {
          description = "Mode defines the health check mode.\nIf defined to grpc, will use the gRPC health check protocol to probe the server.\nDefault: http";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the server URL path for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Port defines the server URL port for the health check endpoint.";
          type = types.nullOr types.int;
        };
        "scheme" = mkOption {
          description = "Scheme replaces the server URL scheme for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "Status defines the expected HTTP status code of the response to the health check request.";
          type = types.nullOr types.int;
        };
        "timeout" = mkOption {
          description = "Timeout defines the maximum duration Traefik will wait for a health check request before considering the server unhealthy.\nDefault: 5s";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "followRedirects" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "interval" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "timeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrors" = {
      options = {
        "healthCheck" = mkOption {
          description = "Healthcheck defines health checks for ExternalName services.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsHealthCheck"
          );
        };
        "kind" = mkOption {
          description = "Kind defines the kind of the Service.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service or TraefikService.\nThe differentiation between the two is specified in the Kind field.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service or TraefikService.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "passHostHeader" = mkOption {
          description = "PassHostHeader defines whether the client Host header is forwarded to the upstream Kubernetes Service.\nBy default, passHostHeader is true.";
          type = types.nullOr types.bool;
        };
        "percent" = mkOption {
          description = "Percent defines the part of the traffic to mirror.\nSupported values: 0 to 100.";
          type = types.nullOr types.int;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseForwarding" = mkOption {
          description = "ResponseForwarding defines how Traefik forwards the response from the upstream Kubernetes Service to the client.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsResponseForwarding"
          );
        };
        "scheme" = mkOption {
          description = "Scheme defines the scheme to use for the request to the upstream Kubernetes Service.\nIt defaults to https when Kubernetes Service port is 443, http otherwise.";
          type = types.nullOr types.str;
        };
        "serversTransport" = mkOption {
          description = "ServersTransport defines the name of ServersTransport resource to use.\nIt allows to configure the transport between Traefik and your servers.\nCan only be used on a Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "sticky" = mkOption {
          description = "Sticky defines the sticky sessions configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#sticky-sessions";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsSticky");
        };
        "strategy" = mkOption {
          description = "Strategy defines the load balancing strategy between the servers.\nSupported values are: wrr (Weighed round-robin) and p2c (Power of two choices).\nRoundRobin value is deprecated and supported for backward compatibility.";
          type = types.nullOr types.str;
        };
        "weight" = mkOption {
          description = "Weight defines the weight and should only be specified when Name references a TraefikService object\n(and to be precise, one that embeds a Weighted Round Robin).";
          type = types.nullOr types.int;
        };
      };

      config = {
        "healthCheck" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "passHostHeader" = mkOverride 1002 null;
        "percent" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "responseForwarding" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "serversTransport" = mkOverride 1002 null;
        "sticky" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsHealthCheck" = {
      options = {
        "followRedirects" = mkOption {
          description = "FollowRedirects defines whether redirects should be followed during the health check calls.\nDefault: true";
          type = types.nullOr types.bool;
        };
        "headers" = mkOption {
          description = "Headers defines custom headers to be sent to the health check endpoint.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "hostname" = mkOption {
          description = "Hostname defines the value of hostname in the Host header of the health check request.";
          type = types.nullOr types.str;
        };
        "interval" = mkOption {
          description = "Interval defines the frequency of the health check calls.\nDefault: 30s";
          type = types.nullOr (types.either types.int types.str);
        };
        "method" = mkOption {
          description = "Method defines the healthcheck method.";
          type = types.nullOr types.str;
        };
        "mode" = mkOption {
          description = "Mode defines the health check mode.\nIf defined to grpc, will use the gRPC health check protocol to probe the server.\nDefault: http";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the server URL path for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Port defines the server URL port for the health check endpoint.";
          type = types.nullOr types.int;
        };
        "scheme" = mkOption {
          description = "Scheme replaces the server URL scheme for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "Status defines the expected HTTP status code of the response to the health check request.";
          type = types.nullOr types.int;
        };
        "timeout" = mkOption {
          description = "Timeout defines the maximum duration Traefik will wait for a health check request before considering the server unhealthy.\nDefault: 5s";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "followRedirects" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "interval" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "timeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsResponseForwarding" = {
      options = {
        "flushInterval" = mkOption {
          description = "FlushInterval defines the interval, in milliseconds, in between flushes to the client while copying the response body.\nA negative value means to flush immediately after each write to the client.\nThis configuration is ignored when ReverseProxy recognizes a response as a streaming response;\nfor such responses, writes are flushed to the client immediately.\nDefault: 100ms";
          type = types.nullOr types.str;
        };
      };

      config = {
        "flushInterval" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsSticky" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie defines the sticky cookie configuration.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsStickyCookie"
          );
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringMirrorsStickyCookie" = {
      options = {
        "domain" = mkOption {
          description = "Domain defines the host to which the cookie will be sent.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#domaindomain-value";
          type = types.nullOr types.str;
        };
        "httpOnly" = mkOption {
          description = "HTTPOnly defines whether the cookie can be accessed by client-side APIs, such as JavaScript.";
          type = types.nullOr types.bool;
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the number of seconds until the cookie expires.\nWhen set to a negative number, the cookie expires immediately.\nWhen set to zero, the cookie never expires.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "Name defines the Cookie name.";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the path that must exist in the requested URL for the browser to send the Cookie header.\nWhen not provided the cookie will be sent on every request to the domain.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#pathpath-value";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "SameSite defines the same site policy.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "Secure defines whether the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "httpOnly" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringResponseForwarding" = {
      options = {
        "flushInterval" = mkOption {
          description = "FlushInterval defines the interval, in milliseconds, in between flushes to the client while copying the response body.\nA negative value means to flush immediately after each write to the client.\nThis configuration is ignored when ReverseProxy recognizes a response as a streaming response;\nfor such responses, writes are flushed to the client immediately.\nDefault: 100ms";
          type = types.nullOr types.str;
        };
      };

      config = {
        "flushInterval" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringSticky" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie defines the sticky cookie configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecMirroringStickyCookie");
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecMirroringStickyCookie" = {
      options = {
        "domain" = mkOption {
          description = "Domain defines the host to which the cookie will be sent.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#domaindomain-value";
          type = types.nullOr types.str;
        };
        "httpOnly" = mkOption {
          description = "HTTPOnly defines whether the cookie can be accessed by client-side APIs, such as JavaScript.";
          type = types.nullOr types.bool;
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the number of seconds until the cookie expires.\nWhen set to a negative number, the cookie expires immediately.\nWhen set to zero, the cookie never expires.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "Name defines the Cookie name.";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the path that must exist in the requested URL for the browser to send the Cookie header.\nWhen not provided the cookie will be sent on every request to the domain.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#pathpath-value";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "SameSite defines the same site policy.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "Secure defines whether the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "httpOnly" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeighted" = {
      options = {
        "services" = mkOption {
          description = "Services defines the list of Kubernetes Service and/or TraefikService to load-balance, with weight.";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "traefik.io.v1alpha1.TraefikServiceSpecWeightedServices" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "sticky" = mkOption {
          description = "Sticky defines whether sticky sessions are enabled.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#stickiness-and-load-balancing";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeightedSticky");
        };
      };

      config = {
        "services" = mkOverride 1002 null;
        "sticky" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedServices" = {
      options = {
        "healthCheck" = mkOption {
          description = "Healthcheck defines health checks for ExternalName services.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesHealthCheck"
          );
        };
        "kind" = mkOption {
          description = "Kind defines the kind of the Service.";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "Name defines the name of the referenced Kubernetes Service or TraefikService.\nThe differentiation between the two is specified in the Kind field.";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "Namespace defines the namespace of the referenced Kubernetes Service or TraefikService.";
          type = types.nullOr types.str;
        };
        "nativeLB" = mkOption {
          description = "NativeLB controls, when creating the load-balancer,\nwhether the LB's children are directly the pods IPs or if the only child is the Kubernetes Service clusterIP.\nThe Kubernetes Service itself does load-balance to the pods.\nBy default, NativeLB is false.";
          type = types.nullOr types.bool;
        };
        "nodePortLB" = mkOption {
          description = "NodePortLB controls, when creating the load-balancer,\nwhether the LB's children are directly the nodes internal IPs using the nodePort when the service type is NodePort.\nIt allows services to be reachable when Traefik runs externally from the Kubernetes cluster but within the same network of the nodes.\nBy default, NodePortLB is false.";
          type = types.nullOr types.bool;
        };
        "passHostHeader" = mkOption {
          description = "PassHostHeader defines whether the client Host header is forwarded to the upstream Kubernetes Service.\nBy default, passHostHeader is true.";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "Port defines the port of a Kubernetes Service.\nThis can be a reference to a named port.";
          type = types.nullOr (types.either types.int types.str);
        };
        "responseForwarding" = mkOption {
          description = "ResponseForwarding defines how Traefik forwards the response from the upstream Kubernetes Service to the client.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesResponseForwarding"
          );
        };
        "scheme" = mkOption {
          description = "Scheme defines the scheme to use for the request to the upstream Kubernetes Service.\nIt defaults to https when Kubernetes Service port is 443, http otherwise.";
          type = types.nullOr types.str;
        };
        "serversTransport" = mkOption {
          description = "ServersTransport defines the name of ServersTransport resource to use.\nIt allows to configure the transport between Traefik and your servers.\nCan only be used on a Kubernetes Service.";
          type = types.nullOr types.str;
        };
        "sticky" = mkOption {
          description = "Sticky defines the sticky sessions configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#sticky-sessions";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesSticky");
        };
        "strategy" = mkOption {
          description = "Strategy defines the load balancing strategy between the servers.\nSupported values are: wrr (Weighed round-robin) and p2c (Power of two choices).\nRoundRobin value is deprecated and supported for backward compatibility.";
          type = types.nullOr types.str;
        };
        "weight" = mkOption {
          description = "Weight defines the weight and should only be specified when Name references a TraefikService object\n(and to be precise, one that embeds a Weighted Round Robin).";
          type = types.nullOr types.int;
        };
      };

      config = {
        "healthCheck" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "nativeLB" = mkOverride 1002 null;
        "nodePortLB" = mkOverride 1002 null;
        "passHostHeader" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "responseForwarding" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "serversTransport" = mkOverride 1002 null;
        "sticky" = mkOverride 1002 null;
        "strategy" = mkOverride 1002 null;
        "weight" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesHealthCheck" = {
      options = {
        "followRedirects" = mkOption {
          description = "FollowRedirects defines whether redirects should be followed during the health check calls.\nDefault: true";
          type = types.nullOr types.bool;
        };
        "headers" = mkOption {
          description = "Headers defines custom headers to be sent to the health check endpoint.";
          type = types.nullOr (types.attrsOf types.str);
        };
        "hostname" = mkOption {
          description = "Hostname defines the value of hostname in the Host header of the health check request.";
          type = types.nullOr types.str;
        };
        "interval" = mkOption {
          description = "Interval defines the frequency of the health check calls.\nDefault: 30s";
          type = types.nullOr (types.either types.int types.str);
        };
        "method" = mkOption {
          description = "Method defines the healthcheck method.";
          type = types.nullOr types.str;
        };
        "mode" = mkOption {
          description = "Mode defines the health check mode.\nIf defined to grpc, will use the gRPC health check protocol to probe the server.\nDefault: http";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the server URL path for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "port" = mkOption {
          description = "Port defines the server URL port for the health check endpoint.";
          type = types.nullOr types.int;
        };
        "scheme" = mkOption {
          description = "Scheme replaces the server URL scheme for the health check endpoint.";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "Status defines the expected HTTP status code of the response to the health check request.";
          type = types.nullOr types.int;
        };
        "timeout" = mkOption {
          description = "Timeout defines the maximum duration Traefik will wait for a health check request before considering the server unhealthy.\nDefault: 5s";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "followRedirects" = mkOverride 1002 null;
        "headers" = mkOverride 1002 null;
        "hostname" = mkOverride 1002 null;
        "interval" = mkOverride 1002 null;
        "method" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "scheme" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
        "timeout" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesResponseForwarding" = {
      options = {
        "flushInterval" = mkOption {
          description = "FlushInterval defines the interval, in milliseconds, in between flushes to the client while copying the response body.\nA negative value means to flush immediately after each write to the client.\nThis configuration is ignored when ReverseProxy recognizes a response as a streaming response;\nfor such responses, writes are flushed to the client immediately.\nDefault: 100ms";
          type = types.nullOr types.str;
        };
      };

      config = {
        "flushInterval" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesSticky" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie defines the sticky cookie configuration.";
          type = types.nullOr (
            submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesStickyCookie"
          );
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedServicesStickyCookie" = {
      options = {
        "domain" = mkOption {
          description = "Domain defines the host to which the cookie will be sent.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#domaindomain-value";
          type = types.nullOr types.str;
        };
        "httpOnly" = mkOption {
          description = "HTTPOnly defines whether the cookie can be accessed by client-side APIs, such as JavaScript.";
          type = types.nullOr types.bool;
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the number of seconds until the cookie expires.\nWhen set to a negative number, the cookie expires immediately.\nWhen set to zero, the cookie never expires.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "Name defines the Cookie name.";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the path that must exist in the requested URL for the browser to send the Cookie header.\nWhen not provided the cookie will be sent on every request to the domain.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#pathpath-value";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "SameSite defines the same site policy.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "Secure defines whether the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "httpOnly" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedSticky" = {
      options = {
        "cookie" = mkOption {
          description = "Cookie defines the sticky cookie configuration.";
          type = types.nullOr (submoduleOf "traefik.io.v1alpha1.TraefikServiceSpecWeightedStickyCookie");
        };
      };

      config = {
        "cookie" = mkOverride 1002 null;
      };
    };
    "traefik.io.v1alpha1.TraefikServiceSpecWeightedStickyCookie" = {
      options = {
        "domain" = mkOption {
          description = "Domain defines the host to which the cookie will be sent.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#domaindomain-value";
          type = types.nullOr types.str;
        };
        "httpOnly" = mkOption {
          description = "HTTPOnly defines whether the cookie can be accessed by client-side APIs, such as JavaScript.";
          type = types.nullOr types.bool;
        };
        "maxAge" = mkOption {
          description = "MaxAge defines the number of seconds until the cookie expires.\nWhen set to a negative number, the cookie expires immediately.\nWhen set to zero, the cookie never expires.";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "Name defines the Cookie name.";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "Path defines the path that must exist in the requested URL for the browser to send the Cookie header.\nWhen not provided the cookie will be sent on every request to the domain.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie#pathpath-value";
          type = types.nullOr types.str;
        };
        "sameSite" = mkOption {
          description = "SameSite defines the same site policy.\nMore info: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite";
          type = types.nullOr types.str;
        };
        "secure" = mkOption {
          description = "Secure defines whether the cookie can only be transmitted over an encrypted connection (i.e. HTTPS).";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "domain" = mkOverride 1002 null;
        "httpOnly" = mkOverride 1002 null;
        "maxAge" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "sameSite" = mkOverride 1002 null;
        "secure" = mkOverride 1002 null;
      };
    };
  };
in
{
  # all resource versions
  options = {
    resources = {
      "hub.traefik.io"."v1alpha1"."AIService" = mkOption {
        description = "AIService is a Kubernetes-like Service to interact with a text-based LLM provider. It defines the parameters and credentials required to interact with various LLM providers.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.AIService" "aiservices" "AIService" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."API" = mkOption {
        description = "API defines an HTTP interface that is exposed to external clients. It specifies the supported versions\nand provides instructions for accessing its documentation. Once instantiated, an API object is associated\nwith an Ingress, IngressRoute, or HTTPRoute resource, enabling the exposure of the described API to the outside world.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.API" "apis" "API" "hub.traefik.io" "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."APIBundle" = mkOption {
        description = "APIBundle defines a set of APIs.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIBundle" "apibundles" "APIBundle" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."APICatalogItem" = mkOption {
        description = "APICatalogItem defines APIs that will be part of the API catalog on the portal.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APICatalogItem" "apicatalogitems" "APICatalogItem"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."APIPlan" = mkOption {
        description = "APIPlan defines API Plan policy.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIPlan" "apiplans" "APIPlan" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."APIPortal" = mkOption {
        description = "APIPortal defines a developer portal for accessing the documentation of APIs.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIPortal" "apiportals" "APIPortal" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."APIRateLimit" = mkOption {
        description = "APIRateLimit defines how group of consumers are rate limited on a set of APIs.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIRateLimit" "apiratelimits" "APIRateLimit"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."APIVersion" = mkOption {
        description = "APIVersion defines a version of an API.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIVersion" "apiversions" "APIVersion"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."AccessControlPolicy" = mkOption {
        description = "AccessControlPolicy defines an access control policy.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.AccessControlPolicy" "accesscontrolpolicies"
            "AccessControlPolicy"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."ManagedApplication" = mkOption {
        description = "ManagedApplication represents a managed application.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.ManagedApplication" "managedapplications"
            "ManagedApplication"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "hub.traefik.io"."v1alpha1"."ManagedSubscription" = mkOption {
        description = "ManagedSubscription defines a Subscription managed by the API manager as the result of a pre-negotiation with its\nAPI consumers. This subscription grant consuming access to a set of APIs to a set of Applications.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.ManagedSubscription" "managedsubscriptions"
            "ManagedSubscription"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."IngressRoute" = mkOption {
        description = "IngressRoute is the CRD implementation of a Traefik HTTP Router.";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.IngressRoute" "ingressroutes" "IngressRoute"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."IngressRouteTCP" = mkOption {
        description = "IngressRouteTCP is the CRD implementation of a Traefik TCP Router.";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.IngressRouteTCP" "ingressroutetcps" "IngressRouteTCP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."IngressRouteUDP" = mkOption {
        description = "IngressRouteUDP is a CRD implementation of a Traefik UDP Router.";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.IngressRouteUDP" "ingressrouteudps" "IngressRouteUDP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."Middleware" = mkOption {
        description = "Middleware is the CRD implementation of a Traefik Middleware.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/overview/";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.Middleware" "middlewares" "Middleware" "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."MiddlewareTCP" = mkOption {
        description = "MiddlewareTCP is the CRD implementation of a Traefik TCP middleware.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/overview/";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.MiddlewareTCP" "middlewaretcps" "MiddlewareTCP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."ServersTransport" = mkOption {
        description = "ServersTransport is the CRD implementation of a ServersTransport.\nIf no serversTransport is specified, the default@internal will be used.\nThe default@internal serversTransport is created from the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#serverstransport_1";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.ServersTransport" "serverstransports" "ServersTransport"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."ServersTransportTCP" = mkOption {
        description = "ServersTransportTCP is the CRD implementation of a TCPServersTransport.\nIf no tcpServersTransport is specified, a default one named default@internal will be used.\nThe default@internal tcpServersTransport can be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#serverstransport_3";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.ServersTransportTCP" "serverstransporttcps"
            "ServersTransportTCP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."TLSOption" = mkOption {
        description = "TLSOption is the CRD implementation of a Traefik TLS Option, allowing to configure some parameters of the TLS connection.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#tls-options";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.TLSOption" "tlsoptions" "TLSOption" "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."TLSStore" = mkOption {
        description = "TLSStore is the CRD implementation of a Traefik TLS Store.\nFor the time being, only the TLSStore named default is supported.\nThis means that you cannot have two stores that are named default in different Kubernetes namespaces.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#certificates-stores";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.TLSStore" "tlsstores" "TLSStore" "traefik.io" "v1alpha1"
        );
        default = { };
      };
      "traefik.io"."v1alpha1"."TraefikService" = mkOption {
        description = "TraefikService is the CRD implementation of a Traefik Service.\nTraefikService object allows to:\n- Apply weight to Services on load-balancing\n- Mirror traffic on services\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-traefikservice";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.TraefikService" "traefikservices" "TraefikService"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
    }
    // {
      "aiServices" = mkOption {
        description = "AIService is a Kubernetes-like Service to interact with a text-based LLM provider. It defines the parameters and credentials required to interact with various LLM providers.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.AIService" "aiservices" "AIService" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "apis" = mkOption {
        description = "API defines an HTTP interface that is exposed to external clients. It specifies the supported versions\nand provides instructions for accessing its documentation. Once instantiated, an API object is associated\nwith an Ingress, IngressRoute, or HTTPRoute resource, enabling the exposure of the described API to the outside world.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.API" "apis" "API" "hub.traefik.io" "v1alpha1"
        );
        default = { };
      };
      "apiBundles" = mkOption {
        description = "APIBundle defines a set of APIs.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIBundle" "apibundles" "APIBundle" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "apiCatalogItems" = mkOption {
        description = "APICatalogItem defines APIs that will be part of the API catalog on the portal.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APICatalogItem" "apicatalogitems" "APICatalogItem"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "apiPlans" = mkOption {
        description = "APIPlan defines API Plan policy.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIPlan" "apiplans" "APIPlan" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "apiPortals" = mkOption {
        description = "APIPortal defines a developer portal for accessing the documentation of APIs.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIPortal" "apiportals" "APIPortal" "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "apiRateLimits" = mkOption {
        description = "APIRateLimit defines how group of consumers are rate limited on a set of APIs.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIRateLimit" "apiratelimits" "APIRateLimit"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "apiVersions" = mkOption {
        description = "APIVersion defines a version of an API.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.APIVersion" "apiversions" "APIVersion"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "accessControlPolicies" = mkOption {
        description = "AccessControlPolicy defines an access control policy.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.AccessControlPolicy" "accesscontrolpolicies"
            "AccessControlPolicy"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "ingressRoutes" = mkOption {
        description = "IngressRoute is the CRD implementation of a Traefik HTTP Router.";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.IngressRoute" "ingressroutes" "IngressRoute"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "ingressRouteTCPs" = mkOption {
        description = "IngressRouteTCP is the CRD implementation of a Traefik TCP Router.";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.IngressRouteTCP" "ingressroutetcps" "IngressRouteTCP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "ingressRouteUDPs" = mkOption {
        description = "IngressRouteUDP is a CRD implementation of a Traefik UDP Router.";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.IngressRouteUDP" "ingressrouteudps" "IngressRouteUDP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "managedApplications" = mkOption {
        description = "ManagedApplication represents a managed application.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.ManagedApplication" "managedapplications"
            "ManagedApplication"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "managedSubscriptions" = mkOption {
        description = "ManagedSubscription defines a Subscription managed by the API manager as the result of a pre-negotiation with its\nAPI consumers. This subscription grant consuming access to a set of APIs to a set of Applications.";
        type = types.attrsOf (
          submoduleForDefinition "hub.traefik.io.v1alpha1.ManagedSubscription" "managedsubscriptions"
            "ManagedSubscription"
            "hub.traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "middlewares" = mkOption {
        description = "Middleware is the CRD implementation of a Traefik Middleware.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/http/overview/";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.Middleware" "middlewares" "Middleware" "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "middlewareTCPs" = mkOption {
        description = "MiddlewareTCP is the CRD implementation of a Traefik TCP middleware.\nMore info: https://doc.traefik.io/traefik/v3.4/middlewares/overview/";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.MiddlewareTCP" "middlewaretcps" "MiddlewareTCP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "serversTransports" = mkOption {
        description = "ServersTransport is the CRD implementation of a ServersTransport.\nIf no serversTransport is specified, the default@internal will be used.\nThe default@internal serversTransport is created from the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#serverstransport_1";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.ServersTransport" "serverstransports" "ServersTransport"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "serversTransportTCPs" = mkOption {
        description = "ServersTransportTCP is the CRD implementation of a TCPServersTransport.\nIf no tcpServersTransport is specified, a default one named default@internal will be used.\nThe default@internal tcpServersTransport can be configured in the static configuration.\nMore info: https://doc.traefik.io/traefik/v3.4/routing/services/#serverstransport_3";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.ServersTransportTCP" "serverstransporttcps"
            "ServersTransportTCP"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "tlsOptions" = mkOption {
        description = "TLSOption is the CRD implementation of a Traefik TLS Option, allowing to configure some parameters of the TLS connection.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#tls-options";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.TLSOption" "tlsoptions" "TLSOption" "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
      "tlsStores" = mkOption {
        description = "TLSStore is the CRD implementation of a Traefik TLS Store.\nFor the time being, only the TLSStore named default is supported.\nThis means that you cannot have two stores that are named default in different Kubernetes namespaces.\nMore info: https://doc.traefik.io/traefik/v3.4/https/tls/#certificates-stores";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.TLSStore" "tlsstores" "TLSStore" "traefik.io" "v1alpha1"
        );
        default = { };
      };
      "traefikServices" = mkOption {
        description = "TraefikService is the CRD implementation of a Traefik Service.\nTraefikService object allows to:\n- Apply weight to Services on load-balancing\n- Mirror traffic on services\nMore info: https://doc.traefik.io/traefik/v3.4/routing/providers/kubernetes-crd/#kind-traefikservice";
        type = types.attrsOf (
          submoduleForDefinition "traefik.io.v1alpha1.TraefikService" "traefikservices" "TraefikService"
            "traefik.io"
            "v1alpha1"
        );
        default = { };
      };
    };
  };

  config = {
    # expose resource definitions
    inherit definitions;

    # register resource types
    types = [
      {
        name = "aiservices";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "AIService";
        attrName = "aiServices";
      }
      {
        name = "apis";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "API";
        attrName = "apis";
      }
      {
        name = "apibundles";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIBundle";
        attrName = "apiBundles";
      }
      {
        name = "apicatalogitems";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APICatalogItem";
        attrName = "apiCatalogItems";
      }
      {
        name = "apiplans";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIPlan";
        attrName = "apiPlans";
      }
      {
        name = "apiportals";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIPortal";
        attrName = "apiPortals";
      }
      {
        name = "apiratelimits";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIRateLimit";
        attrName = "apiRateLimits";
      }
      {
        name = "apiversions";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIVersion";
        attrName = "apiVersions";
      }
      {
        name = "accesscontrolpolicies";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "AccessControlPolicy";
        attrName = "accessControlPolicies";
      }
      {
        name = "managedapplications";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "ManagedApplication";
        attrName = "managedApplications";
      }
      {
        name = "managedsubscriptions";
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "ManagedSubscription";
        attrName = "managedSubscriptions";
      }
      {
        name = "ingressroutes";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRoute";
        attrName = "ingressRoutes";
      }
      {
        name = "ingressroutetcps";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRouteTCP";
        attrName = "ingressRouteTCPs";
      }
      {
        name = "ingressrouteudps";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRouteUDP";
        attrName = "ingressRouteUDPs";
      }
      {
        name = "middlewares";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "Middleware";
        attrName = "middlewares";
      }
      {
        name = "middlewaretcps";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "MiddlewareTCP";
        attrName = "middlewareTCPs";
      }
      {
        name = "serverstransports";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "ServersTransport";
        attrName = "serversTransports";
      }
      {
        name = "serverstransporttcps";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "ServersTransportTCP";
        attrName = "serversTransportTCPs";
      }
      {
        name = "tlsoptions";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "TLSOption";
        attrName = "tlsOptions";
      }
      {
        name = "tlsstores";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "TLSStore";
        attrName = "tlsStores";
      }
      {
        name = "traefikservices";
        group = "traefik.io";
        version = "v1alpha1";
        kind = "TraefikService";
        attrName = "traefikServices";
      }
    ];

    resources = {
      "hub.traefik.io"."v1alpha1"."AIService" = mkAliasDefinitions options.resources."aiServices";
      "hub.traefik.io"."v1alpha1"."API" = mkAliasDefinitions options.resources."apis";
      "hub.traefik.io"."v1alpha1"."APIBundle" = mkAliasDefinitions options.resources."apiBundles";
      "hub.traefik.io"."v1alpha1"."APICatalogItem" =
        mkAliasDefinitions
          options.resources."apiCatalogItems";
      "hub.traefik.io"."v1alpha1"."APIPlan" = mkAliasDefinitions options.resources."apiPlans";
      "hub.traefik.io"."v1alpha1"."APIPortal" = mkAliasDefinitions options.resources."apiPortals";
      "hub.traefik.io"."v1alpha1"."APIRateLimit" = mkAliasDefinitions options.resources."apiRateLimits";
      "hub.traefik.io"."v1alpha1"."APIVersion" = mkAliasDefinitions options.resources."apiVersions";
      "hub.traefik.io"."v1alpha1"."AccessControlPolicy" =
        mkAliasDefinitions
          options.resources."accessControlPolicies";
      "traefik.io"."v1alpha1"."IngressRoute" = mkAliasDefinitions options.resources."ingressRoutes";
      "traefik.io"."v1alpha1"."IngressRouteTCP" = mkAliasDefinitions options.resources."ingressRouteTCPs";
      "traefik.io"."v1alpha1"."IngressRouteUDP" = mkAliasDefinitions options.resources."ingressRouteUDPs";
      "hub.traefik.io"."v1alpha1"."ManagedApplication" =
        mkAliasDefinitions
          options.resources."managedApplications";
      "hub.traefik.io"."v1alpha1"."ManagedSubscription" =
        mkAliasDefinitions
          options.resources."managedSubscriptions";
      "traefik.io"."v1alpha1"."Middleware" = mkAliasDefinitions options.resources."middlewares";
      "traefik.io"."v1alpha1"."MiddlewareTCP" = mkAliasDefinitions options.resources."middlewareTCPs";
      "traefik.io"."v1alpha1"."ServersTransport" =
        mkAliasDefinitions
          options.resources."serversTransports";
      "traefik.io"."v1alpha1"."ServersTransportTCP" =
        mkAliasDefinitions
          options.resources."serversTransportTCPs";
      "traefik.io"."v1alpha1"."TLSOption" = mkAliasDefinitions options.resources."tlsOptions";
      "traefik.io"."v1alpha1"."TLSStore" = mkAliasDefinitions options.resources."tlsStores";
      "traefik.io"."v1alpha1"."TraefikService" = mkAliasDefinitions options.resources."traefikServices";
    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "AIService";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "API";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIBundle";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APICatalogItem";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIPlan";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIPortal";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIRateLimit";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "APIVersion";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "ManagedApplication";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "hub.traefik.io";
        version = "v1alpha1";
        kind = "ManagedSubscription";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRoute";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRouteTCP";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "IngressRouteUDP";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "Middleware";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "MiddlewareTCP";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "ServersTransport";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "ServersTransportTCP";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "TLSOption";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "TLSStore";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "traefik.io";
        version = "v1alpha1";
        kind = "TraefikService";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}
