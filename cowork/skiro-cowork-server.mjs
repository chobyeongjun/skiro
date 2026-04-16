#!/usr/bin/env node
// skiro-cowork MCP server v1.0
// For claude.ai (COWORK) — reads artifacts, learnings, git log from Code sessions
// Helps structure data for PPT, papers, and tech briefs

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "child_process";
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync, mkdirSync, renameSync } from "fs";
import { join, basename, extname } from "path";
import { homedir } from "os";

const GLOBAL_SKIRO = join(homedir(), ".skiro");
const ARTIFACTS_FILE = join(GLOBAL_SKIRO, "artifacts.jsonl");
const LEARNINGS_FILE = process.env.SKIRO_LEARNINGS || join(GLOBAL_SKIRO, "learnings.jsonl");
const PAPER_STATE_DIR = join(GLOBAL_SKIRO, "papers");

// ── Helpers ──────────────────────────────────────────────────────

function readJsonl(filePath) {
  try {
    return readFileSync(filePath, "utf8")
      .trim().split("\n").filter(Boolean)
      .map(l => { try { return JSON.parse(l); } catch { return null; } })
      .filter(Boolean);
  } catch {
    return [];
  }
}

function getGitLog(projectPath, days = 30) {
  const d = parseInt(days, 10) || 30;
  try {
    return execSync(
      `git log --oneline --since="${d} days ago" --no-merges 2>/dev/null`,
      { encoding: "utf8", cwd: projectPath }
    ).trim();
  } catch { return ""; }
}

function getGitStats(projectPath, days = 30) {
  const d = parseInt(days, 10) || 30;
  try {
    const log = execSync(
      `git log --shortstat --since="${d} days ago" --no-merges 2>/dev/null`,
      { encoding: "utf8", cwd: projectPath }
    ).trim();
    const commits = (log.match(/^[a-f0-9]{7,}/gm) || []).length;
    const insertions = [...log.matchAll(/(\d+) insertion/g)].reduce((s, m) => s + parseInt(m[1]), 0);
    const deletions = [...log.matchAll(/(\d+) deletion/g)].reduce((s, m) => s + parseInt(m[1]), 0);
    return { commits, insertions, deletions };
  } catch {
    return { commits: 0, insertions: 0, deletions: 0 };
  }
}

// Atomic write: tmp + rename prevents corruption on crash
function atomicWriteJSON(filePath, obj) {
  const tmp = filePath + ".tmp";
  writeFileSync(tmp, JSON.stringify(obj, null, 2), "utf8");
  renameSync(tmp, filePath);
}

// Schema validation for paper state
function validatePaperState(state, isUpdate) {
  const errs = [];
  if (!isUpdate && !state.title) errs.push("title is required (full set)");
  if (state.completion_pct != null) {
    const n = Number(state.completion_pct);
    if (isNaN(n) || n < 0 || n > 100) errs.push("completion_pct must be 0-100");
  }
  for (const key of ["sections", "contributions", "gaps", "key_figures"]) {
    if (state[key] != null && !Array.isArray(state[key])) errs.push(`${key} must be array`);
  }
  if (Array.isArray(state.sections)) {
    state.sections.forEach((s, i) => {
      if (!s || typeof s !== "object") { errs.push(`sections[${i}] must be object`); return; }
      if (!s.name) errs.push(`sections[${i}].name required`);
    });
  }
  if (Array.isArray(state.gaps)) {
    state.gaps.forEach((g, i) => {
      if (!g || typeof g !== "object") { errs.push(`gaps[${i}] must be object`); return; }
      if (!g.description) errs.push(`gaps[${i}].description required`);
    });
  }
  return errs;
}

// ── MCP Server ───────────────────────────────────────────────────

