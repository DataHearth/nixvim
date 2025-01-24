{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (lib)
    optionalString
    types
    ;
  inherit (lib.nixvim)
    defaultNullOpts
    mkNullOrOption
    toLuaObject
    ;

  cfg = config.plugins.dap.extensions.dap-python;
  dapHelpers = import ./dapHelpers.nix { inherit lib; };
in
{
  options.plugins.dap.extensions.dap-python = {
    enable = lib.mkEnableOption "dap-python";

    package = lib.mkPackageOption pkgs "dap-python" {
      default = [
        "vimPlugins"
        "nvim-dap-python"
      ];
    };

    adapterPythonPath = lib.mkOption {
      default = lib.getExe (pkgs.python3.withPackages (ps: with ps; [ debugpy ]));
      defaultText = lib.literalExpression ''
        lib.getExe (pkgs.python3.withPackages (ps: with ps; [ debugpy ]))
      '';
      description = "Path to the python interpreter. Path must be absolute or in $PATH and needs to have the debugpy package installed.";
      type = types.str;
    };

    console = defaultNullOpts.mkEnumFirstDefault [
      "integratedTerminal"
      "internalConsole"
      "externalTerminal"
    ] "Debugpy console.";

    customConfigurations = mkNullOrOption (types.listOf dapHelpers.configurationOption) "Custom python configurations for dap.";

    includeConfigs = defaultNullOpts.mkBool true "Add default configurations.";

    resolvePython = defaultNullOpts.mkLuaFn null ''
      Function to resolve path to python to use for program or test execution.
      By default the `VIRTUAL_ENV` and `CONDA_PREFIX` environment variables are used if present.
    '';

    testRunner = mkNullOrOption (types.either types.str types.rawLua) ''
      The name of test runner to use by default.
      The default value is dynamic and depends on `pytest.ini` or `manage.py` markers.
      If neither is found "unittest" is used.
    '';

    testRunners = mkNullOrOption (with lib.types; attrsOf strLuaFn) ''
      Set to register test runners.
      Built-in are test runners for unittest, pytest and django.
      The key is the test runner name, the value a function to generate the
      module name to run and its arguments.
      See |dap-python.TestRunner|.
    '';
  };

  config =
    let
      options = with cfg; {
        inherit console;
        include_configs = includeConfigs;
      };
    in
    lib.mkIf cfg.enable {
      extraPlugins = [ cfg.package ];

      plugins.dap = {
        enable = true;

        extensionConfigLua =
          ''
            require("dap-python").setup("${cfg.adapterPythonPath}", ${toLuaObject options})
          ''
          + (optionalString (cfg.testRunners != null) ''
            table.insert(require("dap-python").test_runners,
            ${toLuaObject (builtins.mapAttrs (_: lib.nixvim.mkRaw) cfg.testRunners)})
          '')
          + (optionalString (cfg.customConfigurations != null) ''
            table.insert(require("dap").configurations.python, ${toLuaObject cfg.customConfigurations})
          '')
          + (optionalString (cfg.resolvePython != null) ''
            require("dap-python").resolve_python = ${toLuaObject cfg.resolvePython}
          '')
          + (optionalString (cfg.testRunner != null) ''
            require("dap-python").test_runner = ${toLuaObject cfg.testRunner};
          '');
      };
    };
}
