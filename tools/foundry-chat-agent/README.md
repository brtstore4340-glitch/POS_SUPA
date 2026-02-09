# Foundry Chat Agents (VS Code)

This extension registers multiple VS Code Chat participants that load prompts
from `foundry-agents/*.prompt.md`.

## Install
1) Open `tools/foundry-chat-agent` in VS Code.
2) Run:
   - npm i
   - npm run build
   - npm run package
3) Install the generated `.vsix` from the folder.

## Use
Open Chat and type:
- `@orchestrator`
- `@planner`
- `@supabase-architect`
- `@app-coder`
- `@runner-executor`
- `@debugger`
- `@reviewer-gatekeeper`

## Settings
- `foundryAgents.endpoint`
- `foundryAgents.apiKey`
- `foundryAgents.model`

## Notes
Prompts are read from the currently opened workspace at:
`foundry-agents/<prompt file>`.
