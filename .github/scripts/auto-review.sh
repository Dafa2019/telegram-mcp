#!/usr/bin/env bash
# =============================================================================
# auto-review.sh — 自动 PR 审查脚本
#
# 依赖环境变量:
#   GH_TOKEN           — GitHub token (自动由 workflow 提供)
#   PR_NUMBER          — PR 编号
#   PR_AUTHOR          — PR 作者
#   REPO_FULL_NAME     — 仓库全名 (owner/repo)
#   PR_URL             — PR 链接
#   PR_TITLE           — PR 标题
#   SLACK_WEBHOOK_URL  — Slack webhook (可选, 用于高风险通知)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------

log() {
  echo "[auto-review] $*"
}

# 累积审查结果
BLOCK_ISSUES=()
WARN_ISSUES=()
ESCALATE_ISSUES=()
REVIEW_DETAILS=()

add_block() {
  BLOCK_ISSUES+=("$1")
  REVIEW_DETAILS+=("[BLOCK] $1")
  log "BLOCK: $1"
}

add_warn() {
  WARN_ISSUES+=("$1")
  REVIEW_DETAILS+=("[WARN] $1")
  log "WARN: $1"
}

add_escalate() {
  ESCALATE_ISSUES+=("$1")
  REVIEW_DETAILS+=("[ESCALATE] $1")
  log "ESCALATE: $1"
}

# ---------------------------------------------------------------------------
# 输入验证
# ---------------------------------------------------------------------------

if [[ -z "${PR_NUMBER:-}" ]]; then
  echo "ERROR: PR_NUMBER is required" >&2
  exit 1
fi

if [[ -z "${REPO_FULL_NAME:-}" ]]; then
  echo "ERROR: REPO_FULL_NAME is required" >&2
  exit 1
fi

log "开始审查 PR #${PR_NUMBER} (作者: ${PR_AUTHOR:-unknown}) in ${REPO_FULL_NAME}"

# ---------------------------------------------------------------------------
# 获取 PR 信息
# ---------------------------------------------------------------------------

PR_BODY=$(gh pr view "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" --json body --jq '.body // ""' 2>/dev/null || echo "")
PR_DIFF=$(gh pr diff "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" 2>/dev/null || echo "")
CHANGED_FILES=$(gh pr view "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" --json files --jq '.files[].path' 2>/dev/null || echo "")
FILE_COUNT=$(echo "${CHANGED_FILES}" | grep -c '.' 2>/dev/null || echo "0")

# 获取 additions / deletions
PR_STATS=$(gh pr view "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" --json additions,deletions 2>/dev/null || echo '{"additions":0,"deletions":0}')
ADDITIONS=$(echo "${PR_STATS}" | jq -r '.additions // 0')
DELETIONS=$(echo "${PR_STATS}" | jq -r '.deletions // 0')

log "变更文件数: ${FILE_COUNT}, 新增行: ${ADDITIONS}, 删除行: ${DELETIONS}"

# ---------------------------------------------------------------------------
# 检测: 空 PR (无实际代码变更)
# ---------------------------------------------------------------------------

HAS_CODE_CHANGES=true
if [[ -z "${CHANGED_FILES}" ]] || [[ "${FILE_COUNT}" -eq 0 ]]; then
  HAS_CODE_CHANGES=false
  add_warn "PR 没有任何文件变更"
fi

# ---------------------------------------------------------------------------
# 检测 1: 二进制文件 (.pyc, .exe, .dll, .so, .class, .o)
# ---------------------------------------------------------------------------

BINARY_PATTERNS='\.pyc$|\.exe$|\.dll$|\.so$|\.class$|\.o$'
BINARY_FILES=$(echo "${CHANGED_FILES}" | grep -iE "${BINARY_PATTERNS}" || true)

if [[ -n "${BINARY_FILES}" ]]; then
  add_block "检测到二进制文件，禁止提交:\n$(echo "${BINARY_FILES}" | sed 's/^/  - /')"
fi

# ---------------------------------------------------------------------------
# 检测 2: __pycache__ 或 .pyc 在 diff 中
# ---------------------------------------------------------------------------

if echo "${CHANGED_FILES}" | grep -q '__pycache__' 2>/dev/null; then
  add_block "检测到 __pycache__ 目录，请添加到 .gitignore 并移除"
