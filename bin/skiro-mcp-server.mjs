import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "child_process";
import { existsSync } from "fs";

const SKIRO_BIN = process.env.SKIRO_BIN || `${process.env.HOME}/Desktop/ARLAB/skiro/bin`;
const LEARNINGS = `${SKIRO_BIN}/skiro-learnings`;
const COMPLEXITY = `${SKIRO_BIN}/skiro-complexity`;
const LEARNINGS_FILE = process.env.SKIRO_LEARNINGS || `${process.cwd()}/.skiro/learnings.jsonl`;

function run(cmd) {
  try {
    return execSync(cmd, { encoding: "utf8", env: { ...process.env, SKIRO_LEARNINGS: LEARNINGS_FILE } }).trim();
  } catch (e) {
    return e.stdout?.trim() || e.message;
  }
}

const server = new Server({ name: "skiro", version: "1.0.0" }, { capabilities: { tools: {} } });

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "skiro_record_problem",
      description: "Auto-call when a problem, bug, failure, or unexpected behavior is detected in conversation. Triggers: 'failed', 'not working', 'error', 'bug', 'broken', 'weird behavior', '안됐어', '실패', '에러', '버그', '이상하게'. Records the problem as an unsolved learning entry.",
      inputSchema: {
        type: "object",
        properties: {
          problem: { type: "string", description: "One-line problem summary" },
          category: { type: "string", enum: ["safety","control","hardware","software","protocol","process","experiment"] },
          severity: { type: "string", enum: ["INFO","WARNING","CRITICAL"] },
          context: { type: "string", description: "date + task name" }
        },
        required: ["problem","category","severity"]
      }
    },
    {
      name: "skiro_record_solution",
      description: "Auto-call when a solution or fix is found in conversation. Triggers: 'it worked', 'fixed', 'solved', 'the fix is', 'turns out', '됐어', '해결됐어', '이렇게 하니까', '알고 보니'. Links solution to the most recent unsolved problem. If same problem repeated 3+ times, suggests adding to CHECKLIST.",
      inputSchema: {
        type: "object",
        properties: {
          solution: { type: "string", description: "One-line solution summary" },
          keyword: { type: "string", description: "keyword to find the matching problem" }
        },
        required: ["solution"]
      }
    },
    {
      name: "skiro_analyze_complexity",
      description: "Auto-call when a code file is mentioned or opened. Returns complexity score and which phase files to load for safety analysis.",
      inputSchema: {
        type: "object",
        properties: {
          file_path: { type: "string" }
        },
        required: ["file_path"]
      }
    },
    {
      name: "skiro_list_learnings",
      description: "Auto-call at session start or before starting a new task. Returns recent problem-solution pairs to avoid repeating past mistakes.",
      inputSchema: {
        type: "object",
        properties: {
          last: { type: "number", description: "number of recent entries (default 5)" },
          category: { type: "string" }
        }
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;

  if (name === "skiro_record_problem") {
    const ctx = args.context || new Date().toISOString().slice(0,10);
    run(`${LEARNINGS} add --problem "${args.problem}" --category ${args.category} --severity ${args.severity} --context "${ctx}"`);
    return { content: [{ type: "text", text: `[?] Recorded: ${args.problem.slice(0,60)}` }] };
  }

  if (name === "skiro_record_solution") {
    const kw = args.keyword ? `--keyword "${args.keyword}"` : "";
    run(`${LEARNINGS} solve --solution "${args.solution}" ${kw}`);
    const promote = run(`${LEARNINGS} promote 3`);
    let msg = `[✓] Solution linked: ${args.solution.slice(0,60)}`;
    if (promote.includes("PROMOTE")) {
      const item = promote.split("\n").find(l => l.includes("[ ]"));
      if (item) msg += `\n[CHECKLIST suggestion] ${item.trim()}`;
    }
    return { content: [{ type: "text", text: msg }] };
  }

  if (name === "skiro_analyze_complexity") {
    if (!existsSync(args.file_path)) return { content: [{ type: "text", text: `File not found: ${args.file_path}` }] };
    const out = run(`${COMPLEXITY} "${args.file_path}" --json`);
    try {
      const d = JSON.parse(out);
      return { content: [{ type: "text", text: JSON.stringify({ score: d.score, tier: d.tier, modules: d.modules.split(","), breakdown: d.breakdown }, null, 2) }] };
    } catch { return { content: [{ type: "text", text: out }] }; }
  }

  if (name === "skiro_list_learnings") {
    const n = args.last || 5;
    const cat = args.category ? `--category ${args.category}` : "";
    const out = run(`${LEARNINGS} list --last ${n} ${cat}`);
    return { content: [{ type: "text", text: out }] };
  }

  return { content: [{ type: "text", text: `Unknown tool: ${name}` }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
