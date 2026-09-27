from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
output = root.parents[1] / "outputs" / "KOMBAX_20156_R104_3_NETLIFY_ANDROID_ACCUMULATIVE.zip"
output.parent.mkdir(parents=True, exist_ok=True)

excluded_dirs = {".git", ".gradle", ".gradle-local", "node_modules", "__pycache__"}
excluded_files = {"keystore.properties", "local.properties"}
excluded_suffixes = {".jks", ".keystore", ".p12", ".pfx", ".apk", ".aab"}

files = []
for path in root.rglob("*"):
    if not path.is_file():
        continue
    rel = path.relative_to(root)
    if any(part in excluded_dirs for part in rel.parts):
        continue
    if "android" in rel.parts and "build" in rel.parts:
        continue
    if path.name in excluded_files or path.name.startswith(".env"):
        continue
    if path.suffix.lower() in excluded_suffixes:
        continue
    files.append((path, rel.as_posix()))

with ZipFile(output, "w", compression=ZIP_DEFLATED, compresslevel=4, allowZip64=True) as archive:
    for path, rel in sorted(files, key=lambda item: item[1]):
        archive.write(path, rel)

with ZipFile(output) as archive:
    bad = archive.testzip()
    if bad:
        raise RuntimeError(f"Corrupt ZIP entry: {bad}")
    required = {
        "web/index.html",
        "dist/index.html",
        "android/app/src/main/assets/www/index.html",
        "android/gradle/wrapper/gradle-wrapper.jar",
        "android/app/google-services.json",
        "supabase/functions/health/index.ts",
        "supabase/migrations/290_kombax_showcase_listing_visibility_pilot.sql",
        "supabase/migrations/291_kombax_showcase_commerce_details_visibility_pilot.sql",
        "supabase/migrations/292_kombax_showcase_compliance_visibility_pilot.sql",
        "docs/releases/R104_3_NETLIFY_ANDROID_BUILD.md",
        "docs/releases/R104_2_PILOT_SECURITY.md",
        "scripts/release-netlify-r104-3.mjs",
        "scripts/android-play-bundle.mjs",
    }
    missing = required.difference(archive.namelist())
    if missing:
        raise RuntimeError(f"Missing cumulative files: {sorted(missing)}")
    forbidden = [name for name in archive.namelist() if name.endswith(("keystore.properties", ".jks", ".apk", ".aab"))]
    if forbidden:
        raise RuntimeError(f"Private or generated Android files in ZIP: {forbidden}")

print(f"{output}\n{len(files)} files, {output.stat().st_size:,} bytes, verified")
