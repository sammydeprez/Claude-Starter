# Claude Starter

A terminal launcher for Claude Code with workspace and profile management.

## Features

- **Auto-Install** - Prompts to install Claude CLI if not found
- **Auto-Update** - Checks for new versions and prompts to update
- **Profile Management** - Configure multiple profiles with different environment variables
- **Workspace Tracking** - Save and quickly access your project folders
- **Session Resume** - Automatically resume previous Claude sessions
- **Tagging** - Organize workspaces with custom tags
- **Git Integration** - Shows current branch for each workspace

## Requirements

- macOS
- [jq](https://stedolan.github.io/jq/) - Install with `brew install jq`
- [Node.js/npm](https://nodejs.org/) - For version checking
- [Claude Code CLI](https://claude.ai/claude-code) - Auto-installed if missing

## Installation

1. Clone or download this repository
2. Copy the example config and add your API keys:
   ```bash
   cp profiles.example.json profiles.json
   ```
3. Edit `profiles.json` with your API keys and preferences
4. Make the script executable:
   ```bash
   chmod +x start_claude.command
   ```
5. Double-click `start_claude.command` or run from terminal

## Usage

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| ↑/↓ or j/k | Navigate menu |
| Enter/Space | Select item |
| d | Delete workspace |
| r | Rename workspace |
| t | Set/change tag |
| q | Quit |

### Configuration

Edit `profiles.json` to configure profiles and workspaces:

```json
{
  "profiles": {
    "default": {
      "name": "Default",
      "description": "Standard Claude profile",
      "env": {
        "ANTHROPIC_API_KEY": "your-key-here"
      }
    }
  },
  "workspaces": [],
  "defaults": {
    "folder_path": "/Users/yourname/Projects/"
  }
}
```

## License

MIT
