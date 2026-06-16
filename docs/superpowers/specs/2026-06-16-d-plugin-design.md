# 设计文档：`d` 插件 — AI 项目工作流引擎

- 日期：2026-06-16
- 状态：设计待审
- 工作目录：`/Users/dudu/cc-commands`（插件源码仓库）

## 1. 目标

做一个全局安装的 Claude Code 插件 `d`，对外只提供一个命令 `/d:init`。在任意项目目录运行 `/d:init`，它会：

1. 自动判断**新项目（空目录）**还是**老项目**。
2. 老项目：分析 codebase → 产出架构文档与编码约定文档 → 按项目实际情况生成裁剪过的 subagents → 生成该项目专属的 `/d:task`、`/d:fix` 命令。
3. 新项目：让用户描述需求 → AI 推导 better-t-stack 选型并一次确认后脚手架 → 落入老项目分析流程。

之后在项目里用 `/d:task` 跑需求迭代、`/d:fix` 跑 bug 修复，由主 agent 编排生成的 subagents 干活，验收以脚本结果为准。

## 2. 总体架构

```
插件 d（全局安装）                      /d:init 在项目内生成
├─ commands/init.md  → /d:init          ├─ docs/architecture/*.md        架构文档
├─ reference/                           ├─ docs/conventions.md            编码习惯 + 易踩坑点
│   ├─ analyze-codebase.md              ├─ docs/specs/NNNN-slug/          spec 落地（自增编号）
│   ├─ detect-roles.md                  ├─ .claude/agents/d-*.md          裁剪后的 subagents
│   ├─ agent-templates/*.md             ├─ .claude/commands/d/task.md     → /d:task
│   ├─ task-command.template.md         ├─ .claude/commands/d/fix.md      → /d:fix
│   ├─ fix-command.template.md          └─ .claude/d/manifest.json        名册 + 技术栈 + 编号计数器
│   └─ better-t-stack.md
└─ .claude-plugin/plugin.json
```

### 编排机制（核心约束）

slash command 本质是 prompt，由**主 agent** 执行。Claude Code 中 **subagent 不能再派 subagent**，调度能力只在主 agent 手里。因此：

- **运行 `/d:task`、`/d:fix` 的主 agent 本身就是「项目经理 / 总指挥」**——按命令里的编排逻辑派活、收结果、判驳回、控制循环与升级。
- **d-pm subagent** 只做离散、可被主 agent 调用的事：(a) 拆需求出 spec + 接口契约；(b) 在 gate 上评审（如 tester/ui 用例覆盖度）。
- subagents 之间不直接通信，通过**文件（spec、docs、测试脚本）+ 返回摘要**协作。

不使用 Workflow 工具（需显式 opt-in、偏重）；用原生 Task 工具调度。

### 命令名渲染（实现时验证）

目标是 `/d:init`、`/d:task`、`/d:fix`。`/d:init` 由插件提供（插件名 `d` + `commands/init.md`）；`/d:task`、`/d:fix` 由项目本地 `.claude/commands/d/` 子目录提供。实现首步需验证插件命令是否渲染成 `/d:init`；若拿不到 `d:` 前缀，备选：插件名设为 `d` 或退化为 `/init`。

## 3. `/d:init` 流程

```
/d:init
├─ 探测已初始化：存在 .claude/d/manifest.json？
│   是 → 增量刷新模式（见 §3.3）
│
├─ 探测新/老：目录为空或仅含 .git/README/LICENSE 等琐碎文件？
│   空 → 新项目路径（§3.1）；否则 → 老项目路径（§3.2）
```

### 3.1 新项目路径

1. 让用户用自然语言描述需求 / 产品形态。
2. AI 据此推导 better-t-stack 选型，拼成**非交互**命令：
   `npx create-better-t-stack . --yes --frontend ... --backend ... --database ... --orm ... --api ... --auth ... --package-manager ...`
   （flag 取值见 `reference/better-t-stack.md`：backend ∈ hono/express/fastify/elysia/convex/self/none；database ∈ none/sqlite/postgres/mysql/mongodb；orm ∈ none/drizzle/prisma/mongoose；api ∈ none/trpc/orpc；auth ∈ better-auth/clerk/none 等。）
