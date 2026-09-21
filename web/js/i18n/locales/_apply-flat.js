export function applyFlatTranslations(base, additions = {}) {
  for (const [path, value] of Object.entries(additions || {})) {
    const parts = path.split('.');
    let cursor = base;
    for (let i = 0; i < parts.length - 1; i += 1) {
      const part = parts[i];
      if (!cursor[part] || typeof cursor[part] !== 'object' || Array.isArray(cursor[part])) cursor[part] = {};
      cursor = cursor[part];
    }
    cursor[parts.at(-1)] = value;
  }
  return base;
}
