#!/usr/bin/env bash
set -euo pipefail

########################################
# Colors
########################################

if [[ -t 1 ]]; then
  GREEN="\033[0;32m"
  YELLOW="\033[1;33m"
  RED="\033[0;31m"
  BLUE="\033[0;34m"
  BOLD="\033[1m"
  RESET="\033[0m"
else
  GREEN=""
  YELLOW=""
  RED=""
  BLUE=""
  BOLD=""
  RESET=""
fi

ok() { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err() { echo -e "${RED}❌${RESET} $*"; }
step() { echo -e "${BLUE}▶${RESET} $*"; }

########################################
# Detect OS + Arch
########################################

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  err "Cannot detect OS"
  exit 1
fi

OS="$ID"
ARCH_RAW="$(uname -m)"

case "$ARCH_RAW" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
  err "Unsupported architecture: $ARCH_RAW"
  exit 1
  ;;
esac

if [[ $EUID -ne 0 ]]; then
  SUDO="sudo"
else
  SUDO=""
fi

########################################
# Helpers
########################################

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_apt() {
  $SUDO apt-get update
  $SUDO apt-get install -y "$@"
}

install_pacman() {
  $SUDO pacman -Sy --needed --noconfirm "$@"
}

install_binary() {
  local name="$1"
  local url="$2"

  if command_exists "$name"; then
    ok "$name already installed"
    return
  fi

  step "Installing $name"

  local tmpdir
  tmpdir="$(mktemp -d)"

  curl -fsSL "$url" -o "$tmpdir/$name"
  chmod +x "$tmpdir/$name"
  $SUDO mv "$tmpdir/$name" "/usr/local/bin/$name"

  rm -rf "$tmpdir"
  ok "$name installed"
}

########################################
# Base packages
########################################

install_base_packages() {
  step "Installing base dependencies"

  case "$OS" in
  ubuntu | debian)
    install_apt curl ca-certificates gnupg git tar gzip
    ;;
  arch)
    install_pacman curl ca-certificates gnupg git tar gzip perl
    ;;
  *)
    err "Unsupported OS: $OS"
    exit 1
    ;;
  esac

  ok "Base dependencies ready"
}

########################################
# Tool installs
########################################

install_kubectl() {
  if command_exists kubectl; then
    ok "kubectl already installed"
    return
  fi

  step "Installing kubectl"

  local version
  version="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"

  install_binary kubectl "https://dl.k8s.io/release/${version}/bin/linux/${ARCH}/kubectl"
}

install_talosctl() {
  install_binary talosctl "https://github.com/siderolabs/talos/releases/latest/download/talosctl-linux-${ARCH}"
}

install_helm() {
  if command_exists helm; then
    ok "helm already installed"
    return
  fi

  step "Installing helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ok "helm installed"
}

install_kustomize() {
  if command_exists kustomize; then
    ok "kustomize already installed"
    return
  fi

  step "Installing kustomize"

  local tmpdir
  tmpdir="$(mktemp -d)"

  (
    cd "$tmpdir"
    curl -fsSL https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash
    $SUDO mv kustomize /usr/local/bin/kustomize
  )

  rm -rf "$tmpdir"
  ok "kustomize installed"
}

install_age() {
  if command_exists age; then
    ok "age already installed"
    return
  fi

  step "Installing age"

  case "$OS" in
  ubuntu | debian)
    install_apt age
    ;;
  arch)
    install_pacman age
    ;;
  esac

  ok "age installed"
}

install_sops() {
  if command_exists sops; then
    ok "sops already installed"
    return
  fi

  local version
  version="$(curl -fsSL https://api.github.com/repos/getsops/sops/releases/latest | grep '"tag_name"' | cut -d '"' -f 4)"

  install_binary sops "https://github.com/getsops/sops/releases/download/${version}/sops-${version}.linux.${ARCH}"
}

install_flux() {
  if command_exists flux; then
    ok "flux already installed"
    return
  fi

  step "Installing flux CLI"
  curl -fsSL https://fluxcd.io/install.sh | bash
  ok "flux installed"
}

########################################
# SOPS / age setup
########################################

