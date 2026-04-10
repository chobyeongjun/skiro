import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { execSync, execFileSync } from "child_process";
import { existsSync, readFileSync, writeFileSync, appendFileSync, mkdirSync, readdirSync, statSync } from "fs";
import { join, relative, dirname, extname, basename } from "path";
import { homedir } from "os";

// Fix Bug 4: canonical install path
const SKIRO_BIN = process.env.SKIRO_BIN || join(homedir(), "skiro", "bin");
const LEARNINGS  = join(SKIRO_BIN, "skiro-learnings");
const COMPLEXITY = join(SKIRO_BIN, "skiro-complexity");

// Fix Bug 3: 글로벌 learnings — 프로젝트 변경과 무관하게 일관된 경로
const GLOBAL_SKIRO = join(homedir(), ".skiro");
mkdirSync(GLOBAL_SKIRO, { recursive: true });
const ARTIFACTS_FILE = join(GLOBAL_SKIRO, "artifacts.jsonl");

function getLearningsFile() {
  // 환경변수로 오버라이드 가능 (per-project 운용 원할 때)
  return process.env.SKIRO_LEARNINGS || join(GLOBAL_SKIRO, "learnings.jsonl");
}

// Safe execution: avoids shell injection by passing args as array
function runSafe(file, args) {
  try {
    return execFileSync(file, args, {
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

// ── Codebase Map: 의존성 그래프 생성 ──────────────────────────
function scanSourceFiles(rootDir, exts = [".py", ".c", ".cpp", ".h", ".hpp", ".js", ".ts", ".lua", ".scone", ".osim", ".xml"]) {
  const files = [];
  const maxDepth = 6;
  function walk(dir, depth) {
    if (depth > maxDepth) return;
    let entries;
    try { entries = readdirSync(dir); } catch { return; }
    for (const e of entries) {
      if (e.startsWith(".") || e === "node_modules" || e === "__pycache__" || e === "build" || e === "dist" || e === ".git") continue;
      const full = join(dir, e);
      try {
        const st = statSync(full);
        if (st.isDirectory()) walk(full, depth + 1);
        else if (st.isFile() && exts.includes(extname(e).toLowerCase()) && st.size < (extname(e).match(/\.(osim|xml)$/i) ? 2000000 : 500000)) {
          files.push(full);
        }
      } catch {}
    }
  }
  walk(rootDir, 0);
  return files;
}

function parseImports(filePath) {
  const ext = extname(filePath).toLowerCase();
  let content;
  try { content = readFileSync(filePath, "utf8"); } catch { return []; }
  const imports = [];

  if (ext === ".py") {
    // from X import Y  /  import X
    for (const m of content.matchAll(/^\s*from\s+([\w.]+)\s+import/gm)) imports.push(m[1]);
    for (const m of content.matchAll(/^\s*import\s+([\w.]+)/gm)) imports.push(m[1]);
    // String-based file loading: open("file"), load("file"), read_model("file"), SconeModel("file"), etc.
    for (const m of content.matchAll(/(?:open|load|load_model|read_model|SconeModel|OsimModel|parse|fromfile|loadtxt|read_csv|pd\.read_|np\.load)\s*\(\s*['"]([^'"]+\.\w{1,5})['"]/gm)) {
      imports.push(m[1]);
    }
    // Path variables: path = "file.osim", model_file = "something.scone"
    for (const m of content.matchAll(/(?:path|file|model|config|scene)\w*\s*=\s*['"]([^'"]+\.(?:osim|scone|lua|xml|yaml|yml|json|csv|sto|mot))['"]/gm)) {
      imports.push(m[1]);
    }
  } else if ([".c", ".cpp", ".h", ".hpp"].includes(ext)) {
    // #include "X"  /  #include <X>
    for (const m of content.matchAll(/^\s*#include\s*[<"]([\w./\\-]+)[>"]/gm)) imports.push(m[1]);
  } else if ([".js", ".ts"].includes(ext)) {
    // import X from "Y"  /  require("Y")  /  import("Y")
    for (const m of content.matchAll(/(?:from|require|import)\s*\(\s*['"]([^'"]+)['"]\s*\)|from\s+['"]([^'"]+)['"]/gm)) {
      imports.push(m[1] || m[2]);
    }
  } else if (ext === ".scone") {
    // SCONE DSL: model_file, controller, state_init_file, include, file references
    for (const m of content.matchAll(/(?:model_file|file|state_init_file|include|controller_file|objective_file|init_file|script_file)\s*=\s*['"]?([^\s'";\}]+\.[\w]+)/gm)) {
      imports.push(m[1]);
    }
    // SCONE uses Type { ... } blocks that reference other .scone components
    for (const m of content.matchAll(/(?:Controller|Measure|Objective|Model|Optimizer)\s*\{\s*type\s*=\s*(\w+)/gm)) {
      imports.push(m[1]);
    }
    // Source references: source = "muscle_name" patterns (tracks model coupling)
    for (const m of content.matchAll(/source\s*=\s*['"]?([^\s'";\}]+\.(?:osim|lua|scone|xml))/gm)) {
      imports.push(m[1]);
    }
  } else if (ext === ".osim" || ext === ".xml") {
    // OpenSim XML: file references in geometry, model components
    for (const m of content.matchAll(/<(?:geometry_file|model_file|marker_file|force_file|states_file|coordinates_file|mesh_file|attached_geometry)[^>]*>\s*([^<\s]+\.\w+)/gm)) {
      imports.push(m[1]);
    }
    // Generic file attributes: file="something.vtp", filename="data.sto"
    for (const m of content.matchAll(/(?:file|filename|filepath|source)\s*=\s*"([^"]+\.\w{1,5})"/gm)) {
      imports.push(m[1]);
    }
    // <include> or <defaults_file>
    for (const m of content.matchAll(/<(?:include|defaults_file)[^>]*>\s*([^<\s]+)/gm)) {
      imports.push(m[1]);
    }
  } else if (ext === ".lua") {
    // Lua: require("X"), dofile("X"), loadfile("X")
    for (const m of content.matchAll(/(?:require|dofile|loadfile)\s*\(\s*['"]([^'"]+)['"]\s*\)/gm)) {
      imports.push(m[1]);
    }
    // SCONE Lua controllers: scone.load_model, scone.body, scone.muscle references
    for (const m of content.matchAll(/scone\.\w+\s*\(\s*['"]([^'"]+)['"]/gm)) {
      imports.push(m[1]);
    }
    // File path strings: similar to Python
    for (const m of content.matchAll(/(?:path|file|model)\w*\s*=\s*['"]([^'"]+\.(?:osim|scone|xml|csv|sto))['"]/gm)) {
      imports.push(m[1]);
    }
  }
  return imports;
}

function buildDependencyGraph(rootDir) {
  const files = scanSourceFiles(rootDir);
  const relFiles = files.map(f => relative(rootDir, f));
  const graph = {};  // file -> { imports: [], imported_by: [], lines: 0 }

  // Init all files
  for (const f of relFiles) {
    let lines = 0;
    try { lines = readFileSync(join(rootDir, f), "utf8").split("\n").length; } catch {}
    graph[f] = { imports: [], imported_by: [], lines, impact: 0 };
  }

  // Parse imports and resolve to local files
  const fileBasenames = {};
  for (const f of relFiles) {
    const b = basename(f);
    if (!fileBasenames[b]) fileBasenames[b] = [];
    fileBasenames[b].push(f);
    // Also index without extension
    const noExt = b.replace(extname(b), "");
    if (!fileBasenames[noExt]) fileBasenames[noExt] = [];
    fileBasenames[noExt].push(f);
    // Index by relative path segments (for "subdir/file.osim" style refs)
    const segments = f.split("/");
    for (let i = 1; i < segments.length; i++) {
      const partial = segments.slice(i).join("/");
      if (!fileBasenames[partial]) fileBasenames[partial] = [];
      fileBasenames[partial].push(f);
    }
  }

  for (const f of relFiles) {
    const rawImports = parseImports(join(rootDir, f));
    for (const imp of rawImports) {
      const cleanImp = imp.replace(/\\/g, "/");
      const parts = cleanImp.split("/");
      const lastPart = parts[parts.length - 1];
      const dotParts = imp.split(".");
      const lastDot = dotParts[dotParts.length - 1];

      // 1. Try relative path resolution (for "../models/arm.osim" style refs)
      let relResolved = null;
      if (cleanImp.startsWith("./") || cleanImp.startsWith("../") || cleanImp.includes("/")) {
        const resolved = relative(rootDir, join(rootDir, dirname(f), cleanImp));
        if (graph[resolved]) relResolved = resolved;
      }

      // 2. Match by basename, module name, partial path, or resolved path
      const candidates = [
        ...(relResolved ? [relResolved] : []),
        ...(fileBasenames[lastPart] || []),
        ...(fileBasenames[lastDot] || []),
        ...(fileBasenames[imp] || []),
        ...(fileBasenames[cleanImp] || [])
      ];

      for (const candidate of [...new Set(candidates)]) {
        if (candidate !== f) {
          if (!graph[f].imports.includes(candidate)) graph[f].imports.push(candidate);
          if (!graph[candidate].imported_by.includes(f)) graph[candidate].imported_by.push(f);
        }
      }
    }
  }

  // Compute impact scores
  for (const f of relFiles) {
    graph[f].impact = graph[f].imported_by.length;
  }

  // Identify modules (directories as module boundaries)
  const modules = {};
  for (const f of relFiles) {
    const dir = dirname(f) === "." ? "(root)" : dirname(f).split("/")[0];
    if (!modules[dir]) modules[dir] = [];
    modules[dir].push(f);
  }

  // Hub files (top 5 most depended-on)
  const hubFiles = relFiles
    .filter(f => graph[f].impact > 0)
    .sort((a, b) => graph[b].impact - graph[a].impact)
    .slice(0, 10);

  // Large files (>500 lines)
  const largeFiles = relFiles
    .filter(f => graph[f].lines > 500)
    .sort((a, b) => graph[b].lines - graph[a].lines);

  // Risk files (large + high impact)
  const riskFiles = relFiles
    .filter(f => graph[f].lines > 300 && graph[f].impact >= 2)
    .sort((a, b) => (graph[b].impact * graph[b].lines) - (graph[a].impact * graph[a].lines))
    .slice(0, 10);

  return { graph, modules, hubFiles, largeFiles, riskFiles, totalFiles: relFiles.length };
}

const server = new Server(
  { name: "skiro", version: "3.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "skiro_record_problem",
      description: `Call when user reports a persistent bug or unexpected behavior they want tracked. Stored globally (~/.skiro/learnings.jsonl).`,
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
      description: `Call when a previously recorded problem is resolved. Links to most recent unsolved. 3+ occurrences → CHECKLIST.`,
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
      description: `Analyze code complexity. Hook cache checked first. Returns tier + safety phase files.`,
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
      description: `List recent problem-solution pairs. Call when user asks about past issues or before domain-specific work.`,
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
      name: "skiro_search_learnings",
      description: `Search past learnings by keyword. Call to check if similar issues were seen before.`,
      inputSchema: {
        type: "object",
        properties: {
          keyword: { type: "string", description: "Search keyword (English or Korean)" }
        },
        required: ["keyword"]
      }
    },
    {
      name: "skiro_map_codebase",
      description: `Analyze codebase dependency graph. Call when [skiro/arch] hint appears, or when user asks about code structure. Saves .skiro/architecture.json.`,
      inputSchema: {
        type: "object",
        properties: {
          path:  { type: "string", description: "Project root path (default: cwd)" },
          file:  { type: "string", description: "If set, show only this file's dependencies and dependents (blast radius mode)" },
          depth: { type: "string", enum: ["summary","detail","full"], description: "Output detail level (default summary)" }
        }
      }
    },
    {
      name: "skiro_save_artifact",
      description: `ALWAYS call after writing/creating/moving any file. Registers path + description for later retrieval. User expects every saved file to be findable.`,
      inputSchema: {
        type: "object",
        properties: {
          path:        { type: "string", description: "Absolute path to the saved file" },
          description: { type: "string", description: "One-line: what this file contains" },
          category:    { type: "string", enum: ["figure","data","config","log","analysis","model","document","other"], description: "File category" },
          tags:        { type: "array", items: { type: "string" }, description: "Search tags (e.g. ['emg','walking','subject3'])" }
        },
        required: ["path", "description", "category"]
      }
    },
    {
      name: "skiro_find_artifact",
      description: `Find previously saved files. Call when user asks about any past file, data, figure, or output. Searches path, description, and tags.`,
      inputSchema: {
        type: "object",
        properties: {
          query:    { type: "string", description: "Search keyword (matches path, description, tags)" },
          category: { type: "string", enum: ["figure","data","config","log","analysis","model","document","other"], description: "Filter by category" },
          last:     { type: "number", description: "Return last N entries (default 10)" }
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
    },
    {
      name: "skiro_archive_experiment",
      description: `Archive experiment data to ~/research/experiments/{name}/raw/. Call when experiment is done — moves or copies raw data files into structured research directory with meta.json.`,
      inputSchema: {
        type: "object",
        properties: {
          name:        { type: "string", description: "Experiment name (e.g. '2026-04-10-walking-test')" },
          source_dir:  { type: "string", description: "Directory containing raw experiment data to archive" },
          description: { type: "string", description: "One-line experiment description" },
          status:      { type: "string", enum: ["done","partial","failed"], description: "Experiment status (default: done)" },
          research_root: { type: "string", description: "Research root directory (default: ~/research)" }
        },
        required: ["name", "source_dir", "description"]
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args } = req.params;

  if (name === "skiro_record_problem") {
    const ctx = args.context || new Date().toISOString().slice(0, 10);
    runSafe(LEARNINGS, ["add", "--problem", args.problem, "--category", args.category, "--severity", args.severity, "--context", ctx]);
    return { content: [{ type: "text", text: `[?] Recorded: ${args.problem.slice(0, 60)}` }] };
  }

  if (name === "skiro_record_solution") {
    const solveArgs = ["solve", "--solution", args.solution];
    if (args.keyword) solveArgs.push("--keyword", args.keyword);
    runSafe(LEARNINGS, solveArgs);

    // Fix: promote --auto → CHECKLIST.md 자동 업데이트
    let checklistArg = "";
    try {
      const gitRoot = execSync("git rev-parse --show-toplevel 2>/dev/null", {
        encoding: "utf8", cwd: process.cwd()
      }).trim();
      const cl = join(gitRoot, "CHECKLIST.md");
      if (existsSync(cl)) checklistArg = cl;
    } catch {}

    const promoteEnv = checklistArg
      ? { ...process.env, SKIRO_LEARNINGS: getLearningsFile(), SKIRO_CHECKLIST: checklistArg }
      : { ...process.env, SKIRO_LEARNINGS: getLearningsFile() };

    let promoteResult = "";
    try {
      promoteResult = execFileSync(LEARNINGS, ["promote", "3", "--auto"], {
        encoding: "utf8", env: promoteEnv
      }).trim();
    } catch (e) {
      promoteResult = e.stdout?.trim() || "";
    }

    let msg = `[✓] Solution linked: ${args.solution.slice(0, 60)}`;
    if (promoteResult.includes("PROMOTE") || promoteResult.includes("추가됨")) {
      msg += `\n[CHECKLIST] ${promoteResult.split("\n").find(l => l.includes("[+]") || l.includes("추가됨")) || "updated"}`;
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
    const out = runSafe(COMPLEXITY, [absPath, "--json"]);
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
    const listArgs = ["list", "--last", String(args.last || 5)];
    if (args.category) listArgs.push("--category", args.category);
    if (args.status) listArgs.push("--status", args.status);
    const out = runSafe(LEARNINGS, listArgs);
    return { content: [{ type: "text", text: out }] };
  }

  if (name === "skiro_search_learnings") {
    const out = runSafe(LEARNINGS, ["search", args.keyword]);
    return { content: [{ type: "text", text: out }] };
  }

  if (name === "skiro_map_codebase") {
    const rootDir = args.path || process.cwd();
    const depth = args.depth || "summary";
    const targetFile = args.file || null;

    // Cache: reuse .skiro/architecture.json if < 1h old
    const archPath = join(rootDir, ".skiro", "architecture.json");
    let graph, modules, hubFiles, largeFiles, riskFiles, totalFiles;
    let cached = false;
    if (existsSync(archPath)) {
      try {
        const archStat = statSync(archPath);
        const ageH = (Date.now() - archStat.mtimeMs) / 3600000;
        if (ageH < 1) {
          const arch = JSON.parse(readFileSync(archPath, "utf8"));
          graph = arch.graph; modules = arch.modules; hubFiles = arch.hubFiles;
          largeFiles = arch.largeFiles; riskFiles = arch.riskFiles; totalFiles = arch.totalFiles;
          cached = true;
        }
      } catch {}
    }
    if (!cached) {
      ({ graph, modules, hubFiles, largeFiles, riskFiles, totalFiles } = buildDependencyGraph(rootDir));
    }
    const sections = [];

    // Blast radius mode: single file analysis
    if (targetFile) {
      const rel = targetFile.startsWith("/") ? relative(rootDir, targetFile) : targetFile;
      const info = graph[rel];
      if (!info) {
        return { content: [{ type: "text", text: `파일 없음: ${rel}\n\n사용 가능한 파일:\n${Object.keys(graph).slice(0, 20).join("\n")}` }] };
      }
      sections.push(`# Blast Radius: ${rel}`);
      sections.push(`- 크기: ${info.lines}줄`);
      sections.push(`- 의존하는 파일 (imports): ${info.imports.length}개`);
      sections.push(`- 이 파일에 의존하는 파일 (imported_by): ${info.imported_by.length}개`);
      sections.push(`- **영향도: ${info.impact}** ${info.impact >= 3 ? "⚠️ HIGH IMPACT" : ""}\n`);

      if (info.imports.length) {
        sections.push(`## 이 파일이 사용하는 파일 (수정 시 확인 필요)`);
        info.imports.forEach(f => sections.push(`- ${f} (${graph[f]?.lines || "?"}줄)`));
        sections.push("");
      }
      if (info.imported_by.length) {
        sections.push(`## 이 파일을 사용하는 파일 (수정 시 영향받음 ⚠️)`);
        info.imported_by.forEach(f => sections.push(`- ${f} (${graph[f]?.lines || "?"}줄)`));
        sections.push("");
      }

      // 2-depth dependents (indirect impact)
      const indirect = new Set();
      info.imported_by.forEach(f => {
        (graph[f]?.imported_by || []).forEach(ff => {
          if (ff !== rel && !info.imported_by.includes(ff)) indirect.add(ff);
        });
      });
      if (indirect.size) {
        sections.push(`## 간접 영향 (2단계)`);
        [...indirect].forEach(f => sections.push(`- ${f}`));
        sections.push("");
      }

      sections.push(`## 안전한 수정 전략`);
      if (info.impact >= 3) {
        sections.push(`1. 이 파일의 **공개 인터페이스**(함수 시그니처, 클래스 API)를 먼저 파악`);
        sections.push(`2. 인터페이스 변경 시 imported_by ${info.imported_by.length}개 파일 모두 업데이트`);
        sections.push(`3. 내부 구현만 바꿀 경우 → 인터페이스 유지하면 안전`);
      } else {
        sections.push(`1. 영향도 낮음 — 직접 수정 가능`);
        if (info.imported_by.length) sections.push(`2. 수정 후 ${info.imported_by.join(", ")} 테스트`);
      }

      return { content: [{ type: "text", text: sections.join("\n") }] };
    }

    // Full codebase map
    sections.push(`# Codebase Map: ${basename(rootDir)}`);
    sections.push(`총 소스 파일: ${totalFiles}개\n`);

    // Hub files
    if (hubFiles.length) {
      sections.push(`## 🔗 Hub Files (가장 많이 의존되는 파일 — 수정 주의)`);
      sections.push(`| 파일 | 크기 | 의존하는 파일 수 | 영향도 |`);
      sections.push(`|------|------|----------------|--------|`);
      hubFiles.forEach(f => {
        const d = graph[f];
        sections.push(`| ${f} | ${d.lines}줄 | ${d.imported_by.length}개 | ${d.impact >= 3 ? "HIGH ⚠️" : d.impact >= 1 ? "MED" : "LOW"} |`);
      });
      sections.push("");
    }

    // Risk files
    if (riskFiles.length) {
      sections.push(`## ⚠️ Risk Files (크고 + 의존 많음 — 가장 위험한 파일)`);
      riskFiles.forEach(f => {
        const d = graph[f];
        sections.push(`- **${f}** — ${d.lines}줄, ${d.imported_by.length}개 파일이 의존`);
      });
      sections.push("");
    }

    // Large files
    if (largeFiles.length) {
      sections.push(`## 📄 Large Files (>500줄 — Claude context 주의)`);
      largeFiles.slice(0, 10).forEach(f => {
        sections.push(`- ${f}: ${graph[f].lines}줄 ${graph[f].lines > 1000 ? "⚠️ 부분 로드 필요" : ""}`);
      });
      sections.push("");
    }

    // Modules
    sections.push(`## 📦 모듈 구조`);
    for (const [mod, files] of Object.entries(modules).sort((a, b) => b[1].length - a[1].length)) {
      sections.push(`### ${mod}/ (${files.length}개)`);
      if (depth === "detail" || depth === "full") {
        files.slice(0, 20).forEach(f => {
          const d = graph[f];
          sections.push(`  - ${basename(f)} (${d.lines}줄, →${d.imports.length} ←${d.imported_by.length})`);
        });
        if (files.length > 20) sections.push(`  - ... 외 ${files.length - 20}개`);
      }
    }
    sections.push("");

    // Full dependency detail
    if (depth === "full") {
      sections.push(`## 전체 의존성 상세`);
      for (const [f, d] of Object.entries(graph).sort((a, b) => b[1].impact - a[1].impact)) {
        if (d.imports.length || d.imported_by.length) {
          sections.push(`### ${f} (${d.lines}줄)`);
          if (d.imports.length) sections.push(`  imports: ${d.imports.join(", ")}`);
          if (d.imported_by.length) sections.push(`  used by: ${d.imported_by.join(", ")}`);
        }
      }
    }

    // 작업 전략 제안
    sections.push(`## 작업 전략 제안`);
    if (riskFiles.length) {
      sections.push(`1. **Risk Files 먼저 구조 파악**: ${riskFiles.slice(0, 3).join(", ")} — 이 파일들의 public API를 이해한 후 작업 시작`);
    }
    const leafFiles = Object.entries(graph).filter(([f, d]) => d.imported_by.length === 0 && d.imports.length > 0);
    if (leafFiles.length) {
      sections.push(`2. **Leaf Files부터 수정**: ${leafFiles.slice(0, 5).map(([f]) => f).join(", ")} — 다른 파일에 영향 없음, 안전하게 수정 가능`);
    }
    sections.push(`3. **특정 파일 수정 전**: \`skiro_map_codebase(file="파일명")\` 으로 blast radius 확인`);

    // Save architecture.json (only on fresh scan)
    if (!cached) {
      const archDir = join(rootDir, ".skiro");
      mkdirSync(archDir, { recursive: true });
      const archData = { generated: new Date().toISOString(), root: rootDir, graph, modules, hubFiles, largeFiles, riskFiles, totalFiles };
      writeFileSync(join(archDir, "architecture.json"), JSON.stringify(archData, null, 2));
      sections.push(`\n_architecture.json 저장됨: .skiro/architecture.json_`);
    }

    return { content: [{ type: "text", text: sections.join("\n") }] };
  }

  if (name === "skiro_save_artifact") {
    const entry = {
      date: new Date().toISOString().slice(0, 10),
      time: new Date().toISOString().slice(11, 19),
      path: args.path,
      name: basename(args.path),
      description: args.description,
      category: args.category,
      tags: args.tags || [],
      project: basename(process.cwd())
    };
    try {
      appendFileSync(ARTIFACTS_FILE, JSON.stringify(entry) + "\n");
      return { content: [{ type: "text", text: `[artifact] Registered: ${entry.name} (${entry.category}) — ${entry.description.slice(0, 50)}` }] };
    } catch (e) {
      return { content: [{ type: "text", text: `Failed to register: ${e.message}` }] };
    }
  }

  if (name === "skiro_find_artifact") {
    let lines;
    try {
      lines = readFileSync(ARTIFACTS_FILE, "utf8").trim().split("\n").filter(Boolean);
    } catch {
      return { content: [{ type: "text", text: "No artifacts registered yet." }] };
    }
    let entries = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);

    if (args.category) entries = entries.filter(e => e.category === args.category);
    if (args.query) {
      const q = args.query.toLowerCase();
      entries = entries.filter(e =>
        (e.path || "").toLowerCase().includes(q) ||
        (e.description || "").toLowerCase().includes(q) ||
        (e.name || "").toLowerCase().includes(q) ||
        (e.tags || []).some(t => t.toLowerCase().includes(q)) ||
        (e.project || "").toLowerCase().includes(q)
      );
    }

    const last = args.last || 10;
    entries = entries.slice(-last);

    if (!entries.length) {
      return { content: [{ type: "text", text: `No artifacts found${args.query ? ` for "${args.query}"` : ""}.` }] };
    }

    const out = entries.map(e =>
      `[${e.date}] ${e.category} | ${e.name}\n  ${e.description}\n  → ${e.path}${e.tags.length ? `\n  tags: ${e.tags.join(", ")}` : ""}`
    ).join("\n\n");

    return { content: [{ type: "text", text: `Found ${entries.length} artifact(s):\n\n${out}` }] };
  }

  if (name === "skiro_safety_gate_create") {
    // Fix 1: CRITICAL unsolved 있으면 gate 생성 거부
    const criticalCheck = runSafe(LEARNINGS, ["list", "--status", "unsolved"]);
    // Count lines that are both unsolved [?] AND contain CRITICAL
    const criticalLines = criticalCheck.split("\n").filter(l => l.includes("[?]") && /CRITICAL/i.test(l));
    const criticalCount = criticalLines.length;
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

  // ── Archive Experiment ──────────────────────────────────────────
  if (name === "skiro_archive_experiment") {
    const researchRoot = args.research_root || join(homedir(), "research");
    const expDir = join(researchRoot, "experiments", args.name);
    const rawDir = join(expDir, "raw");
    const sourceDir = args.source_dir;

    if (!existsSync(sourceDir)) {
      return { content: [{ type: "text", text: `Source directory not found: ${sourceDir}` }] };
    }

    // Create structure
    mkdirSync(rawDir, { recursive: true });

    // Copy files from source to raw/
    const copied = [];
    try {
      const entries = readdirSync(sourceDir);
      for (const entry of entries) {
        const srcPath = join(sourceDir, entry);
        try {
          const stat = statSync(srcPath);
          if (stat.isFile()) {
            const dest = join(rawDir, entry);
            writeFileSync(dest, readFileSync(srcPath));
            copied.push(entry);
          }
        } catch {}
      }
    } catch (e) {
      return { content: [{ type: "text", text: `Error reading source: ${e.message}` }] };
    }

    // Create meta.json
    const meta = {
      date: args.name.match(/^\d{4}-\d{2}-\d{2}/)?.[0] || new Date().toISOString().slice(0, 10),
      description: args.description,
      status: args.status || "done",
      source: sourceDir,
      archived: new Date().toISOString()
    };
    writeFileSync(join(expDir, "meta.json"), JSON.stringify(meta, null, 2), "utf8");

    // Register as artifact
    const entry = {
      date: meta.date,
      path: expDir,
      name: args.name,
      description: `[experiment] ${args.description}`,
      category: "data",
      tags: ["experiment", "raw", args.name],
      project: basename(sourceDir)
    };
    appendFileSync(ARTIFACTS_FILE, JSON.stringify(entry) + "\n");

    return { content: [{ type: "text", text: `Archived to ${expDir}\n  raw/ files: ${copied.length} (${copied.join(", ")})\n  meta.json created\n  artifact registered\n\nNext: ppt/ paper/ 승격은 COWORK에서 진행` }] };
  }

  return { content: [{ type: "text", text: `Unknown tool: ${name}` }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
