{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.dconf;
  dag = config.lib.dag;

  toDconfIni = generators.toINI { mkKeyValue = mkIniKeyValue; };

  mkIniKeyValue = key: value:
    let
      tweakVal = v:
        if isString v then "'${v}'"
        else if isList v then "[" + concatStringsSep "," (map tweakVal v) + "]"
        else if isBool v then (if v then "true" else "false")
        else toString v;
    in
      "${key}=${tweakVal value}";

  primitive = with types; either bool (either int str);

in

{
  meta.maintainers = [ maintainers.gnidorah maintainers.rycee ];

  options = {
    dconf.settings = mkOption {
      type = with types;
        attrsOf (attrsOf (either primitive (listOf primitive)));
      default = {};
      example = literalExample ''
        {
          "org/gnome/calculator" = {
            button-mode = "programming";
            show-thousands = true;
            base = 10;
            word-size = 64;
          };
        }
      '';
      description = ''
        Settings to write to the dconf configuration system.
      '';
    };
  };

  config = mkIf (cfg.settings != {}) {
    systemd.user.services.dconf-settings =
      let
        iniFile = pkgs.writeText "hm-dconf.ini" (toDconfIni cfg.settings);
      in
        {
          Install = {
            WantedBy = [ "graphical-session-pre.target" ];
          };

          Unit = {
            Description = "Load dconf settings";
          };

          Service = {
            Type = "oneshot";
            ExecStart = pkgs.writeScript "hm-dconf" ''
              #!${pkgs.stdenv.shell}

              ${pkgs.gnome3.dconf}/bin/dconf load / < ${iniFile}
            '';
          };
        };
  };
}
