# Monitoring Baseline

**Repository:** `linux-environments`\
**Scope:** Defines the current monitoring implementation, the desired
operational model, and the implementation roadmap for host monitoring.

## Purpose

Monitoring exists to answer one question:

> **Does the homelab require my attention?**

Routine success should increase operational confidence without
generating notifications. Actionable events should notify immediately.

------------------------------------------------------------------------

# Status Classification

-   **Verified** -- Tested and confirmed.
-   **Configured** -- Present but not recently validated.
-   **Planned** -- Intended future work.

------------------------------------------------------------------------

# Current State

## Host Monitoring

### Verified

-   Host monitoring is performed with scheduled scripts.
-   Monitoring results are delivered to Discord.
-   Hosts perform automatic package updates.
-   Basic checks exist for disk usage, heartbeat, and repository
    monitoring.

### Current Limitations

-   Successful checks generate routine notifications.
-   Automatic package updates do not consistently report:
    -   whether updates were applied,
    -   whether updates failed,
    -   whether a reboot is required.
-   Repository synchronization is manual.
-   Monitoring focuses on individual checks rather than operational
    state.
-   There is no overall system health or confidence metric.

------------------------------------------------------------------------

# Desired State

## Design Principles

1.  Silence is success.
2.  Notify only when something changes or requires action.
3.  Every automated task produces a meaningful outcome.
4.  Daily summaries replace repetitive status messages.
5.  Monitoring measures operational readiness rather than script
    execution.

------------------------------------------------------------------------

# Monitoring Categories

## Infrastructure

Track silently:

-   Host availability
-   CPU
-   Memory
-   Disk usage
-   Temperature
-   SMART health
-   Filesystem health

Notify only on threshold violations.

------------------------------------------------------------------------

## Updates

Every automatic update should report:

-   Packages updated
-   Packages skipped
-   Errors
-   Kernel updates
-   Reboot required

Example:

    server01

    8 packages updated

    Kernel updated

    ⚠ Reboot required

No message should be sent if nothing changed.

------------------------------------------------------------------------

## Repository State

Each host should report:

-   Current branch
-   Current commit
-   Remote commit
-   Dirty working tree
-   Automatic pull status

Automatic pulls should occur only when:

-   working tree is clean
-   branch matches expected
-   remote contains newer commits

------------------------------------------------------------------------

## Services

Track:

-   Container health
-   Restart count
-   HTTP availability
-   TLS certificate status
-   Response time

Notify only on changes or failures.

------------------------------------------------------------------------

## Networking

Track:

-   WireGuard handshake age
-   Connected peers
-   DNS resolution
-   VPN availability
-   Internet connectivity

------------------------------------------------------------------------

## Daily Operations Report

Replace multiple routine notifications with a single summary including:

-   Host availability
-   Repository status
-   Package updates
-   Containers
-   VPN
-   Outstanding actions

------------------------------------------------------------------------

# Operational Confidence

Introduce a confidence score representing overall infrastructure health.

Inputs may include:

-   Hosts online
-   Services healthy
-   VPN healthy
-   Repository synchronization
-   Successful backups
-   Pending reboots
-   Failed monitoring tasks

Confidence should decrease only when operational issues are detected.

------------------------------------------------------------------------

# Roadmap

## Phase 1

-   Standardize monitoring output format.
-   Inventory all existing monitoring scripts.
-   Remove routine "success" notifications.
-   Add package update reporting.
-   Detect and report reboot requirements.

## Phase 2

-   Add repository synchronization reporting.
-   Add automatic Git updates for clean repositories.
-   Add WireGuard and DNS health checks.
-   Add service health summaries.

## Phase 3

-   Generate daily operations reports.
-   Introduce operational confidence score.
-   Reduce Discord notifications to actionable events only.

## Long-Term Vision

Monitoring should evolve from a collection of independent scripts into
an operational awareness platform.

Every host contributes telemetry.

Only meaningful operational events generate notifications.

The daily report becomes the primary interface for understanding the
health of the homelab.
