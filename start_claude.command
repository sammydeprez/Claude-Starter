#!/bin/zsh
setopt KSH_ARRAYS  # Use 0-based arrays like bash

# Save original stdin, redirect to TTY for menu interaction
exec 3<&0
exec < /dev/tty

# Colors for better visualization
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
YELLOW=$'\033[1;33m'
MAGENTA=$'\033[0;35m'
WHITE=$'\033[1;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/profiles.json"

# Global variables for selector
SELECTOR_RESULT=0
SELECTOR_ACTION=""
RENAME_RESULT=""
TAG_RESULT=""

# Display order mapping (menu index -> workspace index)
declare -a DISPLAY_ORDER

# Ensure cursor is restored on exit
trap 'tput cnorm 2>/dev/null' EXIT

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "${RED}Error: jq is required but not installed.${NC}"
    echo "Install it with: brew install jq"
    exit 1
fi

# Check if Claude CLI is installed
if ! command -v claude &> /dev/null; then
    echo ""
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${RED}Claude CLI is not installed.${NC}"
    echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -n "Would you like to install it now? (Y/n): "
    read -rsk1 install_choice </dev/tty
    echo ""

    if [[ "$install_choice" != "n" && "$install_choice" != "N" ]]; then
        echo "${CYAN}Installing Claude CLI...${NC}"
        echo ""
        curl -fsSL https://claude.ai/install.sh | sh

        # Refresh PATH to find claude
        export PATH="$HOME/.local/bin:$PATH"

        if command -v claude &> /dev/null; then
            echo ""
            echo "${GREEN}Claude CLI installed successfully!${NC}"
            sleep 1
        else
            echo ""
            echo "${RED}Installation may have failed. Please install manually:${NC}"
            echo "  curl -fsSL https://claude.ai/install.sh | sh"
            exit 1
        fi
    else
        echo "${RED}Claude CLI is required. Exiting.${NC}"
        exit 1
    fi
fi

# Check for Claude CLI updates (in background to not slow down startup)
check_claude_update() {
    local current_version=$(claude --version 2>/dev/null | head -1 | awk '{print $1}')
    local latest_version=$(npm view @anthropic-ai/claude-code version 2>/dev/null)

    if [ -n "$latest_version" ] && [ -n "$current_version" ] && [ "$current_version" != "$latest_version" ]; then
        echo ""
        echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "${CYAN}Claude CLI update available:${NC} ${DIM}$current_version${NC} → ${GREEN}$latest_version${NC}"
        echo "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -n "Would you like to update now? (Y/n): "
        read -rsk1 update_choice </dev/tty
        echo ""

        if [[ "$update_choice" != "n" && "$update_choice" != "N" ]]; then
            echo "${CYAN}Updating Claude CLI...${NC}"
            curl -fsSL https://claude.ai/install.sh | sh
            echo ""
            echo "${GREEN}Update complete!${NC}"
            sleep 1
        fi
    fi
}

# Run update check
check_claude_update

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "${RED}Error: profiles.json not found at $CONFIG_FILE${NC}"
    exit 1
fi

# Function to draw the Claude Starter banner
draw_banner() {
    echo "${MAGENTA}   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗"
    echo "  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝"
    echo "  ██║     ██║     ███████║██║   ██║██║  ██║█████╗  "
    echo "  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝  "
    echo "  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗"
    echo "   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝${NC}"
    echo "${CYAN}  ███████╗████████╗ █████╗ ██████╗ ████████╗███████╗██████╗ "
    echo "  ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗"
    echo "  ███████╗   ██║   ███████║██████╔╝   ██║   █████╗  ██████╔╝"
    echo "  ╚════██║   ██║   ██╔══██║██╔══██╗   ██║   ██╔══╝  ██╔══██╗"
    echo "  ███████║   ██║   ██║  ██║██║  ██║   ██║   ███████╗██║  ██║"
    echo "  ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝${NC}"
    echo "${DIM}                    ⬡ Powered by Anthropic ⬡${NC}"
}

# Function to draw a box
draw_box() {
    local title="$1"
    local width=50
    echo "${CYAN}"
    printf '╔'; printf '═%.0s' $(seq 1 $width); printf '╗\n'
    printf '║'; printf " %-$((width-1))s" "$title"; printf '║\n'
    printf '╚'; printf '═%.0s' $(seq 1 $width); printf '╝'
    echo "${NC}"
}

