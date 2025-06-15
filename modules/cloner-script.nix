{
  lib,
  pkgs,
  cfg,
  generateDeploymentHash,
  ...
}: let
  generateProperRsyncCmd = (
    deployment:
      "${cfg.packages.rsync}/bin/rsync "
      + "${
        if (deployment.extraOptions != null)
        then deployment.extraOptions + " "
        else ""
      }"
      + "-avh "
      + "${
        if deployment.remote.enable == true
        then
          (
            (
              if deployment.remote.user.password != null
              then "--rsh=\"${cfg.packages.sshpass}/bin/sshpass -p ${deployment.remote.user.password} ${cfg.packages.openssh}/bin/ssh -o StrictHostKeyChecking=no -l ${deployment.remote.user.name}\" "
              else ""
            )
            + (
              if deployment.remote.user.keyfile != null
              then "-e \"${cfg.packages.openssh}/bin/ssh -i ${deployment.remote.user.keyfile}\" "
              else ""
            )
            + (
              if deployment.remote.user.password == null && deployment.remote.user.keyfile == null
              then "--rsh=\"${cfg.packages.openssh}/bin/ssh -o 'StrictHostKeyChecking=no'\" "
              else ""
            )
          )
        else ""
      }"
      + "${
        if (builtins.length deployment.local.exclude > 0)
        then with lib; pipe deployment.local.exclude [
          (map (p: "--exclude=${p}"))
          (concatStringsSep " ")
          (prepend: "${prepend} ")
        ]
        else ""
      }"
      + "${deployment.local.dir}/* "
      + "${
        if deployment.remote.enable == true
        then "${deployment.remote.user.name}@${deployment.remote.ipOrHostname}:${deployment.targetDir} "
        else "${deployment.targetDir} "
      }"
      + "${if deployment.should-propagate-file-deletion then "--delete " else ""}"
  );

  uniqueRsyncCmd = (
    deployment: ''
      if [ "$1"  == "${generateDeploymentHash deployment}" ] ; then 

        ${generateProperRsyncCmd deployment}
      
      fi''
  );
in
  pkgs.writeShellScriptBin "clonix-main" ''
    set -euo pipefail
    ${lib.concatMapStringsSep "\n" (deployment:
      if (deployment != null)
      then (uniqueRsyncCmd deployment)
      else "")
    cfg.deployments}
  ''
