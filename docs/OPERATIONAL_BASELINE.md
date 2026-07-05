# Operational Baseline

**Repository:** `linux-environments`\
**Scope:** This document applies only to the `linux-environments`
repository. It records the verified operational state, identified
configuration drift, and the desired future state of the repository and
the systems it provisions.

## Status Classification

-   **Verified** -- Tested and confirmed to work.
-   **Configured** -- Present in configuration but not recently
    verified.
-   **Experimental** -- Not part of the active production environment.
-   **Retired** -- No longer used in production.

## 1. Repository Status

  -----------------------------------------------------------------------
  Component         Original          Verified Status   Desired Future
                    Configuration                       State
  ----------------- ----------------- ----------------- -----------------
  Host bootstraps   Bootstrap Linux   **Verified.**     Continue to be
                    hosts from a      Successfully used the authoritative
                    common            on server01,      provisioning
                    repository.       laptop01, and     source.
                                      laptop02.         

  WireGuard client  Automated on      **Verified.**     Single shared
  setup             laptop01.         laptop02          workflow across
                                      automation has    all admin
                                      been added and is laptops.
                                      being aligned     
                                      with laptop01.    

  Monitoring        Host monitoring   **Configured.**   Integrate with
  scripts           and reporting.    Functional,       improved fleet
                                      pending broader   reporting and
                                      review.           health checks.
  -----------------------------------------------------------------------

## 2. Remote Access

### Original Configuration

-   WireGuard server hosted on the VPS.
-   server01 connected as a persistent peer.
-   Administrative laptops connect through WireGuard.
-   Internal services accessed through Caddy using private DNS.

### Verified

-   WireGuard tunnel functions remotely.
-   SSH to `vpn.wormlogic.com` using key authentication functions.
-   SSH from VPN clients to `10.8.0.2` functions.
-   Routing to `10.42.42.0/24` functions through the VPN.
-   Private DNS resolves `search`, `type`, `type-api`, and
    `automate`.wormlogic.com.
-   Remote access to private services through Caddy functions.

### Configuration Drift Found

-   Running WireGuard configuration contained peer definitions absent
    from `/etc/wireguard/wg0.conf`.
-   VPS public key existed as `/etc/wireguard/wg0.public`; compatibility
    file `/etc/wireguard/publickey` added.
-   laptop02 required explicit `systemd-resolved` configuration after
    WireGuard activation before private DNS functioned.

### Desired Future State

1.  Generate client keys.
2.  Install WireGuard configuration.
3.  Configure DNS routing automatically.
4.  Display peer block.
5.  Manually approve peer on VPS.
6.  Verify connectivity.

## 3. DNS

### Verified

-   Private DNS overrides exist for search/type/type-api/automate.
-   VPN clients resolve these records.
-   `arrakis.local` resolves on the local network and is not part of the
    documented remote workflow.

## 4. Security

### Verified

-   Server WireGuard public key may be stored in the repository.
-   Client private keys remain host-local.
-   Peer enrollment requires manual VPS approval.

### Desired Future State

Canonical public key: `shared/wireguard/wormlogic-server.pub`

## 5. Reproducibility

### Verified

Provisioning a new VPN client currently requires: - Bootstrap - Manual
VPS peer approval

### Desired Future State

1.  Clone repository.
2.  Run bootstrap.
3.  Copy peer block.
4.  Approve peer.
5.  Verify.

## 6. Confirmed Findings

-   `vpn.wormlogic.com` is the VPS administrative endpoint.
-   WireGuard runtime differed from persistent configuration.
-   VPS public key location standardized.
-   laptop02 follows the same WireGuard provisioning workflow as
    laptop01.
-   Ubuntu requires explicit DNS configuration after WireGuard
    activation.

## 7. Next Actions

### High Priority

-   Complete laptop02 VPN provisioning.
-   Update laptop01 bootstrap.
-   Commit `shared/wireguard/wormlogic-server.pub`.

### Medium Priority

-   Audit Linux host bootstraps.
-   Audit monitoring scripts.
-   Inventory DNS.
-   Produce recovery documentation.

### Future

-   Fleet repository synchronization.
-   Automated update reporting.
-   Remote access verification script.
-   Disaster recovery validation.