# Function to get git branch for a folder
get_git_branch() {
    local folder="$1"
    local branch=$(git -C "$folder" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        echo "$branch"
    fi
}

# Function to get folder display name
get_folder_display() {
    echo "${1:t}"
}

# Function to format relative time
format_relative_time() {
    local timestamp="$1"
    if [ -z "$timestamp" ] || [ "$timestamp" = "null" ]; then
        echo ""
        return
    fi

    local now=$(date +%s)
    local diff=$((now - timestamp))

    if [ $diff -lt 60 ]; then
        echo "just now"
    elif [ $diff -lt 3600 ]; then
        local mins=$((diff / 60))
        echo "${mins}m ago"
    elif [ $diff -lt 86400 ]; then
        local hours=$((diff / 3600))
        echo "${hours}h ago"
    elif [ $diff -lt 604800 ]; then
        local days=$((diff / 86400))
        echo "${days}d ago"
    else
        local weeks=$((diff / 604800))
        echo "${weeks}w ago"
    fi
}

# Load profiles
load_profiles() {
    PROFILE_KEYS=("${(@f)$(jq -r '.profiles | keys[]' "$CONFIG_FILE")}")
    PROFILE_COUNT=${#PROFILE_KEYS[@]}

    PROFILE_NAMES=()
    PROFILE_DESCS=()
    for key in "${PROFILE_KEYS[@]}"; do
        PROFILE_NAMES+=("$(jq -r ".profiles[\"$key\"].name" "$CONFIG_FILE")")
        PROFILE_DESCS+=("$(jq -r ".profiles[\"$key\"].description" "$CONFIG_FILE")")
    done
}

# Load workspaces
load_workspaces() {
    WORKSPACE_PROFILES=()
    WORKSPACE_FOLDERS=()
    WORKSPACE_NAMES=()
    WORKSPACE_BRANCHES=()
    WORKSPACE_TAGS=()
    WORKSPACE_LAST_USED=()

    local workspace_count=$(jq -r '.workspaces | length' "$CONFIG_FILE")

    for ((i=0; i<workspace_count; i++)); do
        local folder=$(jq -r ".workspaces[$i].folder" "$CONFIG_FILE")
        if [ -d "$folder" ]; then
            WORKSPACE_PROFILES+=("$(jq -r ".workspaces[$i].profile" "$CONFIG_FILE")")
            WORKSPACE_FOLDERS+=("$folder")
            local name=$(jq -r ".workspaces[$i].name // empty" "$CONFIG_FILE")
            if [ -z "$name" ]; then
                name=$(get_folder_display "$folder")
            fi
            WORKSPACE_NAMES+=("$name")
            WORKSPACE_BRANCHES+=("$(get_git_branch "$folder")")
            local tag=$(jq -r ".workspaces[$i].tag // empty" "$CONFIG_FILE")
            WORKSPACE_TAGS+=("$tag")
            WORKSPACE_LAST_USED+=("$(jq -r ".workspaces[$i].lastUsed // empty" "$CONFIG_FILE")")
        fi
    done

    # Get unique tags for grouping
    ALL_TAGS=("${(@f)$(jq -r '[.workspaces[].tag // empty | select(. != "")] | unique | .[]' "$CONFIG_FILE" 2>/dev/null)}")
}

# Initial load
load_profiles
load_workspaces

# Function to get profile name from key
get_profile_name() {
    local key="$1"
    for ((i=0; i<${#PROFILE_KEYS[@]}; i++)); do
        if [[ "${PROFILE_KEYS[$i]}" = "$key" ]]; then
            echo "${PROFILE_NAMES[$i]}"
            return
        fi
    done
    echo "$key"
}

# Function to save workspace (updates lastUsed timestamp)
save_workspace() {
    local profile="$1"
    local folder="$2"
    local name="$3"
    local tag="$4"
    local last_used="$5"
    folder="${folder%/}"

    # Get existing tag if not provided
    if [ -z "$tag" ]; then
        tag=$(jq -r --arg folder "$folder" '.workspaces[] | select(.folder == $folder) | .tag // empty' "$CONFIG_FILE")
    fi

    # Get existing lastUsed if not provided
    if [ -z "$last_used" ]; then
        last_used=$(jq -r --arg folder "$folder" '.workspaces[] | select(.folder == $folder) | .lastUsed // empty' "$CONFIG_FILE")
    fi

    local new_workspace
    if [ -n "$tag" ]; then
        new_workspace=$(jq -n \
            --arg profile "$profile" \
            --arg folder "$folder" \
            --arg name "$name" \
            --arg tag "$tag" \
            --arg lastUsed "$last_used" \
            '{profile: $profile, folder: $folder, name: $name, tag: $tag, lastUsed: (if $lastUsed == "" then null else ($lastUsed | tonumber) end)}')
    else
        new_workspace=$(jq -n \
            --arg profile "$profile" \
            --arg folder "$folder" \
            --arg name "$name" \
            --arg lastUsed "$last_used" \
            '{profile: $profile, folder: $folder, name: $name, lastUsed: (if $lastUsed == "" then null else ($lastUsed | tonumber) end)}')
    fi

    local updated=$(jq --argjson new "$new_workspace" '
        .workspaces = ([$new] + [.workspaces[] | select(.folder != $new.folder)])
    ' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
}

# Function to update lastUsed timestamp
update_last_used() {
    local folder="$1"
    local timestamp=$(date +%s)
    local updated=$(jq --arg folder "$folder" --argjson ts "$timestamp" '
        .workspaces = [.workspaces[] | if .folder == $folder then .lastUsed = $ts else . end]
    ' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
}

# Function to check if workspace was used before
was_used_before() {
    local folder="$1"
    local last_used=$(jq -r --arg folder "$folder" '.workspaces[] | select(.folder == $folder) | .lastUsed // empty' "$CONFIG_FILE")
    if [ -n "$last_used" ] && [ "$last_used" != "null" ]; then
        return 0
    fi
    return 1
}

# Function to delete workspace
delete_workspace() {
    local folder="$1"
    local updated=$(jq --arg folder "$folder" '
        .workspaces = [.workspaces[] | select(.folder != $folder)]
    ' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
}

# Function to rename workspace
rename_workspace() {
    local folder="$1"
    local new_name="$2"
    local updated=$(jq --arg folder "$folder" --arg name "$new_name" '
        .workspaces = [.workspaces[] | if .folder == $folder then .name = $name else . end]
    ' "$CONFIG_FILE")
    echo "$updated" > "$CONFIG_FILE"
}

# Function to update workspace tag
update_workspace_tag() {
    local folder="$1"
    local tag="$2"

    local updated
    if [ -n "$tag" ]; then
        updated=$(jq --arg folder "$folder" --arg tag "$tag" '
            .workspaces = [.workspaces[] | if .folder == $folder then .tag = $tag else . end]
        ' "$CONFIG_FILE")
    else
        updated=$(jq --arg folder "$folder" '
            .workspaces = [.workspaces[] | if .folder == $folder then del(.tag) else . end]
        ' "$CONFIG_FILE")
    fi
    echo "$updated" > "$CONFIG_FILE"
}

# ============== MAIN MENU ==============

show_main_menu() {
    local selected=$1
    clear
    draw_banner
    echo ""
    echo "${BOLD}Workspaces${NC}  ${DIM}↑/↓:move  Enter:open  d:delete  r:rename  t:tag  q:quit${NC}"
    echo ""

    # Reset display order mapping
    DISPLAY_ORDER=()

    # Option 0: New Workspace (maps to -1 to indicate "new")
    DISPLAY_ORDER+=(-1)
    if [ $selected -eq 0 ]; then
        echo "  ${CYAN}▶${NC} ${GREEN}${BOLD}+ New Workspace${NC}"
        echo "    ${CYAN}Create a new profile + folder combination${NC}"
    else
        echo "  ${DIM}0${NC} ${DIM}+ New Workspace${NC}"
        echo ""
    fi
    echo ""

    if [ ${#WORKSPACE_FOLDERS[@]} -eq 0 ]; then
        echo "    ${DIM}No saved workspaces yet${NC}"
        echo ""
        return
    fi

    local displayed=()
    local menu_index=1

    # First show tagged workspaces grouped by tag
    for tag in "${ALL_TAGS[@]}"; do
        [ -z "$tag" ] && continue

        local has_items=false
        for ((i=0; i<${#WORKSPACE_FOLDERS[@]}; i++)); do
            if [[ "${WORKSPACE_TAGS[$i]}" = "$tag" ]]; then
                has_items=true
                break
            fi
        done

        if [ "$has_items" = "true" ]; then
            echo "  ${WHITE}━━━ ${tag} ━━━${NC}"
            echo ""

            for ((i=0; i<${#WORKSPACE_FOLDERS[@]}; i++)); do
                if [[ "${WORKSPACE_TAGS[$i]}" = "$tag" ]]; then
                    # Check if already displayed
                    local already_shown=false
                    for d in "${displayed[@]}"; do
                        [ "$d" = "$i" ] && already_shown=true && break
                    done
                    [ "$already_shown" = "true" ] && continue

                    displayed+=("$i")
                    DISPLAY_ORDER+=("$i")
                    render_workspace_item $i $menu_index $selected
                    ((menu_index++))
                fi
            done
        fi
    done

    # Then show untagged workspaces
    local has_untagged=false
    for ((i=0; i<${#WORKSPACE_FOLDERS[@]}; i++)); do
        if [ -z "${WORKSPACE_TAGS[$i]}" ]; then
            has_untagged=true
            break
        fi
    done

    if [ "$has_untagged" = "true" ]; then
        if [ ${#displayed[@]} -gt 0 ]; then
            echo "  ${WHITE}━━━ Other ━━━${NC}"
            echo ""
        fi

        for ((i=0; i<${#WORKSPACE_FOLDERS[@]}; i++)); do
            if [ -z "${WORKSPACE_TAGS[$i]}" ]; then
                displayed+=("$i")
                DISPLAY_ORDER+=("$i")
                render_workspace_item $i $menu_index $selected
                ((menu_index++))
            fi
        done
    fi
}

render_workspace_item() {
    local i=$1
    local menu_index=$2
    local selected=$3

    local profile_name=$(get_profile_name "${WORKSPACE_PROFILES[$i]}")
    local folder_name="${WORKSPACE_NAMES[$i]}"
    local folder_path="${WORKSPACE_FOLDERS[$i]}"
    local branch="${WORKSPACE_BRANCHES[$i]}"
    local last_used="${WORKSPACE_LAST_USED[$i]}"

    # Format branch display
    local branch_display=""
    if [ -n "$branch" ]; then
        branch_display=" ${BLUE}${branch}${NC}"
    fi

    # Format last used
    local time_display=""
    local relative=$(format_relative_time "$last_used")
    if [ -n "$relative" ]; then
        time_display=" ${DIM}${relative}${NC}"
    fi

    if [ $menu_index -eq $selected ]; then
        echo "  ${CYAN}▶${NC} ${GREEN}${BOLD}$folder_name${NC}  ${MAGENTA}[$profile_name]${NC}${branch_display}${time_display}"
        echo "    ${CYAN}$folder_path${NC}"
    else
        echo "  ${DIM}$menu_index${NC} $folder_name  ${DIM}[$profile_name]${NC}${branch_display}${time_display}"
        echo "    ${DIM}$folder_path${NC}"
    fi
    echo ""
}

# ============== PROFILE SELECTOR ==============

show_profile_menu() {
    local selected=$1
    clear
    echo ""
    draw_box "Select Profile"
    echo ""
    echo "${BOLD}Choose a profile:${NC}  ${DIM}↑/↓:move  Enter:select  q:back${NC}"
    echo ""

    for ((i=0; i<${#PROFILE_KEYS[@]}; i++)); do
        if [ $i -eq $selected ]; then
            echo "  ${CYAN}▶${NC} ${GREEN}${BOLD}${PROFILE_NAMES[$i]}${NC}"
            echo "    ${CYAN}${PROFILE_DESCS[$i]}${NC}"
        else
            echo "  ${DIM}$((i+1))${NC} ${PROFILE_NAMES[$i]}"
            echo "    ${YELLOW}${PROFILE_DESCS[$i]}${NC}"
        fi
        echo ""
    done
}

# ============== FOLDER SELECTOR ==============

show_folder_menu() {
    local selected=$1
    local profile_name="$2"
    clear
    echo ""
    draw_box "Select Folder for $profile_name"
    echo ""
    echo "${BOLD}Choose a folder:${NC}  ${DIM}↑/↓:move  Enter:select  q:back${NC}"
    echo ""

    if [ $selected -eq 0 ]; then
        echo "  ${CYAN}▶${NC} ${GREEN}${BOLD}Browse...${NC}"
        echo "    ${CYAN}Open Finder to select a folder${NC}"
    else
        echo "  ${DIM}0${NC} ${DIM}Browse...${NC}"
        echo ""
    fi
    echo ""

    declare -a seen_folders
    local folder_index=1
    for ((i=0; i<${#WORKSPACE_FOLDERS[@]}; i++)); do
        local folder="${WORKSPACE_FOLDERS[$i]}"
        local already_seen=false
        for seen in "${seen_folders[@]}"; do
            [ "$seen" = "$folder" ] && already_seen=true && break
        done
        if [ "$already_seen" = "false" ]; then
            seen_folders+=("$folder")
            local display=$(get_folder_display "$folder")
            if [ $folder_index -eq $selected ]; then
                echo "  ${CYAN}▶${NC} ${GREEN}${BOLD}$display${NC}"
                echo "    ${CYAN}$folder${NC}"
            else
                echo "  ${DIM}$folder_index${NC} $display"
                echo "    ${DIM}$folder${NC}"
            fi
            echo ""
            ((folder_index++))
        fi
    done
}

# ============== DIALOGS ==============

do_rename_dialog() {
    local current_name="$1"
    tput cnorm
    clear
    echo ""
    draw_box "Rename Workspace"
    echo ""
    echo "${BOLD}Current name:${NC} ${YELLOW}$current_name${NC}"
    echo ""
    echo -n "${BOLD}New name:${NC} "
    read -r RENAME_RESULT </dev/tty
}

do_tag_dialog() {
    local current_tag="$1"
    tput cnorm
    clear
    echo ""
    draw_box "Set Tag"
    echo ""
    if [ -n "$current_tag" ]; then
        echo "${BOLD}Current tag:${NC} ${YELLOW}$current_tag${NC}"
    else
        echo "${BOLD}Current tag:${NC} ${DIM}none${NC}"
    fi
    echo ""
    echo "${DIM}Enter a tag to group this workspace (leave empty to remove)${NC}"
    echo ""
    echo -n "${BOLD}Tag:${NC} "
    read -r TAG_RESULT </dev/tty
}

# ============== GENERIC SELECTOR ==============

run_selector() {
    local menu_func="$1"
    local total_options="$2"
    local extra_arg="$3"
    local allow_delete="${4:-false}"
    local allow_rename="${5:-false}"
    local allow_tag="${6:-false}"
    local selected=0
    local key

    tput civis
    SELECTOR_ACTION="select"

    while true; do
        $menu_func $selected "$extra_arg"

        read -rsk1 key </dev/tty

        case "$key" in
            $'\e')
                read -rsk2 -t 0.1 key </dev/tty 2>/dev/null || key=""
                case "$key" in
                    '[A') ((selected--)); [ $selected -lt 0 ] && selected=$((total_options - 1)) ;;
                    '[B') ((selected++)); [ $selected -ge $total_options ] && selected=0 ;;
                esac
                ;;
            $'\n'|$'\r'|'')
                tput cnorm
                SELECTOR_RESULT=$selected
                SELECTOR_ACTION="select"
                return 0
                ;;
            ' ')
                tput cnorm
                SELECTOR_RESULT=$selected
                SELECTOR_ACTION="select"
                return 0
                ;;
            'q'|'Q')
                tput cnorm
                SELECTOR_RESULT=-1
                SELECTOR_ACTION="quit"
                return 0
                ;;
            'd'|'D')
                if [[ "$allow_delete" = "true" && $selected -gt 0 ]]; then
                    tput cnorm
                    SELECTOR_RESULT=$selected
                    SELECTOR_ACTION="delete"
                    return 0
                fi
                ;;
            'r'|'R')
                if [[ "$allow_rename" = "true" && $selected -gt 0 ]]; then
                    tput cnorm
                    SELECTOR_RESULT=$selected
                    SELECTOR_ACTION="rename"
                    return 0
                fi
                ;;
            't'|'T')
                if [[ "$allow_tag" = "true" && $selected -gt 0 ]]; then
                    tput cnorm
                    SELECTOR_RESULT=$selected
                    SELECTOR_ACTION="tag"
                    return 0
                fi
                ;;
            'k') ((selected--)); [ $selected -lt 0 ] && selected=$((total_options - 1)) ;;
            'j') ((selected++)); [ $selected -ge $total_options ] && selected=0 ;;
            [0-9])
                local num=$key
                if [ $num -lt $total_options ]; then
                    tput cnorm
                    SELECTOR_RESULT=$num
                    SELECTOR_ACTION="select"
                    return 0
                fi
                ;;
        esac
    done
}

# ============== MAIN FLOW ==============

while true; do
    load_workspaces  # Reload to get fresh data
    MAIN_MENU_OPTIONS=$((${#WORKSPACE_FOLDERS[@]} + 1))

    run_selector show_main_menu $MAIN_MENU_OPTIONS "" "true" "true" "true"
    choice=$SELECTOR_RESULT
    action=$SELECTOR_ACTION

    # Map display choice to actual workspace index
    if [ $choice -ge 0 ] && [ $choice -lt ${#DISPLAY_ORDER[@]} ]; then
        workspace_index=${DISPLAY_ORDER[$choice]}
    else
        workspace_index=-1
    fi

    if [ "$action" = "quit" ]; then
        echo ""
        echo "${YELLOW}Goodbye!${NC}"
        exit 0
    fi

    if [ "$action" = "delete" ] && [ $workspace_index -ge 0 ]; then
        folder_to_delete="${WORKSPACE_FOLDERS[$workspace_index]}"
        name_to_delete="${WORKSPACE_NAMES[$workspace_index]}"

        tput cnorm
        clear
        echo ""
        draw_box "Delete Workspace"
        echo ""
        echo "${BOLD}Delete workspace:${NC} ${RED}$name_to_delete${NC}"
        echo "${DIM}$folder_to_delete${NC}"
        echo ""
        echo -n "Are you sure? (y/N): "
        read -rsk1 confirm </dev/tty
        echo ""

        if [[ "$confirm" = "y" || "$confirm" = "Y" ]]; then
            delete_workspace "$folder_to_delete"
            echo "${GREEN}Workspace deleted.${NC}"
            sleep 0.5
        fi
        continue
    fi

    if [ "$action" = "rename" ] && [ $workspace_index -ge 0 ]; then
        folder_to_rename="${WORKSPACE_FOLDERS[$workspace_index]}"
        current_name="${WORKSPACE_NAMES[$workspace_index]}"

        RENAME_RESULT=""
        do_rename_dialog "$current_name"

        if [ -n "$RENAME_RESULT" ]; then
            rename_workspace "$folder_to_rename" "$RENAME_RESULT"
        fi
        continue
    fi

    if [ "$action" = "tag" ] && [ $workspace_index -ge 0 ]; then
        folder_to_tag="${WORKSPACE_FOLDERS[$workspace_index]}"
        current_tag="${WORKSPACE_TAGS[$workspace_index]}"

        TAG_RESULT=""
        do_tag_dialog "$current_tag"

        update_workspace_tag "$folder_to_tag" "$TAG_RESULT"
        continue
    fi

    # Regular selection
    if [ $workspace_index -eq -1 ]; then
        # New workspace flow
        run_selector show_profile_menu $PROFILE_COUNT
        profile_choice=$SELECTOR_RESULT

        if [ "$profile_choice" -eq -1 ]; then
            continue
        fi

        SELECTED_PROFILE="${PROFILE_KEYS[$profile_choice]}"
        PROFILE_NAME="${PROFILE_NAMES[$profile_choice]}"

        # Count unique folders + browse option
        declare -a unique_folders
        unique_folders=()
        for f in "${WORKSPACE_FOLDERS[@]}"; do
            local exists=false
            for uf in "${unique_folders[@]}"; do
                [ "$uf" = "$f" ] && exists=true && break
            done
            [ "$exists" = "false" ] && unique_folders+=("$f")
        done
        FOLDER_OPTIONS=$((${#unique_folders[@]} + 1))

        run_selector show_folder_menu $FOLDER_OPTIONS "$PROFILE_NAME"
        folder_choice=$SELECTOR_RESULT

        if [ "$folder_choice" -eq -1 ]; then
            continue
        fi

        if [ "$folder_choice" -eq 0 ]; then
            DEFAULT_FOLDER=$(jq -r '.defaults.folder_path // "/Users/sammydeprez/Desktop/"' "$CONFIG_FILE")
            tput cnorm
            echo ""
            echo "${BLUE}Opening folder picker...${NC}"
            folder=$(osascript -e "tell application \"Finder\" to POSIX path of (choose folder with prompt \"Select project folder\" default location POSIX file \"$DEFAULT_FOLDER\")" 2>/dev/null)

            if [ -z "$folder" ]; then
                echo "${YELLOW}No folder selected.${NC}"
                sleep 1
                continue
            fi
        else
            folder="${unique_folders[$((folder_choice - 1))]}"
        fi

        folder="${folder%/}"
        FOLDER_NAME="${folder:t}"
        save_workspace "$SELECTED_PROFILE" "$folder" "$FOLDER_NAME" "" ""

    else
        # Use existing workspace
        SELECTED_PROFILE="${WORKSPACE_PROFILES[$workspace_index]}"
        PROFILE_NAME=$(get_profile_name "$SELECTED_PROFILE")
        folder="${WORKSPACE_FOLDERS[$workspace_index]}"
        FOLDER_NAME="${WORKSPACE_NAMES[$workspace_index]}"

        # Check if should resume
        SHOULD_RESUME=false
        if was_used_before "$folder"; then
            SHOULD_RESUME=true
        fi

        # Update last used timestamp and move to top
        update_last_used "$folder"
        save_workspace "$SELECTED_PROFILE" "$folder" "$FOLDER_NAME" "${WORKSPACE_TAGS[$workspace_index]}" "$(date +%s)"
        break
    fi
done

cd "$folder" || { echo "${RED}Failed to change to directory${NC}"; exit 1; }

clear
echo ""
draw_box "Starting Claude Code"
echo ""
echo "${BOLD}Workspace:${NC} ${GREEN}$FOLDER_NAME${NC}"
echo "${BOLD}Profile:${NC}   ${MAGENTA}$PROFILE_NAME${NC}"
echo "${BOLD}Folder:${NC}    ${BLUE}$folder${NC}"

# Show git branch if available
current_branch=$(get_git_branch "$folder")
if [ -n "$current_branch" ]; then
    echo "${BOLD}Branch:${NC}    ${BLUE}$current_branch${NC}"
fi

# Show if resuming
if [ "$SHOULD_RESUME" = "true" ]; then
    echo "${BOLD}Mode:${NC}      ${YELLOW}Resuming previous session${NC}"
fi

echo ""
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

while IFS='=' read -r key value; do
    if [ -n "$key" ]; then
        export "$key=$value"
        if [[ "$key" == *"KEY"* || "$key" == *"SECRET"* ]]; then
            echo "  ${GREEN}✓${NC} $key = ****${value: -4}"
        else
            echo "  ${GREEN}✓${NC} $key = $value"
        fi
    fi
done < <(jq -r ".profiles[\"$SELECTED_PROFILE\"].env | to_entries[] | \"\(.key)=\(.value)\"" "$CONFIG_FILE")

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

WINDOW_TITLE="Claude: $PROFILE_NAME | $FOLDER_NAME"
print -n "\033]0;${WINDOW_TITLE}\007"
print -n "\033]1;${WINDOW_TITLE}\007"
osascript -e "tell application \"Terminal\" to set custom title of front window to \"$WINDOW_TITLE\"" 2>/dev/null || true

echo "${GREEN}Launching...${NC}"
echo ""

# Restore stdin and reset terminal settings
exec 0<&3 3<&-
stty sane 2>/dev/null

# Start Claude (with --resume if used before)
if [ "$SHOULD_RESUME" = "true" ]; then
    claude --resume
else
    claude
fi
