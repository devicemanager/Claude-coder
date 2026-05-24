#!/bin/bash
# Install skills from 9arm-skills and superpowers repos.
# Usage: ./install-skills.sh
set -euo pipefail

SKILL_DIRS=()
for d in "${HOME}/.claude/skills" "${HOME}/.config/opencode/skills"; do
  mkdir -p "$d"
  SKILL_DIRS+=("$d")
done

install_repo() {
  local repo_url="$1" repo_dir="$2" skill_glob="$3"
  if [ -d "$repo_dir" ]; then
    echo "  $repo_dir exists, pulling..."
    git -C "$repo_dir" pull --quiet
  else
    echo "  Cloning $repo_url..."
    git clone --quiet "$repo_url" "$repo_dir"
  fi
  for skill in "$repo_dir"/$skill_glob; do
    name=$(basename "$skill")
    for target in "${SKILL_DIRS[@]}"; do
      if [ ! -L "$target/$name" ]; then
        ln -sfn "$skill" "$target/$name"
        echo "  Linked $name → $target/"
      fi
    done
  done
}

echo "Installing 9arm-skills..."
install_repo "https://github.com/thananon/9arm-skills.git" \
  "/tmp/9arm-skills" "skills/engineering/* skills/productivity/*"

echo "Installing superpowers..."
install_repo "https://github.com/anomalyco/superpowers.git" \
  "/tmp/superpowers" "skills/*"

echo "Done. Skills installed to: ${SKILL_DIRS[*]}"
