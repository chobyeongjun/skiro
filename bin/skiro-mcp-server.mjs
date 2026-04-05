import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { execSync, execFileSync } from "child_process";
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// Fix Bug 4: canonical install path
const SKIRO_BIN = process.env.SKIRO_BIN || join(homedir(), "skiro", "bin");
const LEARNINGS  = join(SKIRO_BIN, "skiro-learnings");
const COMPLEXITY = join(SKIRO_BIN, "skiro-complexity");

// Fix Bug 3: 글로벌 learnings — 프로젝트 변경과 무관하게 일관된 경로
const GLOBAL_SKIRO = join(homedir(), ".skiro");
mkdirSync(GLOBAL_SKIRO, { recursive: true });

function getLearningsFile() {
  // 환경변수로 오버라이드 가능 (per-project 운용 원할 때)
  return process.env.SKIRO_LEARNINGS || join(GLOBAL_SKIRO, "learnings.jsonl");
}

function run(cmd) {
  try {
    return execSync(cmd, {
      encoding: "utf8",
      env: { ...process.env, SKIRO_LEARNINGS: getLearningsFile() }
    }).trim();
  } catch (e) {
    return e.stdout?.trim() || e.message;
  }
}

// hook 캐시는 프로젝트별 (process.cwd() 고정이지만 캐시 목적이라 OK)
function getLastComplexity(filePath) {
  // filePath 기준 상위로 .skiro 탐색
  const parts = filePath.split("/");
  for (let i = parts.length; i > 0; i--) {
    const candidate = join(...parts.slice(0, i), ".skiro", "last-complexity.json");
    if (existsSync(candidate)) {
      try {
        const d = JSON.parse(readFileSync(candidate, "utf8"));
        if (d.file === filePath) return d;
      } catch {}
    }
  }
  return null;
}

