{ config, inputs, ... }:
let
  diffTheme = config.theme // { selection = "#30353D"; };
in
{
  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    {
      packages.jj-diff-editor =
        let
          treesitter = pkgs.symlinkJoin {
            name = "jj-diff-treesitter";
            paths = with pkgs.vimPlugins.nvim-treesitter; [
              parsers.nix
              parsers.rust
              queries.nix
              queries.rust
            ];
          };
        in
        pkgs.writeShellApplication {
          name = "jj-diff-editor";
          runtimeInputs = [ pkgs.coreutils ];
          text = ''
            if [[ $# != 2 && $# != 3 ]]; then
              echo "usage: jj-diff-editor LEFT RIGHT [LINE]" >&2
              exit 2
            fi
            export JJUI_DIFF_LINE="''${3:-}"
            if [[ -n "$JJUI_DIFF_LINE" && ! "$JJUI_DIFF_LINE" =~ ^[1-9][0-9]*$ ]]; then
              echo "LINE must be a positive integer" >&2
              exit 2
            fi

            session_dir=$(mktemp -d)
            trap 'rm -rf "$session_dir"' EXIT
            export JJUI_DIFF_ACCEPT="$session_dir/accepted"

            if ${lib.getExe pkgs.neovim-unwrapped} --noplugin -n -i NONE \
              --cmd 'set runtimepath^=${pkgs.vimPlugins.mini-diff}' \
              --cmd 'set runtimepath^=${treesitter}' \
              -u ${pkgs.writeText "jj-diff-editor.lua" (''
                vim.g.jj_diff_theme = vim.json.decode([==[${builtins.toJSON diffTheme}]==])
              '' + builtins.readFile ./jj-diff-editor.lua)} \
              -- "$1" "$2"; then
              if [[ -f "$JJUI_DIFF_ACCEPT" ]]; then
                exit 0
              fi
            fi
            echo "Diff edit discarded" >&2
            exit 1
          '';
        };
      packages.git = inputs.wrapper-modules.wrappers.git.wrap {
        inherit pkgs;
        settings.user = {
          name = "Threated";
          email = "jan2001.07@gmail.com";
        };
      };
      packages.jj =
        let
          remoteChange = pkgs.writeShellScript "jj-remote-change" ''
            set -euo pipefail

            action="$1"
            shift
            revision="''${1:-@}"
            if (( $# > 0 )); then
              shift
            fi

            local_commit="$(
              jj log --no-graph -r "exactly(($revision), 1)" \
                -T 'commit_id ++ "\n"'
            )"
            change_id="$(
              jj log --no-graph -r "commit_id($local_commit)" \
                -T 'change_id.normal_hex() ++ "\n"'
            )"
            remote_commits="$(
              jj log --no-graph -r '::remote_bookmarks()' \
                -T "if(change_id.normal_hex() == \"$change_id\", commit_id ++ \"\\n\")"
            )"
            if [[ -z "$remote_commits" || "$remote_commits" == *$'\n'* ]]; then
              echo "expected exactly one remote version of $revision with change ID $change_id" >&2
              exit 1
            fi
            remote_commit="$remote_commits"

            case "$action" in
              diff)
                exec jj diff --from "commit_id($remote_commit)" --to "commit_id($local_commit)" "$@"
                ;;
              extract)
                if (( $# > 0 )); then
                  echo "usage: jj erc [REVISION]" >&2
                  exit 2
                fi

                jj new "commit_id($remote_commit)"
                jj restore --from "commit_id($local_commit)"

                if [[ -n "$(jj log --no-graph -r "children(commit_id($local_commit))" -T 'commit_id')" ]]; then
                  jj rebase -s "children(commit_id($local_commit))" -o "commit_id($remote_commit)"
                fi
                if [[ -n "$(jj log --no-graph -r "bookmarks() & commit_id($local_commit)" -T 'commit_id')" ]]; then
                  jj bookmark move \
                    --from "commit_id($local_commit)" \
                    --to "commit_id($remote_commit)" \
                    --allow-backwards
                fi

                jj abandon "commit_id($local_commit)"
                ;;
              *)
                echo "unknown remote-change action: $action" >&2
                exit 2
                ;;
            esac
          '';
        in
        inputs.wrapper-modules.wrappers.jujutsu.wrap {
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
            aliases = {
              # Diff a locally rewritten change against the version reachable
              # from a remote bookmark with the same change ID.
              drc = [
                "util"
                "exec"
                "--"
                "${remoteChange}"
                "diff"
              ];
              # Extract that diff into a new leaf based on the remote version,
              # then discard the local variant from the reviewed stack.
              erc = [
                "util"
                "exec"
                "--"
                "${remoteChange}"
                "extract"
              ];
            };
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
            ui.colors."diff:selected".bg = diffTheme.selection;
            actions = [
              {
                name = "diff.edit_revision";
                key = "e";
                scope = "diff";
                desc = "edit selected hunk";
                lua = ''
                  local revision = jjui.diff.target_revision()
                  local file = jjui.diff.target_file()
                  local line = jjui.diff.target_line()
                  if revision == nil or file == nil or line == nil then
                    flash("No editable text hunk at the selected line")
                    return
                  end
                  jj_interactive({
                    "diffedit", "-r", revision, file,
                    "--tool", "jjui-neovim",
                    "--config", 'merge-tools.jjui-neovim.program="${lib.getExe self'.packages.jj-diff-editor}"',
                    "--config", 'merge-tools.jjui-neovim.edit-args=["$left", "$right", "' .. tostring(line) .. '"]',
                    "--config", "ui.diff-instructions=false"
                  })
                  revisions.refresh()
                  jjui.diff.refresh()
                '';
              }
              {
                name = "revisions.reveal_parent";
                desc = "reveal and jump to parent";
                key = "shift+j";
                scope = "revisions";
                lua = ''
                  local commit_id = context.commit_id()
                  if commit_id ~= nil then
                    local selected = 'commit_id("' .. commit_id .. '")'
                    jjui.builtin.revset.set(
                      "(" .. revset.default() .. ") | " .. selected .. " | parents(" .. selected .. ")"
                    )
                    jjui.wait_refresh()
                    jjui.builtin.revisions.jump_to_parent()
                  end
                '';
              }
              {
                name = "revisions.reveal_child";
                desc = "reveal and jump to child";
                key = "shift+k";
                scope = "revisions";
                lua = ''
                  local commit_id = context.commit_id()
                  if commit_id ~= nil then
                    local selected = 'commit_id("' .. commit_id .. '")'
                    jjui.builtin.revset.set(
                      "(" .. revset.default() .. ") | " .. selected .. " | children(" .. selected .. ")"
                    )
                    jjui.wait_refresh()
                    jjui.builtin.revisions.jump_to_children()
                  end
                '';
              }
            ];
            bindings = allow_ctrl_c ++ [
              {
                key = "ctrl+j";
                action = "diff.next_file";
                scope = "diff";
                desc = "next file";
              }
              {
                key = "ctrl+k";
                action = "diff.prev_file";
                scope = "diff";
                desc = "prev file";
              }
              {
                key = [
                  "enter"
                  "alt+enter"
                  "ctrl+s"
                ];
                action = "revisions.inline_describe.accept";
                scope = "revisions.inline_describe";
                desc = "accept";
              }
              {
                key = "shift+enter";
                action = "revisions.inline_describe.new_line";
                scope = "revisions.inline_describe";
                desc = "new line";
              }
            ];
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
          package = pkgs.jjui.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./jjui-onscreen-hunk.patch ];
          });
          env = {
            JJUI_CONFIG_DIR = "${config_dir}";
          };
        }
      );
    };
}
