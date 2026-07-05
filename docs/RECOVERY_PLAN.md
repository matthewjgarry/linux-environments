# Recovery Plan

**Repository:** `linux-environments`  
**Scope:** Recovery procedures for systems provisioned by this repository. This document describes the current recovery process, identifies gaps, and defines the target recovery workflow.


# Purpose

The objective of this plan is to ensure that any managed workstation or server can be rebuilt from documented procedures rather than memory.

Recovery is successful when a freshly installed system can be returned to service using only the repository, documented secrets, and approved credentials.


# Status Classification

- **Verified** -- Tested and confirmed.

- **Configured** -- Present but not recently verified.

- **Experimental** -- Not relied upon.

- **Planned** -- Intended future work.


# Current Recovery Model

## Verified

Current recovery generally follows this pattern:

1. Install the operating system.

2. Clone `linux-environments`.

3. Run the install.sh and select coresponding bootstrap.

4. Restore host-specific credentials.

5. Verify operation.

The repository successfully provisions:

- server01

- laptop01

- laptop02

WireGuard client provisioning is documented and being standardized.


# Current Gaps

The following items currently rely on operator knowledge:

- Recovery order between infrastructure components.

- Inventory of required credentials and secrets.

- VPS rebuild procedure.

- Verification checklist following recovery.

- Complete disaster recovery validation.


# Recovery Priorities

Infrastructure should be recovered in the following order.

## Phase 1 -- Administrative Access

Recover an administrative workstation capable of:

- Git access

- SSH access

- WireGuard connectivity

This workstation becomes the recovery platform.


## Phase 2 -- External Access

Recover:

- VPS

- WireGuard server

- Administrative SSH access

Verify remote connectivity before proceeding.


## Phase 3 -- Core Infrastructure

Recover:

- server01

- Docker

- Reverse proxy

- Internal DNS access

Verify private services are reachable.


## Phase 4 -- Supporting Services

Recover remaining services in dependency order.

Typical sequence:

- Database services

- Redis

- MongoDB

- Applications

- Monitoring


# Verification Checklist

Recovery is complete when the following have been verified.

## Host

- Operating system updated.

- Bootstrap completed successfully.

- Repository synchronized.

- Host monitoring operational.

## Network

- WireGuard connected.

- VPN routing functional.

- Private DNS resolves.

- Administrative SSH verified.

## Services

- Containers healthy.

- Reverse proxy responding.

- Required applications accessible.


# Desired Future State

Recovery should require only:

1. Install operating system.

2. Clone repository.

3. Run bootstrap.

4. Restore approved secrets.

5. Perform documented verification.

No undocumented manual configuration should be required.


# Disaster Recovery Goal

A complete rebuild should be achievable using only:

- Repository documentation

- Version-controlled configuration

- Managed secrets

- Approved credentials

No recovery step should depend on memory.


# Roadmap

## Phase 1

- Document recovery order.

- Document required credentials.

- Standardize verification procedures.

## Phase 2

- Audit every bootstrap for reproducibility.

- Eliminate undocumented manual steps.

- Align documentation with verified behavior.

## Phase 3

- Perform a controlled rebuild of a workstation.

- Perform a controlled rebuild of the VPS.

- Record findings and update documentation.

## Phase 4

- Perform a complete infrastructure recovery exercise.

- Validate that documentation alone is sufficient.


# Success Criteria

The recovery process is considered complete when:

- A new administrator workstation can be provisioned without undocumented steps.

- Infrastructure can be rebuilt in the documented order.

- Verification confirms expected operation.

- Documentation reflects the production environment rather than historical assumptions.

