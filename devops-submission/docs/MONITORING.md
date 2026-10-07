# LocalBuka Monitoring & Reliability

## Monitoring solution (Task 28)

AWS CloudWatch was chosen because it is natively integrated with the EC2 and RDS infrastructure already provisioned in Part 2. It provides metric storage, dashboards, and alerting without requiring any additional infrastructure or cost beyond the free tier.

## Health checking (Task 29)

A cron job runs on the EC2 instance every minute (/etc/cron.d/localbuka-healthcheck), executing /usr/local/bin/health-check.sh. The script:
1. Curls http://localhost/health on the container.
2. Measures the HTTP status code and round-trip latency.
3. Pushes custom metrics to CloudWatch under the LocalBuka/API namespace: HealthCheck (HTTP status) and ResponseTime (ms).

## Metrics monitored (Tasks 30, 31)

| Metric | Namespace | Unit | Purpose |
|---|---|---|---|
| ResponseTime | LocalBuka/API | Milliseconds | Detect latency degradation |
| HealthCheck | LocalBuka/API | Count (HTTP status) | Confirm API is reachable |

## Dashboard (Task 32)

The LocalBuka-API CloudWatch dashboard displays ResponseTime and HealthCheck widgets refreshed every minute.

## Alerting (Tasks 33, 34)

A CloudWatch alarm (localbuka-api-health-failed) fires when HealthCheck < 200 over a 5-minute window. It publishes to the localbuka-alerts SNS topic, which emails the on-call engineer.

Test conducted on 2026-10-07:
- Container stopped at ~08:02 UTC
- Alarm transitioned to In alarm at 08:07:44 UTC
- Email notification delivered
- Container restarted at 08:23 UTC
- Alarm returned to OK at 08:29:44 UTC
- Recovery email delivered

## Most important metrics (Task 36)

1. ResponseTime - direct measure of user experience.
2. HealthCheck - binary signal that the API is reachable.
3. ServerErrors5xx - indicates server-side bugs or infrastructure failures.
4. EC2 CPUUtilization - predicts capacity issues.
5. RDS DatabaseConnections - detects connection pool exhaustion.

## Critical vs non-critical alerts (Task 37)

| Severity | Example | Response |
|---|---|---|
| P1 Critical | HealthCheck < 200 for 5 min | Wake on-call, immediate rollback |
| P2 High | ResponseTime > 1000 ms for 10 min | Investigate during business hours |
| P3 Medium | CPU > 80% for 15 min | Queue for next sprint |
| P4 Low | Single 5xx error | Note and monitor |

## Investigating a 2x response-time spike (Task 38)

1. Scope: Is it all endpoints or just one?
2. Time correlation: Did a deploy happen?
3. Resource check: EC2 CPU, RDS connections, RDS CPU.
4. External factors: Slow RDS queries?
5. Rollback: If correlated with a deploy, roll back via GitHub.
