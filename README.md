# Dotfiles

Personal configuration repository for managing and deploying my Linux environments across multiple machines.

## Overview

This repository contains my system configuration files (“dotfiles”) and supporting scripts used to customize and standardize my development environments. It is designed to be modular, reproducible, and adaptable across different machines and distributions.

The project is currently in an early stage and actively evolving. Structure, tooling, and conventions will continue to improve over time as part of an ongoing effort to refine my workflow and system design practices.

## Goals

- Maintain a centralized, version-controlled source of truth for system configuration  
- Enable quick setup and recovery of development environments  
- Support multiple machines with differing roles and operating systems  
- Gradually transition toward a more automated and reproducible setup process  

## Scope

This repository currently includes:

- Shell configuration (zsh, bash)  
- Hyprland and Wayland-related configuration  
- Application configs (e.g., Neovim, terminal, window manager)  
- Package lists and environment setup references  
- Early-stage post-installation scripting  

## Structure (WIP)

The repository is in the process of being reorganized to better support:

- Multiple environments (desktop, laptop(s), server)  
- Multiple distributions (Arch Linux, Ubuntu)  
- Clear separation between shared and machine-specific configs  

Planned structure improvements include:

- `common/` → shared configurations across all systems  
- `arch/` → Arch-specific configurations  
- `ubuntu/` → Ubuntu-specific configurations  
- `hosts/` → machine-specific overrides  
- `scripts/` → installation and automation scripts  

## Installation

Dotfiles are currently managed using GNU Stow:

```bash
stow <package>