3. 展示命令 + 选型理由 → **用户一次确认**。
4. 执行脚手架，落到当前目录。
5. **拉框架最佳实践**：用 context7 取所选框架/库的当前官方最佳实践与风格指南，蒸馏成 `docs/conventions.md` + **可执行规则配置**（该框架推荐的 ESLint/Biome preset、formatter、严格版 tsconfig、目录结构约定），直接写进项目并提交。新项目没有存量代码可推断，质量基线全靠这一步建立。
6. 落入老项目分析流程（对刚生成的代码做分析）。

### 3.2 老项目路径

1. **分析架构（自适应深度）**：并行派 `Explore`/分析 subagent 读 codebase；小项目一遍出概览，大项目并行深挖分层/分模块。
2. 写 `docs/architecture/`：`overview.md`（技术栈、分层、数据流、入口）+ 按需的分模块文件。
3. 写 `docs/conventions.md`：**合并显式约定、推断、最佳实践**——扫 lint/formatter 配置、`CONTRIBUTING`、已有 `CLAUDE.md`、tsconfig 等显式规则，叠加 AI 从代码里推断的命名/结构/习惯/易踩坑点，再用 context7 拉框架官方最佳实践补齐。若项目缺少 lint/format/typecheck 配置，**补齐为可执行规则配置**（质量门要靠它）。
4. **提取并实测命令**：从 package.json scripts / 配置里提取 lint、format、typecheck、test、build、dev 命令，**实际各跑一遍确认存在且可用**（猜错的门是假门）。
5. **判定角色**（见 `reference/detect-roles.md`）：按项目类型裁剪 worker。例：纯前端 SPA → frontend/ui，无 backend；CLI/库 → backend(core)，无 frontend/ui；全栈 → 全部。**`d-pm`、`d-tester`、`d-reviewer` 三个角色任何项目都生成**（拆分、测试门、质量门是通用关卡）。
6. **UI setup（仅当项目含 ui 角色；纯后端/CLI/库跳过）**——给 UI 立「设计真相源」，保证长期迭代一致。交互由主 agent 驱动，design.md 撰写委托 d-ui（subagent 问不了用户）：
   - 主 agent 问「UI 怎么处理？」
   - **用外部设计工具（Figma/Stitch/其他）** → 检测对应 MCP 是否可用，未绑定则提示用户完成 MCP 绑定 → `uiBaseline.mode="design"`、`designSource=figma/stitch`，**以外部工具为唯一真相源**，不生成本地 design.md。
   - **让 AI 决定 UI** → 主 agent 问用户 UI 偏好（风格/调性/配色/密度/参考产品）→ 委托 d-ui 结合需求 + 偏好 + 参考最佳实践写 `docs/design.md`（审美/排版/配色/布局/间距/组件规范）→ `designSource=docs/design.md`。
   - d-ui 视觉门统一以 `designSource` 为准做实现 vs 设计比对。
7. ⏸ **校准 checkpoint**：把提取出的架构、约定、角色名册、各门命令展示给用户过目，用户可纠正（「我们不用 X」「测试命令是 Y」）。确认后再生成。
8. 生成裁剪后的 `.claude/agents/d-*.md`：把**该项目的规范/习惯/质量红线内联进每个 agent 的 system prompt**，并**锚定到仓库真实范例文件**（「照 `src/features/auth/` 写、测试照 `tests/auth.test.ts`」），细节再指向 `docs/conventions.md`。
9. 生成 `.claude/commands/d/task.md`、`fix.md`，写死本项目技术栈、agent 名册、各门命令。
10. **自检建立绿色基线**：对当前 HEAD 实跑质量门 + 测试门，确认门能跑且现有代码能过。若干净代码上门就挂 → 门配错，当场修到绿再收尾。
11. 写 `manifest.json`，打印总结。

### 3.3 增量刷新模式（已初始化重跑）

