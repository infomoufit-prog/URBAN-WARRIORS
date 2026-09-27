from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parents[1]
output = root.parents[1] / 'outputs' / 'KOMBAX_20156_R104_PUBLIC_CLUB_LOGO_ACCUMULATIVE.zip'
output.parent.mkdir(parents=True, exist_ok=True)

excluded_dirs = {'.git', '.gradle', 'node_modules', '__pycache__'}
excluded_files = {'keystore.properties', 'local.properties'}
excluded_suffixes = {'.jks', '.keystore', '.p12', '.pfx', '.apk', '.aab'}

files = []
for path in root.rglob('*'):
    if not path.is_file():
        continue
    rel = path.relative_to(root)
    if any(part in excluded_dirs for part in rel.parts):
        continue
    if 'android' in rel.parts and 'build' in rel.parts:
        continue
    if path.name in excluded_files or path.name.startswith('.env'):
        continue
    if path.suffix.lower() in excluded_suffixes:
        continue
    files.append((path, rel.as_posix()))

with ZipFile(output, 'w', compression=ZIP_DEFLATED, compresslevel=4, allowZip64=True) as archive:
    for path, rel in sorted(files, key=lambda item: item[1]):
        archive.write(path, rel)

with ZipFile(output) as archive:
    bad = archive.testzip()
    if bad:
        raise RuntimeError(f'Corrupt ZIP entry: {bad}')
    required = {
        'web/js/modules/media-content-center.js',
        'web/js/modules/managed-profile-hub.js',
        'web/js/modules/showcase.js',
        'supabase/migrations/273_kombax_media_content_member_showcase_r101.sql',
        'android/app/src/main/assets/www/js/modules/media-content-center.js',
        'docs/releases/R102_VERIFIED_BADGES.md',
        'supabase/migrations/274_kombax_paid_organization_badges_r102.sql',
        'web/js/core/verification-visual.js',
        'docs/releases/R103_AI_CREDITS_CLOSURE.md',
        'supabase/migrations/285_kombax_ai_admin_expiry_r103.sql',
        'supabase/migrations/286_kombax_ai_cache_analytics_r103.sql',
        'supabase/migrations/284_kombax_ai_migration_batch_r103.sql',
        'supabase/migrations/275_kombax_ai_metering_precision_r103.sql',
        'docs/releases/R104_PUBLIC_CLUB_LOGO.md',
        'docs/releases/R104_FREEZE_MANIFEST.md',
        'supabase/migrations/287_kombax_club_visual_identity_sync_r104.sql',
        'supabase/migrations/288_kombax_reconcile_existing_club_logo_r104.sql',
        'supabase/migrations/289_kombax_public_logo_documents_r104.sql',
    }
    missing = required.difference(archive.namelist())
    if missing:
        raise RuntimeError(f'Missing cumulative files: {sorted(missing)}')

print(f'{output}\n{len(files)} files · {output.stat().st_size:,} bytes · verified')
