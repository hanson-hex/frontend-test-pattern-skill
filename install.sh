#!/bin/bash
# frontend-test-pattern skill 安装脚本

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$CLAUDE_SKILLS_DIR"

if [ -L "$CLAUDE_SKILLS_DIR/frontend-test-pattern" ]; then
  rm "$CLAUDE_SKILLS_DIR/frontend-test-pattern"
fi

ln -s "$SKILL_DIR" "$CLAUDE_SKILLS_DIR/frontend-test-pattern"
echo "✓ frontend-test-pattern skill 已安装到 $CLAUDE_SKILLS_DIR/frontend-test-pattern"
