# ./pkgs/vscode-custom.nix
{ pkgs, lib }:

oldAttrs: let
  cssFile = ./source/vscode-custom/custom.css;
  jsFile = ./source/vscode-custom/custom.js;
in {
  postInstall = ''
    workbench_html="$out/lib/vscode/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html"
    injection=""
    css_content=""
    js_content=""

    if [ -f "${cssFile}" ]; then
      echo "Injecting custom CSS from ${cssFile}..."
      css_content=$(cat "${cssFile}")
      injection="$injection<style>$css_content</style>
  "
    fi

    if [ -f "${jsFile}" ]; then
      echo "Injecting custom JS from ${jsFile}..."
      js_content=$(cat "${jsFile}")
      injection="$injection<script>$js_content</script>
  "
    fi

    tmpfile=$(mktemp)
    awk -v injection="$injection" '/<\/html>/ {print injection} {print}' "$workbench_html" > "$tmpfile"
    mv "$tmpfile" "$workbench_html"
  '';
}
