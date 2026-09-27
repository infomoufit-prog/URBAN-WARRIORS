# KOMBAX R88 · build 20141 · QA scorecard

| Gate | Result |
| --- | --- |
| R88 specific pre-pilot checks | PASS 44/44 |
| Full cumulative `npm test` | PASS |
| Legal release gate | PASS |
| Production/release web build | PASS |
| i18n strict ES/EN/FR/PT/IT/DE/TH/FIL | PASS · 0 warnings |
| New pre-pilot language placeholder audit | PASS |
| Web ↔ dist parity | PASS · 548 files |
| dist ↔ Android assets parity | PASS · 548 files |
| Android Play static readiness | PASS |
| Android R52.1 static build gate | PASS 13/13 |
| Android BuildConfig regression | PASS · uses `ApplicationInfo.FLAG_DEBUGGABLE` |
| Android release signing in package | NOT INCLUDED BY DESIGN |
| Android Gradle binary compile in this environment | BLOCKED BY NETWORK DOWNLOAD, not source failure |
| Supabase R83–R88 migrations live | PASS |
| Stripe/Finance/SEPA/Terminal Edge Functions ACTIVE | PASS |
| No real money movement during QA | PASS |
| Secret/signing file scan | PASS · only documented placeholders detected |

See `qa/r88-final/` for the retained logs.