const server = new Server(
  { name: "skiro", version: "2.1.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "skiro_record_problem",
      description: `Auto-call when ANY problem, bug, failure, or unexpected behavior appears in conversation.

TRIGGER on these signals (Korean AND English):
- Korean: 안됐어, 실패했어, 에러, 버그, 이상하게, 안 되더라, 동작 안 해, 문제 생겼어, 안됨, 작동 안 함
- English: failed, error, bug, broken, not working, crashed, unexpected, issue, problem, wrong output

ALWAYS call this tool when user describes something not working as expected.
Records as unsolved until skiro_record_solution is called.
Learnings are stored GLOBALLY (~/.skiro/learnings.jsonl) and apply across all projects.`,
      inputSchema: {
        type: "object",
        properties: {
          problem:  { type: "string", description: "One-line problem summary" },
          category: { type: "string", enum: ["safety","control","hardware","software","protocol","process","experiment"] },
          severity: { type: "string", enum: ["INFO","WARNING","CRITICAL"], description: "CRITICAL=motor/power/safety, WARNING=logic error, INFO=minor" },
          context:  { type: "string", description: "date + task name (auto-fill if not provided)" }
        },
        required: ["problem","category","severity"]
      }
    },
    {
      name: "skiro_record_solution",
      description: `Auto-call when a solution, fix, or workaround is found in conversation.

TRIGGER on these signals (Korean AND English):
- Korean: 됐어, 해결됐어, 이렇게 하니까, 알고 보니, 이렇게 하면 돼, 됩니다, 해결
- English: fixed, solved, worked, the fix is, turns out, solution is, it works now

ALWAYS call after a problem is resolved. Links solution to most recent unsolved problem.
If same problem seen 3+ times → suggests CHECKLIST addition.`,
      inputSchema: {
        type: "object",
        properties: {
          solution: { type: "string", description: "One-line solution summary" },
          keyword:  { type: "string", description: "Keyword to find matching problem" }
        },
        required: ["solution"]
      }
    },
    {
      name: "skiro_analyze_complexity",
      description: `Auto-call when a firmware or code file is mentioned, opened, or about to be modified.

Checks hook cache first, falls back to fresh analysis.
Returns tier (fast/partial/full) and which safety phase files to Read.

ALWAYS call before safety analysis or code review of C/C++/Python firmware files.`,
      inputSchema: {
        type: "object",
        properties: {
          file_path: { type: "string", description: "Absolute or relative path to source file" }
        },
        required: ["file_path"]
      }
    },
    {
      name: "skiro_list_learnings",
      description: `Auto-call at session start and before any new task or experiment.
Returns recent problem-solution pairs to prevent repeating past mistakes.
Shows unsolved problems and CHECKLIST promotion candidates.`,
      inputSchema: {
        type: "object",
        properties: {
          last:     { type: "number", description: "Number of recent entries (default 5)" },
          category: { type: "string", description: "Filter by category" },
          status:   { type: "string", enum: ["solved","unsolved"], description: "Filter by status" }
        }
      }
    },
    {
      name: "skiro_safety_gate_create",
      description: `Call after completing safety analysis with ZERO critical issues.
Creates .skiro_safety_gate in current project directory — unlocks flash/hwtest.
DO NOT call if any CRITICAL issues remain.`,
      inputSchema: {
        type: "object",
        properties: {
          file_analyzed: { type: "string" },
          tier:          { type: "string", enum: ["fast","partial","full"] },
          score:         { type: "number" },
          warnings:      { type: "number" }
        },
        required: ["file_analyzed","tier","score"]
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;

  if (name === "skiro_record_problem") {
    const ctx = args.context || new Date().toISOString().slice(0, 10);
    run(`${LEARNINGS} add --problem "${args.problem}" --category ${args.category} --severity ${args.severity} --context "${ctx}"`);
    return { content: [{ type: "text", text: `[?] Recorded: ${args.problem.slice(0, 60)}` }] };
  }

  if (name === "skiro_record_solution") {
    const kw = args.keyword ? `--keyword "${args.keyword}"` : "";
    run(`${LEARNINGS} solve --solution "${args.solution}" ${kw}`);
    const promote = run(`${LEARNINGS} promote 3`);
    let msg = `[✓] Solution linked: ${args.solution.slice(0, 60)}`;
    if (promote.includes("PROMOTE")) {
      const item = promote.split("\n").find(l => l.includes("[ ]"));
      if (item) msg += `\n[CHECKLIST suggestion] ${item.trim()}`;
    }
    return { content: [{ type: "text", text: msg }] };
  }

  if (name === "skiro_analyze_complexity") {
    const absPath = args.file_path.startsWith("/")
      ? args.file_path
      : join(process.cwd(), args.file_path);

    // hook 캐시 확인
    const cached = getLastComplexity(absPath);
    if (cached) {
      return {
        content: [{
          type: "text",
          text: JSON.stringify({
            source: "hook-cache",
            score: cached.score, tier: cached.tier,
            modules_to_load: cached.modules.split(","),
            breakdown: cached.breakdown
          }, null, 2)
        }]
      };
    }

    if (!existsSync(absPath)) {
      return { content: [{ type: "text", text: `File not found: ${absPath}` }] };
    }
    const out = run(`${COMPLEXITY} "${absPath}" --json`);
    try {
      const d = JSON.parse(out);
      return {
        content: [{
          type: "text",
          text: JSON.stringify({
            source: "fresh",
            score: d.score, tier: d.tier,
            modules_to_load: d.modules.split(","),
            breakdown: d.breakdown
          }, null, 2)
        }]
      };
    } catch {
      return { content: [{ type: "text", text: out }] };
    }
  }

  if (name === "skiro_list_learnings") {
    const n      = args.last     || 5;
    const cat    = args.category ? `--category ${args.category}` : "";
    const status = args.status   ? `--status ${args.status}`     : "";
    const out = run(`${LEARNINGS} list --last ${n} ${cat} ${status}`);
    return { content: [{ type: "text", text: out }] };
  }

  if (name === "skiro_safety_gate_create") {
    // Fix 1: CRITICAL unsolved 있으면 gate 생성 거부
    const criticalCheck = run(`${LEARNINGS} list --status unsolved --severity CRITICAL`);
    const criticalCount = (criticalCheck.match(/\[\?\]/g) || []).length;
    if (criticalCount > 0) {
      return {
        content: [{
          type: "text",
          text: `[GATE REFUSED] ${criticalCount} unresolved CRITICAL issue(s) detected.\nResolve all CRITICAL issues before creating safety gate.\n\n${criticalCheck}`
        }]
      };
    }

    const gateFile = join(process.cwd(), ".skiro_safety_gate");
    const gateContent = [
      "SAFETY_GATE_PASSED",
      `timestamp: ${new Date().toISOString()}`,
      `file: ${args.file_analyzed}`,
      `tier: ${args.tier}`,
      `score: ${args.score}`,
      `warnings: ${args.warnings || 0}`,
      `analyst: skiro v2.1`
    ].join("\n");
    try {
      writeFileSync(gateFile, gateContent);
      return { content: [{ type: "text", text: `[GATE] .skiro_safety_gate created — flash/hwtest unlocked` }] };
    } catch (e) {
      return { content: [{ type: "text", text: `Failed to create gate: ${e.message}` }] };
    }
  }

  return { content: [{ type: "text", text: `Unknown tool: ${name}` }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