读 manifest 发现已初始化 → 重新分析架构、更新 `docs/architecture` 与 `docs/conventions`；**保留**已有 `docs/specs/*` 与用户手改过的 agent 文件；对会覆盖手改内容的变更**先问再写**。

### 3.4 如何保证生成的工作流贴合当前项目

框架是通用的，但产出必须贴合本项目。**贴合不靠模板，靠「分析 + 校准 + 自检」**——模板只是空骨架，具体内容全部来自实地提取：

1. **模板薄、提取厚**：agent/命令里所有具体内容来自分析结果（真实目录边界、模块划分、测试位置与命名），不是写死的通用话术。
2. **命令实测**：lint/test/build/dev 从 scripts 提取后**实际跑一遍验证**（§3.2 步骤 4），不存在/跑不通的门当场暴露。
3. **锚定真实范例**：worker prompt 指向仓库真实范例文件，让 agent 模仿真实代码而非通用理想。
4. **约定回到代码验证**：AI 推断的习惯先 grep 确认在代码里**占主导**再写进 conventions，避免强加不属于本项目的规范。
5. **校准 checkpoint**：生成前用户过目并纠正提取结果（§3.2 步骤 7）。
6. **绿色基线自检**：生成后对 HEAD 实跑门禁，配错当场修（§3.2 步骤 10）。

## 4. 生成的 subagents

每个 agent = frontmatter（name/description/tools）+ 注入了本项目栈、规范红线、`docs` 指针、角色边界的 system prompt。**自包含为主**：逻辑不依赖外部插件，保证可移植；但检测到装了 superpowers / gstack 时**机会性调用**（如 d-tester 调 `systematic-debugging`、d-ui 调 `design-review`）。

| Agent | 职责 | 工具 |
|---|---|---|
| `d-pm` | 拆需求 → spec + 接口契约；gate 评审用例覆盖度 | Read/Grep/Glob/Write(仅 docs) |
| `d-frontend` | 实现前端，遵守内联规范 | 全 |
| `d-backend` | 实现后端 / API / DB，遵守内联规范 | 全 |
| `d-tester` | 把验收标准落成项目测试框架的**真实测试用例**；跑测试判 PASS/FAIL；脚本自身有 bug 自行修；fix 时负责根因定位 | 全 |
| `d-ui` | init 时撰写 `docs/design.md`（AI 决定 UI 的情形）；视觉回归脚本以 `designSource`（Figma/Stitch 或 design.md）为准做像素级比对；脚本自身有 bug 自行修 | 全（有则用浏览器工具 / figma MCP） |
| `d-reviewer` | 守**机械质量门**：跑 lint + format check + typecheck（+ 可选复杂度/分层架构 lint），以脚本结果判 PASS/FAIL；门禁脚本/配置自身有问题自行修；超出 lint 能力的规范判断（命名/分层/结构）做补充评审 | 全 |

## 5. `/d:task` 闭环（需求迭代）

```
/d:task <需求描述>
1. d-pm 拆需求 → spec + 接口契约 → docs/specs/NNNN-slug/spec.md
   （子任务分解、验收标准、各子任务归属 agent、API 契约先行）
2. ⏸ 人工 checkpoint：用户审批 spec
3. d-tester + d-ui 并行：依据 spec 生成测试用例 / 视觉基线脚本（d-reviewer 的质量门规则在 init 时已固化，无需逐任务生成）
4. d-pm 自动评审用例/基线对 spec 的覆盖度 → 通过 or 退回重写（自动 gate，不打扰用户）
5. d-frontend / d-backend 按 spec + 契约 实现（无依赖可并行；契约先行避免并行改同处冲突）
6. 主 agent 并列跑三道门 → 以脚本结果判 PASS/FAIL：
   · d-reviewer 质量门：lint + format + typecheck（+ 可选架构/复杂度 lint）
   · d-tester 测试门：测试用例运行
   · d-ui 视觉门：截图 diff
7. 任一门 FAIL → 带失败报告驳回开发 → 回到 5；门禁脚本自身有 bug 由对应 agent 自修
   · 同一子任务驳回累计 3 轮仍不过 → 暂停并升级给用户决策
8. 三门全 PASS → **reflow 回流**（见 §7）：收集本次冒出的候选学习项 → doc owner 按耐久性门槛筛选 → 自动更新 docs 并提交
9. 最终报告（改动、测试/质量/视觉结果、**本次回流了哪些文档**），更新 spec 状态
```