const server = new Server(
  { name: "skiro-cowork", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "cowork_list_artifacts",
      description: "List files saved during Claude Code sessions. Use to find figures, data, configs, analysis results for PPT/paper.",
      inputSchema: {
        type: "object",
        properties: {
          query:    { type: "string", description: "Search keyword (path, description, tags)" },
          category: { type: "string", enum: ["figure","data","config","log","analysis","model","document","other"] },
          last:     { type: "number", description: "Return last N entries (default 20)" },
          project:  { type: "string", description: "Filter by project name" }
        }
      }
    },
    {
      name: "cowork_get_learnings",
      description: "Get problem-solution history from Code sessions. Use for methodology changelog, troubleshooting history, or paper methods section.",
      inputSchema: {
        type: "object",
        properties: {
          category: { type: "string", description: "Filter: hardware, software, control, experiment, safety, protocol, process" },
          status:   { type: "string", enum: ["solved","unsolved"] },
          days:     { type: "number", description: "Last N days (default: all)" },
          format:   { type: "string", enum: ["list","table","timeline","paper"], description: "Output format (default: list)" }
        }
      }
    },
    {
      name: "cowork_project_summary",
      description: "Generate a structured project summary for PPT/paper/meeting. Combines artifacts + learnings + git activity.",
      inputSchema: {
        type: "object",
        properties: {
          project_path: { type: "string", description: "Path to the project (for git log)" },
          days:         { type: "number", description: "Period in days (default 30)" },
          purpose:      { type: "string", enum: ["meeting","paper","poster","portfolio"], description: "What this summary is for" },
          lang:         { type: "string", enum: ["ko","en"], description: "Output language (default ko)" }
        },
        required: ["project_path"]
      }
    },
    {
      name: "cowork_paper_data",
      description: "Extract structured data for a specific paper section. Pulls relevant artifacts, learnings, and stats.",
      inputSchema: {
        type: "object",
        properties: {
          section:      { type: "string", enum: ["introduction","methods","results","discussion","all"], description: "Paper section" },
          project_path: { type: "string", description: "Path to the project" },
          category:     { type: "string", description: "Focus area (e.g. control, experiment)" }
        },
        required: ["section"]
      }
    },
    {
      name: "cowork_read_file",
      description: "Read the actual content of a file. Use after cowork_list_artifacts to read data, configs, or analysis results for PPT/paper.",
      inputSchema: {
        type: "object",
        properties: {
          path:      { type: "string", description: "Absolute path to the file" },
          max_lines: { type: "number", description: "Max lines to return (default 200, max 1000)" }
        },
        required: ["path"]
      }
    },
    {
      name: "cowork_scan_experiments",
      description: "Scan experiments/ and meetings/ directories to build a complete inventory. Returns each experiment's meta, status, available files, and figures. Data tiers: raw (all captured), ppt (presentation-ready), paper (publication-quality). Use as the first step for paper writing.",
      inputSchema: {
        type: "object",
        properties: {
          project_path: { type: "string", description: "Root path of the research project" },
          experiments_dir: { type: "string", description: "Experiments subdirectory name (default: experiments)" },
          meetings_dir: { type: "string", description: "Meetings subdirectory name (default: meetings)" },
          tier: { type: "string", enum: ["raw","ppt","paper","all"], description: "Filter by data tier (default: all)" }
        },
        required: ["project_path"]
      }
    },
    {
      name: "cowork_paper_state",
      description: "Read or write persistent paper design state (title, contributions, sections, key_figures, completion_pct, gaps). Actions: list (enumerate all papers), get (read), set (full overwrite with validation), update (partial merge with existing). Atomic writes prevent corruption.",
      inputSchema: {
        type: "object",
        properties: {
          paper_id:   { type: "string", description: "Unique paper identifier (required for get/set/update, ignored for list)" },
          action:     { type: "string", enum: ["list","get","set","update"], description: "list: all papers, get: read, set: full overwrite, update: partial merge" },
          state:      { type: "object", description: "Paper state (required for set/update). Keys: title, contributions[], sections[{name,status,key_experiments[]}], key_figures[], completion_pct (0-100), gaps[{description,priority,type}]" }
        },
        required: ["action"]
      }
    },
    {
      name: "cowork_paper_check",
      description: "Validate paper_state consistency: (1) referenced experiments exist in project, (2) key_figures resolve to actual artifacts, (3) completion_pct matches section status, (4) unresolved high-priority gaps. Run before deciding next steps.",
      inputSchema: {
        type: "object",
        properties: {
          paper_id:     { type: "string", description: "Paper identifier to validate" },
          project_path: { type: "string", description: "Project root (to locate experiments/)" }
        },
        required: ["paper_id"]
      }
    },
    {
      name: "cowork_promote_data",
      description: "Promote experiment files between tiers: raw→ppt or raw→paper or ppt→paper. Use when selecting data for presentation or publication.",
      inputSchema: {
        type: "object",
        properties: {
          experiment_path: { type: "string", description: "Path to the experiment directory" },
          files:           { type: "array", items: { type: "string" }, description: "File names to promote (from source tier)" },
          from_tier:       { type: "string", enum: ["raw","ppt"], description: "Source tier" },
          to_tier:         { type: "string", enum: ["ppt","paper"], description: "Destination tier" }
        },
        required: ["experiment_path", "files", "from_tier", "to_tier"]
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;

  // ── List Artifacts ─────────────────────────────────────────────
  if (name === "cowork_list_artifacts") {
    let entries = readJsonl(ARTIFACTS_FILE);

    if (args.category) entries = entries.filter(e => e.category === args.category);
    if (args.project) entries = entries.filter(e => (e.project || "").toLowerCase().includes(args.project.toLowerCase()));
    if (args.query) {
      const q = args.query.toLowerCase();
      entries = entries.filter(e =>
        (e.path || "").toLowerCase().includes(q) ||
        (e.description || "").toLowerCase().includes(q) ||
        (e.name || "").toLowerCase().includes(q) ||
        (e.tags || []).some(t => t.toLowerCase().includes(q))
      );
    }

    entries = entries.slice(-(args.last || 20));

    if (!entries.length) {
      return { content: [{ type: "text", text: `No artifacts found${args.query ? ` for "${args.query}"` : ""}.` }] };
    }

    const out = entries.map(e =>
      `[${e.date}] ${e.category} | **${e.name}**\n  ${e.description}\n  → \`${e.path}\`${e.tags?.length ? `\n  tags: ${e.tags.join(", ")}` : ""}`
    ).join("\n\n");

    return { content: [{ type: "text", text: `## Artifacts (${entries.length})\n\n${out}` }] };
  }

  // ── Get Learnings ──────────────────────────────────────────────
  if (name === "cowork_get_learnings") {
    let entries = readJsonl(LEARNINGS_FILE);

    if (args.category) entries = entries.filter(e => e.category === args.category);
    if (args.status) entries = entries.filter(e => e.status === args.status);
    if (args.days) {
      const cutoff = new Date(Date.now() - args.days * 86400000).toISOString().slice(0, 10);
      entries = entries.filter(e => (e.date || e.last_seen || "") >= cutoff);
    }

    if (!entries.length) {
      return { content: [{ type: "text", text: "No learnings found." }] };
    }

    const format = args.format || "list";

    if (format === "table") {
      const header = "| Date | Category | Severity | Problem | Solution | Status |\n|------|----------|----------|---------|----------|--------|\n";
      const rows = entries.map(e =>
        `| ${e.date || "-"} | ${e.category || "-"} | ${e.severity || "-"} | ${(e.problem || "-").slice(0, 40)} | ${(e.solution || "-").slice(0, 40)} | ${e.status || "-"} |`
      ).join("\n");
      return { content: [{ type: "text", text: `## Learnings\n\n${header}${rows}` }] };
    }

    if (format === "timeline") {
      const byDate = {};
      entries.forEach(e => {
        const d = e.date || "unknown";
        if (!byDate[d]) byDate[d] = [];
        byDate[d].push(e);
      });
      const out = Object.entries(byDate).sort().map(([date, items]) => {
        const lines = items.map(e => {
          const icon = e.status === "solved" ? "✓" : "?";
          return `  - [${icon}] ${e.problem || "N/A"}${e.solution ? ` → ${e.solution}` : ""}`;
        }).join("\n");
        return `### ${date}\n${lines}`;
      }).join("\n\n");
      return { content: [{ type: "text", text: `## Timeline\n\n${out}` }] };
    }

    if (format === "paper") {
      // Group by category, show problem→solution flow
      const grouped = {};
      entries.forEach(e => {
        const cat = e.category || "general";
        if (!grouped[cat]) grouped[cat] = [];
        grouped[cat].push(e);
      });
      const out = Object.entries(grouped).map(([cat, items]) => {
        const solved = items.filter(e => e.status === "solved");
        const lines = solved.map(e =>
          `- **Problem**: ${e.problem}\n  **Solution**: ${e.solution}\n  *(${e.severity}, ${e.date})*`
        ).join("\n\n");
        return `### ${cat} (${items.length} issues, ${solved.length} resolved)\n\n${lines}`;
      }).join("\n\n");
      return { content: [{ type: "text", text: `## Methodology Changelog\n\n${out}` }] };
    }

    // default: list
    const out = entries.map(e => {
      const icon = e.status === "solved" ? "✓" : "?";
      return `[${icon}] [${e.category || "?"}] ${e.problem || "N/A"}${e.solution ? `\n  → ${e.solution}` : ""} (${e.date || "?"}, ${e.severity || "?"})`;
    }).join("\n");
    return { content: [{ type: "text", text: `## Learnings (${entries.length})\n\n${out}` }] };
  }

  // ── Project Summary ────────────────────────────────────────────
  if (name === "cowork_project_summary") {
    const projectPath = args.project_path;
    const days = args.days || 30;
    const purpose = args.purpose || "meeting";
    const isKo = (args.lang || "ko") === "ko";

    const artifacts = readJsonl(ARTIFACTS_FILE);
    const learnings = readJsonl(LEARNINGS_FILE);
    const gitLog = getGitLog(projectPath, days);
    const stats = getGitStats(projectPath, days);

    const projectName = basename(projectPath);
    const problems = learnings.filter(e => e.problem);
    const solved = problems.filter(e => e.status === "solved");
    const unsolved = problems.filter(e => e.status !== "solved");
    const criticals = unsolved.filter(e => e.severity === "CRITICAL");

    const figures = artifacts.filter(e => e.category === "figure");
    const data = artifacts.filter(e => e.category === "data" || e.category === "analysis");

    const sections = [];

    sections.push(`# ${isKo ? "프로젝트 요약" : "Project Summary"} — ${projectName}`);
    sections.push(`${isKo ? "기간" : "Period"}: ${isKo ? "최근" : "Last"} ${days}${isKo ? "일" : " days"} | ${isKo ? "목적" : "Purpose"}: ${purpose}\n`);

    // Overview
    sections.push(`## ${isKo ? "개요" : "Overview"}`);
    sections.push(`- ${isKo ? "커밋" : "Commits"}: ${stats.commits}`);
    sections.push(`- ${isKo ? "코드 변경" : "Code changes"}: +${stats.insertions} / -${stats.deletions}`);
    sections.push(`- ${isKo ? "이슈" : "Issues"}: ${problems.length}${isKo ? "건" : ""} (${isKo ? "해결" : "solved"}: ${solved.length}, ${isKo ? "미해결" : "open"}: ${unsolved.length})`);
    if (criticals.length) sections.push(`- **${isKo ? "미해결 CRITICAL" : "Unresolved CRITICAL"}**: ${criticals.length}`);
    sections.push(`- ${isKo ? "저장된 파일" : "Saved artifacts"}: ${artifacts.length} (${isKo ? "그래프" : "figures"}: ${figures.length}, ${isKo ? "데이터" : "data"}: ${data.length})`);
    sections.push("");

    // Key achievements
    if (solved.length) {
      sections.push(`## ${isKo ? "주요 해결 사항" : "Key Solutions"}`);
      solved.slice(-10).forEach(s => {
        sections.push(`- ${s.solution || "N/A"} ← *${s.problem || ""}* (${s.category || "?"})`);
      });
      sections.push("");
    }

    // Open issues
    if (unsolved.length) {
      sections.push(`## ${isKo ? "미해결 이슈" : "Open Issues"}`);
      unsolved.forEach(u => {
        sections.push(`- [${u.severity || "?"}] ${u.problem || "N/A"} (${u.category || "?"})`);
      });
      sections.push("");
    }

    // Available figures
    if (figures.length) {
      sections.push(`## ${isKo ? "사용 가능한 Figure" : "Available Figures"}`);
      figures.slice(-10).forEach(f => {
        sections.push(`- **${f.name}**: ${f.description}\n  → \`${f.path}\``);
      });
      sections.push("");
    }

    // Git timeline
    if (gitLog) {
      sections.push(`## ${isKo ? "개발 타임라인" : "Development Timeline"}`);
      sections.push("```");
      sections.push(gitLog.split("\n").slice(0, 15).join("\n"));
      sections.push("```\n");
    }

    // Purpose-specific notes
    if (purpose === "paper") {
      sections.push(`## ${isKo ? "논문 작성 참고" : "Paper Writing Notes"}`);
      sections.push(`- ${isKo ? "방법론 변경 근거" : "Methodology rationale"}: cowork_get_learnings(format="paper")`);
      sections.push(`- ${isKo ? "수치 데이터" : "Numerical data"}: cowork_list_artifacts(category="data")`);
      sections.push(`- ${isKo ? "Figure 목록" : "Figures"}: cowork_list_artifacts(category="figure")`);
    } else if (purpose === "meeting") {
      sections.push(`## ${isKo ? "다음 스텝 제안" : "Suggested Next Steps"}`);
      if (criticals.length) sections.push(`1. CRITICAL ${isKo ? "이슈 우선 해결" : "issues first"}: ${criticals.length}${isKo ? "건" : ""}`);
      sections.push(`${criticals.length ? "2" : "1"}. ${isKo ? "미해결" : "Open"}: ${unsolved.length}${isKo ? "건 처리" : " remaining"}`);
    }

    return { content: [{ type: "text", text: sections.join("\n") }] };
  }

  // ── Paper Data ─────────────────────────────────────────────────
  if (name === "cowork_paper_data") {
    const section = args.section || "all";
    const projectPath = args.project_path || process.cwd();
    const catFilter = args.category || null;

    const artifacts = readJsonl(ARTIFACTS_FILE);
    let learnings = readJsonl(LEARNINGS_FILE);
    if (catFilter) learnings = learnings.filter(e => e.category === catFilter);

    const sections = [];

    if (section === "all" || section === "introduction") {
      sections.push("## Introduction Data\n");
      const stats = getGitStats(projectPath, 365);
      sections.push(`- Total development: ${stats.commits} commits, +${stats.insertions}/-${stats.deletions} lines`);
      const categories = [...new Set(learnings.map(e => e.category).filter(Boolean))];
      sections.push(`- Technical areas: ${categories.join(", ")}`);
      const problems = learnings.filter(e => e.problem);
      sections.push(`- Challenges encountered: ${problems.length} (${problems.filter(e => e.status === "solved").length} resolved)`);
      sections.push("");
    }

    if (section === "all" || section === "methods") {
      sections.push("## Methods Data\n");
      sections.push("### Methodology Evolution (problem → solution → design change)\n");
      const solved = learnings.filter(e => e.status === "solved" && e.problem && e.solution);
      const grouped = {};
      solved.forEach(e => {
        const cat = e.category || "general";
        if (!grouped[cat]) grouped[cat] = [];
        grouped[cat].push(e);
      });
      for (const [cat, items] of Object.entries(grouped)) {
        sections.push(`#### ${cat}`);
        items.forEach(e => {
          sections.push(`- **Challenge**: ${e.problem}`);
          sections.push(`  **Resolution**: ${e.solution}`);
          sections.push(`  *(${e.severity}, ${e.date})*\n`);
        });
      }
    }

    if (section === "all" || section === "results") {
      sections.push("## Results Data\n");

      const figures = artifacts.filter(e => e.category === "figure");
      const dataFiles = artifacts.filter(e => e.category === "data" || e.category === "analysis");

      if (figures.length) {
        sections.push("### Available Figures");
        sections.push("| # | File | Description | Path |");
        sections.push("|---|------|-------------|------|");
        figures.forEach((f, i) => {
          sections.push(`| ${i + 1} | ${f.name} | ${f.description} | \`${f.path}\` |`);
        });
        sections.push("");
      }

      if (dataFiles.length) {
        sections.push("### Data Files");
        dataFiles.forEach(d => {
          sections.push(`- **${d.name}**: ${d.description}\n  → \`${d.path}\``);
        });
        sections.push("");
      }

      const problems = learnings.filter(e => e.problem);
      const solvedCount = problems.filter(e => e.status === "solved").length;
      sections.push("### Issue Statistics");
      sections.push(`- Total issues: ${problems.length}`);
      sections.push(`- Resolution rate: ${problems.length ? Math.round(solvedCount / problems.length * 100) : 0}%`);

      const byCat = {};
      problems.forEach(p => { const c = p.category || "?"; byCat[c] = (byCat[c] || 0) + 1; });
      sections.push("\n| Category | Count |");
      sections.push("|----------|-------|");
      for (const [c, n] of Object.entries(byCat).sort((a, b) => b[1] - a[1])) {
        sections.push(`| ${c} | ${n} |`);
      }
      sections.push("");
    }

    if (section === "all" || section === "discussion") {
      sections.push("## Discussion Data\n");
      const unsolved = learnings.filter(e => e.status !== "solved" && e.problem);
      if (unsolved.length) {
        sections.push("### Known Limitations / Open Issues");
        unsolved.forEach(u => {
          sections.push(`- [${u.severity || "?"}] ${u.problem} *(${u.category || "?"})*`);
        });
        sections.push("");
      }
      sections.push("### Lessons Learned");
      const recurring = learnings.filter(e => (e.count || 0) >= 2);
      if (recurring.length) {
        recurring.forEach(r => {
          sections.push(`- ${r.problem} (occurred ${r.count}x)${r.solution ? ` → ${r.solution}` : ""}`);
        });
      } else {
        sections.push("- No recurring issues detected.");
      }
      sections.push("");
    }

    return { content: [{ type: "text", text: sections.join("\n") }] };
  }

  // ── Read File ───────────────────────────────────────────────────
  if (name === "cowork_read_file") {
    const filePath = args.path;
    const maxLines = Math.min(args.max_lines || 200, 1000);

    if (!filePath || !existsSync(filePath)) {
      return { content: [{ type: "text", text: `File not found: ${filePath || "(no path)"}` }] };
    }

    try {
      const stat = statSync(filePath);
      if (stat.isDirectory()) {
        const files = readdirSync(filePath).slice(0, 50);
        return { content: [{ type: "text", text: `Directory listing (${files.length}):\n${files.join("\n")}` }] };
      }

      // Binary file check by extension
      const binExts = new Set([".png",".jpg",".jpeg",".gif",".bmp",".ico",".pdf",".zip",".tar",".gz",".bin",".exe",".dll",".so",".o",".pyc"]);
      const ext = extname(filePath).toLowerCase();
      if (binExts.has(ext)) {
        return { content: [{ type: "text", text: `Binary file (${ext}, ${(stat.size / 1024).toFixed(1)}KB): ${filePath}\nUse cowork_list_artifacts to see description and tags.` }] };
      }

      const content = readFileSync(filePath, "utf8");
      const lines = content.split("\n");
      const truncated = lines.length > maxLines;
      const output = lines.slice(0, maxLines).join("\n");

      return { content: [{ type: "text", text: `## ${basename(filePath)} (${lines.length} lines${truncated ? `, showing first ${maxLines}` : ""})\n\n\`\`\`\n${output}\n\`\`\`` }] };
    } catch (e) {
      return { content: [{ type: "text", text: `Error reading ${filePath}: ${e.message}` }] };
    }
  }

  // ── Scan Experiments ────────────────────────────────────────────
  if (name === "cowork_scan_experiments") {
    const root = args.project_path;
    const expDir = join(root, args.experiments_dir || "experiments");
    const mtgDir = join(root, args.meetings_dir || "meetings");
    const tierFilter = args.tier || "all";

    const figExts = new Set([".png",".jpg",".jpeg",".svg",".pdf"]);
    const dataExts = new Set([".csv",".json",".jsonl",".txt",".log",".yaml",".yml"]);

    const countFiles = (dir) => {
      if (!existsSync(dir)) return { figures: 0, data: 0, files: [] };
      const result = { figures: 0, data: 0, files: [] };
      try {
        for (const f of readdirSync(dir)) {
          const ext = extname(f).toLowerCase();
          if (figExts.has(ext)) { result.figures++; result.files.push(join(dir, f)); }
          else if (dataExts.has(ext)) { result.data++; result.files.push(join(dir, f)); }
        }
      } catch {}
      return result;
    };

    const scanDir = (dirPath, type) => {
      if (!existsSync(dirPath)) return [];
      const items = [];
      try {
        for (const entry of readdirSync(dirPath)) {
          const entryPath = join(dirPath, entry);
          try { if (!statSync(entryPath).isDirectory()) continue; } catch { continue; }

          const item = { name: entry, path: entryPath, type };

          // Read meta.json
          const metaPath = join(entryPath, "meta.json");
          if (existsSync(metaPath)) {
            try { item.meta = JSON.parse(readFileSync(metaPath, "utf8")); } catch { item.meta = null; }
          }

          // Key files
          item.has_summary = existsSync(join(entryPath, "summary.md"));
          item.has_feedback = existsSync(join(entryPath, "feedback.md"));

          // 3-tier data: raw → ppt → paper
          item.tiers = {};
          for (const tier of ["raw", "ppt", "paper"]) {
            const tierPath = join(entryPath, tier);
            if (existsSync(tierPath) && statSync(tierPath).isDirectory()) {
              item.tiers[tier] = countFiles(tierPath);
            }
          }

          // Also check legacy dirs (results/, figures/, data/)
          const legacyFigures = countFiles(join(entryPath, "figures"));
          const legacyResults = countFiles(join(entryPath, "results"));
          const legacyData = countFiles(join(entryPath, "data"));
          const rootFiles = countFiles(entryPath);
          item.other_files = {
            figures: legacyFigures.figures + legacyResults.figures + rootFiles.figures,
            data: legacyData.data + legacyResults.data + rootFiles.data
          };

          items.push(item);
        }
      } catch {}
      return items;
    };

    const experiments = scanDir(expDir, "experiment");
    const meetings = scanDir(mtgDir, "meeting");

    if (!experiments.length && !meetings.length) {
      return { content: [{ type: "text", text: `No experiments or meetings found.\nSearched: ${expDir}, ${mtgDir}` }] };
    }

    const lines = [];
    lines.push(`## Research Inventory\n`);

    if (experiments.length) {
      lines.push(`### Experiments (${experiments.length})\n`);
      for (const e of experiments) {
        const status = e.meta?.status || "unknown";
        const date = e.meta?.date || "-";
        lines.push(`**${e.name}** (${status}, ${date})`);
        if (e.meta?.description) lines.push(`  ${e.meta.description}`);

        // Tier summary
        const tierNames = Object.keys(e.tiers);
        if (tierNames.length) {
          const tierInfo = tierNames.map(t => {
            const ti = e.tiers[t];
            return `${t}: ${ti.figures}fig/${ti.data}data`;
          }).join(" | ");
          lines.push(`  tiers: [${tierInfo}]`);

          // Show highest tier reached
          const highest = tierNames.includes("paper") ? "paper" : tierNames.includes("ppt") ? "ppt" : "raw";
          lines.push(`  highest tier: **${highest}**`);

          // If tier filter applied, show that tier's files
          if (tierFilter !== "all" && e.tiers[tierFilter]) {
            const tf = e.tiers[tierFilter];
            if (tf.files.length) {
              tf.files.forEach(f => lines.push(`    - ${basename(f)}`));
            }
          }
        } else {
          // No tier dirs — show legacy
          const flags = [];
          if (e.has_summary) flags.push("summary");
          if (e.has_feedback) flags.push("feedback");
          lines.push(`  files: [${flags.join(", ")}] | figures: ${e.other_files.figures} | data: ${e.other_files.data}`);
          lines.push(`  tiers: none (raw/, ppt/, paper/ 폴더 없음)`);
        }

        lines.push(`  → \`${e.path}\`\n`);
      }
    }

    if (meetings.length) {
      lines.push(`### Meetings (${meetings.length})\n`);
      for (const m of meetings) {
        const date = m.meta?.date || "-";
        lines.push(`**${m.name}** (${date})`);
        if (m.has_feedback) lines.push(`  has feedback`);
        lines.push(`  → \`${m.path}\`\n`);
      }
    }

    return { content: [{ type: "text", text: lines.join("\n") }] };
  }

  // ── Paper State ───────────────────────────────────────────────
  if (name === "cowork_paper_state") {
    if (!existsSync(PAPER_STATE_DIR)) mkdirSync(PAPER_STATE_DIR, { recursive: true });

    // List: enumerate all papers
    if (args.action === "list") {
      let files = [];
      try { files = readdirSync(PAPER_STATE_DIR).filter(f => f.endsWith(".json") && !f.endsWith(".tmp")); } catch {}
      if (!files.length) return { content: [{ type: "text", text: "No paper states yet. Create one with action=set + paper_id + state." }] };
      const lines = [`## Saved Papers (${files.length})\n`];
      for (const f of files) {
        const id = f.replace(/\.json$/, "");
        try {
          const s = JSON.parse(readFileSync(join(PAPER_STATE_DIR, f), "utf8"));
          lines.push(`- **${id}** — ${s.title || "(no title)"}`);
          const meta = [];
          if (s.completion_pct != null) meta.push(`${s.completion_pct}%`);
          if (s.sections?.length) meta.push(`${s.sections.length} sections`);
          if (s.gaps?.length) meta.push(`${s.gaps.length} gaps`);
          if (s.updated) meta.push(`updated ${s.updated}`);
          if (meta.length) lines.push(`  ${meta.join(" | ")}`);
        } catch {
          lines.push(`- **${id}** — (corrupted, cannot parse)`);
        }
      }
      return { content: [{ type: "text", text: lines.join("\n") }] };
    }

    if (!args.paper_id) {
      return { content: [{ type: "text", text: `Error: paper_id required for action="${args.action}". Use action="list" to see existing papers.` }] };
    }
    const paperId = args.paper_id.replace(/[^a-zA-Z0-9_-]/g, "_");
    const stateFile = join(PAPER_STATE_DIR, `${paperId}.json`);

    if (args.action === "get") {
      if (!existsSync(stateFile)) {
        return { content: [{ type: "text", text: `No paper state found for "${args.paper_id}". Use action="set" to create initial state, or action="list" to see existing papers.` }] };
      }
      try {
        const state = JSON.parse(readFileSync(stateFile, "utf8"));
        const lines = [];
        lines.push(`## Paper: ${state.title || paperId}\n`);
        if (state.completion_pct != null) lines.push(`**Completion: ${state.completion_pct}%**\n`);
        if (state.contributions?.length) {
          lines.push(`### Contributions`);
          state.contributions.forEach(c => lines.push(`- ${c}`));
          lines.push("");
        }
        if (state.sections?.length) {
          lines.push(`### Sections`);
          lines.push("| Section | Status | Key Experiments |");
          lines.push("|---------|--------|-----------------|");
          state.sections.forEach(s => {
            lines.push(`| ${s.name} | ${s.status || "-"} | ${(s.key_experiments || []).join(", ") || "-"} |`);
          });
          lines.push("");
        }
        if (state.key_figures?.length) {
          lines.push(`### Key Figures`);
          state.key_figures.forEach(f => lines.push(`- ${f}`));
          lines.push("");
        }
        if (state.gaps?.length) {
          lines.push(`### Gaps`);
          state.gaps.forEach(g => lines.push(`- [${g.priority || "?"}] ${g.description} *(${g.type || "?"})*`));
          lines.push("");
        }
        if (state.updated) lines.push(`*Last updated: ${state.updated}*`);
        lines.push(`\n---\nRaw state:\n\`\`\`json\n${JSON.stringify(state, null, 2)}\n\`\`\``);
        return { content: [{ type: "text", text: lines.join("\n") }] };
      } catch (e) {
        return { content: [{ type: "text", text: `Error reading state (corrupted file?): ${e.message}\nFile: ${stateFile}` }] };
      }
    }

    if (args.action === "set" || args.action === "update") {
      if (!args.state || typeof args.state !== "object" || Array.isArray(args.state)) {
        return { content: [{ type: "text", text: `Error: state object required for action="${args.action}"` }] };
      }

      const isUpdate = args.action === "update";
      const errs = validatePaperState(args.state, isUpdate);
      if (errs.length) {
        return { content: [{ type: "text", text: `Validation errors:\n${errs.map(e => "- " + e).join("\n")}` }] };
      }

      // Merge with existing for update
      let merged = { ...args.state };
      if (isUpdate && existsSync(stateFile)) {
        try {
          const prev = JSON.parse(readFileSync(stateFile, "utf8"));
          merged = { ...prev, ...args.state };
        } catch (e) {
          return { content: [{ type: "text", text: `Existing state corrupted, cannot update: ${e.message}\nUse action="set" to overwrite.` }] };
        }
      }

      const state = {
        ...merged,
        updated: new Date().toISOString().slice(0, 10),
        schema_version: 1
      };

      try {
        atomicWriteJSON(stateFile, state);
      } catch (e) {
        return { content: [{ type: "text", text: `Error saving state: ${e.message}` }] };
      }

      return { content: [{ type: "text", text: `Paper state ${args.action}: ${paperId}\nCompletion: ${state.completion_pct ?? "?"}%\nSections: ${(state.sections || []).length}\nGaps: ${(state.gaps || []).length}\n\nNext: run cowork_paper_check to validate consistency.` }] };
    }

    return { content: [{ type: "text", text: `Unknown action: ${args.action}. Use "list", "get", "set", or "update".` }] };
  }

  // ── Paper Check ────────────────────────────────────────────────
  if (name === "cowork_paper_check") {
    const paperId = args.paper_id.replace(/[^a-zA-Z0-9_-]/g, "_");
    const stateFile = join(PAPER_STATE_DIR, `${paperId}.json`);
    if (!existsSync(stateFile)) {
      return { content: [{ type: "text", text: `No state for "${args.paper_id}". Run cowork_scan_experiments + cowork_paper_state(action=set) first.` }] };
    }
    let state;
    try { state = JSON.parse(readFileSync(stateFile, "utf8")); }
    catch (e) { return { content: [{ type: "text", text: `State file corrupted: ${e.message}` }] }; }

    const projectPath = args.project_path || process.cwd();
    const issues = [];
    const ok = [];

    // 1. Referenced experiments exist
    const expDir = join(projectPath, "experiments");
    let experiments = [];
    if (existsSync(expDir)) {
      try {
        experiments = readdirSync(expDir).filter(f => {
          try { return statSync(join(expDir, f)).isDirectory(); } catch { return false; }
        });
      } catch {}
    }
    const referencedExps = new Set();
    (state.sections || []).forEach(s => (s.key_experiments || []).forEach(e => referencedExps.add(e)));
    if (referencedExps.size === 0) {
      if ((state.sections || []).length) issues.push("no sections reference any experiment (key_experiments empty)");
    } else {
      for (const ref of referencedExps) {
        if (experiments.includes(ref)) ok.push(`experiment exists: ${ref}`);
        else issues.push(`referenced experiment not found in ${expDir}/: ${ref}`);
      }
    }

    // 2. Key figures resolve to artifacts
    const artifacts = readJsonl(ARTIFACTS_FILE);
    const figurePaths = artifacts.filter(a => a.category === "figure").map(a => a.path);
    (state.key_figures || []).forEach(f => {
      const matched = figurePaths.some(p => p === f || p.endsWith("/" + f) || basename(p) === f);
      if (matched) ok.push(`figure found: ${f}`);
      else issues.push(`key_figure not in artifacts: ${f} (run skiro_save_artifact in Code session)`);
    });

    // 3. completion_pct vs sections status coherence
    const sections = state.sections || [];
    if (sections.length && state.completion_pct != null) {
      const doneStatuses = new Set(["done", "complete", "completed", "draft-done"]);
      const doneCount = sections.filter(s => doneStatuses.has((s.status || "").toLowerCase())).length;
      const actualPct = Math.round(doneCount / sections.length * 100);
      const claimed = Number(state.completion_pct);
      if (Math.abs(actualPct - claimed) > 25) {
        issues.push(`completion_pct ${claimed}% inconsistent with section status (${doneCount}/${sections.length} done = ${actualPct}%)`);
      } else {
        ok.push(`completion coherent: claimed ${claimed}%, actual ${actualPct}%`);
      }
    }

    // 4. High-priority unresolved gaps
    const critical = (state.gaps || []).filter(g => ["high", "critical"].includes((g.priority || "").toLowerCase()));
    if (critical.length) {
      issues.push(`${critical.length} high-priority gap(s) open:`);
      critical.forEach(g => issues.push(`  - ${g.description}`));
    } else if ((state.gaps || []).length) {
      ok.push(`no critical gaps (${state.gaps.length} low/medium-priority noted)`);
    }

    // 5. Schema version
    if (!state.schema_version) issues.push("state missing schema_version (old format, re-save with set/update to upgrade)");

    const lines = [`## Paper Check: ${state.title || paperId}\n`];
    lines.push(`**Issues: ${issues.length}** | OK: ${ok.length}\n`);
    if (issues.length) {
      lines.push(`### Issues`);
      issues.forEach(i => lines.push(`- [!] ${i}`));
      lines.push("");
    }
    if (ok.length) {
      lines.push(`### OK`);
      ok.forEach(o => lines.push(`- [v] ${o}`));
      lines.push("");
    }
    if (!issues.length) lines.push(`All checks passed. Paper state is consistent.`);

    return { content: [{ type: "text", text: lines.join("\n") }] };
  }

  // ── Promote Data ───────────────────────────────────────────────
  if (name === "cowork_promote_data") {
    const expPath = args.experiment_path;
    const fromDir = join(expPath, args.from_tier);
    const toDir = join(expPath, args.to_tier);
    const files = args.files || [];

    if (!existsSync(fromDir)) {
      return { content: [{ type: "text", text: `Source tier not found: ${fromDir}` }] };
    }

    if (args.from_tier === args.to_tier) {
      return { content: [{ type: "text", text: "Source and destination tiers must be different." }] };
    }
    if (args.from_tier === "paper" || args.to_tier === "raw") {
      return { content: [{ type: "text", text: "Can only promote forward: raw→ppt, raw→paper, ppt→paper" }] };
    }

    mkdirSync(toDir, { recursive: true });

    const promoted = [];
    const skipped = [];

    for (const file of files) {
      const src = join(fromDir, file);
      const dest = join(toDir, file);
      if (!existsSync(src)) {
        skipped.push(`${file} (not found in ${args.from_tier}/)`);
        continue;
      }
      try {
        writeFileSync(dest, readFileSync(src));
        promoted.push(file);
      } catch (e) {
        skipped.push(`${file} (${e.message})`);
      }
    }

    const lines = [];
    lines.push(`## ${args.from_tier} → ${args.to_tier}`);
    lines.push(`Experiment: ${basename(expPath)}\n`);
    if (promoted.length) {
      lines.push(`Promoted (${promoted.length}):`);
      promoted.forEach(f => lines.push(`  + ${f}`));
    }
    if (skipped.length) {
      lines.push(`\nSkipped (${skipped.length}):`);
      skipped.forEach(f => lines.push(`  - ${f}`));
    }
    if (!promoted.length && !skipped.length) {
      lines.push("No files specified.");
    }

    return { content: [{ type: "text", text: lines.join("\n") }] };
  }

  return { content: [{ type: "text", text: `Unknown tool: ${name}` }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
