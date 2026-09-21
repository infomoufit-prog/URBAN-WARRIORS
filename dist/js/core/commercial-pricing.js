// KOMBAX R64.4 pricing fallback snapshot.
// The database commercial catalog is authoritative when available. This file keeps the UI readable before the R64 migration is applied.
export const COMMERCIAL_PRICING_VERSION='r72-v1';
export const COMMERCIAL_PDF='./assets/docs/commercial/KOMBAX_PLAN_PRECIOS.pdf';
export const FALLBACK_COMMERCIAL_CATALOG={
  version:COMMERCIAL_PRICING_VERSION,
  pricing_note:'Precios finales con IVA incluido cuando corresponda. Founder no acumulable con descuento anual.',
  partner_annual_rule:'pending',
  config:{
    founder_sales_open:true,
    annual_discount_percent:16,
    ticketing_buyer_fee_minor:0,
    large_event_threshold:1000,
    ticketing_activation_tiers:{50:1000,100:1500,200:2500,500:4500,1000:7500},
    commerce_temporary:{30:{price_minor:1200,renewable:true},plan:'club',billing_period:'monthly'},
    showcase_catalog_plus_25:{slots:25,days:30,price_minor:800,renewable:true,stackable:true},
    event_publication:{7:500,15:800,30:1200,60:1800},
    content_promotion:{7:300,15:500,30:800,max_promoted_events_per_user_day:2,same_event_frequency_hours:72,no_consecutive_promotions:true},
    partner_program:{'1_9_percent':25,'10_plus_percent':30,federation_agreement_percent:30,commissioned_installments_start:2,commissioned_installments_end:13,federation_free_active_referrals:5,annual_billing_reward_rule:'pending'},
    assist_limits:{base:10,plus:30,pro:100},migrations_limits:{base:2,plus:10,pro:30}
  },
  plans:[
    {plan_code:'club',audience:'club',name:'KOMBAX Club',tagline:'Gestiona',founder_monthly_minor:2900,standard_monthly_minor:3600,standard_annual_minor:36300,annual_discount_percent:16,platform_fee_percent:1.5,showcase_model_limit:15,events_monthly_limit:0,commerce_mode:'temporary',ticketing_mode:'temporary',assist_level:'base',migrations_level:'base'},
    {plan_code:'premium',audience:'club',name:'KOMBAX Premium',tagline:'Gestiona y promociona',founder_monthly_minor:4700,standard_monthly_minor:5900,standard_annual_minor:59500,annual_discount_percent:16,platform_fee_percent:1.5,showcase_model_limit:25,events_monthly_limit:2,commerce_mode:'included',ticketing_mode:'temporary',assist_level:'plus',migrations_level:'plus'},
    {plan_code:'enterprise',audience:'club',name:'KOMBAX Enterprise',tagline:'Gestiona, promociona y vende sin comisión KOMBAX',founder_monthly_minor:7900,standard_monthly_minor:9900,standard_annual_minor:99800,annual_discount_percent:16,platform_fee_percent:0,showcase_model_limit:null,events_monthly_limit:null,commerce_mode:'included',ticketing_mode:'included',assist_level:'pro',migrations_level:'pro'},
    {plan_code:'brand_start',audience:'brand',name:'Brand Start',tagline:'Vende y haz crecer tu marca',founder_monthly_minor:3900,standard_monthly_minor:4900,standard_annual_minor:49400,annual_discount_percent:16,platform_fee_percent:1.5,showcase_model_limit:25,events_monthly_limit:0,commerce_mode:'included',ticketing_mode:'temporary',assist_level:'base',migrations_level:'base'},
    {plan_code:'brand_growth',audience:'brand',name:'Brand Growth',tagline:'Escala catálogo y promoción',founder_monthly_minor:6900,standard_monthly_minor:8900,standard_annual_minor:89700,annual_discount_percent:16,platform_fee_percent:1.5,showcase_model_limit:100,events_monthly_limit:2,commerce_mode:'included',ticketing_mode:'temporary',assist_level:'plus',migrations_level:'plus'},
    {plan_code:'brand_enterprise',audience:'brand',name:'Brand Enterprise',tagline:'Commerce sin límites y sin comisión KOMBAX',founder_monthly_minor:12900,standard_monthly_minor:16100,standard_annual_minor:162300,annual_discount_percent:16,platform_fee_percent:0,showcase_model_limit:null,events_monthly_limit:null,commerce_mode:'included',ticketing_mode:'included',assist_level:'pro',migrations_level:'pro'},
    {plan_code:'federation',audience:'federation',name:'KOMBAX Federation',tagline:'Gestiona y conecta tu red',founder_monthly_minor:1900,standard_monthly_minor:2400,standard_annual_minor:24200,annual_discount_percent:16,platform_fee_percent:1.5,showcase_model_limit:0,events_monthly_limit:null,commerce_mode:'none',ticketing_mode:'temporary',assist_level:'plus',migrations_level:'plus'},
    {plan_code:'federation_partner',audience:'federation',name:'KOMBAX Federation Partner',tagline:'Haz crecer tu red y consigue ventajas',founder_monthly_minor:1900,standard_monthly_minor:2400,standard_annual_minor:24200,annual_discount_percent:16,platform_fee_percent:1.5,showcase_model_limit:0,events_monthly_limit:null,commerce_mode:'none',ticketing_mode:'temporary',assist_level:'plus',migrations_level:'plus'}
  ]
};
