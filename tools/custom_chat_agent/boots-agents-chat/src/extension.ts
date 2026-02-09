import * as vscode from "vscode";
import * as fs from "fs";
import * as path from "path";

type AgentInfo = {
  key: string;
  name: string;
  description: string;
  body: string;
  sourcePath: string;
  priority: number;
};

function getWorkspaceRoot(): string | null {
  const folders = vscode.workspace.workspaceFolders;
  if (!folders || folders.length === 0) return null;
  return folders[0].uri.fsPath;
}

function parseFrontmatter(content: string): { frontmatter: string; body: string } {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n([\s\S]*)$/);
  if (!match) {
    return { frontmatter: "", body: content };
  }
  return { frontmatter: match[1], body: match[2] };
}

function parseKey(frontmatter: string, key: string): string | null {
  const re = new RegExp(`^${key}:\\s*["']?(.+?)["']?\\s*$`, "mi");
  const m = frontmatter.match(re);
  return m ? m[1].trim() : null;
}

function cleanBody(body: string): string {
  let out = body;
  out = out.replace(/^\s*describt:\s*\|\s*\r?\n/i, "");
  out = out.replace(/^\s{2}/gm, "");
  return out.trim();
}

function stripNumericPrefix(name: string): string {
  return name.replace(/^\d+[-_ ]*/, "");
}

