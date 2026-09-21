# KOMBAX 20.101 R52.2 — Social Android Poster Fix

## Scope
Corrective QA revision derived from R52.1. R51 remains the frozen stabilization baseline.

## Root cause
`app_kombax_social_feed_v238` exposes the resolved media identifier in the `media_id` output column. The frontend was requesting `social_media` presentation metadata only from `social_media_id`, which is not part of the v238 result contract. Therefore the Social feed could receive the video URL but miss `media_presentation.cover_storage_path`, so Android WebView rendered the video without the selected/automatic poster while the album rendered it correctly.

A second issue was also fixed: an empty `{}` media presentation could incorrectly win over a non-empty presentation returned by the media presentation RPC because empty objects are truthy in JavaScript.

## Fix
- Social feed resolves presentation IDs from `social_media_id || media_id`.
- It checks both `social_media` and `profile_media` presentation scopes for backward compatibility.
- It reconstructs `social_media_id` when the resolved media belongs to Social media.
- Empty presentation objects no longer override actual framing/cover metadata.
- Existing `<video poster="...">` rendering and bucket access rules are preserved.
- Android QA and Google Play artifact names identify R52.2.

## Live evidence
A real Social post created 2026-09-05 23:23 UTC contains a video with a valid automatic cover at 9.47 s and a valid `cover_storage_path`; this confirms the backend data is present and the defect was in feed-side presentation resolution.

## Deployment
No Netlify deploy, GitHub push, or Google Play publish performed.
No new database migration is required for this frontend resolver correction.
