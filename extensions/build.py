# Packs each folder in extensions/ into a .aseprite-extension file
# (a zip archive with package.json at its root).
#
#   python3 extensions/build.py

import pathlib
import zipfile

here = pathlib.Path(__file__).resolve().parent
license_file = here.parent / "LICENSE"

for folder in sorted(p for p in here.iterdir() if (p / "package.json").is_file()):
    out = here / f"{folder.name}.aseprite-extension"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(folder.iterdir()):
            if f.is_file():
                z.write(f, f.name)
        if license_file.is_file():
            z.write(license_file, "LICENSE")
    print(f"wrote {out.relative_to(here.parent)}")