ensure_age_key_dir() {
  step "Checking SOPS age key directory"

  mkdir -p "$HOME/.config/sops/age"
  chmod 700 "$HOME/.config/sops/age"

  if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
    ok "Existing age key found"
    return
  fi

  warn "No age key found at $HOME/.config/sops/age/keys.txt"
  echo ""
  read -rp "Generate a new age key now? [y/N]: " generate_key

  if [[ "$generate_key" =~ ^[Yy]$ ]]; then
    age-keygen -o "$HOME/.config/sops/age/keys.txt"
    chmod 600 "$HOME/.config/sops/age/keys.txt"
    ok "New age key generated"
  else
    warn "Skipping age key generation"
  fi
}

########################################
# GitOps repo setup
########################################

maybe_clone_gitops_repo() {
  echo ""
  read -rp "Clone or update GitOps repo (wormlogic-gitops)? [y/N]: " clone_repo

  if [[ ! "$clone_repo" =~ ^[Yy]$ ]]; then
    warn "Skipping GitOps repo setup"
    return
  fi

  local repo_url="https://github.com/matthewjgarry/wormlogic-gitops.git"
  local default_dir="$HOME/wormlogic-gitops"

  echo ""
  read -rp "Clone directory [$default_dir]: " target_dir
  target_dir="${target_dir:-$default_dir}"

  if [[ -d "$target_dir/.git" ]]; then
    step "Repo already exists, pulling latest"
    git -C "$target_dir" pull
    ok "Repo updated: $target_dir"
  else
    step "Cloning GitOps repo"
    git clone "$repo_url" "$target_dir"
    ok "Repo cloned: $target_dir"
  fi

  echo ""
  echo "Next:"
  echo "  cd $target_dir"
}

########################################
# Version helpers
########################################

version_or_missing() {
  local tool="$1"
  local version_cmd="$2"

  if ! command_exists "$tool"; then
    echo "missing"
    return
  fi

  bash -c "$version_cmd" 2>/dev/null || echo "unknown"
}

get_kubectl_version() {
  kubectl version --client=true 2>/dev/null |
    awk -F': ' '/Client Version/ {print $2; exit}'
}

get_talosctl_version() {
  talosctl version --client 2>/dev/null |
    awk '/Tag:/ {print $2; exit}'
}

get_helm_version() {
  helm version --short 2>/dev/null |
    cut -d'+' -f1
}

get_kustomize_version() {
  kustomize version 2>/dev/null |
    head -n1
}

get_sops_version() {
  sops --version --check-for-updates 2>/dev/null |
    head -n1 |
    awk '{print $2}'
}

get_age_version() {
  age --version 2>/dev/null |
    awk '{print $1}'
}

get_flux_version() {
  flux --version 2>/dev/null |
    awk '{print $3}'
}

print_tool_row() {
  local name="$1"
  local version="$2"

  if [[ -z "$version" || "$version" == "missing" || "$version" == "unknown" ]]; then
    printf "  ${RED}✗${RESET} %-10s %s\n" "$name" "${version:-unknown}"
  else
    printf "  ${GREEN}✓${RESET} %-10s %s\n" "$name" "$version"
  fi
}

print_versions() {
  echo ""
  echo -e "${BOLD}✅ Workstation bootstrap complete${RESET}"
  echo ""
  echo -e "${BOLD}Installed tools:${RESET}"
  echo ""

  print_tool_row "kubectl" "$(get_kubectl_version || echo unknown)"
  print_tool_row "talosctl" "$(get_talosctl_version || echo unknown)"
  print_tool_row "helm" "$(get_helm_version || echo unknown)"
  print_tool_row "kustomize" "$(get_kustomize_version || echo unknown)"
  print_tool_row "sops" "$(get_sops_version || echo unknown)"
  print_tool_row "age" "$(get_age_version || echo unknown)"
  print_tool_row "flux" "$(get_flux_version || echo unknown)"

  echo ""
}

########################################
# Main
########################################

main() {
  echo -e "${BOLD}▶ Workstation bootstrap${RESET}"
  echo "OS:   $OS"
  echo "Arch: $ARCH"
  echo ""

  install_base_packages

  install_kubectl
  install_talosctl
  install_helm
  install_kustomize
  install_age
  install_sops
  install_flux

  ensure_age_key_dir
  maybe_clone_gitops_repo

  print_versions
}

main "$@"
