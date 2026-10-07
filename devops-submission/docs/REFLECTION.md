cat > docs/REFLECTION.md <<'EOF'
# LocalBuka DevOps Case Study — Reflection

## Overview

This project delivered an end-to-end DevOps capability for the LocalBuka API, covering CI/CD, cloud infrastructure, and monitoring. The final system automatically tests, builds, and deploys code from GitHub to a live AWS EC2 instance, with CloudWatch alerting on health failures.

## Architecture and design decisions (Task 41)

**Why AWS for infrastructure.** The case study required VPC creation, public/private subnets, and a managed database — all of which are foundational IaaS building blocks that Render and Vercel intentionally abstract away. AWS was the natural choice: it exposes every layer of the stack and has the most mature Terraform provider.

**Why EC2 + Docker instead of a managed platform.** Running the API on a t3.micro with Docker gave us full control over networking, security groups, and process management. It also mirrors how many production services are actually deployed, so the case study demonstrates realistic skills rather than platform-specific abstractions.

**Why RDS PostgreSQL in a private subnet.** The database is not publicly accessible and only accepts traffic from the API's security group on port 5432. This enforces the principle of least privilege at the network layer, not just at the application layer.

**Why GitHub Actions for CI/CD.** Native integration with the GitHub repo, no additional SaaS signup, and full access to the underlying runner (which we needed to run `ssh` and `docker build`).

**Why CloudWatch for monitoring.** Already in the AWS account, no extra setup, free tier covers 10 alarms + 3 dashboards. Pushing custom metrics from the EC2 gave us application-level visibility (ResponseTime, HealthCheck) alongside infrastructure metrics.

## What went wrong and how we recovered (Tasks 43, 44)

### The Render deployment failure (Part 1)

The first deployment target was Render's Docker runtime. Every deploy failed with `Exited with status 128` — a signal-based exit that occurred within seconds of container startup. The logs gave no clear reason; only a cryptic "Common ways to troubleshoot your deploy" link.

**Root cause:** Render clears the `/tmp` directory at container startup on the free tier. Node.js and npm default to writing cache and temporary files under `$TMPDIR` which points at `/tmp`. When the directory was wiped, npm crashed trying to write cache files, the entrypoint failed, and Render killed the container.

**Recovery:** We migrated the deployment target to AWS EC2 in Part 2. On the EC2 we had full control of the filesystem and could use a standard Dockerfile with a stable `TMPDIR` set to `/home/node/tmp`. The same image that failed on Render works perfectly on EC2.

**Prevention for the future:** Always test Docker images against the actual production runtime before committing to a platform. `Exited with status 128` on Render Docker is a known warning sign of `/tmp` issues — the fix is to set `TMPDIR` to a directory that persists across the container's lifetime.

### The AWS Free Plan VPC restriction

When `terraform apply` tried to create a custom VPC, it failed with `UnauthorizedOperation` and `explicit deny in a service control policy`. AWS's new free tier sandboxes accounts inside an SCP that blocks `ec2:CreateVpc` and `rds:CreateDBInstance` in some regions.

**Recovery:** We adapted the architecture to reuse the default VPC that AWS provisions automatically, and created our public and private subnets inside it. This satisfies the case study's design intent (public/private separation) while working within the free tier's constraints. All other infrastructure — subnets, route tables, security groups, EC2, RDS — was created successfully via Terraform.

## A realistic failure scenario (Task 43)

**Scenario:** A code change introduces a bug that causes the API to return 500 for all `/health` requests. The pipeline tests pass (they only test the Express app, not the deployed container), the deploy succeeds, but the API is now unhealthy in production.

**How we'd catch it:** The cron job on the EC2 pushes `HealthCheck` metrics every minute. Within 5 minutes, the average drops below 200, the `localbuka-api-health-failed` alarm fires, and the on-call engineer receives an SNS email. They check the dashboard and see `HealthCheck` dropped at the same time as the deploy.

**How we'd recover:** Roll back to the previous Docker image on the EC2 via the GitHub Actions "Re-run" feature on the last known-good commit — the deploy job rebuilds and restarts the container with older code. The alarm auto-clears within 2 minutes.

**How we'd prevent it:** Add a smoke test to the pipeline's post-deploy stage that curls `/health` and `/api/v1/bukas` and fails if either returns non-200. This catches bad deploys before they reach users.

## Personal outage / deployment experience (Task 45)

The most memorable moment during this project was debugging the Render `Exited with status 128`. I spent hours iterating on Dockerfile changes — adding `--chown=node:node`, setting `HOME`, trying `USER root` instead of `USER node`, trying different base images. Every failure produced the same cryptic exit code with no useful log output.

The breakthrough came when I read the Render troubleshooting documentation more carefully and realised the platform clears `/tmp` at startup. That led to setting `TMPDIR=/home/node/tmp` explicitly, which finally revealed the real issue: not the permissions, but the ephemeral filesystem.

**The lesson:** when a failure message doesn't tell you what's wrong, the answer is usually in the platform's documentation, not in your code. I spent more time debugging my Dockerfile than reading Render's docs, and paid for it. Now when something fails cryptically, my first step is to check the platform's known issues.

The AWS SCP discovery was a different lesson: cloud free tiers are not the same as paid accounts. Behaviours that work in a paid AWS account fail silently in the free tier. Always check the free tier's specific restrictions before designing an architecture.

## What I would improve with more time (Task 42)

1. **Add a proper staging environment.** Right now `main` deploys directly to production (with a manual approval gate). A true staging environment would be a separate EC2 instance with its own RDS and its own deploy job, promoting to production only after staging passes smoke tests.

2. **Enable RDS Multi-AZ and automated backups.** The current RDS is single-AZ with `skip_final_snapshot = true`. For production, enable Multi-AZ failover, set `backup_retention_period = 7`, and remove `skip_final_snapshot`.

3. **Add integration tests to the pipeline.** The current Jest tests use Supertest in-process. Adding integration tests against a Dockerised PostgreSQL in the CI runner would catch more bugs before deploy.

4. **Move the app to a proper ORM.** The current API reads from a hardcoded array. Connecting it to the RDS instance via `pg` and querying the `bukas` table would demonstrate the full stack.

5. **Add automated container image scanning.** Trivy or Grype in the pipeline would flag CVEs in the base image before deploy.

6. **Use AWS Secrets Manager instead of GitHub Secrets.** Secrets would rotate automatically and be audited.

7. **Write a Terraform module.** Currently everything is in a single `main.tf`. Splitting into modules (`network`, `compute`, `database`) would make it reusable across environments.

## Closing

The case study required me to touch every layer of a modern DevOps stack: application code, containerisation, CI/CD automation, IaC, cloud networking, managed databases, custom metrics, alerting, and documentation. Two different platforms failed before we found a working solution, and each failure taught me something concrete about how production systems actually behave.

The final system works end-to-end: a code push triggers tests, builds a Docker image, SSHes into production, restarts the container, and verifies the API is healthy. When something breaks, CloudWatch catches it within 5 minutes and emails the on-call engineer. That's not perfect — but it's production-shaped, and it's a foundation worth building on.
EOF