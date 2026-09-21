# QA handoff — KOMBAX 20.108 R58

Use this ZIP as the derived QA candidate from R57. Do not declare production-ready until migration 249 is applied to the intended Supabase environment and authenticated manual QA confirms RLS/multiclub isolation.

Priority scenarios:
1. Club A imports a student without Auth; admin functions remain usable.
2. Student activates that exact Club A record via personal invitation; no duplicate student is created.
3. Same account is independently activated in Club B; Club A/B finance, documents, groups, notifications and access stay isolated.
4. Deactivate Club A membership; Club B remains active. If no authorized memberships/profiles remain, account behaves as Spectator.
5. Spectator: read/like/comment/share according to existing Social rules, but no Social/Showcase publish, Mi Red or Mi Club; club prospective-student contact and product-scoped Showcase inquiry remain available.
6. Media / Creador: request/verification flow; once verified it can publish Social + Showcase, with no Club/Finance/Federation privileges.
7. Minor: child record remains the member; tutor account is linked without converting the child into the adult Auth identity.