**接口契约先行**：pm 在 spec 里定好 API 契约（端点/入参/出参/错误），前后端各自照契约实现，降低并行冲突。

## 6. `/d:fix` 闭环（bug 修复）

```
/d:fix <bug 描述>
1. d-tester 根因调查：复现 → 定位根因（无根因不修），可机会性调用 systematic-debugging
2. ⏸ 人工 checkpoint：展示诊断结论，用户确认（与 task 的 spec 卡点对称）
3. 确认后：把修复路由给归属 agent（frontend/backend）实现
4. d-tester 验证修复 + 回归 + d-reviewer 质量门（脚本结果为准）；累计 3 轮不过 → 升级给用户
5. **reflow 回流**（见 §7）：把根因/踩坑点等候选学习项筛选后回流到 conventions/architecture
6. 报告；记录到 docs/specs/NNNN-fix-slug/（轻量）
```

## 7. 知识回流（reflow）

文档是「真相源」，但开发中架构会演进、会冒出新踩坑点 / 新约定 / 更好的 UI 方式。没有回流，`architecture`/`conventions.md`/`design.md` 就会变成过期快照、一致性保证失效。回流是保证体系不腐烂的一等机制。

**两个互补节奏**
- **持续回流**：每次 `/d:task`、`/d:fix` 全 PASS 后自动跑（轻量，即时沉淀）。
- **周期深扫**：`/d:init` 增量刷新（§3.3），整体重新对齐架构（重量）。

**回什么 / 谁写**（沿用文档归属）
- 架构变更（新模块/分层/数据流）、新踩坑点、新约定 → **d-pm** 整合进 `docs/architecture`、`docs/conventions.md`。
- 更好的 UI 方式 → **d-ui** 整合进 `docs/design.md`（外部 Figma 为真相源时，回流由用户处理，仓库不留 design.md）。

**耐久性门槛（防噪声）**：worker agent 在报告里冒出「候选学习项」，doc owner 按三条筛——①够通用（会再次出现）②文档里还没有（去重）③稳定非一次性。够格才写，否则丢弃。

**精简纪律（回流是编辑整合，不是追加）**：架构/约定/设计属于基础建设，臃肿即负担。doc owner 写入时遵守——
- **就地整合**：并进对应章节、改写措辞，不在末尾堆条目。
- **取代 + 修剪**：新认知与旧条目冲突/替代时，删掉或更新旧的，不新旧并存。
- **历史进 git 不进文档**：正文只留「当前为真」的精炼版，演进史靠 git，不在文档里留 changelog。
- **深扫整体压缩**：`/d:init` 增量刷新时对文档做一次 consolidation 重写。

**审批**：筛选后自动更新并提交，在最终报告里明列「本次回流了哪些文档」；用户不满意可回滚（不加额外打断）。

## 8. manifest.json

```jsonc
{
  "version": 1,
  "initializedAt": "<ISO>",
  "lastAnalyzedCommit": "<sha 或 null>",
  "projectType": "fullstack | frontend | backend | cli | library",
  "stack": { "frontend": "...", "backend": "...", "database": "...", "orm": "...", "test": "...", "pm": "pnpm" },
  "roles": ["d-pm", "d-frontend", "d-backend", "d-tester", "d-ui", "d-reviewer"],
  "qualityGate": { "lint": "<命令>", "format": "<命令>", "typecheck": "<命令>", "extra": ["<可选架构/复杂度 lint>"] },
  "uiBaseline": { "mode": "design | regression", "designSource": "<figma url / 路径 / null>", "tool": "playwright | backstopjs" },
  "specCounter": 0
}
```

