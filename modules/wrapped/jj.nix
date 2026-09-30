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
              --cmd 'set runtimepath^=${pkgs.vimPlugins.plenary-nvim}' \
              --cmd 'set runtimepath^=${pkgs.vimPlugins.telescope-nvim}' \
              --cmd 'set runtimepath^=${pkgs.vimPlugins.onedarkpro-nvim}' \
              --cmd 'set runtimepath^=${treesitter}' \
              -u ${pkgs.writeText "jj-diff-editor.lua" (builtins.readFile ./jj-diff-editor.lua)} \
              -- "$1" "$2"; then
              if [[ -f "$JJUI_DIFF_ACCEPT" ]]; then
                exit 0
              fi
            fi
            if [[ -z "''${JJUI_DIFF_DISCARDED:-}" || ! -f "$JJUI_DIFF_DISCARDED" ]]; then
              echo "Diff editor failed" >&2
            fi
            exit 1
          '';
        };
      packages.jj-diff-edit =
        let
          copySnapshot = pkgs.writeShellApplication {
            name = "jj-copy-diff";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              cp -a "$1/." "$JJUI_DIFF_SESSION/left/"
              cp -a "$2/." "$JJUI_DIFF_SESSION/right/"
            '';
          };
          selectFile = pkgs.writeShellApplication {
            name = "jj-select-file";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              target="$2/$JJUI_DIFF_PATH"
              if [[ "$JJUI_HUNK_DELETE" == true ]]; then
                rm -f -- "$target"
              else
                mkdir -p -- "$(dirname "$target")"
                cat "$JJUI_HUNK_SELECTION" > "$target"
              fi
            '';
          };
        in
        pkgs.writeShellApplication {
          name = "jj-diff-edit";
          runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.jq ];
          text = ''
            capture_diff() {
              if [[ -n "''${JJUI_DIFF_PATH:-}" ]]; then
                rm -f -- "$JJUI_DIFF_SESSION/left/$JJUI_DIFF_PATH" "$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH"
              fi
              mkdir -p "$JJUI_DIFF_SESSION/left" "$JJUI_DIFF_SESSION/right"
              jj diffedit -r "$JJUI_DIFF_REVISION" "$JJUI_DIFF_FILESET" --tool jjui-copy \
                --config 'merge-tools.jjui-copy.program="${lib.getExe copySnapshot}"' \
                --config "merge-tools.jjui-copy.edit-args=[\"\$left\", \"\$right\"]" \
                --config ui.diff-instructions=false
              # Keep an unchanged file editable after its final hunk is moved.
              if [[ -n "''${JJUI_DIFF_PATH:-}" && ! -e "$JJUI_DIFF_SESSION/left/$JJUI_DIFF_PATH" && ! -e "$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH" ]]; then
                if [[ -n "$(jj file list -r "$JJUI_DIFF_REVISION" "$JJUI_DIFF_FILESET")" ]]; then
                  mkdir -p "$(dirname "$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH")" "$(dirname "$JJUI_DIFF_SESSION/left/$JJUI_DIFF_PATH")"
                  jj file show -r "$JJUI_DIFF_REVISION" "$JJUI_DIFF_FILESET" > "$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH"
                  cp "$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH" "$JJUI_DIFF_SESSION/left/$JJUI_DIFF_PATH"
                fi
              fi
            }

            file_base() {
              if [[ ! -f "$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH" ]]; then
                while IFS= read -r parent; do
                  if [[ -n "$(jj file list -r "commit_id(\"$parent\")" "$JJUI_DIFF_FILESET")" ]]; then
                    JJUI_DIFF_BASE="commit_id(\"$parent\")"
                    break
                  fi
                done < <(jj log --no-graph -r "parents($JJUI_DIFF_REVISION)" -T 'commit_id ++ "\n"')
              fi
            }

            stage_edits() {
              local baseline='root()'
              if [[ -z "$(jj --at-operation "$operation" file list -r "$JJUI_DIFF_REVISION" "$JJUI_DIFF_FILESET")" ]]; then
                baseline="$JJUI_DIFF_BASE"
              fi
              export JJUI_HUNK_SELECTION="$JJUI_DIFF_SESSION/right/$JJUI_DIFF_PATH"
              export JJUI_HUNK_DELETE=false
              if [[ ! -f "$JJUI_HUNK_SELECTION" ]]; then JJUI_HUNK_DELETE=true; fi
              stage diffedit --from "$baseline" --to "$JJUI_DIFF_REVISION" "$JJUI_DIFF_FILESET" \
                --tool jjui-select \
                --config 'merge-tools.jjui-select.program="${lib.getExe selectFile}"' \
                --config "merge-tools.jjui-select.edit-args=[\"\$left\", \"\$right\"]" \
                --config ui.diff-instructions=false
            }

            # Build a prospective operation without changing the live graph or
            # working copy. No-op commands leave the operation unchanged.
            stage() {
              local output
              if ! jj --at-operation "$operation" --ignore-working-copy --no-integrate-operation \
                --color never "$@" 2> "$JJUI_DIFF_SESSION/stage.log"; then
                cat "$JJUI_DIFF_SESSION/stage.log" >&2
                return 1
              fi
              output=$(cat "$JJUI_DIFF_SESSION/stage.log")
              if [[ "$output" =~ Operation\ left\ uncommitted\ because\ --no-integrate-operation\ was\ requested:\ ([[:xdigit:]]+) ]]; then
                operation="''${BASH_REMATCH[1]}"
              elif [[ "$output" != *"Nothing changed."* ]]; then
                cat "$JJUI_DIFF_SESSION/stage.log" >&2
                echo "Could not identify the prospective jj operation" >&2
                return 1
              fi
            }

            accept_operation() {
              jj op integrate "$operation"
              # Integrating an operation updates the graph but deliberately
              # leaves the on-disk working copy at its previous operation.
              jj workspace update-stale
            }

            if [[ "$1" == --action ]]; then
              direction="$2"
              case "$direction" in
                load)
                  JJUI_DIFF_BASE="''${JJUI_DIFF_INITIAL:-$JJUI_DIFF_BASE}"
                  capture_diff
                  file_base
                  jq -n --arg base "$JJUI_DIFF_BASE" '{base: $base}'
                  exit 0
                  ;;
                apply|before|after) ;;
                *) echo "Invalid diff editor action" >&2; exit 1 ;;
              esac
              # Comparing against root includes unchanged files too, so they
              # remain editable after the last hunk has been extracted.
              jj log --no-graph -r "$JJUI_DIFF_REVISION" -T '""' > /dev/null
              operation=$(jj op log --no-graph -n 1 -T id)
              if [[ "$direction" == apply && -n "''${JJUI_DIFF_APPLY:-}" ]]; then
                while IFS= read -r file; do
                  JJUI_DIFF_PATH=$(jq -r .path <<< "$file")
                  JJUI_DIFF_BASE=$(jq -r .base <<< "$file")
                  JJUI_DIFF_FILESET="file:$(jq -c .path <<< "$file")"
                  stage_edits
                done < <(jq -c '.[]' <<< "$JJUI_DIFF_APPLY")
              else
                stage_edits
              fi
              if [[ "$direction" != apply ]]; then
                case "$direction" in
                  before) placement=--insert-before ;;
                  after) placement=--insert-after ;;
                esac
                export JJUI_HUNK_SELECTION="$JJUI_DIFF_SESSION/selected"
                JJUI_HUNK_DELETE=$(jq -r .delete "$JJUI_HUNK_REQUEST")
                destination_file="$JJUI_DIFF_SESSION/$direction-change"
                if [[ -f "$destination_file" ]]; then
                  destination=$(cat "$destination_file")
                  move_args=(squash --from "$JJUI_DIFF_REVISION" --into "change_id(\"$destination\")" \
                    --keep-emptied --use-destination-message)
                else
                  move_args=(split -r "$JJUI_DIFF_REVISION" "$placement" "$JJUI_DIFF_REVISION" --message "")
                fi
                stage "''${move_args[@]}" "$JJUI_DIFF_FILESET" --tool jjui-select \
                  --config 'merge-tools.jjui-select.program="${lib.getExe selectFile}"' \
                  --config "merge-tools.jjui-select.edit-args=[\"\$left\", \"\$right\"]" \
                  --config ui.diff-instructions=false
                if [[ ! -f "$destination_file" ]]; then
                  case "$direction" in
                    before) destination_revision="parents($JJUI_DIFF_REVISION)" ;;
                    after) destination_revision="children($JJUI_DIFF_REVISION)" ;;
                  esac
                  destination=$(jj --at-operation "$operation" log --no-graph -r "exactly($destination_revision, 1)" -T change_id)
                fi
                conflicts=$(jj --at-operation "$operation" log --no-graph \
                  -r "($JJUI_DIFF_REVISION | change_id(\"$destination\")) & conflicts()" -T 'change_id.short() ++ "\n"')
                if [[ -n "$conflicts" ]]; then
                  echo "Extraction rejected: it would leave conflicts in the current or destination change. Select adjacent hunks together, or try the other direction." >&2
                  exit 1
                fi
                accept_operation
                printf '%s' "$destination" > "$destination_file"
                capture_diff
              else
                accept_operation
              fi
              exit 0
            fi

            unset JJUI_DIFF_PICKER
            if [[ "$1" == --pick ]]; then
              revision="$2"
              mapfile -d "" -t changed_paths < <(jj diff -r "$revision" --color never -T 'path ++ "\0"')
              if [[ "''${#changed_paths[@]}" == 0 ]]; then
                echo "This change has no files to edit" >&2
                exit 0
              fi
              export JJUI_DIFF_FILESET
              JJUI_DIFF_FILESET="file:$(jq -cn --arg path "''${changed_paths[0]}" '$path')"
              export JJUI_DIFF_PICKER=true
              line=1
            else
              revision="$1"
              export JJUI_DIFF_FILESET="$2"
              line="$3"
            fi
            session_dir=$(mktemp -d)
            trap 'rm -rf "$session_dir"' EXIT
            export JJUI_DIFF_SESSION="$session_dir"
            export JJUI_DIFF_ACTION="$0"
            export JJUI_HUNK_REQUEST="$session_dir/request.json"
            export JJUI_HUNK_SELECTION="$session_dir/selected"
            export JJUI_DIFF_DISCARDED="$session_dir/discarded"

            change_id=$(jj log --no-graph -r "$revision" -T change_id)
            export JJUI_DIFF_REVISION="change_id(\"$change_id\")"
            initial_commit=$(jj log --no-graph -r "$JJUI_DIFF_REVISION" -T commit_id)
            export JJUI_DIFF_BASE="commit_id(\"$initial_commit\")"
            export JJUI_DIFF_INITIAL="$JJUI_DIFF_BASE"
            unset JJUI_DIFF_PATH JJUI_DIFF_APPLY
            capture_diff
            mapfile -d "" -t paths < <(
              find "$session_dir/left" "$session_dir/right" \
                \( -type f -o -type l \) ! -name JJ-INSTRUCTIONS -printf '%P\0' | sort -zu
            )
            if [[ "''${#paths[@]}" != 1 ]]; then
              echo "Expected a diff for exactly one file" >&2
              exit 1
            fi
            export JJUI_DIFF_PATH="''${paths[0]}"
            file_base
            if ${lib.getExe self'.packages.jj-diff-editor} "$session_dir/left" "$session_dir/right" "$line"; then
              exit 0
            elif [[ -f "$JJUI_DIFF_DISCARDED" ]]; then
              exit 0
            else
              exit 1
            fi
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
                name = "revisions.edit_diff";
                key = "shift+e";
                scope = "revisions";
                desc = "edit change files";
                lua = ''
                  local commit_id = context.commit_id()
                  if commit_id == nil then return end
                  local revision = 'commit_id("' .. commit_id .. '")'
                  local files = jj({"diff", "-r", revision, "--name-only"})
                  if files == nil or files == "" then
                    flash("This change has no files to edit")
                    return
                  end
                  jj_interactive({
                    "util", "exec", "--", "${lib.getExe self'.packages.jj-diff-edit}",
                    "--pick", revision
                  })
                  revisions.refresh()
                '';
              }
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
                    "util", "exec", "--", "${lib.getExe self'.packages.jj-diff-edit}",
                    revision, file, tostring(line)
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
