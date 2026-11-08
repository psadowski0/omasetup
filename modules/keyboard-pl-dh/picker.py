#!/usr/bin/python3
"""Open Omarchy's keyboard layout picker with a readable Colemak-DH name.

Omarchy builds its keyboard catalog from setup-form.sh and kbd-model-map.
Polish Colemak-DH exists in xkeyboard-config as pl(colemak_dh), but it is not
in that catalog, so the stock picker falls back to the raw key
"pl:colemak_dh". This wrapper imports the stock picker and adds the label
xkeyboard-config itself uses.
"""

import os
from pathlib import Path
import sys


LABEL = "Polish (Colemak-DH ISO)"
KEY = "pl:colemak_dh"


def main():
    os.environ.setdefault("OMARCHY_PATH", "/usr/share/omarchy")
    methods = Path(os.environ["OMARCHY_PATH"]) / "default/input-methods"
    sys.path.insert(0, str(methods))

    try:
        import typing_setup
    except (ImportError, OSError) as error:
        print(f"keyboard-pl-dh: Omarchy's input-method helpers could not be loaded: {error}", file=sys.stderr)
        return 1

    original = typing_setup.keyboard_catalog

    def keyboard_catalog():
        catalog = original()
        catalog[KEY] = LABEL
        return catalog

    typing_setup.keyboard_catalog = keyboard_catalog

    if len(sys.argv) == 1:
        sys.argv.append("keyboard")
    typing_setup.main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
