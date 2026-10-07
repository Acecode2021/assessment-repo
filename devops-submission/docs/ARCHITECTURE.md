cat > docs/ARCHITECTURE.md <<'EOF'
# LocalBuka Cloud Architecture (AWS)

## Overview

The LocalBuka API is deployed on AWS using a two-tier network architecture provisioned entirely with Terraform.

## Components

| Component | Resource | Region/AZ | Purpose |
|---|---|---|---|
| VPC | Default VPC | eu-north-1 | Isolated network |
| Public subnet | 172.31.100.0/24 | eu-north-1a | Hosts the API EC2 instance |
| Private subnet | 172.31.101.0/24 | eu-north-1a | Isolated from internet |
| Private subnet B | 172.31.102.0/24 | eu-north-1b | Required for RDS multi-AZ subnet group |
| Internet Gateway | default IGW | eu-north-1 | Provides internet access |
| Route Table | localbuka-public-rt | eu-north-1 | Routes 0.0.0.0/0 to IGW |
| EC2 Instance | t3.micro | eu-north-1a | Runs the Dockerized LocalBuka API |
| RDS Instance | db.t3.micro, PostgreSQL 15.18 | eu-north-1 | Stores buka data |
| SG - API | localbuka-api-sg | eu-north-1 | Allows 22, 80, 443 from internet |
| SG - DB | localbuka-db-sg | eu-north-1 | Allows 5432 only from API SG |

## Why this architecture (Task 24)

- Public/private split isolates the database from the internet.
- Security groups enforce least-privilege: DB only accepts traffic from the API SG.
- Two AZs satisfy RDS's high-availability requirement and provide fault tolerance.
- Terraform makes the whole stack reproducible, reviewable, and version-controlled.

## Cost control: 1,000 to 1 million users (Task 25)

| Stage | Users | Change |
|---|---|---|
| Free tier | 1,000 | Current: single t3.micro EC2 + db.t3.micro RDS |
| Growth | 10,000 | Upgrade EC2 to t3.small; enable RDS Multi-AZ |
| Scale | 100,000 | Add an Application Load Balancer + 2-3 EC2 instances; move RDS to db.m5.large |
| Large scale | 1 million | Auto Scaling Group behind ALB; RDS read replicas + ElastiCache; CloudFront for static assets |

## Disaster recovery (Task 26)

- RDS: Enable automated backups (7-day retention) and Multi-AZ for automatic failover.
- EC2: Bake the app into a launch template + Auto Scaling Group so a failed instance is replaced automatically.
- Terraform: Store state in S3 with versioning; the entire stack can be re-created in a new region in under an hour.

## Recovery expectations (Task 27)

- EC2 failure: ASG replaces in about 2 minutes; RTO around 5 min, RPO = 0.
- RDS failure: Multi-AZ auto-failover in about 60s; RTO around 2 min, RPO around 0 (synchronous replication).
- Region failure: Restore from latest snapshot in a new region; RTO around 2-4 hours, RPO around 5 min.

## AWS Free Plan limitation

The AWS Free Plan applies a Service Control Policy (SCP) that blocks ec2:CreateVpc and rds:CreateDBInstance. To work within these constraints, the architecture reuses the default VPC that AWS provisions automatically. All other networking components (public subnet, private subnets, route table, security groups) are created and managed by Terraform. Upgrading to the paid plan removes the SCP and allows terraform apply to create a dedicated localbuka-vpc (10.0.0.0/16) without changing any application code.
EOF