function slugifyName(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function titleizeFromSlug(name: string): string {
  const parts = name.split(/[-_ ]+/).filter(Boolean);
  return parts.map((p) => p.charAt(0).toUpperCase() + p.slice(1)).join(" ");
}

function detectNameFromContent(raw: string): string | null {
  const firstLine = raw.split(/\r?\n/).find((l) => l.trim().length > 0) || "";
  const m = firstLine.match(/you\s+are\s+the\s+(.+?)\s+agent\b/i);
  if (m) return m[1].trim();
  return null;
}

function readAgentsYml(filePath: string): string[] {
  if (!fs.existsSync(filePath)) return [];
  const raw = fs.readFileSync(filePath, "utf8");
  const lines = raw.split(/\r?\n/);
  const out: string[] = [];
  let inList = false;
  for (const line of lines) {
    const t = line.trim();
    if (!t || t.startsWith("#")) continue;
    if (t.startsWith("agents:")) {
      inList = true;
      continue;
    }
    if (inList) {
      const m = t.match(/^-\s*(.+)$/);
      if (m) out.push(m[1].trim().toLowerCase());
    }
  }
  return out;
}

function filePriority(fileName: string): number {
  const lower = fileName.toLowerCase();
  if (lower.endsWith(".agent.md")) return 3;
  if (lower.endsWith(".prompt.md")) return 2;
  if (/^\d+_/.test(lower)) return 2;
  return 1;
}

function loadAgents(agentsDir: string): { map: Map<string, AgentInfo>; order: string[] } {
  const map = new Map<string, AgentInfo>();
  if (!fs.existsSync(agentsDir)) return { map, order: [] };

  const files = fs.readdirSync(agentsDir).filter((f) => {
    const lower = f.toLowerCase();
    return lower.endsWith(".agent.md") || lower.endsWith(".prompt.md");
  });
  for (const file of files) {
    const fullPath = path.join(agentsDir, file);
    const raw = fs.readFileSync(fullPath, "utf8");
    const { frontmatter, body } = parseFrontmatter(raw);
    let name = parseKey(frontmatter, "name") || "";
    let description = parseKey(frontmatter, "description") || "";
    let bodyText = cleanBody(body);
    const isPromptFile = file.toLowerCase().endsWith(".prompt.md");

    if (!name) {
      const detected = detectNameFromContent(raw);
      if (!detected && !isPromptFile) {
        continue;
      }
      const base = stripNumericPrefix(path.basename(file).replace(/\.md$/i, "").replace(/\.prompt$/i, ""));
      name = detected || titleizeFromSlug(base);
      if (!bodyText) bodyText = raw.trim();
    }

    if (!name) continue;
    const key = slugifyName(name) || stripNumericPrefix(path.basename(file).replace(/\.md$/i, "").replace(/\.prompt$/i, "")).toLowerCase();
    const info: AgentInfo = {
      key,
      name: name.trim(),
      description: description.trim(),
      body: bodyText,
      sourcePath: fullPath,
      priority: filePriority(file),
    };

    const existing = map.get(key);
    if (!existing || info.priority >= existing.priority) {
      map.set(key, info);
    }
  }

  const orderFromYaml = readAgentsYml(path.join(agentsDir, "agents.yml"));
  const order: string[] = [];
  const seen = new Set<string>();

  for (const key of orderFromYaml) {
    if (map.has(key) && !seen.has(key)) {
      order.push(key);
      seen.add(key);
    }
  }

  const remaining = Array.from(map.keys()).filter((k) => !seen.has(k)).sort();
  for (const key of remaining) order.push(key);

  return { map, order };
}

function normalizeEndpoint(endpoint: string): string {
  const e = endpoint.trim();
  const lower = e.toLowerCase();
  if (!e) return e;
  if (lower.includes("/chat/completions")) return e;
  if (lower.endsWith("/v1") || lower.endsWith("/v1/")) {
    return e.replace(/\/+$/, "") + "/chat/completions";
  }
  if (lower.endsWith("/")) return e + "v1/chat/completions";
  return e + "/v1/chat/completions";
}

function parseAgentRequest(rawPrompt: string): { command?: "list"; agentName?: string; userPrompt: string } {
  const listCmd = /^\s*\/agents\b|^\s*\/agent\s+list\b/i;
  if (listCmd.test(rawPrompt)) {
    return { command: "list", userPrompt: "" };
  }

  const m = rawPrompt.match(/^\s*(?:\/agent\s+|@)([A-Za-z0-9_-]+)\b/);
  if (m) {
    const agentName = m[1];
    const userPrompt = rawPrompt.slice(m[0].length).trim();
    return { agentName, userPrompt };
  }

  return { userPrompt: rawPrompt.trim() };
}

function buildSystemPrompt(agent: AgentInfo, includeCopilot: boolean, repoRoot: string): string {
  const parts: string[] = [];
  parts.push("You are a helpful assistant.");
  parts.push(`Selected agent: ${agent.name}`);
  parts.push("Follow the agent instructions below exactly.");
  parts.push(agent.body);

  if (includeCopilot) {
    const copilotPath = path.join(repoRoot, ".github", "copilot-instructions.md");
    if (fs.existsSync(copilotPath)) {
      const copilotText = fs.readFileSync(copilotPath, "utf8").trim();
      if (copilotText) {
        parts.push("Additional project instructions:");
        parts.push(copilotText);
      }
    }
  }

  return parts.join("\n\n");
}

function formatAgentList(map: Map<string, AgentInfo>, order: string[]): string {
  if (order.length === 0) return "No agents found.";
  const lines: string[] = [];
  lines.push("Available agents:");
  for (const key of order) {
    const agent = map.get(key);
    if (!agent) continue;
    const desc = agent.description ? ` — ${agent.description}` : "";
    lines.push(`- ${agent.name} (id: ${agent.key})${desc}`);
  }
  lines.push("");
  lines.push("Usage:");
  lines.push("  /agent <name> your request");
  lines.push("  @<name> your request");
  return lines.join("\n");
}

export function activate(context: vscode.ExtensionContext) {
  const participantId = "bootsagents";

  const handler: vscode.ChatRequestHandler = async (request, ctx, stream, token) => {
    const cfg = vscode.workspace.getConfiguration();
    const endpoint = cfg.get<string>(`${participantId}.endpoint`) || "";
    const apiKey = cfg.get<string>(`${participantId}.apiKey`) || "";
    const model = cfg.get<string>(`${participantId}.model`) || "gpt-4o-mini";
    const agentsRoot = cfg.get<string>(`${participantId}.agentsRoot`) || "foundry-agents";
    const includeCopilot = cfg.get<boolean>(`${participantId}.includeCopilotInstructions`);

    const repoRoot = getWorkspaceRoot();
    if (!repoRoot) {
      stream.markdown("No workspace open. Open the repo and try again.");
      return;
    }

    if (!endpoint) {
      stream.markdown(`Missing endpoint. Set "${participantId}.endpoint" in Settings.`);
      return;
    }

    const agentsDir = path.isAbsolute(agentsRoot) ? agentsRoot : path.join(repoRoot, agentsRoot);
    const { map, order } = loadAgents(agentsDir);
    if (map.size === 0) {
      stream.markdown(`No agents found in: ${agentsDir}`);
      return;
    }

    const parsed = parseAgentRequest(request.prompt || "");
    if (parsed.command === "list") {
      stream.markdown(formatAgentList(map, order));
      return;
    }

    if (!parsed.agentName) {
      stream.markdown(formatAgentList(map, order));
      return;
    }

    const key = parsed.agentName.toLowerCase();
    const agent = map.get(key);
    if (!agent) {
      stream.markdown(`Agent "${parsed.agentName}" not found.\n\n` + formatAgentList(map, order));
      return;
    }

    if (!parsed.userPrompt) {
      stream.markdown(`Provide a prompt after "${parsed.agentName}".\n\n` + formatAgentList(map, order));
      return;
    }

    const systemPrompt = buildSystemPrompt(agent, includeCopilot !== false, repoRoot);
    const messages = [
      { role: "system", content: systemPrompt },
      { role: "user", content: parsed.userPrompt },
    ];

    const url = normalizeEndpoint(endpoint);

    try {
      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (apiKey) headers["Authorization"] = `Bearer ${apiKey}`;

      const res = await fetch(url, {
        method: "POST",
        headers,
        body: JSON.stringify({ model, messages, stream: false }),
        signal: token.isCancellationRequested ? undefined : undefined,
      });

      if (!res.ok) {
        const t = await res.text();
        stream.markdown(`HTTP ${res.status}\n\n${t}`);
        return;
      }

      const json: any = await res.json();
      const answer =
        json?.choices?.[0]?.message?.content ??
        json?.choices?.[0]?.text ??
        "(no content)";
      stream.markdown(answer);
    } catch (e: any) {
      stream.markdown(`Error: ${e?.message || String(e)}`);
    }
  };

  const participant = vscode.chat.createChatParticipant(participantId, handler);
  participant.iconPath = new vscode.ThemeIcon("sparkle");
  context.subscriptions.push(participant);
}

export function deactivate() {}
