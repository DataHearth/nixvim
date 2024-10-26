{ lib, ... }:
lib.nixvim.neovim-plugin.mkNeovimPlugin {
  name = "nui";
  originalName = "nui.nvim";
  package = "nui-nvim";
  url = "https://github.com/MunifTanjim/nui.nvim/";
  description = "UI Component Library for Neovim";
  maintainers = [ lib.maintainers.DataHearth ];

  callSetup = false;
}
