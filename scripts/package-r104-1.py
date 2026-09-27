from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
output = root.parents[1] / "outputs" / "KOMBAX_20156_R104_1_PILOT_TECHNICAL_GATE_ACCUMULATIVE.zip"
output.parent.mkdir(parents=True, exist_ok=True)

excluded_dirs = {".git", ".gradle", "node_modules", "__pycache__"}
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
        "supabase/functions/backup-verify-20077/index.ts",
        "supabase/migrations/287_kombax_club_visual_identity_sync_r104.sql",
        "supabase/migrations/288_kombax_reconcile_existing_club_logo_r104.sql",
        "supabase/migrations/289_kombax_public_logo_documents_r104.sql",
        "docs/releases/R104_1_PILOT_TECHNICAL_GATE.md",
        "docs/releases/R104_1_FREEZE_MANIFEST.md",
    }
    missing = required.difference(archive.namelist())
    if missing:
        raise RuntimeError(f"Missing cumulative files: {sorted(missing)}")

print(f"{output}\n{len(files)} files, {output.stat().st_size:,} bytes, verified")