fi

if echo "${PR_DIFF}" | grep -q '__pycache__\|\.pyc' 2>/dev/null; then
  # 避免重复报告 (如果已经通过文件名检测到了)
  if [[ -z "${BINARY_FILES}" ]] && ! echo "${CHANGED_FILES}" | grep -q '__pycache__' 2>/dev/null; then
    add_block "diff 中包含 __pycache__ 或 .pyc 引用，请清理"
  fi
fi

# ---------------------------------------------------------------------------
# 检测 3: 锁文件冲突
# ---------------------------------------------------------------------------

# 检测仓库使用的包管理器
HAS_PNPM_LOCK=false
HAS_NPM_LOCK=false
HAS_YARN_LOCK=false

[[ -f "pnpm-lock.yaml" ]] && HAS_PNPM_LOCK=true
[[ -f "package-lock.json" ]] && HAS_NPM_LOCK=true
[[ -f "yarn.lock" ]] && HAS_YARN_LOCK=true

# 也检查 package.json 中的 packageManager 声明
if [[ -f "package.json" ]]; then
  PKG_MANAGER=$(jq -r '.packageManager // ""' package.json 2>/dev/null || echo "")
  if echo "${PKG_MANAGER}" | grep -qi 'pnpm'; then
    HAS_PNPM_LOCK=true
  fi
fi

# pnpm 仓库不应有 package-lock.json
if [[ "${HAS_PNPM_LOCK}" == "true" ]]; then
  if echo "${CHANGED_FILES}" | grep -q 'package-lock\.json' 2>/dev/null; then
    add_block "此仓库使用 pnpm，不应提交 package-lock.json（npm 锁文件冲突）"
  fi
  if echo "${CHANGED_FILES}" | grep -q 'yarn\.lock' 2>/dev/null; then
    add_block "此仓库使用 pnpm，不应提交 yarn.lock（yarn 锁文件冲突）"
  fi
fi

# npm 仓库不应有 yarn.lock
if [[ "${HAS_NPM_LOCK}" == "true" ]] && [[ "${HAS_PNPM_LOCK}" == "false" ]]; then
  if echo "${CHANGED_FILES}" | grep -q 'yarn\.lock' 2>/dev/null; then
    add_block "此仓库使用 npm，不应提交 yarn.lock（yarn 锁文件冲突）"
  fi
  if echo "${CHANGED_FILES}" | grep -q 'pnpm-lock\.yaml' 2>/dev/null; then
    add_block "此仓库使用 npm，不应提交 pnpm-lock.yaml（pnpm 锁文件冲突）"
  fi
fi

# yarn 仓库不应有 package-lock.json
if [[ "${HAS_YARN_LOCK}" == "true" ]] && [[ "${HAS_PNPM_LOCK}" == "false" ]]; then
  if echo "${CHANGED_FILES}" | grep -q 'package-lock\.json' 2>/dev/null; then
    add_block "此仓库使用 yarn，不应提交 package-lock.json（npm 锁文件冲突）"
  fi
fi

# ---------------------------------------------------------------------------
# 检测 4: PR 描述为空或过于简短/通用
# ---------------------------------------------------------------------------

