#!/usr/bin/env bash

# This script now relies on the $out environment variable being set correctly
# We confirmed this is the case with the previous debug step.

echo "DEBUG: Using environment variable out: [$out]"

# Nix will replace these placeholders:
# __CUSTOM_FILES_SRC_NIX__  -> /nix/store/...-vscode-custom (actual Nix path)
# __WORKBENCH_REL_PATH_NIX__ -> lib/vscode/.../workbench.html (relative path string)

local rel_path="__WORKBENCH_REL_PATH_NIX__"
local custom_src_path="__CUSTOM_FILES_SRC_NIX__"

# Construct final paths using the environment $out directly
local workbench_html="$out/$rel_path"
local custom_css_src="$custom_src_path/custom.css"
local custom_js_src="$custom_src_path/custom.js"
local custom_dest_dir="$out/share/vscodium-custom" # Still needed to copy files into the package

# --- DEBUG LINES ---
echo "DEBUG: Final workbench_html='$workbench_html'"
echo "DEBUG: Final custom_css_src='$custom_css_src'"
echo "DEBUG: Final custom_js_src='$custom_js_src'"
echo "DEBUG: Final custom_dest_dir='$custom_dest_dir'"
# -------------------

echo "Attempting to patch: $workbench_html"

# Ensure the destination directory exists
mkdir -p "$custom_dest_dir"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create destination directory '$custom_dest_dir'"
    exit 1
fi

# Check and copy custom CSS
if test -f "$custom_css_src"; then
    echo "Copying custom CSS from $custom_css_src to $custom_dest_dir/custom.css"
    cp "$custom_css_src" "$custom_dest_dir/custom.css"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy CSS file."
        # exit 1 # Decide if this is fatal
    fi
else
    echo "Warning: Custom CSS file not found at $custom_css_src. Skipping CSS injection."
fi

# Check and copy custom JS
if test -f "$custom_js_src"; then
    echo "Copying custom JS from $custom_js_src to $custom_dest_dir/custom.js"
    cp "$custom_js_src" "$custom_dest_dir/custom.js"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to copy JS file."
        # exit 1 # Decide if this is fatal
    fi
else
    echo "Warning: Custom JS file not found at $custom_js_src. Skipping JS injection."
fi

# Prepare injection tags, only if the files were successfully copied
local css_tag=""
if test -f "$custom_dest_dir/custom.css"; then
    css_tag="<link rel=\"stylesheet\" href=\"file://${custom_dest_dir}/custom.css\">"
fi

local js_tag=""
if test -f "$custom_dest_dir/custom.js"; then
    js_tag="<script src=\"file://${custom_dest_dir}/custom.js\"></script>"
fi

# Combine tags carefully
local injection_tags=""
if [ -n "$css_tag" ]; then
    injection_tags+="$css_tag"
fi
if [ -n "$js_tag" ]; then
    if [ -n "$injection_tags" ]; then
        injection_tags+="\n$js_tag"
    else
        injection_tags+="$js_tag"
    fi
fi

# Inject tags only if there's something to inject and the target file exists
if [ -n "$injection_tags" ]; then
    if test -f "$workbench_html"; then
        echo "Injecting tags into $workbench_html"
        # Add newline before tags and before closing tag
        sed -i "s|</html>|\n$injection_tags\n</html>|" "$workbench_html"
        if [ $? -ne 0 ]; then
            echo "Error: sed failed to patch $workbench_html with status $?."
            exit 1
        else
            echo "Successfully patched $workbench_html"
        fi
    else
        echo "Error: Workbench HTML file not found at $workbench_html. Cannot inject tags."
        exit 1
    fi
else
    echo "No custom CSS or JS files found/copied. No tags injected."
fi

exit 0
