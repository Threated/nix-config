{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      self',
      lib,
      ...
    }:
    {
      packages.fish = inputs.wrapper-modules.lib.wrapPackage (
        let
          conf = ''
            set fish_greeting
            alias lsa "ls -la"
            alias cat "bat"
            ${lib.getExe self'.packages.starship} init fish | source
          '';
          confFile = pkgs.writeText "config.fish" conf;
        in
        {
          inherit pkgs;
          package = pkgs.fish;
          extraPackages = [ self'.packages.starship ];
          passthru.shellPath = "/bin/fish";
          flags = {
            "-C" = "source ${confFile}";
          };
        }
      );
      packages.starship = inputs.wrapper-modules.lib.wrapPackage (
        let
          conf = ''
            format = "$all''${custom.jj}$cmd_duration$status$line_break$character"
            [container]
            disabled = true

            [hostname]
            disabled = true

            [status]
            disabled = false
            map_symbol = true
            pipestatus = true
            sigint_symbol = "⚡"
            format = "[➜ $status](bold red)"

            [username]
            disabled = true

            [custom.jj]
            description = "The current jj status"
            detect_folders = [".jj"]
            symbol = " "
            command = ''''
            jj log -r '@' --limit 1 --no-graph --ignore-working-copy --color always --template '
              separate(" ",
                change_id.shortest(4),
                bookmarks,
                "|",
                label("diff removed", concat(
                  if(conflict, "⨯"),
                  if(divergent, "≠"),
                  if(immutable, "⊘"),
                )),
                if(empty, label("diff added", "±0"), concat(
                  if(diff.stat().total_added() > 0,
                    label("diff added", "+" ++ diff.stat().total_added()),
                    ""),
                  if(diff.stat().total_removed() > 0,
                    " " ++ label("diff removed", "-" ++ diff.stat().total_removed()),
                    ""),
                )),
                coalesce(
                  truncate_end(29, description.first_line(), "…"),
                  "…",
                ),
              )
            '
            ''''

            [git_status]
            disabled = true

            [git_commit]
            disabled = true

            [git_metrics]
            disabled = true

            [git_branch]
            disabled = true
          '';
          confFile = pkgs.writeText "starship.toml" conf;
        in
        {
          inherit pkgs;
          package = pkgs.starship;
          env.STARSHIP_CONFIG = confFile;
        }
      );
    };
}