## 9. 关键决策汇总

| 项 | 决策 |
|---|---|
| 分发形态 | Claude Code 插件 `d`；`/d:init` 全局，`/d:task`、`/d:fix` 由 init 生成到项目本地 |
| 新项目脚手架 | AI 推荐 better-t-stack 选型 + 一次确认，非交互执行 |
| task 节奏 | spec 后停一次人工 checkpoint，之后实现全自动 |
| spec 目录 | `docs/specs/NNNN-slug/`（自增编号 + 可读 slug） |
| fix 卡点 | 根因确认后停一次，再自动修（与 task 对称） |
| 编排角色 | 主 agent 当总指挥；d-pm 只做拆分 + gate 评审（subagent 不能派 subagent） |
| 验收（三门并列） | d-tester=真实测试用例、d-ui=视觉回归脚本、d-reviewer=机械质量门，**全部以脚本结果为准**；脚本 bug 由对应 agent 自修 |
| 质量门 | lint+format+typecheck(+可选架构/复杂度 lint) 落成脚本，与测试同等关卡；规则在 init 固化，由 d-reviewer 守 |
| 质量基线来源 | 新项目用 context7 拉框架官方最佳实践生成 conventions + 可执行规则配置；老项目缺配置则补齐 |
| 用例 gate | d-pm 自动评审覆盖度（不增加人工打断） |
| UI 基准 | 项目自适应，init 探测；默认 Playwright 截图 diff，有设计稿则比设计稿 |
| UI 真相源 | init 问 UI 怎么处理：外部 Figma/Stitch（验 MCP 绑定，唯一真相源）/ AI 决定（问偏好 → d-ui 写 docs/design.md）；纯后端跳过 |
| design.md | UI 之于设计 ≈ conventions 之于代码；仅 AI 决定 UI 时生成，是 UI 长期迭代的硬约束 |
| 驳回上限 | 同一子任务 3 轮不过 → 升级给用户 |
| 规范绑定 | 项目规范/习惯/质量红线内联进每个 worker agent 的 system prompt |
| 技能复用 | 自包含为主，检测到 superpowers/gstack 则机会性调用 |
| 重跑 init | 检测到已初始化 → 增量刷新，保留 spec 与手改，覆盖前先问 |
| 知识回流 | 每次 task/fix 全 PASS 后自动 reflow，按耐久性门槛筛候选学习项 → doc owner 更新 docs 并提交，报告里亮出（见 §7） |
| 文档精简 | 回流是「编辑整合」非「追加」：就地整合、取代修剪、历史进 git、深扫整体压缩，保基础建设文档不臃肿 |
| 贴合保证 | 模板薄+提取厚、命令实测、锚定真实范例、约定 grep 验证、校准 checkpoint、绿色基线自检（见 §3.4） |
| init 校准 | 生成前加一次校准 checkpoint，用户过目并纠正提取结果 |
| init 自检 | 生成后对 HEAD 实跑质量门+测试门建绿色基线，门配错当场修 |

## 10. 分阶段实现（plan 阶段细化）

1. 插件骨架 + 命令名渲染验证 + `/d:init` 老项目路径（分析 → docs → UI setup → 角色裁剪 → 生成 agents → 生成 task/fix 命令 + manifest）。
2. `/d:task` 编排（含 d-pm 拆分、用例 gate、三门并列验收-驳回闭环、3 轮升级、reflow 回流）。
3. `/d:fix` 编排（根因卡点 + 路由修复 + 回归 + reflow 回流）。
4. 新项目（better-t-stack）路径 + 增量刷新模式。

## 11. 待实现时验证的风险点

- 插件命令是否渲染成 `/d:init`（命名机制）。
- better-t-stack 确切 flag 取值与版本兼容（以 `--help` 实测为准）。
- 外部设计 MCP（Figma/Stitch）的可用性检测与绑定引导方式（不同 MCP 检测手段不一）。
- 视觉回归在无设计稿项目里的基线初始化体验。
- 大型 codebase 分析的 token 成本与并行度上限。
