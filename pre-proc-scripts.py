#!/usr/bin/env python3

"""
turn scripts into .as scripts
"""

from pathlib import Path
import pathlib

script_folder = Path("ml-scripts")
output_folder = Path("src/scripts")

def proc_line(line: str):
    if line.startswith("#"):
        line = " " + line  # prepend a space: does not trigger angelscript preprocessor + works in maniascript
    return line

def script_to_as_files(sf: Path):
    script_as_name = sf.stem + ".as"
    constant_name = sf.name.replace(".", "_").upper()
    lines = [f'const string {constant_name} = """']
    lines.extend(map(proc_line, sf.read_text().replace('"""', '_"_"_"_').replace('/*CUT\n','').replace('CUT*/\n','').splitlines()))
    lines.append(f'""".Replace(\'_"_"_"_\', \'"""\');')
    output_file = output_folder / script_as_name
    output_file.write_text("\n".join(lines))
    print(f"Processed: {sf} -- output: {output_file}")


def main():
    for script_file in script_folder.iterdir():
        if script_file.name.lower().endswith(".script.txt"):
            script_to_as_files(script_file)
        else:
            print(
                f"Warning, file in {script_folder} does not end with .Script.txt: {script_file}; suffixes: {script_file.suffixes}"
            )


if __name__ == "__main__":
    main()
