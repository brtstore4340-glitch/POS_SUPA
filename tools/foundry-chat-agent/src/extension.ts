import * as fs from "fs";
import * as path from "path";
import * as vscode from "vscode";

type ChatReq = {
  model: string;
  messages: Array<{ role: "system" | "user" | "assistant"; content: string }>;
  stream?: boolean;
};

type AgentSpec = {
  id: string;
  name: string;
  promptFile: string;
};

const AGENTS: AgentSpec[] = [
  { id: "orchestrator", name: "Orchestrator", promptFile: "00-orchestrator.prompt.md" },
  { id: "planner", name: "Planner", promptFile: "01-planner.prompt.md" },
  { id: "supabase-architect", name: "Supabase Architect", promptFile: "02-supabase-architect.prompt.md" },
  { id: "app-coder", name: "App Coder", promptFile: "03-app-coder.prompt.md" },
  { id: "runner-executor", name: "Runner / Executor", promptFile: "04-runner-executor.prompt.md" },
  { id: "debugger", name: "Debugger", promptFile: "05-debugger.prompt.md" },
  { id: "reviewer-gatekeeper", name: "Reviewer / Gatekeeper", promptFile: "06-reviewer-gatekeeper.prompt.md" }
];

function readPromptFromWorkspace(promptFile: string): string {
  const ws = vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
  if (!ws) {
    return "Workspace not found. Open the repo root in VS Code.";
  }
  const promptPath = path.join(ws, "foundry-agents", promptFile);
  if (!fs.existsSync(promptPath)) {
    return `Prompt file not found: ${promptPath}`;
  }
  return fs.readFileSync(promptPath, "utf8");
}

async function callEndpoint(
  endpoint: string,
  apiKey: string,
  model: string,
  systemPrompt: string,
  userText: string,
  token: vscode.CancellationToken
): Promise<string> {
  const payload: ChatReq = {
    model,
    messages: [
      { role: "system", content: systemPrompt },
      { role: "user", content: userText }
    ],
    stream: false
  };

  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (apiKey) {
    headers["Authorization"] = `Bearer ${apiKey}`;
  }

  const controller = new AbortController();
  token.onCancellationRequested(() => controller.abort());

  const res = await fetch(endpoint, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
    signal: controller.signal
  });

  if (!res.ok) {
    const t = await res.text();
    return `HTTP ${res.status}\n\n${t}`;
  }

  const json: any = await res.json();
  return (
    json?.choices?.[0]?.message?.content ??
    json?.choices?.[0]?.text ??
    "(no content)"
  );
}

export function activate(context: vscode.ExtensionContext) {
  for (const agent of AGENTS) {
    const handler: vscode.ChatRequestHandler = async (request, _ctx, stream, token) => {
      const cfg = vscode.workspace.getConfiguration();
      const endpoint = cfg.get<string>("foundryAgents.endpoint") || "";
      const apiKey = cfg.get<string>("foundryAgents.apiKey") || "";
      const model = cfg.get<string>("foundryAgents.model") || "gpt-4o-mini";

      if (!endpoint) {
        stream.markdown("**Missing endpoint**. Set `foundryAgents.endpoint` in Settings.");
        return;
      }

      const systemPrompt = readPromptFromWorkspace(agent.promptFile);
      const userText = request.prompt || "";

      try {
        const answer = await callEndpoint(endpoint, apiKey, model, systemPrompt, userText, token);
        stream.markdown(answer);
      } catch (e: any) {
        stream.markdown(`**Error**: ${e?.message || String(e)}`);
      }
    };

    const participant = vscode.chat.createChatParticipant(agent.id, handler);
    participant.iconPath = new vscode.ThemeIcon("sparkle");
    context.subscriptions.push(participant);
  }
}

export function deactivate() {}
