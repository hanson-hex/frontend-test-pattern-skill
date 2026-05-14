#!/bin/bash
# frontend-test-pattern skill 安装脚本
# 支持 Claude Code、Cursor、Gemini CLI、Codex CLI 等工具

set -e

SKILL_NAME="frontend-test-pattern"
SKILL_VERSION="0.1.0"
REPO_URL="https://github.com/hanson-hex/frontend-test-pattern-skill"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Register skill in .skills-manifest.json
register_manifest() {
    local name="$1"
    local version="$2"
    local skill_path="$3"
    local manifest="$HOME/.claude/skills/.skills-manifest.json"

    if [ ! -f "$manifest" ]; then
        echo '{}' > "$manifest"
    fi

    if command -v python3 &> /dev/null; then
        python3 -c "
import json, os
manifest = '$manifest'
name = '$name'
version = '$version'
path = '$skill_path'
try:
    with open(manifest, 'r') as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    data = {}
if 'skills' not in data:
    data['skills'] = {}
from datetime import datetime, timezone
data['skills'][name] = {
    'version': version,
    'installedAt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.000Z'),
    'path': path,
    'target': 'claude-code'
}
with open(manifest, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
print(f'✓ Registered {name} v{version} in manifest')
"
    else
        echo -e "${YELLOW}python3 not found, skipping manifest registration${NC}"
    fi
}

# 检测 AI 工具
detect_ai_tool() {
    if [ -d "$HOME/.claude" ] || command -v claude &> /dev/null; then
        echo "claude"
    elif [ -d "$HOME/.cursor" ] || command -v cursor &> /dev/null; then
        echo "cursor"
    elif [ -f ".github/copilot-instructions.md" ]; then
        echo "copilot"
    else
        echo "unknown"
    fi
}

# 安装到 Claude Code
install_claude() {
    local skill_dir="$HOME/.claude/skills/$SKILL_NAME"

    echo -e "${YELLOW}Detected Claude Code${NC}"
    echo "Installing to: $skill_dir"

    mkdir -p "$HOME/.claude/skills"

    # 如果是符号链接则删除
    if [ -L "$skill_dir" ]; then
        rm "$skill_dir"
    elif [ -d "$skill_dir" ]; then
        echo "Skill already exists, updating..."
        rm -rf "$skill_dir"
    fi

    # 如果从源码目录运行（已有 SKILL.md），直接链接
    local source_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$source_dir/SKILL.md" ]; then
        ln -s "$source_dir" "$skill_dir"
        echo -e "${GREEN}✓ Linked from source: $source_dir${NC}"
    elif command -v git &> /dev/null; then
        git clone --depth 1 "$REPO_URL.git" "$skill_dir" 2>/dev/null || {
            echo -e "${RED}Failed to clone from GitHub${NC}"
            exit 1
        }
        echo -e "${GREEN}✓ Cloned from GitHub${NC}"
    else
        echo -e "${RED}Git not found and no local source${NC}"
        exit 1
    fi

    # Register in manifest
    register_manifest "$SKILL_NAME" "$SKILL_VERSION" "$skill_dir"

    echo -e "${GREEN}✓ Installed to Claude Code${NC}"
}

# 安装到项目 (通用 — 适用于 Codex CLI、Gemini CLI 等)
install_project() {
    local target_dir="${1:-.ai-patterns/frontend-test}"

    echo "Installing to project: $target_dir"

    mkdir -p "$target_dir"

    # 复制 patterns
    local source_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -d "$source_dir/patterns" ]; then
        cp -r "$source_dir/patterns" "$target_dir/"
    fi

    # 创建通用 instructions
    cat > "$target_dir/TESTING_GUIDE.md" << 'GUIDE'
# Frontend Testing Guide (React + Vite + Vitest)

## Quick Reference

### Generate Tests for Components
```
Generate Vitest + @testing-library/react tests for [Component]:
- Render with default props
- Test user interactions (click, type, submit)
- Test conditional rendering
- Mock API calls with vi.mock
- Test accessibility (role, label)
```

### Test Coverage Checklist
- [ ] Component renders without crashing
- [ ] User interactions work (click, type, submit)
- [ ] Conditional rendering (loading, error, empty states)
- [ ] API calls mocked with vi.mock
- [ ] Zustand store state tested
- [ ] Custom hooks tested with renderHook
- [ ] Accessibility (aria roles, labels)

### Mock Patterns
```typescript
// API mock
vi.mock('@/api/request', () => ({
  default: vi.fn().mockResolvedValue({ data: [] })
}))

// Router mock
vi.mock('react-router-dom', () => ({
  ...vi.importActual('react-router-dom'),
  useNavigate: () => vi.fn()
}))

// Store mock
const useStore = create<StoreState>(() => ({ ...initialState }))
```
GUIDE

    echo -e "${GREEN}✓ Installed to $target_dir${NC}"
}

# 主流程
main() {
    local tool=${1:-"auto"}

    if [ "$tool" = "auto" ]; then
        tool=$(detect_ai_tool)
    fi

    case "$tool" in
        claude)
            install_claude
            ;;
        project)
            install_project "$2"
            ;;
        *)
            echo -e "${YELLOW}AI tool not specifically detected${NC}"
            echo "Installing as project-level patterns..."
            install_project
            ;;
    esac

    echo ""
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""
    echo "Usage:"
    echo "  - Claude Code: Restart to load the skill"
    echo "  - Codex CLI / Gemini CLI: Reference .ai-patterns/ in project"
    echo "  - Other: Reference patterns/ directory for templates"
}

# 处理参数
case "${1:-}" in
    -h|--help|help)
        echo "Frontend Test Pattern Skill Installer"
        echo ""
        echo "Usage:"
        echo "  bash install.sh [tool]"
        echo ""
        echo "Options:"
        echo "  auto     - Auto-detect AI tool (default)"
        echo "  claude   - Install for Claude Code"
        echo "  project  - Install to current directory"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac