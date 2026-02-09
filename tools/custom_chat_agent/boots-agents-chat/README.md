# Boots Agents Chat (VS Code Chat Participant)

Custom chat participant that loads agent instructions from `foundry-agents` (or any folder you set) and sends requests to your OpenAI-compatible endpoint (e.g. AI Toolkit).

## Install
1) Open this folder in VS Code:
   `d:/01 Main Work/Boots/Boots-POS Gemini/tools/custom_chat_agent/boots-agents-chat`
2) In terminal:
   - `npm i`
   - `npm run build`
   - `npm run package` (creates a `.vsix`)
3) Install the VSIX in VS Code.

## Configure
Settings (User or Workspace):
- `bootsagents.endpoint` = your OpenAI-compatible base or full `/v1/chat/completions` URL
- `bootsagents.apiKey` = API key if needed
- `bootsagents.model` = model name
- `bootsagents.agentsRoot` = default `foundry-agents` (this repo)

## Use
Open Chat and use the participant:
- `@bootsagents /agent devopsandrelease <your question>`
- `@bootsagents @coderanddebugger <your question>`
- `@bootsagents /agents` (list available agents)
