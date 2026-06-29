{
  lib,
  stdenv,
  writers,
  ...
}@pkgs:
rec {
  mapSingleAttr =
    attr: f: set:
    set
    // (if (builtins.hasAttr attr set) then { ${attr} = f set.${attr}; } else { });

  processDensityFunction =
    df:
    if !(builtins.hasAttr "_df_type" df) then
      abort ''
        Untyped density function: ${df}.
        Density functions should be constructed with one of the functions provided in
        the lib.
      ''
    else if df._df_type == "unchecked" then
      builtins.toJSON df._nix
    else if df._df_type == "checked" then
      assert checkDensityFunction df._nix;
      builtins.toJSON df._nix
    else
      abort ''
        Unrecognised density function type: ${df._df_type}.
      '';

  hasMapAttr =
    attr: f: set:
    if builtins.hasAttr set then f set.attr else false;

  densityFunctionCheckers =
    let
      verifySimilar =
        verifyWith: types:
        types
        |> (builtins.map (name: {
          inherit name;
          value = verifyWith;
        }))
        |> builtins.listToAttrs;
      verifyOneArg = ({ argument, ... }: checkDensityFunction argument);
      verifyTwoArgs = (
        { argument1, argument2, ... }:
        checkDensityFunction argument1 && checkDensityFunction argument2
      );
    in
    (verifySimilar verifyTwoArgs [
      "add"
      "mul"
      "min"
      "max"
    ])
    // (verifySimilar verifyOneArg [
      "interpolated"
      "flat_cache"
      "cache_2d"
      "cache_once"
      "cache_all_in_cell"
      "abs"
      "square"
      "cube"
      "half_negative"
      "quater_negative"
      "squeeze"
      "invert"
    ]);

  checkDensityFunction =
    df:
    assert lib.assertMsg (
      lib.elem (builtins.typeOf df) [
        "int"
        "float"
        "string"
      ]
      || (densityFunctionCheckers.${df.type} df)
    ) "Invalid density function: ${df}";
    true;

  processPack =
    pack_data:
    pack_data
    |> (builtins.mapAttrs (
      namespace:
      (
        data:
        data
        |> mapSingleAttr "density_function" (
          builtins.mapAttrs (location: processDensityFunction)
        )
      )
    ));

  makePack =
    pack_config: pack_data:
    let
      processed_pack = processPack pack_data;
    in
    [
      (makeMCMeta pack_config)
      (makeDFs processed_pack)
    ]
    |> (builtins.concatStringsSep "\n\n");

  makeMCMeta =
    pack_config:
    let
      mcmeta_file = writers.writeJSON "pack.mcmeta" {
        format = 10;
      };
    in
    ''
      mkdir -p "$out/pack"
      cp ${mcmeta_file} "$out/pack/pack.mcmeta"
    '';

  makeDFs =
    processed_pack:
    processed_pack
    |> (lib.filterAttrs (_namespace: builtins.hasAttr "density_function"))
    |> (builtins.mapAttrs (_namespace: builtins.getAttr "density_function"))
    |> (lib.mapAttrsToList (
      namespace:
      (lib.mapAttrsToList (
        location: json: {
          path = "${namespace}/worldgen/density_function/${location}.json";
          json_file = builtins.toFile "df" json;
        }
      ))
    ))
    |> builtins.concatLists
    |> (builtins.map (
      { path, json_file }:
      ''
        mkdir -p $(dirname "$out/pack/${path}")
        cp "${json_file}" "$out/pack/${path}"
      ''
    ))
    |> (builtins.concatStringsSep "\n");
}
