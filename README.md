# Claude Code with ACP

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

# Redirect ALL stderr to log — nothing should reach ZED except ACP JSON on stdout
exec 2>>/tmp/claude-sandbox.log

install_acp() {
    echo "$(date): installing claude-agent-acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
    if ! sbx exec "$SANDBOX" npm install -g @agentclientprotocol/claude-agent-acp >>/tmp/claude-sandbox.log; then
        echo "$(date): failed to install claude-agent-acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
        exit 1
    fi
}

# Try to create sandbox; if it already exists, verify exec works
# NOTE: If you need to add any volumes, add it here (add it after the $PWD)
# check: https://docs.docker.com/reference/cli/sbx/create/ the `create` command docs for more info
if ! sbx create --name "$SANDBOX" claude "$PWD" >>/tmp/claude-sandbox.log; then
    # Sandbox already exists — check if container is actually running
    if ! sbx exec "$SANDBOX" true >>/tmp/claude-sandbox.log; then
        echo "Sandbox stale, recreating..." >>/tmp/claude-sandbox.log
        sbx rm "$SANDBOX" >>/tmp/claude-sandbox.log || true
        if ! sbx create --name "$SANDBOX" claude "$PWD" >>/tmp/claude-sandbox.log; then
            echo "$(date): failed to recreate sandbox $SANDBOX" >>/tmp/claude-sandbox.log
            exit 1
        fi
        CREATED=1
    fi
else
    CREATED=1
fi

if [ "$CREATED" -eq 1 ]; then
    install_acp
fi

# Run Claude Code in ACP mode over stdio
echo "$(date): starting claude code acp in sandbox $SANDBOX" >>/tmp/claude-sandbox.log
exec sbx exec -i "$SANDBOX" claude-agent-acp
```

Remember to `chmod +x` whatever you call the script so JetBrains/Zed can run it.

Then in JetBrains AI Assistant, add a custom agent and add the following to the `acp.json` file:


```json
{
  ... other stuff like mcp_servers ...
  "agent_servers": {
    "claude-code-sbx": {
      "command": "<MY PROJECT DIR>/sandbox-script.sh",
      "args": []
    }
  }
}

```

Remember this makes claude run in YOLO mode, so your chats will bypass all permissions.