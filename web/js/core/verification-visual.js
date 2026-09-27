export function verificationVisual(type, verified) {
  if (type === 'miembro') return 'member';
  if (type === 'competidor') return verified === true ? 'competitor' : 'none';
  return ['club', 'marca', 'federacion'].includes(type) && verified === true ? 'organization' : 'none';
}
