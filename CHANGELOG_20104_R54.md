# KOMBAX 20104 · R54 · Events Flow & Mobile Quality

R54 is a stabilization revision focused on KOMBAX Events without changing the working KOMBAX Social, Showcase or public-profile modules.

- Resilient discovery reads with transient retry and preservation of already-rendered cards.
- In-context event-open recovery instead of a toast-only dead end.
- Event album batch preflight for media count/type/size plus inline progress/error state.
- Compact vertical-phone event discovery card with full detail preserved after opening.
- Keyboard-accessible event cards.
- Removal of visible QA/revision/implementation labels from Events product UI.
- Build bumped to 20104 with deterministic Web/PWA/Android asset parity.
- New R54 regression suite, with full project regression suite passing.

Internal audit/maintenance material is kept under `maintenance/` and is not copied into deployed web or Android assets.
