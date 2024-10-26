# Contributing (and hacking onto) nixvim

This document is mainly for contributors to nixvim, but it can also be useful for extending nixvim.

## Submitting a change

In order to submit a change you must be careful of several points:

- The code must be properly formatted. This can be done through `nix fmt`.
- The tests must pass. This can be done through `nix flake check --all-systems` (this also checks formatting).
- The change should try to avoid breaking existing configurations.
- If the change introduces a new feature it should add tests for it (see the architecture section for details).
- The commit title should be consistent with our style. This usually looks like "plugins/<name>: fixed some bug",
  you can browse the commit history of the files you're editing to see previous commit messages.

## Nixvim Architecture

Nixvim is mainly built around `pkgs.neovimUtils.makeNeovimConfig`.
This function takes a list of plugins (and a few other misc options), and generates a configuration for neovim.
This can then be passed to `pkgs.wrapNeovimUnstable` to generate a derivation that bundles the plugins, extra programs and the lua configuration.

All the options that nixvim expose end up in those three places. This is done in the `modules/output.nix` file.

The guiding principle of nixvim is to only add to the `init.lua` what the user added to the configuration. This means that we must trim out all the options that were not set.

This is done by making most of the options of the type `types.nullOr ....`, and not setting any option that is null.

### Plugin configurations

Most of nixvim is dedicated to wrapping neovim plugins such that we can configure them in Nix.
To add a new plugin you need to do the following.

1. Add a file in the correct sub-directory of [`plugins`](plugins).
  - Most plugins should be added to [`plugins/by-name/<name>`](plugins/by-name).
    Plugins in `by-name` are automatically imported 🚀
  - Occasionally, you may wish to add a plugin to a directory outside of `by-name`, such as [`plugins/colorschemes`](plugins/colorschemes).
    If so, you will also need to add your plugin to [`plugins/default.nix`](plugins/default.nix) to ensure it gets imported.
    Note: the imports list is sorted and grouped. In vim, you can usually use `V` (visual-line mode) with the `:sort` command to achieve the desired result.

2. The vast majority of plugins fall into one of those two categories:
- _vim plugins_: They are configured through **global variables** (`g:plugin_foo_option` in vimscript and `vim.g.plugin_foo_option` in lua).\
  For those, you should use the `lib.nixvim.vim-plugin.mkVimPlugin`.\
  -> See [this plugin](plugins/utils/direnv.nix) for an example.
- _neovim plugins_: They are configured through a `setup` function (`require('plugin').setup({opts})`).\
  For those, you should use the `lib.nixvim.neovim-plugin.mkNeovimPlugin`.\
  -> See the [template](plugins/TEMPLATE.nix).

