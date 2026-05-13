#!/bin/bash

# docker sandboxes does not allow spaces, _ in names
# (and possibly other stuff but these are the only ones this script deals with)
# replace spaces and underscores with dashes
SANDBOX="claude-$(basename "$PWD" | tr '_ ' '-')"
# can be empty/blank also
VOLUMES=(
  "/my/additional/data/volume"
  "/a/readonly/volume:ro"
)

# Redirect ALL stderr to log — nothing should reach ZED except ACP JSON on stdout
exec 2>>/tmp/claude-sandbox.log

install_acp() {
    echo "$(date): checking for claude-agent-acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
    if sbx exec "$SANDBOX" npm list -g @agentclientprotocol/claude-agent-acp >/dev/null 2>&1; then
        echo "$(date): claude-agent-acp already installed" >>/tmp/claude-sandbox.log
        return 0
    fi

    echo "$(date): installing claude-agent-acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
    if ! sbx exec "$SANDBOX" npm install -g @agentclientprotocol/claude-agent-acp >>/tmp/claude-sandbox.log; then
        echo "$(date): failed to install claude-agent-acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
        exit 1
    fi
}

# Try to create sandbox; if it already exists, verify exec works
# NOTE: If you need to add any volumes, add it here (add it after the $PWD)
# check: https://docs.docker.com/reference/cli/sbx/create/ the `create` command docs for more info
if ! sbx create --name "$SANDBOX" claude "$PWD" "${VOLUMES[@]}" >>/tmp/claude-sandbox.log; then
    # Sandbox already exists — check if container is actually running
    if ! sbx exec "$SANDBOX" true >>/tmp/claude-sandbox.log; then
        echo "Sandbox stale, recreating..." >>/tmp/claude-sandbox.log
        sbx rm "$SANDBOX" >>/tmp/claude-sandbox.log || true
        if ! sbx create --name "$SANDBOX" claude "$PWD" "${VOLUMES[@]}" >>/tmp/claude-sandbox.log; then
            echo "$(date): failed to recreate sandbox $SANDBOX" >>/tmp/claude-sandbox.log
            exit 1
        fi
    fi
fi

install_acp

# Run Claude Code in ACP mode over stdio
echo "$(date): starting claude code acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
exec sbx exec -i "$SANDBOX" claude-agent-acp