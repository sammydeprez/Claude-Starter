# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Starter is a macOS terminal launcher for Claude Code. It provides a TUI (text user interface) for managing workspaces and profiles, allowing quick switching between different projects and Claude deployment configurations.

## Architecture

### Core Components

- **start_claude.command** - Main zsh script providing the interactive menu system
- **profiles.json** - Configuration file storing profiles, workspaces, and defaults

### Profile System

Profiles define environment variables for different Claude deployment backends:
- Azure AI Foundry (`CLAUDE_CODE_USE_FOUNDRY=1`)
- Google Vertex AI (`CLAUDE_CODE_USE_VERTEX=1`)
- Direct Anthropic API (`ANTHROPIC_API_KEY`)

### Workspace System

Workspaces link a profile to a project folder. They support:
- Custom display names
- Tags for grouping (rendered as sections in the menu)
- Last-used timestamps for sorting/resuming
- Git branch detection

### Startup Checks

1. Verifies `claude` CLI is installed; if missing, prompts to install via official installer
2. Compares installed version against npm registry; prompts to update if newer version available

### Menu Flow

1. Main menu shows all workspaces grouped by tag
2. "New Workspace" flow: select profile → select/browse folder
3. Selecting existing workspace sets environment variables and launches `claude` (with `--resume` if previously used)

## Dependencies

- **jq** - Required for JSON parsing (`brew install jq`)
- **osascript** - Used for native macOS folder picker dialog

## Testing Changes

Run the script directly:
```bash
./start_claude.command
```

Or double-click the `.command` file in Finder.
