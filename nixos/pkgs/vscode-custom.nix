# ./pkgs/vscode-custom.nix
{ pkgs, lib }:

oldAttrs: let
  cssFile = ./source/vscode-custom/custom.css; # adjust as needed
  jsFile  = ./source/vscode-custom/custom.js;  # adjust as needed
in {
  postInstall = ''
    workbench_html="$out/lib/vscode/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html"
    # Patch CSS: still fine to inline as style tag
    css_injection=""
    if [ -f "${cssFile}" ]; then
      echo "Injecting custom CSS from ${cssFile}..."
      css_content=$(cat "${cssFile}")
      css_injection="<style>$css_content</style>
"
      # Insert CSS block before </html>
      tmpfile=$(mktemp)
      awk -v injection="$css_injection" '/<\/html>/ {print injection} {print}' "$workbench_html" > "$tmpfile"
      mv "$tmpfile" "$workbench_html"
    fi

    # Patch JS: Append JS directly to workbench.js (CSP-safe)
    workbench_js_dir="$(dirname "$workbench_html")"
    workbench_js="$workbench_js_dir/workbench.js"
    if [ -f "${jsFile}" ] && [ -f "$workbench_js" ]; then
      echo "Appending custom JS from ${jsFile} to $workbench_js"
      echo "//=== BEGIN VSCODIUM CUSTOM INJECTION ===" >> "$workbench_js"
      cat "${jsFile}" >> "$workbench_js"
      echo "//=== END VSCODIUM CUSTOM INJECTION ===" >> "$workbench_js"
    fi
  '';
}
