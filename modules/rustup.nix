{ ... }:
{
  flake.nixosModules.rustup =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.programs.rustup-wild;
      user = config.users.users.${cfg.user};
      cargoHome = "${user.home}/.cargo";

      muslCompiler = pkgs.writeShellScriptBin "musl-clang" ''
        exec ${lib.getExe pkgs.llvmPackages.clang-unwrapped} \
          --target=x86_64-unknown-linux-musl \
          -nostdlibinc \
          -isystem ${pkgs.musl.dev}/include \
          "$@"
      '';

      wildLinker = pkgs.writeShellScriptBin "wild-linker" ''
        exec ${lib.getExe pkgs.clang} --ld-path=${pkgs.wild}/bin/ld.wild "$@"
      '';

      cargoConfig = (pkgs.formats.toml { }).generate "cargo-config.toml" {
        env = {
          # cc-rs otherwise guesses x86_64-linux-musl-gcc. Reuse Clang with
          # musl's sysroot wrapper instead of pulling in a cross-GCC toolchain.
          CC_x86_64_unknown_linux_musl = lib.getExe muslCompiler;
          CXX_x86_64_unknown_linux_musl = lib.getExe muslCompiler;
          AR_x86_64_unknown_linux_musl = lib.getExe' pkgs.clang "ar";
        };

        target = {
          x86_64-unknown-linux-gnu.linker = lib.getExe wildLinker;
          x86_64-unknown-linux-musl.linker = lib.getExe wildLinker;
        };
      };
    in
    {
      options.programs.rustup-wild = {
        enable = lib.mkEnableOption "rustup with Wild as Cargo's default Linux linker";

        user = lib.mkOption {
          type = lib.types.str;
          description = "User whose global Cargo configuration should use Wild.";
          example = "alice";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = user.isNormalUser;
            message = "programs.rustup-wild.user must name a normal user";
          }
        ];

        users.users.${cfg.user}.packages = [ pkgs.rustup ];

        # Cargo needs its home to remain writable for registries and caches, so
        # only the declarative config file is linked into it.
        systemd.tmpfiles.rules = [
          "d ${cargoHome} 0755 ${cfg.user} ${user.group} - -"
          "L+ ${cargoHome}/config.toml - - - - ${cargoConfig}"
        ];
      };
    };
}
