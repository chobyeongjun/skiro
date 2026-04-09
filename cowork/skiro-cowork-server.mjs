#!/usr/bin/env node
// skiro-cowork MCP server v1.0
// For claude.ai (COWORK) — reads artifacts, learnings, git log from Code sessions
// Helps structure data for PPT, papers, and tech briefs

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "child_process";
import { existsSync, readFileSync, readdirSync, statSync } from "fs";
import { join, basename, extname } from "path";
import { homedir } from "os";

const GLOBAL_SKIRO = join(homedir(), ".skiro");
const ARTIFACTS_FILE = join(GLOBAL_SKIRO, "artifacts.jsonl");
const LEARNINGS_FILE = process.env.SKIRO_LEARNINGS || join(GLOBAL_SKIRO, "learnings.jsonl");

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

  return { content: [{ type: "text", text: `Unknown tool: ${name}` }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
