# R54 Events Flow Quality

## Failure handling
R54 changes critical Events reads from notification-only behavior to state-preserving flows:
- Discovery retries transient read failures once.
- If cards are already rendered, a failed refresh keeps those cards instead of clearing the screen.
- If initial discovery cannot load, Events renders an inline recovery state with an actionable retry.
- Event detail reads retry transient failures and open a dedicated recovery view when the event cannot be resolved.
- Event album uploads validate count/type/size before starting the batch and report selection/progress/failure inside the album flow.

Success confirmations may still use lightweight toasts where they do not interrupt navigation. A toast is not used as the only recovery path for the critical discovery/open/upload flows above.

## Vertical mobile event card
At `max-width: 620px` the discovery card now uses a 180 px visual stage, tighter content spacing, two-line title/summary, compact facts and one primary `Ver evento` action. Secondary external actions and the Main Event teaser are moved out of the discovery card on narrow screens; they remain available inside event detail.

At `max-width: 390px` the visual stage reduces to 160 px and non-essential discovery metadata is further collapsed. This avoids the oversized vertical card while preserving the entire primary card interaction.

## Product copy hygiene
The following are not rendered to users in R54:
- QA/demo control panels.
- revision/build labels such as R25/R48/R53/R54.
- “pilot stabilization / flow preserved” engineering labels.
- storage implementation language such as signed-URL or private-storage mechanics.

Internal markers stay in maintenance documentation or source comments only.

## Media quality
Events continues to use the shared 16:9 / 9:16 / 1:1 orientation-aware media framing, non-destructive album presentation and separate video-cover metadata introduced in the prior stabilized line.