3. Add the necessary parameters for the [`mkNeovimPlugin`](#mkneovimplugin)/[`mkVimPlugin`](#mkvimplugin)

#### `mkNeovimPlugin`

The `mkNeovimPlugin` function provide a standardize way to create a `Neovim` plugin.

| Parameter                  | Description                                                                                                                                                                                                 | Required | Default Value |
|----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|---------------|
| **name**                   | The name of the plugin.                                                                                                                                                                                      | Yes      | N/A           |
| **maintainers**            | Maintainers for the plugin.                                                                                                                                                                                  | Yes      | N/A           |
| **url**                    | The URL of the plugin's repository.                                                                                                                                                                          | Yes      | If not set, `package`'s' `homepage` attribute |
| **package**                | The nixpkgs package attr for this plugin. Can be a string, a list of strings, a module option, or any derivation. For example, "foo-bar-nvim" for `pkgs.vimPlugins.foo-bar-nvim`, or `[ "hello" "world" ]` will be referenced as `pkgs.hello.world`. | No       | `name` parameter |
| **imports**                | Additional Nix modules to import.                                                                                                                                                                            | No       | `[]`            |
| **description**            | A brief description of the plugin.                                                                                                                                                                           | No       | `null`          |
| **deprecateExtraOptions**  | Indicating whether to deprecate the `extraOptions` attribute. Mainly used for old plugins.                                                                                                                   | No       | `false`         |
| **optionsRenamedToSettings** | Options that have been renamed and move to the `settings` attribute.                                                                                                                                       | No       | `[]`            |
| **isColorscheme**          | Indicating whether the plugin is a colorscheme.                                                                                                                                                              | No       | `false`         |
| **colorscheme**            | The name of the colorscheme.                                                                                                                                                                                 | No       | `name` parameter |
| **configLocation**         | The location for the Lua configuration.                                                                                                                                                                      | No       | `"extraConfigLuaPre"` if `isColorscheme` is `true`, otherwise `"extraConfigLua"` |
| **hasConfigAttrs**         | Indicating whether the plugin has configuration attributes.                                                                                                                                                  | No       | `true`          |
| **originalName**           | The original name of the plugin.                                                                                                                                                                             | No       | `name` parameter |
| **settingsOptions**        | Options for the plugin's settings.                                                                                                                                                                           | No       | `{}`            |
| **settingsExample**        | An example configuration for the plugin's settings.                                                                                                                                                          | No       | `null`          |
| **settingsDescription**    | A description of the settings provided to the `require('${luaName}')${setup}` function.                                                                                                                      | No       | `"Options provided to the require('${luaName}')${setup} function."` |
| **hasSettings**            | Indicating whether the plugin has settings.                                                                                                                                                                  | No       | `true`          |
| **extraOptions**           | Additional options for the plugin.                                                                                                                                                                           | No       | `{}`            |
| **luaName**                | The Lua name for the plugin.                                                                                                                                                                                 | No       | `name` parameter |
| **setup**                  | The setup function for the plugin.                                                                                                                                                                           | No       | `".setup"`      |
| **extraConfig**            | Additional configuration for the plugin.                                                                                                                                                                     | No       | `{}`            |
| **extraPlugins**           | Extra plugins to include.                                                                                                                                                                                    | No       | `[]`            |
| **extraPackages**          | Extra packages to include.                                                                                                                                                                                   | No       | `[]`            |
| **callSetup**              | Indicating whether to call the setup function.                                                                                                                                                               | No       | `true`          |
| **installPackage**         | Indicating whether to install the package.                                                                                                                                                                   | No       | `true`          |
##### Functionality

The `mkNeovimPlugin` function generates a Nix module that:

1. Defines the plugin's metadata, including maintainers, description, and URL.
2. Sets up options for enabling the plugin, specifying the package, and configuring settings and Lua configuration.
3. Handles deprecations by renaming options to settings if necessary.
4. Merges additional configurations and plugins as specified.
5. Asserts that a valid configuration location is provided if the setup function is called.
6. Imports additional Nix modules as specified.

##### Example Usage

```nix
mkNeovimPlugin {
  name = "example-plugin";
  maintainers = [ lib.maintainers.user ];
  url = "https://github.com/example/example-plugin";
  description = "An example Neovim plugin";
  settingsOptions = {
    option1 = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "An example option";
    };
  };
}
```

This example defines a Neovim plugin named `example-plugin` with specified maintainers, URL, description, settings options, and additional configuration. `package` will be 'example-plugin'
thanks to package referring to the `name` attribute.


#### `mkVimPlugin`

The `mkVimPlugin` function provides a standardized way to create a `Vim` plugin.

| Parameter                | Description                                                                 | Required | Default Value |
|--------------------------|-----------------------------------------------------------------------------|----------|---------------|
| **name**                 | The name of the Vim plugin.                                                 | Yes      | N/A           |
| **url**                  | The URL of the plugin repository.                                           | Yes      | N/A           |
| **maintainers**          | The maintainers of the plugin.                                              | Yes      | Throw if not set and `package` doesn't contain a `homepage` attribute |
| **imports**              | A list of imports for the plugin.                                           | No       | `[]`          |
| **description**          | A description of the plugin.                                                | No       | `null`        |
| **deprecateExtraConfig** | Flag to deprecate extra configuration.                                      | No       | `false`       |
| **optionsRenamedToSettings** | List of options renamed to settings.                                    | No       | `[]`          |
| **isColorscheme**        | Flag to indicate if the plugin is a colorscheme.                            | No       | `false`       |
| **colorscheme**          | The name of the colorscheme.                                                | No       | `name` parameter |
| **originalName**         | The original name of the plugin.                                            | No       | `name` parameter |
| **package**              | The package for the plugin.                                                 | No       | `name` parameter |
| **settingsOptions**      | Settings options for the plugin.                                            | No       | `{}`          |
| **settingsExample**      | Example settings for the plugin.                                            | No       | `null`        |
| **globalPrefix**         | Global prefix for the settings.                                             | No       | `""`          |
| **extraOptions**         | Extra options for the plugin.                                               | No       | `{}`          |
| **extraConfig**          | Extra configuration for the plugin.                                         | No       | `cfg: {}`     |
| **extraPlugins**         | Extra plugins to include.                                                   | No       | `[]`          |
| **extraPackages**        | Extra packages to include.                                                  | No       | `[]`          |

##### Functionality

The `mkVimPlugin` function generates a Nix module that:

1. Defines the plugin's metadata, including maintainers, description, and URL.
2. Sets up options for enabling the plugin, specifying the package, and configuring settings and extra configuration.
3. Handles deprecations by renaming options to settings if necessary.
4. Merges additional configurations and plugins as specified.
5. Asserts that a valid configuration location is provided if the setup function is called.
6. Imports additional Nix modules as specified.

##### Example Usage

```nix
mkVimPlugin {
  name = "example-plugin";
  url = "https://github.com/example/plugin";
  maintainers = [ lib.maintainers.user ];
  description = "An example Vim plugin.";
  globalPrefix = "example_";
}
```

#### Declaring plugin options

> [!CAUTION]
> Declaring `settings`-options is **not required**, because the `settings` option is a freeform type.
>
> While `settings` options can be helpful for documentation and type-checking purposes, this is a double-edged sword because we have to ensure the options are correctly typed and documented to avoid unnecessary restrictions or confusion.

> [!TIP]
> Learn more about the [RFC 42](https://github.com/NixOS/rfcs/blob/master/rfcs/0042-config-option.md) which motivated this new approach.

If you feel having nix options for some of the upstream plugin options adds value and is worth the maintenance cost, you can declare these in `settingsOptions`.

Take care to ensure option names exactly match the upstream plugin's option names (without `globalsPrefix`, if used).
You must also ensure that the option type is permissive enough to avoid unnecessarily restricting config definitions.
If unsure, you can forego declaring the option or use a permissive type such as `lib.types.anything`.

There are a number of helpers added into `lib` that can help you correctly implement them:

- `lib.nixvim.defaultNullOpts.{mkBool,mkInt,mkStr,...}`: This family of helpers takes a default value and a description, and sets the Nix default to `null`.
  These are the main functions you should use to define options.
- `lib.nixvim.defaultNullOpts.<name>'`: These "prime" variants of the above helpers do the same thing, but expect a "structured" attrs argument.
  This allows more flexibility in what arguments are passed through to the underlying `lib.mkOption` call.
- `lib.types.rawLua`: A type to represent raw lua code. The values are of the form `{ __raw = "<code>";}`.

The resulting `settings` attrs will be directly translated to `lua` and will be forwarded the plugin:
- Using globals (`vim.g.<globalPrefix><option-name>`) for plugins using `mkVimPlugin`
- Using the `require('<plugin>').setup(<options>)` function for the plugins using `mkNeovimPlugin`

In either case, you don't need to bother implementing this part. It is done automatically.

### Tests

Most of the tests of nixvim consist of creating a neovim derivation with the supplied nixvim configuration, and then try to execute neovim to check for any output. All output is considered to be an error.

The tests are located in the [tests/test-sources](tests/test-sources) directory, and should be added to a file in the same hierarchy than the repository. For example if a plugin is defined in `./plugins/ui/foo.nix` the test should be added in `./tests/test-sources/ui/foo.nix`.

Tests can either be a simple attribute set, or a function taking `{pkgs}` as an input. The keys of the set are configuration names, and the values are a nixvim configuration.

You can specify the special `tests` attribute in the configuration that will not be interpreted by nixvim, but only the test runner. The following keys are available:

- `tests.dontRun`: avoid launching this test, simply build the configuration.

The tests are then runnable with `nix flake check --all-systems`.

There are a second set of tests, unit tests for nixvim itself, defined in `tests/lib-tests.nix` that use the `pkgs.lib.runTests` framework.

If you want to speed up tests, we have set up a Cachix for nixvim.
This way, only tests whose dependencies have changed will be re-run, speeding things up
considerably. To use it, just install cachix and run `cachix use nix-community`.
