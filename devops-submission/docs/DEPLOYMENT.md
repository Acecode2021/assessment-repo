# Deployment Guide

## Pipeline Stages
1. Run tests
2. Build Docker image
3. Deploy to Render (staging)

## Failed Deployment Handling

### If tests fail
- Pipeline stops immediately.
- No Docker image is built, no deployment occurs.
- Developer fixes code and pushes again.

### If Docker build fails
- Pipeline stops.
- No Render deploy.
- Check Dockerfile and GitHub Actions build logs.

### If Render deploy fails or health check fails
- Roll back via Render dashboard: Events → previous deploy → Rollback.
- Open incident notes.
- Fix forward only after root cause is understood.

### Known Render-specific issue
- `Exited with status 128` on Render's Docker runtime is caused by Render clearing `/tmp` at startup.
- Resolution: switched to Render's native Node.js runtime to avoid Docker permission issues.

## Rollback Steps
1. Render dashboard → service → Events.
2. Find last known good deploy.
3. Click Rollback.
4. Verify `/health`.
5. Confirm with the team.