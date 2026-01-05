# Apply Config

Apply dotfile changes through chezmoi with validation.

## Workflow

1. **Review pending changes**
   - Run `chezmoi diff` to show what will change
   - Summarize the changes for the user

2. **Validate configs**
   - Lua files: check syntax with `luac -p` if available
   - Shell files: check with `shellcheck` if available
   - TOML files: check syntax with `tomlq` or similar if available
   - Report any issues found

3. **Apply changes**
   - Run `chezmoi apply` to apply changes to the system
   - Report success or any errors

4. **Git commit**
   - Show git status
   - Stage changed files
   - Create a commit with a descriptive message
   - Ask user if they want to push

## Instructions

Run this workflow step by step. Stop and report if any validation fails or errors occur. Always show the user what's happening at each step.
