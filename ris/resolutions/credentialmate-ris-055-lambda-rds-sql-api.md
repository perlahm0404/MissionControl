---
category: infrastructure
compliance:
  hipaa:
    access-audit-required: true
    controls:
    - 164.308(a)(1)(ii)(D)
    - 164.312(a)(1)
    encryption-required: true
    phi-contains: credential-data
    retention-period: 7-years
    review-frequency: quarterly
  iso27001:
    classification: internal
    controls:
    - A.12.1.1
    - A.18.1.3
    review-frequency: quarterly
  soc2:
    controls:
    - CC7.3
    - CC8.1
    evidence-type: documentation
    retention-period: 7-years
created: 2025-12-31
project: credentialmate
resolved: 2025-12-31
ris_id: RIS-055
severity: P1
status: RESOLVED
tags:
- rds
- lambda
- database
- production-access
title: Lambda-Based RDS SQL API for Production Database Access
updated: '2026-01-10'
version: '1.0'
---

# RIS-055: Lambda-Based RDS SQL API for Production Database Access

## Problem Statement

Production RDS database access from Claude Code terminal required:
1. Starting EC2 instance (~2-3 min wait)
2. SSM Session Manager connection
3. Docker exec into backend container
4. Complex shell escaping for SQL queries

This created friction for routine database queries and risked forgotten EC2 instances (~$7.50/month if left running).

## Root Cause Analysis

| Factor | Issue |
|--------|-------|
| RDS Private VPC | Database not publicly accessible (correct security posture) |
| No RDS Data API | Standard PostgreSQL doesn't support native Data API (Aurora only) |
| EC2 Dependency | Only access path was through EC2 bastion |
| Multiple Failed Attempts | 4 Lambda functions created with varying approaches, causing confusion |

## Resolution

### Implemented: Lambda SQL API

Created `credmate-rds-sql-api` Lambda function that:
1. Runs inside VPC with RDS network access
2. Fetches credentials from Secrets Manager
3. Executes SQL via psycopg2
4. Returns full result sets as JSON

### Components Delivered

| Component | Location | Purpose |
|-----------|----------|---------|
| Lambda | `credmate-rds-sql-api` | SQL execution in VPC |
| CLI | `tools/rds-query` | Terminal interface |
| Skill | `.claude/skills/query-production-db/SKILL.md` | Read-only queries |
| Skill | `.claude/skills/execute-production-sql/SKILL.md` | Mutations with audit |

### Cleanup Performed

| Deleted | Reason |
|---------|--------|
| `credmate-rds-sql-executor` | Broken - returned empty results |
| `credmate-rds-sql-executor-psql` | Redundant approach |

### Final Lambda Inventory

| Lambda | Purpose |
|--------|---------|
| `credmate-rds-sql-api` | All SQL operations |
| `credmate-migration-runner` | Alembic migrations |

## Technical Details

### Lambda Configuration

```yaml
FunctionName: credmate-rds-sql-api
Runtime: python3.11
Timeout: 300
MemorySize: 512
VPC:
  Subnets: [subnet-073278e5fe856193f, subnet-00b5e70aa57af370c]
  SecurityGroups: [sg-069061f2e220dc537]
Layers: [credmate-psycopg2-manylinux:1]
```

### API Actions

| Action | Payload | Returns |
|--------|---------|---------|
| Query | `{"query": "SELECT ..."}` | columns, rows, row_count |
| Mutate | `{"sql": "INSERT/UPDATE/DELETE"}` | affected_rows |
| Tables | `{"action": "tables"}` | List of table names |
| Schema | `{"action": "schema", "table": "X"}` | Column definitions |
| Count | `{"action": "count", "table": "X"}` | Row count |
| Version | `{"action": "version"}` | PostgreSQL version |

## Limitations

| Constraint | Limit | Workaround |
|------------|-------|------------|
| Payload size | 6 MB | Batch large INSERTs |
| Timeout | 5 min | Use EC2 for long operations |
| No COPY command | N/A | Use EC2 + psql for CSV imports |
| No pg_dump | N/A | Use EC2 + psql for backups |

## When to Use EC2 Fallback

For operations exceeding Lambda limits:

```bash
# Start EC2
aws ec2 start-instances --instance-ids i-0c13a5d1def4a6578

# Port forward
aws ssm start-session --target i-0c13a5d1def4a6578 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["prod-credmate-db.cm1ksgqm0c00.us-east-1.rds.amazonaws.com"],"portNumber":["5432"],"localPortNumber":["5432"]}'

# Use psql directly
psql -h localhost -U credmate_admin -d credmate

# Stop when done
aws ec2 stop-instances --instance-ids i-0c13a5d1def4a6578
```

## Impact

| Metric | Before | After |
|--------|--------|-------|
| Time to query | 2-3 min | 2-3 sec |
| Monthly cost | $0.08-7.50 | ~$0.01 |
| Idle resources | EC2 risk | Zero |
| Developer friction | High | Low |

## Prevention

1. **Single Lambda for SQL**: Consolidated to one well-tested Lambda
2. **CLI abstraction**: `rds-query` tool hides Lambda invocation complexity
3. **Skill documentation**: Clear guidance on when to use Lambda vs EC2
4. **Cost monitoring**: Lambda has zero idle cost

## Related Documents

- Session: `docs/09-sessions/2025-12-31/session-20251231-004-rds-lambda-api-implementation.md`
- KB: `docs/05-kb/infrastructure/kb-007-rds-lambda-sql-api.md`

## Lessons Learned

1. **Standard RDS ≠ Aurora**: RDS Data API only works with Aurora Serverless
2. **Consolidate early**: Multiple similar Lambdas create confusion
3. **CLI wrappers matter**: Raw Lambda invocation is cumbersome; CLI makes adoption easy
4. **Keep EC2 as fallback**: Lambda handles 90% of cases; EC2 for edge cases