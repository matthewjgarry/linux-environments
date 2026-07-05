# NETWORK

**Repository:** `linux-environments`\
**Scope:** Documents the logical network architecture, address
allocation, and administrative access patterns for systems managed by
this repository.

------------------------------------------------------------------------

# Purpose

This document defines the network as it exists today and serves as the
authoritative source for address allocation and network design
decisions.

------------------------------------------------------------------------

# Status Classification

-   **Verified** -- Tested and confirmed.
-   **Configured** -- Present in configuration but not recently
    verified.
-   **Experimental** -- Reserved for future work.
-   **Planned** -- Intended future implementation.

------------------------------------------------------------------------

# Network Overview

## LAN

Subnet:

`10.42.42.0/24`

Purpose:

Primary homelab LAN.

## VPN

Subnet:

`10.8.0.0/24`

Purpose:

Administrative WireGuard network providing secure remote access to the
homelab.

------------------------------------------------------------------------

# Address Allocation

## Infrastructure

  -----------------------------------------------------------------------
  Range                Purpose                    Status
  -------------------- -------------------------- -----------------------
  `10.42.42.1`         Router / Gateway           Verified

  `10.42.42.3–9`       Foundational network       Verified
                       devices (outside homelab)  

  `10.42.42.10–12`     Pi-hole servers            Verified

  `10.42.42.50–53`     Kubernetes cluster         Experimental
                       reservation                

  `10.42.42.100–200`   DHCP client pool           Verified
  -----------------------------------------------------------------------

Additional static infrastructure addresses should be allocated outside
the DHCP pool.

------------------------------------------------------------------------

# VPN Address Allocation

  Address       Device       Status
  ------------- ------------ ----------
  `10.8.0.1`    VPN Server   Verified
  `10.8.0.2`    server01     Verified
  `10.8.0.10`   laptop01     Verified
  `10.8.0.11`   laptop02     Verified

Future VPN clients should receive the next available static address.

------------------------------------------------------------------------

# Administrative Access

## Verified

Primary administrative endpoint:

`vpn.wormlogic.com`

Authentication:

-   SSH key authentication
-   WireGuard for private infrastructure access

Private services are accessed through private DNS over the VPN.

------------------------------------------------------------------------

# Private DNS

## Verified

Private DNS service endpoints:

-   `search.wormlogic.com`
-   `type.wormlogic.com`
-   `type-api.wormlogic.com`
-   `automate.wormlogic.com`

These names resolve through the homelab DNS infrastructure.

------------------------------------------------------------------------

# Network Design Principles

-   Infrastructure addresses remain static.
-   DHCP allocations remain within the defined pool.
-   VPN clients receive static addresses.
-   Administrative access occurs through the VPN.
-   Private services are not directly exposed to the public Internet.

------------------------------------------------------------------------

# Roadmap

## Phase 1

-   Inventory all static IP assignments.
-   Document every administrative host.
-   Document all DNS overrides.

## Phase 2

-   Add logical traffic flow diagrams.
-   Document service-to-service communication.
-   Document Docker networking.

## Phase 3

-   Integrate Kubernetes networking.
-   Document cluster addressing.
-   Document storage and service networking.

------------------------------------------------------------------------

# Future State

The network documentation will evolve into the authoritative reference
for:

-   Address allocation
-   VPN topology
-   DNS
-   Administrative access
-   Infrastructure relationships

All new hosts and services should be assigned addresses here before
deployment.
