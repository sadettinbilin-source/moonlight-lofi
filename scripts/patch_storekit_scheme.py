#!/usr/bin/env python3
"""Point the scheme Run and Test actions at Products.storekit.

XcodeGen records scheme.run.storeKitConfiguration on LaunchAction and ignores
the same key on the test action. UI tests launch through TestAction, so the
paywall never receives the configuration unless it is copied across.

The identifier is relative to xcshareddata (XcodeGen's default schemePathPrefix
of ../../). From there, ../../MoonlightLofi/Resources/Products.storekit is the
file in the repo.
"""

import re
import sys
from pathlib import Path

IDENTIFIER = "../../MoonlightLofi/Resources/Products.storekit"
BLOCK = (
    "      <StoreKitConfigurationFileReference\n"
    f'         identifier = "{IDENTIFIER}">\n'
    "      </StoreKitConfigurationFileReference>\n"
)
ROOT = Path(__file__).resolve().parents[1]
SCHEME = ROOT / "MoonlightLofi.xcodeproj/xcshareddata/xcschemes/MoonlightLofi.xcscheme"


def patch_action(text: str, name: str) -> str:
    match = re.search(rf"(<{name}\b[^>]*>)(.*?)(</{name}>)", text, re.DOTALL)
    if match is None:
        sys.exit(f"{SCHEME} has no {name}")
    body = match.group(2)
    if "<StoreKitConfigurationFileReference" in body:
        body = re.sub(
            r'identifier = "[^"]*"',
            f'identifier = "{IDENTIFIER}"',
            body,
            count=1,
        )
    else:
        body = body + BLOCK
    return text[: match.start()] + match.group(1) + body + match.group(3) + text[match.end() :]


def main() -> None:
    if not SCHEME.is_file():
        sys.exit(f"Missing scheme. Run xcodegen generate first: {SCHEME}")
    text = patch_action(SCHEME.read_text(), "LaunchAction")
    text = patch_action(text, "TestAction")
    SCHEME.write_text(text)
    resolved = (SCHEME.parents[1] / IDENTIFIER).resolve()
    if not resolved.is_file():
        sys.exit(f"StoreKit path does not resolve to a file: {resolved}")
    for name in ("LaunchAction", "TestAction"):
        section = re.search(rf"<{name}\b.*?</{name}>", text, re.DOTALL)
        if section is None or IDENTIFIER not in section.group(0):
            sys.exit(f"{name} is missing {IDENTIFIER}")
        print(f"{name} -> {IDENTIFIER}")


if __name__ == "__main__":
    main()
