# AutoForge AI — Production Frontend Branch

This package preserves the supplied interactive demo UI and adds a production runtime bridge to Application 2.

## Branch
`autoforge-frontend-production`

## Runtime modes
- `auto` (default): use Application 2 when `/health/ready` is healthy; otherwise preserve the interactive demo.
- `demo`: force local fixtures.

Browser console:
```js
localStorage.setItem('af-runtime-mode','auto')
localStorage.setItem('af-api-base','http://localhost:8080')
location.reload()
```

## Production-backed surfaces
- Google sign-in redirect
- GitHub installation/OAuth redirect
- installation/repository discovery
- project creation
- project branch lookup hooks
- repository analysis
- workflow fetch
- pipeline creation
- run polling
- steps/logs/events/artifacts polling
- cancellation
- rebuild/diagnose/repair API client contracts

## Security boundary
The browser never receives GitHub App private keys, Kaggle credentials, Jenkins credentials, model keys, or deployment secrets. All privileged operations remain in Application 2.

## Run
Serve `dist/` over HTTP. Do not use `file://` for production mode because credentialed CORS/OAuth flows require an origin.

Example:
```bash
python -m http.server 5173 --directory dist
```
