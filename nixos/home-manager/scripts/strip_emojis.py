#!/usr/bin/env python3

import subprocess
import os

# Emoji ranges (modify as desired)
emoji_ranges = [
    "1F300-1FAFF",  # Misc emoji, pictographs, symbols
    "1F600-1F64F",  # Emoticons
    "1F680-1F6FF",  # Transport & Map
    "2600-26FF",  # Misc Symbols
    "2700-27BF",  # Dingbats
]


# All basic multilingual plane except emoji
def make_include_list():
    def urange(r):
        start, end = [int(x, 16) for x in r.split("-")]
        return set(range(start, end + 1))

    allc = set(range(0x0020, 0xFFFF))
    for r in emoji_ranges:
        allc -= urange(r)
    return sorted(allc)


def main():
    from sys import argv

    if len(argv) < 2:
        print("Usage: {} FONT1.ttf [FONT2.ttf ...]".format(argv[0]))
        return

    include_codepoints = make_include_list()
    # Write include-list.txt in cwd
    with open("include-list.txt", "w") as f:
        f.write(",".join("{:04X}".format(cp) for cp in include_codepoints))

    # Process all font files passed as args
    for ttf in argv[1:]:
        if not os.path.isfile(ttf):
            print(f"File not found: {ttf}")
            continue
        outname = ttf.replace(".ttf", "-noemoji.ttf")
        print(f"Processing: {ttf} -> {outname}")
        subprocess.run(
            [
                "pyftsubset",
                ttf,
                f"--output-file={outname}",
                "--unicodes-file=include-list.txt",
            ],
            check=True,
        )

    print("All done. You can delete 'include-list.txt' now if you want.")


if __name__ == "__main__":
    main()
