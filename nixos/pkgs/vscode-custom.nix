# ./pkgs/vscode-custom.nix
{ pkgs, lib, customFilesSrc }:

let
  workbenchHtmlRelPath = "lib/vscode/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html";
  rawScriptContent = builtins.readFile ./vscode-custom-script.sh;

  # Remove __OUT_SHELL__ replacement, keep others
  processedScript = lib.replaceStrings
    [ "__CUSTOM_FILES_SRC_NIX__" "__WORKBENCH_REL_PATH_NIX__" ]
    [ "${customFilesSrc}"         "${workbenchHtmlRelPath}" ]
    rawScriptContent;
in
oldAttrs:
{
  postInstall = ''
    ${oldAttrs.postInstall or ""}

    # The environment variable $out is available here automatically
    # Execute the processed script content directly
    ${processedScript}
  '';
  # Ensure bash is available if the script uses bash features
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ pkgs.bash ];
}
