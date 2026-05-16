# Claude Code with ACP

Due to changes with Claude Agent SDK [1](https://www.reddit.com/r/ClaudeCode/comments/1tc832e/anthropic_just_ripped_off_everyone_and_they_still/), [2](https://zed.dev/blog/anthropic-subscription-changes) this method will use the "SDK credit" starting June 15.

## Description

Adds `@agentclientprotocol/claude-agent-acp` to the standard Claude Code docker sbx sandbox.

## Usage

Follow the instructions in this blog: https://olegselajev.substack.com/p/safe-coding-agents-in-intellij-idea, to get started.
You will need to modify the script presented in their blog for starting the OpenCode sandbox.

I recommend writing this script in the project file instead of the `~` home dir
since, you might need project specific volumes mounted to the microVM.

```shell
#!/bin/bash

# docker sandboxes does not allow spaces, _ in names
# (and possibly other stuff but these are the only ones this script deals with)
# replace spaces and underscores with dashes
SANDBOX="claude-$(basename "$PWD" | tr '_ ' '-')"
CREATED=0
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
        CREATED=1
    fi
else
    CREATED=1
fi

install_acp

# Run Claude Code in ACP mode over stdio
echo "$(date): starting claude code acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
exec sbx exec -i "$SANDBOX" claude-agent-acp
```

Remember to `chmod +x` whatever you call the script so JetBrains/Zed can run it.

Then in JetBrains AI Chat, click on the 3 dots icon to bring up the menu,
add a custom agent and add the following to the `acp.json` file:


```json
{
  ... other stuff like mcp_servers ...
  "agent_servers": {
    "claude-code-sbx": {
      "command": "<MY PROJECT DIR>/start_claude_sbx.sh",
      "args": []
    }
  }
}

```
