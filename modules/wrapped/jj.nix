{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    {
      packages.jj = inputs.wrapper-modules.wrappers.jujutsu.wrap {
        inherit pkgs;
        settings = {
          user.name = "Threated";
          user.email = "jan2001.07@gmail.com";
          ui.editor = "vim";
          ui.default-command = [
            "util"
            "exec"
            "--"
            "${lib.getExe self'.packages.jjui}"
          ];
          templates.log = ''
            if(self.root(),
              format_root_commit(self),
              label(
                separate(" ",
                  if(self.current_working_copy(), "working_copy"),
                  if(self.immutable(), "immutable", "mutable"),
                  if(self.conflict(), "conflicted"),
                ),
                concat(
                  format_short_commit_header(self) ++ " ",
                  if(diff.stat().total_added() > 0,
                    label("diff added", "+" ++ diff.stat().total_added()),
                    ""),
                  if(diff.stat().total_removed() > 0,
                    " " ++ label("diff removed", "-" ++ diff.stat().total_removed()),
                    ""),
                  "\n",
                  separate(" ",
                    if(self.empty(), empty_commit_marker),
                    if(self.description(),
                      self.description().first_line(),
                      label(if(self.empty(), "empty"), description_placeholder),
                    ),
                  ) ++ "\n",
                ),
              )
            )
          '';
        };
      };
      packages.jjui = inputs.wrapper-modules.lib.wrapPackage (
        let
          from_git = pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/idursun/jjui/577b20190e23e802d6593af1865ceb22662208f3/internal/config/default/bindings.toml";
            hash = "sha256-zCmjMEkaiwcoNb/sX9LuT5LupXW/9SBsUFOaeF5sSEQ=";
          };
          base_keymap = fromTOML (builtins.readFile from_git);
          close_keymaps = builtins.filter (
            { key, ... }: if builtins.isString key then key == "esc" else lib.lists.elem "esc" key
          ) base_keymap.bindings;
          allow_ctrl_c = map (
            km:
            km
            // (
              if builtins.isString km.key then
                {
                  key = [
                    km.key
                    "ctrl+c"
                  ];
                }
              else
                {
                  key = km.key ++ [ "ctrl+c" ];
                }
            )
          ) close_keymaps;
          jjui_conf = {
            bindings = allow_ctrl_c;
          };
          toml = pkgs.formats.toml { };
          serialized_conf = toml.generate "jjui.toml" jjui_conf;
          config_dir = pkgs.runCommand "jjui-config" { } ''
            mkdir -p $out
            cp ${serialized_conf} $out/config.toml
          '';
        in
        {
          inherit pkgs;
          package = pkgs.jjui;
          env = {
            JJUI_CONFIG_DIR = "${config_dir}";
          };
        }
      );
    };
}
