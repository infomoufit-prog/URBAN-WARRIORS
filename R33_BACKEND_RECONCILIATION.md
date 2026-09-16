# KOMBAX 20.101 R33 · Backend reconciliation

R33 was implemented and hardened directly against the principal Supabase project as required by the project protocol. The applied migration history is therefore the canonical source of the exact historical SQL bodies.

| Local trace | Live version | Live migration | Canonical SQL SHA-256 |
|---|---:|---|---|
| 205 | 20260831111254 | `kombax_federation_licenses_admin_20101_r33` | `5802559718b6734385453faae040676e016e0cee9d44575d97aec0510fa1935b` |
| 206 | 20260831111634 | `kombax_federation_licenses_r33_hardening` | `5e11d7f8c05f23eba6d4fd3bb10ac595d414c1075d0463e4b6056b953dce2966` |
| 207 | 20260831111729 | `kombax_federation_license_documents_reader_20101_r33` | `5089452eafc925be0c435003ed163c8b302de323d265305415d2899600d35545` |
| 208 | 20260831112640 | `kombax_federation_club_scope_fix_20101_r33` | `cf1f12dbb5548cbf87f914e7f88f597a0894e60f2af8e4829e2a227f7b983e08` |
| 209 | 20260831123311 | `kombax_federation_r33_fk_index_hardening_20101` | `5c3db7b506494fae51983a71602be2838dab7252a034d40c05b06cdff19a68cf` |

`209` is included as runnable local SQL because it was created during the final packaging pass. The prior 205–208 local files are deliberately traceability markers: their exact live SQL is not fabricated or rewritten after the fact. This does not affect local/PWA/Android operation against the current principal backend.

For disaster-recovery bootstrap from a database older than R33, export the exact `statements` values from `supabase_migrations.schema_migrations` and verify the hashes above before treating the export as canonical.
