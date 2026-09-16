-- KOMBAX i18n B03 / F15
-- Additive legal metadata only. Translation locale is not jurisdiction and does not change legal validity.
begin;

alter table if exists public.textos_legales
  add column if not exists locale text not null default 'es',
  add column if not exists jurisdiction text not null default 'ES';

comment on column public.textos_legales.locale is 'Language/locale of this legal text. Does not imply jurisdiction.';
comment on column public.textos_legales.jurisdiction is 'Legal jurisdiction code/context. Independent from locale.';
comment on column public.textos_legales.version is 'Legal document version; treated as legal_version by the application.';

create index if not exists textos_legales_locale_jurisdiction_idx
  on public.textos_legales (club_id,tipo,locale,jurisdiction,vigente);

-- Preserve current Spanish legal texts as Spanish / Spain jurisdiction unless a future authorized migration specifies otherwise.
update public.textos_legales set locale='es' where locale is null or btrim(locale)='';
update public.textos_legales set jurisdiction='ES' where jurisdiction is null or btrim(jurisdiction)='';


-- Commercial-compliance legal evidence also keeps locale and jurisdiction
-- independent. Existing document versions/hashes are preserved.
alter table if exists kombax_compliance.legal_documents
  add column if not exists jurisdiction text not null default 'ES';

comment on column kombax_compliance.legal_documents.locale is
  'Presentation language/locale of this legal document. It does not determine jurisdiction.';
comment on column kombax_compliance.legal_documents.jurisdiction is
  'Legal jurisdiction code, independent from locale. Translation alone does not adapt a document to another jurisdiction.';
comment on column kombax_compliance.legal_documents.version is
  'Immutable legal document version (legal_version concept in KOMBAX i18n architecture).';

create index if not exists idx_kombax_compliance_legal_documents_locale_jurisdiction
  on kombax_compliance.legal_documents(document_code,locale,jurisdiction,status);

commit;
