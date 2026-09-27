import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { verificationVisual } from '../web/js/core/verification-visual.js';

assert.equal(verificationVisual('miembro', true), 'member', 'Club affiliation must not grant a competitor badge');
assert.equal(verificationVisual('miembro', false), 'member');
assert.equal(verificationVisual('competidor', false), 'none', 'An unverified competitor must not receive the badge');
assert.equal(verificationVisual('competidor', true), 'competitor');
assert.equal(verificationVisual('club', true), 'organization', 'Existing organization verification remains available');
assert.equal(verificationVisual('marca', true), 'organization');
assert.equal(verificationVisual('federacion', true), 'organization');
assert.equal(verificationVisual('profesional', true), 'none', 'Other free accounts never get an organization badge');

const publicProfile = readFileSync(new URL('../web/js/modules/public-profile.js', import.meta.url), 'utf8');
const social = readFileSync(new URL('../web/js/modules/kombax-social.js', import.meta.url), 'utf8');
const css = readFileSync(new URL('../web/css/kombax-premium.css', import.meta.url), 'utf8');
assert.match(publicProfile, /verification==='competitor'\?`<span class="kx-competitor-hero-badge"/);
assert.match(publicProfile, /verification==='organization'\?`<span class="kx-organization-verified"/);
assert.match(social, /if\(visual==='none'\|\|visual==='member'\)return ''/);
assert.match(css, /\.kx-public-profile\.is-verified-competitor \.kx-public-avatar/);
console.log('R102 competitor verification visual rules: OK');
