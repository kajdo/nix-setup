# ./pkgs/vscode-custom.nix
{ pkgs, lib }:

oldAttrs: rec {
  postInstall = ''
    workbench_html="$out/lib/vscode/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html"
    static_css_tag='<link rel="stylesheet" href="file:///etc/nixos/pkgs/source/vscode-custom/custom.css">'
    static_js_tag='<script src="file:///etc/nixos/pkgs/source/vscode-custom/custom.js"></script>'
    injection_tags="$static_css_tag\n$static_js_tag\n"

    echo "Injecting static custom tags into $workbench_html"
    sed -i "s|</html>|$injection_tags</html>|" "$workbench_html"
  '';
}