GENERIC_PATTERNS="^(fix|update|change|test|wip|no description|n/a|none|todo|tmp|temp)$"
TRIMMED_BODY=$(echo "${PR_BODY}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -c 500)

if [[ -z "${TRIMMED_BODY}" ]] || [[ "${#TRIMMED_BODY}" -lt 5 ]]; then
  add_warn "PR 描述为空或过于简短，建议添加有意义的描述"
elif echo "${TRIMMED_BODY}" | head -1 | grep -iqE "${GENERIC_PATTERNS}"; then
  add_warn "PR 描述过于通用 (\"${TRIMMED_BODY:0:50}\")，建议补充详细说明"
fi

# ---------------------------------------------------------------------------
# 检测 5: 大型变更 (文件数 > 50 或新增行 > 500)
# ---------------------------------------------------------------------------

if [[ "${FILE_COUNT}" -gt 50 ]]; then
  add_escalate "变更文件数过多 (${FILE_COUNT} 个文件)，建议拆分 PR"
fi

if [[ "${ADDITIONS}" -gt 500 ]]; then
  add_escalate "新增代码行数过多 (${ADDITIONS} 行)，需要人工审查"
fi

# ---------------------------------------------------------------------------
# 检测 6: 治理/政策文件变更
# ---------------------------------------------------------------------------

GOVERNANCE_FILES=$(echo "${CHANGED_FILES}" | grep -iE 'governance|constitution|policy' || true)
if [[ -n "${GOVERNANCE_FILES}" ]]; then
  add_escalate "检测到治理/政策文件变更，需要 Boss 审批:\n$(echo "${GOVERNANCE_FILES}" | sed 's/^/  - /')"
fi

# ---------------------------------------------------------------------------
# 检测 7: 生产配置变更 (workflows, secrets, deploy)
# ---------------------------------------------------------------------------

PROD_CONFIG_FILES=$(echo "${CHANGED_FILES}" | grep -iE '\.github/workflows/|secrets|deploy' || true)
if [[ -n "${PROD_CONFIG_FILES}" ]]; then
  add_escalate "检测到生产配置文件变更，需要 Boss 审批:\n$(echo "${PROD_CONFIG_FILES}" | sed 's/^/  - /')"
fi

# ---------------------------------------------------------------------------
# 检测 8: 大量删除无新增
# ---------------------------------------------------------------------------

if [[ "${DELETIONS}" -gt 100 ]] && [[ "${ADDITIONS}" -eq 0 ]]; then
  add_escalate "大量删除 (${DELETIONS} 行) 且无新增代码，可能是误操作，需要确认"
fi

# ---------------------------------------------------------------------------
# 判定结果
# ---------------------------------------------------------------------------

BLOCK_COUNT=${#BLOCK_ISSUES[@]}
WARN_COUNT=${#WARN_ISSUES[@]}
ESCALATE_COUNT=${#ESCALATE_ISSUES[@]}

log "审查完成: BLOCK=${BLOCK_COUNT}, WARN=${WARN_COUNT}, ESCALATE=${ESCALATE_COUNT}"

# ---------------------------------------------------------------------------
# 构建审查报告
# ---------------------------------------------------------------------------

build_review_comment() {
  local comment=""
  comment+="## 🤖 自动 PR 审查报告\n\n"
  comment+="| 项目 | 值 |\n|------|----|\n"
  comment+="| PR | #${PR_NUMBER} |\n"
  comment+="| 作者 | @${PR_AUTHOR:-unknown} |\n"
  comment+="| 变更文件 | ${FILE_COUNT} 个 |\n"
  comment+="| 新增行数 | +${ADDITIONS} |\n"
  comment+="| 删除行数 | -${DELETIONS} |\n\n"

  if [[ ${BLOCK_COUNT} -gt 0 ]]; then
    comment+="### 🚫 阻塞问题 (必须修复)\n\n"
    for issue in "${BLOCK_ISSUES[@]}"; do
      comment+="- ${issue}\n"
    done
    comment+="\n"
  fi

  if [[ ${ESCALATE_COUNT} -gt 0 ]]; then
    comment+="### ⚠️ 需要 Boss 审查\n\n"
    for issue in "${ESCALATE_ISSUES[@]}"; do
      comment+="- ${issue}\n"
    done
    comment+="\n"
  fi

  if [[ ${WARN_COUNT} -gt 0 ]]; then
    comment+="### 💡 建议改进\n\n"
    for issue in "${WARN_ISSUES[@]}"; do
      comment+="- ${issue}\n"
    done
    comment+="\n"
  fi

  if [[ ${BLOCK_COUNT} -eq 0 ]] && [[ ${ESCALATE_COUNT} -eq 0 ]] && [[ ${WARN_COUNT} -eq 0 ]]; then
    comment+="### ✅ 所有检查通过\n\n"
    comment+="未发现问题，PR 已自动批准。\n"
  fi

  comment+="---\n"
  comment+="*由 Crown AI 自动审查系统生成*"

  echo -e "${comment}"
}

REVIEW_COMMENT=$(build_review_comment)

# ---------------------------------------------------------------------------
# 发布审查评论
# ---------------------------------------------------------------------------

log "发布审查评论..."
echo -e "${REVIEW_COMMENT}" | gh pr comment "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" --body-file - || {
  log "WARNING: 发布评论失败"
}

# ---------------------------------------------------------------------------
# 执行操作
# ---------------------------------------------------------------------------

if [[ ${BLOCK_COUNT} -gt 0 ]]; then
  # ---- BLOCK: Request changes ----
  log "检测到阻塞问题，提交 request-changes 审查..."

  REVIEW_BODY="自动审查发现以下阻塞问题，请修复后重新提交:\n\n"
  for issue in "${BLOCK_ISSUES[@]}"; do
    REVIEW_BODY+="- ${issue}\n"
  done

  echo -e "${REVIEW_BODY}" | gh pr review "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" \
    --request-changes \
    --body-file - || {
    log "WARNING: 提交审查失败"
  }

elif [[ ${ESCALATE_COUNT} -gt 0 ]]; then
  # ---- ESCALATE: 通知 Boss ----
  log "检测到高风险变更，通知 Boss..."

  # 发送 Slack 通知
  if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
    SLACK_TEXT="🔔 *PR 需要人工审查*\n\n"
    SLACK_TEXT+="*仓库:* ${REPO_FULL_NAME}\n"
    SLACK_TEXT+="*PR:* <${PR_URL:-}|#${PR_NUMBER} - ${PR_TITLE:-untitled}>\n"
    SLACK_TEXT+="*作者:* ${PR_AUTHOR:-unknown}\n"
    SLACK_TEXT+="*变更:* ${FILE_COUNT} 文件, +${ADDITIONS}/-${DELETIONS}\n\n"
    SLACK_TEXT+="*触发原因:*\n"
    for issue in "${ESCALATE_ISSUES[@]}"; do
      SLACK_TEXT+="  • ${issue}\n"
    done

    SLACK_PAYLOAD=$(jq -n \
      --arg text "$(echo -e "${SLACK_TEXT}")" \
      '{text: $text}')

    curl -s -X POST \
      -H 'Content-Type: application/json' \
      -d "${SLACK_PAYLOAD}" \
      "${SLACK_WEBHOOK_URL}" || {
      log "WARNING: Slack 通知发送失败"
    }

    log "Slack 通知已发送"
  else
    log "WARNING: SLACK_WEBHOOK_URL 未配置，跳过 Slack 通知"
  fi

else
  # ---- 规则检查通过，调用 Tembo 深度审查 ----
  if [[ "${HAS_CODE_CHANGES}" == "true" ]]; then
    log "规则检查通过，提交给 Tembo 深度代码审查..."

    if [[ -n "${TEMBO_API_KEY:-}" ]]; then
      # 构建 Tembo review prompt
      REPO_SHORT="${REPO_FULL_NAME##*/}"
      TEMBO_PROMPT="Review PR #${PR_NUMBER} in ${REPO_FULL_NAME}.\n\nPR: ${PR_URL}\nTitle: ${PR_TITLE}\nAuthor: ${PR_AUTHOR}\nChanges: ${FILE_COUNT} files, +${ADDITIONS}/-${DELETIONS}\n\nInstructions:\n1. Analyze the diff for bugs, security issues, performance problems\n2. Check code quality and best practices\n3. If the PR is good, approve it with gh pr review --approve\n4. If issues found, submit request-changes review with specific feedback\n5. After approving, add the boss-approved label and merge the PR\n\nCommands to use after review:\n- Approve: gh pr review ${PR_NUMBER} --repo ${REPO_FULL_NAME} --approve --body 'review message'\n- Add label: gh api repos/${REPO_FULL_NAME}/issues/${PR_NUMBER}/labels --method POST --input - <<< '{\"labels\":[\"boss-approved\"]}'\n- Merge: gh pr merge ${PR_NUMBER} --repo ${REPO_FULL_NAME} --merge"

      TEMBO_PAYLOAD=$(cat <<PAYLOAD
{
  "prompt": "$(echo -e "${TEMBO_PROMPT}" | sed 's/"/\\"/g' | tr '\n' ' ')",
  "repositories": ["https://github.com/${REPO_FULL_NAME}"],
  "agent": "claudeCode:claude-opus-4-6"
}
PAYLOAD
)

      TEMBO_RESPONSE=$(curl -s -X POST \
        -H "Authorization: Bearer ${TEMBO_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "${TEMBO_PAYLOAD}" \
        "https://api.tembo.io/task/create" 2>/dev/null || echo '{"error":"failed"}')

      TEMBO_TASK_ID=$(echo "${TEMBO_RESPONSE}" | jq -r '.id // "unknown"' 2>/dev/null || echo "unknown")
      TEMBO_URL=$(echo "${TEMBO_RESPONSE}" | jq -r '.htmlUrl // "unknown"' 2>/dev/null || echo "unknown")

      if [[ "${TEMBO_TASK_ID}" != "unknown" ]] && [[ "${TEMBO_TASK_ID}" != "null" ]]; then
        log "Tembo 审查任务已创建: ${TEMBO_TASK_ID}"
        log "任务链接: ${TEMBO_URL}"

        # 在 PR 上留 comment 说明已提交 Tembo 审查
        gh pr comment "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" \
          --body "🔍 **已提交 Tembo 深度代码审查**

规则检查已通过（无二进制文件、无锁文件冲突、非高风险变更）。

Tembo 正在进行代码质量、安全性、性能审查：
- Task ID: \`${TEMBO_TASK_ID}\`
- [查看审查进度](${TEMBO_URL})

审查通过后将自动批准并合并。" || {
          log "WARNING: 发布 Tembo 通知评论失败"
        }
      else
        log "WARNING: Tembo 任务创建失败，回退到自动批准"
        # 回退: 直接批准
        gh pr review "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" \
          --approve \
          --body "✅ 规则检查通过，Tembo 不可用时自动批准。" || true

        gh label create "boss-approved" \
          --repo "${REPO_FULL_NAME}" \
          --color "0E8A16" \
          --description "Boss 自动批准" \
          --force 2>/dev/null || true

        gh api "repos/${REPO_FULL_NAME}/issues/${PR_NUMBER}/labels" \
          --method POST \
          --input - <<< '{"labels":["boss-approved"]}' > /dev/null || true

        gh pr merge "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" --merge \
          --body "✅ 自动审查通过，自动合并。" || {
          log "WARNING: 自动合并失败"
        }
      fi
    else
      log "WARNING: TEMBO_API_KEY 未配置，回退到直接自动批准"
      # 无 Tembo key 时直接批准
      gh pr review "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" \
        --approve \
        --body "✅ 自动审查通过，PR 已批准。" || true

      gh label create "boss-approved" \
        --repo "${REPO_FULL_NAME}" \
        --color "0E8A16" \
        --description "Boss 自动批准" \
        --force 2>/dev/null || true

      gh api "repos/${REPO_FULL_NAME}/issues/${PR_NUMBER}/labels" \
        --method POST \
        --input - <<< '{"labels":["boss-approved"]}' > /dev/null || true

      gh pr merge "${PR_NUMBER}" --repo "${REPO_FULL_NAME}" --merge \
        --body "✅ 自动审查通过，自动合并。" || {
        log "WARNING: 自动合并失败"
      }
    fi
  else
    log "PR 无实际代码变更，跳过审查"
  fi
fi

# ---------------------------------------------------------------------------
# 输出审查摘要
# ---------------------------------------------------------------------------

echo ""
echo "============================================"
echo "  自动审查摘要"
echo "============================================"
echo "  PR:        #${PR_NUMBER}"
echo "  作者:      ${PR_AUTHOR:-unknown}"
echo "  仓库:      ${REPO_FULL_NAME}"
echo "  文件数:    ${FILE_COUNT}"
echo "  新增:      +${ADDITIONS}"
echo "  删除:      -${DELETIONS}"
echo "  阻塞问题:  ${BLOCK_COUNT}"
echo "  警告:      ${WARN_COUNT}"
echo "  需升级:    ${ESCALATE_COUNT}"
echo "--------------------------------------------"
if [[ ${BLOCK_COUNT} -gt 0 ]]; then
  echo "  结果: ❌ REQUEST CHANGES"
elif [[ ${ESCALATE_COUNT} -gt 0 ]]; then
  echo "  结果: ⚠️ ESCALATED TO BOSS"
elif [[ "${HAS_CODE_CHANGES}" == "true" ]]; then
  echo "  结果: ✅ AUTO-APPROVED"
else
  echo "  结果: ⏭️ SKIPPED (no code changes)"
fi
echo "============================================"
