{ ... }:
{
  flake.homeModules.jj =
    { pkgs, lib, ... }:
    {
      programs.jjui = {
        enable = true;
        # Allow ctrl-c in every context where esc works
        settings.bindings = [
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "ui.cancel";
            scope = "ui";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "help.cancel";
            scope = "help";
            desc = "close";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "help.cancel";
            scope = "help.filter";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.quick_search_clear";
            scope = "revisions.quick_search";
            desc = "clear";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.rebase.cancel";
            scope = "revisions.rebase";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.squash.cancel";
            scope = "revisions.squash";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.revert.cancel";
            scope = "revisions.revert";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.duplicate.cancel";
            scope = "revisions.duplicate";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.details.confirmation.cancel";
            scope = "revisions.details.confirmation";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.evolog.cancel";
            scope = "revisions.evolog";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.abandon.cancel";
            scope = "revisions.abandon";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.set_parents.cancel";
            scope = "revisions.set_parents";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.inline_describe.cancel";
            scope = "revisions.inline_describe";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.set_bookmark.cancel";
            scope = "revisions.set_bookmark";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.target_picker.cancel";
            scope = "revisions.target_picker";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.ace_jump.cancel";
            scope = "revisions.ace_jump";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "revisions.quick_search.input.cancel";
            scope = "revisions.quick_search.input";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "status.input.cancel";
            scope = "status.input";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "file_search.cancel";
            scope = "file_search";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "bookmarks.cancel";
            scope = "bookmarks";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "bookmarks.cancel";
            scope = "bookmarks.filter";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "git.cancel";
            scope = "git";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "git.cancel";
            scope = "git.filter";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "oplog.close";
            scope = "oplog";
            desc = "close";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "oplog.quick_search.quick_search_clear";
            scope = "oplog.quick_search";
            desc = "clear";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "undo.cancel";
            scope = "undo";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "redo.cancel";
            scope = "redo";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "ui.cancel";
            scope = "diff";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "command_history.close";
            scope = "command_history";
            desc = "close";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "input.cancel";
            scope = "input";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "choose.cancel";
            scope = "choose";
            desc = "cancel";
          }
          {
            key = [
              "esc"
              "ctrl+c"
            ];
            action = "choose.cancel";
            scope = "choose.filter";
            desc = "cancel";
          }
          {
            key = [
              "left"
              "h"
              "esc"
              "ctrl+c"
            ];
            action = "revisions.details.cancel";
            scope = "revisions.details";
            desc = "cancel";
          }
        ];
      };
      programs.jujutsu = {
        enable = true;
        settings = {
          user.name = "Threated";
          user.email = "jan2001.07@gmail.com";
          ui.editor = "vim";
          ui.default-command = [
            "util"
            "exec"
            "--"
            "${lib.getExe pkgs.jjui}"
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
    };
}
