import fs from 'node:fs';
const must=(c,m)=>{if(!c)throw new Error(m)};
const show=fs.readFileSync('web/js/modules/showcase.js','utf8');
const cart=fs.readFileSync('web/js/modules/showcase-cart.js','utf8');
const repo=fs.readFileSync('web/js/core/repositories.js','utf8');
const cfg=fs.readFileSync('web/config.js','utf8');
must(show.includes('showcase-add-cart'),'missing add-to-cart CTA');
must(show.includes('showcase-quantity'),'missing quantity selector');
must(show.includes('variantOptionsHtml(item)'),'missing variant selector');
must(show.includes('commerce_enabled')&&show.includes('showcase-primary-cta'),'Display/Commerce split regressed');
must(cart.includes('singleSellerOnly')&&cart.includes('seller_provider_id'),'single-seller cart isolation missing');
must(cart.includes('localStorage')&&cart.includes('data-cart-qty')&&cart.includes('data-cart-remove'),'cart edit/remove persistence missing');
must(repo.includes("kind:'showcase_cart'"),'cart checkout repository contract missing');
const currentBuild=Number(cfg.match(/build:\s*(\d+)/)?.[1]||0);must(currentBuild>=20135,'runtime build must stay at or above Phase 2 build 20135');
for(const code of ['es','en','fr','pt','it','de','th','fil']){const s=fs.readFileSync(`web/js/i18n/locales/${code}/commerce.js`,'utf8');must(s.includes('addToCart')&&s.includes('singleSellerNotice')&&s.includes('adultsOnly'),`commerce i18n incomplete ${code}`)}
console.log('KOMBAX 20135 Block1 Phase2 Commerce cart: PASS');
