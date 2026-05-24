# Claude Code — LiteLLM proxy config

Point Claude Code at your own LLM backend (Ollama, LiteLLM, etc.) instead of
using Anthropic's API.

## Quick start

```bash
# 1. Copy the example config
cp .env.example .env
# Edit .env with your LiteLLM URL and admin key

# 2. Auto-detect the best models from your proxy
./generate-settings

# 3. Write settings to file
./generate-settings env > settings.txt

# 4. Source them when running Claude Code
source settings.txt && claude
```

## How it works

[LiteLLM](https://litellm.vercel.app/) is a proxy that exposes any LLM
(Ollama, OpenAI-compatible, etc.) through a single API. Claude Code talks to
it as if it were Anthropic's API.

The `generate-settings` script:

1. Connects to your LiteLLM proxy's `/model/info` endpoint
2. Finds models with `supports_function_calling=true` (required for Claude
   Code tool use)
3. Picks the **fastest** model (smallest context) for `HAIKU` and the **most
   capable** (largest context) for `SONNET`
4. Prints the required environment variables

## Commands

```bash
# List available models with their capabilities
./generate-settings models

# Print shell exports (default)
./generate-settings env

# JSON output (for programmatic use)
./generate-settings json
```

## Override model selection

```bash
HAIKU_MODEL="llama3.1:8b" SONNET_MODEL="qwen3.6:latest" ./generate-settings
```

## Manual config

If you prefer not to use the script, copy `settings.example.txt` to
`settings.txt` and fill in your values.

```bash
cp settings.example.txt settings.txt
# Edit settings.txt with your models and credentials
source settings.txt
claude
```

## Project structure

```
├── CLAUDE.md              # Engineering rules for Claude Code sessions
├── .env.example           # Template for LiteLLM credentials
├── .gitignore             # Excludes settings.txt, .env
├── generate-settings      # Auto-detect models from proxy
├── settings.example.txt   # Example manual config
├── settings.txt           # Your actual config (gitignored)
└── README.md
```

## Skills

Claude Code uses skills — specialized instruction sets — to enforce disciplined
workflows. This repo references skills from two sources:

1. **[9arm-skills](https://github.com/thananon/9arm-skills)** — debug-mantra,
   scrutinize, post-mortem, management-talk
2. **[superpowers](https://github.com/anomalyco/superpowers)** — brainstorming,
   writing-plans, test-driven-development, verification-before-completion,
   requesting-code-review, receiving-code-review

Install them by cloning and symlinking into `~/.config/opencode/skills/`:

```bash
# 9arm-skills
git clone https://github.com/thananon/9arm-skills.git /tmp/9arm-skills
for dir in /tmp/9arm-skills/skills/engineering/* /tmp/9arm-skills/skills/productivity/*; do
  ln -sfn "$dir" ~/.config/opencode/skills/"$(basename "$dir")"
done

# superpowers
git clone https://github.com/anomalyco/superpowers.git /tmp/superpowers
for dir in /tmp/superpowers/skills/*/; do
  ln -sfn "$dir" ~/.config/opencode/skills/"$(basename "$dir")"
done
```

After installing skills, Claude Code can load them by name as directed in
`CLAUDE.md`.

## Engineering Process

Once the project is set up, Claude Code reads `CLAUDE.md` at session start and
follows disciplined workflows — load skills for debugging, TDD for features,
verification before completion, and post-mortems for bugs. See `CLAUDE.md` for
the full rules.
