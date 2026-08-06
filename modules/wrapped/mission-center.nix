{
  perSystem =
    { pkgs, ... }:
    let
      systemdInstancePatch = pkgs.writeText "mission-center-systemd-instance.patch" ''
        diff --git a/src/lib.rs b/src/lib.rs
        --- a/src/lib.rs
        +++ b/src/lib.rs
        @@ -519,5 +519,14 @@ fn app_id(path: &Path) -> Option<Rc<str>> {
                 Some(Rc::from(app_id))
             } else if dir_name.starts_with("app-") {
        +        // Instantiated application services use
        +        // app-<desktop-id>@<instance>.service. The instance is not part of
        +        // the desktop ID.
        +        if let Some(instance_separator) = dir_name.find('@') {
        +            return Some(Rc::from(
        +                dir_name["app-".len()..instance_separator].replace("\\x2d", "-"),
        +            ));
        +        }
        +
                 let extension = path.extension()?.to_string_lossy();
                 // Include the '.' in the extension
                 let extension = &dir_name[dir_name.len() - extension.len() - 1..];
      '';
    in
    {
      packages.mission-center = pkgs.mission-center.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          # Mission Center delegates app detection to app-rummage. Patch the
          # vendored crate to accept instantiated app services such as
          # app-<desktop-id>@<instance>.service, which Noctalia creates.
          cp -rL --no-preserve=mode,ownership \
            ${old.cargoDeps}/source-registry-0/app-rummage-0.2.9 \
            subprojects/magpie/app-rummage
          chmod -R u+w subprojects/magpie/app-rummage
          patch -d subprojects/magpie/app-rummage -p1 \
            < ${systemdInstancePatch}
          substituteInPlace subprojects/magpie/Cargo.toml \
            --replace-fail \
              '[workspace]' \
              $'[patch.crates-io]\napp-rummage = { path = "app-rummage" }\n\n[workspace]'
        '';
      });
    };
}
