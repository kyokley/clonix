{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.clonix;
  ifNotNull = value: lib.mkIf (value != null) value;
  generateDeploymentHash = deployment: builtins.hashString "sha256" (builtins.toJSON deployment);
  generateService = deployment: {
    "clonix@${generateDeploymentHash deployment}-${deployment.deploymentName}" = {
      enable = true;
      unitConfig = {
        Description = "Clonix for ${deployment.deploymentName}: source: ${deployment.source.dir}, target: ${deployment.targetDir}";
        Wants = "network-online.target";
        After = "network-online.target";
      };

      serviceConfig = {
        User = "root";
        WorkingDirectory = deployment.source.dir;
        ExecStart = "${import ./cloner-script.nix {inherit cfg pkgs lib generateDeploymentHash;}}/bin/clonix-main ${generateDeploymentHash deployment}";
      };
    };
  };
  generateTimer = deployment: {
    "clonix@${generateDeploymentHash deployment}-${deployment.deploymentName}" = {
      enable = deployment.timer.enable;

      wantedBy = ["timers.target"];

      timerConfig = {
        OnActiveSec = ifNotNull deployment.timer.OnActiveSec;
        OnBootSec = ifNotNull deployment.timer.OnBootSec;
        OnStartupSec = ifNotNull deployment.timer.OnStartupSec;
        OnUnitActiveSec = ifNotNull deployment.timer.OnUnitActiveSec;
        OnUnitInactiveSec = ifNotNull deployment.timer.OnUnitInactiveSec;
        OnCalendar = ifNotNull deployment.timer.OnCalendar;
        Unit = "clonix@${generateDeploymentHash deployment}.service";
        Persistent = ifNotNull deployment.timer.Persistent;
      };
    };
  };
in {
  options.services.clonix = import ./options.nix {inherit lib pkgs;};

  config = lib.mkIf cfg.enable {
    systemd.services = lib.mkMerge (lib.lists.flatten (builtins.map generateService cfg.deployments));
    systemd.timers = lib.mkMerge (lib.lists.flatten (builtins.map generateTimer cfg.deployments));
  };
}
