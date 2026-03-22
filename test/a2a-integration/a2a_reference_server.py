#!/usr/bin/env python3
"""
Minimal A2A Reference Server using the official a2a-sdk.

This server implements a simple echo agent for testing our Qore A2A client
against a known-good Python implementation.

Usage:
    python a2a_reference_server.py <port>
"""

import sys
import signal
import json
import uuid
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timezone

# Agent card served at /.well-known/agent-card.json
AGENT_CARD = {
    "name": "Python A2A Reference Agent",
    "description": "A reference A2A agent for cross-implementation testing",
    "url": "",  # Set dynamically
    "version": "1.0",
    "capabilities": {
        "streaming": False,
        "pushNotifications": False,
    },
    "defaultInputModes": ["text", "text/plain"],
    "defaultOutputModes": ["text", "text/plain"],
    "skills": [
        {
            "id": "echo",
            "name": "Echo",
            "description": "Echoes messages back to the sender",
            "tags": ["test", "echo"],
        },
        {
            "id": "hello",
            "name": "Hello World",
            "description": "Returns a greeting message",
            "tags": ["test", "greeting"],
        },
    ],
}

# In-memory task store
tasks = {}


def create_task(context_id=None, metadata=None):
    """Create a new task."""
    task_id = f"task-{uuid.uuid4().hex[:8]}"
    now = datetime.now(timezone.utc).isoformat()
    task = {
        "id": task_id,
        "contextId": context_id,
        "status": {
            "state": "completed",
            "timestamp": now,
        },
        "history": [],
        "artifacts": [],
        "metadata": metadata,
    }
    tasks[task_id] = task
    return task


def handle_message_send(params):
    """Handle message/send JSON-RPC method."""
    message = params.get("message", {})
    config = params.get("configuration", {})

    # Extract text from parts
    text_parts = []
    for part in message.get("parts", []):
        kind = part.get("type") or part.get("kind", "")
        if kind == "text":
            text_parts.append(part.get("text", ""))

    input_text = "".join(text_parts) if text_parts else ""

    # Create task
    task = create_task(
        context_id=config.get("contextId") or params.get("contextId"),
        metadata=message.get("metadata"),
    )

    # Add user message to history
    task["history"] = [message]

    # Create agent response
    agent_message = {
        "role": "agent",
        "parts": [{"type": "text", "text": f"Echo: {input_text}"}],
        "messageId": str(uuid.uuid4()),
    }
    task["history"].append(agent_message)
    task["status"]["message"] = agent_message

    return task


def handle_tasks_get(params):
    """Handle tasks/get JSON-RPC method."""
    task_id = params.get("id")
    if not task_id or task_id not in tasks:
        return None, {"code": -32002, "message": f"Task not found: {task_id}"}
    return tasks[task_id], None


def handle_tasks_cancel(params):
    """Handle tasks/cancel JSON-RPC method."""
    task_id = params.get("id")
    if not task_id or task_id not in tasks:
        return None, {"code": -32002, "message": f"Task not found: {task_id}"}

    task = tasks[task_id]
    state = task["status"]["state"]
    if state in ("completed", "failed", "canceled", "rejected"):
        return None, {"code": -32003, "message": f"Cannot cancel task in state: {state}"}

    task["status"]["state"] = "canceled"
    task["status"]["timestamp"] = datetime.now(timezone.utc).isoformat()
    return task, None


def handle_tasks_list(params):
    """Handle tasks/list JSON-RPC method."""
    context_id = params.get("contextId")
    result = list(tasks.values())
    if context_id:
        result = [t for t in result if t.get("contextId") == context_id]
    return result, None


class A2ARequestHandler(BaseHTTPRequestHandler):
    """HTTP request handler for A2A protocol."""

    def log_message(self, format, *args):
        """Suppress default logging."""
        pass

    def do_GET(self):
        """Handle GET requests - agent card discovery."""
        if self.path in ("/.well-known/agent-card.json", "/.well-known/agent.json"):
            body = json.dumps(AGENT_CARD).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def do_POST(self):
        """Handle POST requests - JSON-RPC."""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        try:
            request = json.loads(body)
        except json.JSONDecodeError:
            self._send_jsonrpc_error(None, -32700, "Parse error")
            return

        req_id = request.get("id")
        method = request.get("method")
        params = request.get("params", {})

        if method == "message/send":
            result = handle_message_send(params)
            self._send_jsonrpc_result(req_id, result)
        elif method == "tasks/get":
            result, error = handle_tasks_get(params)
            if error:
                self._send_jsonrpc_error(req_id, error["code"], error["message"])
            else:
                self._send_jsonrpc_result(req_id, result)
        elif method == "tasks/cancel":
            result, error = handle_tasks_cancel(params)
            if error:
                self._send_jsonrpc_error(req_id, error["code"], error["message"])
            else:
                self._send_jsonrpc_result(req_id, result)
        elif method == "tasks/list":
            result, error = handle_tasks_list(params)
            if error:
                self._send_jsonrpc_error(req_id, error["code"], error["message"])
            else:
                self._send_jsonrpc_result(req_id, result)
        else:
            self._send_jsonrpc_error(req_id, -32601, f"Method not found: {method}")

    def _send_jsonrpc_result(self, req_id, result):
        """Send a successful JSON-RPC response."""
        response = {
            "jsonrpc": "2.0",
            "id": req_id,
            "result": result,
        }
        body = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_jsonrpc_error(self, req_id, code, message):
        """Send a JSON-RPC error response."""
        response = {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {
                "code": code,
                "message": message,
            },
        }
        body = json.dumps(response).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    if len(sys.argv) < 2:
        print("Usage: python a2a_reference_server.py <port>", file=sys.stderr)
        sys.exit(1)

    port = int(sys.argv[1])
    AGENT_CARD["url"] = f"http://localhost:{port}"

    server = HTTPServer(("127.0.0.1", port), A2ARequestHandler)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    # Write port file if specified
    import os
    port_file = os.environ.get("A2A_REF_PORT_FILE")
    if port_file:
        with open(port_file, "w") as f:
            f.write(f"{port}\n")

    print(f"A2A reference server started on port {port}", file=sys.stderr)
    print(f"PORT={port}")
    sys.stdout.flush()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
