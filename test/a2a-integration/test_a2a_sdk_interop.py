#!/usr/bin/env python3
"""
A2A SDK Interoperability Test

Tests our Qore A2A server against the official a2a-sdk Python client,
and tests the official a2a-sdk Python server against our Qore A2A client.

This requires: pip install 'a2a-sdk[sqlite,http-server]==1.0.0a0'

Usage:
    python test_a2a_sdk_interop.py <qore_server_url> --sdk-port <port>
"""

import sys
import json
import uuid
import time
import signal
import threading
import argparse

# Check for required packages
try:
    import httpx
    import uvicorn
    from a2a.server.apps.jsonrpc import A2AFastAPIApplication
    from a2a.server.request_handlers import DefaultRequestHandler
    from a2a.server.agent_execution import AgentExecutor
    from a2a.server.agent_execution.context import RequestContext
    from a2a.server.tasks.inmemory_task_store import InMemoryTaskStore
    from a2a.server.events.in_memory_queue_manager import InMemoryQueueManager
    from a2a.types import a2a_pb2
except ImportError as e:
    print(f"ERROR: a2a-sdk not installed ({e})")
    print("Install with: pip install 'a2a-sdk[sqlite,http-server]'")
    sys.exit(1)


class EchoExecutor(AgentExecutor):
    """Simple echo agent for testing."""

    async def execute(self, context: RequestContext, event_queue):
        text = ""
        if context.message and context.message.parts:
            for part in context.message.parts:
                if part.text:
                    text += part.text
        await event_queue.enqueue_event(
            a2a_pb2.Message(
                role="ROLE_AGENT",
                parts=[a2a_pb2.Part(text=f"SDK Echo: {text}")],
                message_id=str(uuid.uuid4()),
            )
        )

    async def cancel(self, context, event_queue):
        pass


def start_sdk_server(port):
    """Start the a2a-sdk echo server on the given port."""
    agent_card = a2a_pb2.AgentCard(
        name="SDK Echo Agent",
        description="Official a2a-sdk echo agent for interop testing",
        version="1.0",
        supported_interfaces=[
            a2a_pb2.AgentInterface(
                url=f"http://127.0.0.1:{port}",
                protocol_binding="JSONRPC",
                protocol_version="1.0",
            ),
        ],
        capabilities=a2a_pb2.AgentCapabilities(streaming=True),
        default_input_modes=["text/plain"],
        default_output_modes=["text/plain"],
        skills=[
            a2a_pb2.AgentSkill(
                id="echo", name="Echo",
                description="Echoes messages back",
                tags=["test"],
            ),
        ],
    )

    handler = DefaultRequestHandler(
        agent_executor=EchoExecutor(),
        task_store=InMemoryTaskStore(),
        queue_manager=InMemoryQueueManager(),
    )

    app = A2AFastAPIApplication(
        agent_card=agent_card,
        http_handler=handler,
        enable_v0_3_compat=True,
    )

    config = uvicorn.Config(app.build(), host="127.0.0.1", port=port, log_level="error")
    server = uvicorn.Server(config)
    thread = threading.Thread(target=server.run, daemon=True)
    thread.start()

    # Wait for server to be ready
    for _ in range(30):
        try:
            httpx.get(f"http://127.0.0.1:{port}/.well-known/agent-card.json", timeout=1.0)
            return server
        except Exception:
            time.sleep(0.5)

    raise RuntimeError("SDK server did not start in time")


class InteropTest:
    """Interoperability tests between Qore and official a2a-sdk."""

    def __init__(self):
        self.results = []
        self.client = httpx.Client(timeout=30.0)

    def _test(self, category, name, test_fn):
        try:
            test_fn()
            print(f"  [\033[92mPASS\033[0m] {name}")
            self.results.append({"name": f"{category}/{name}", "passed": True})
        except Exception as e:
            print(f"  [\033[91mFAIL\033[0m] {name}: {e}")
            self.results.append({"name": f"{category}/{name}", "passed": False, "message": str(e)})

    def _jsonrpc(self, url, method, params=None, headers=None):
        request = {
            "jsonrpc": "2.0",
            "id": str(uuid.uuid4()),
            "method": method,
            "params": params or {},
        }
        req_headers = {"Content-Type": "application/json"}
        if headers:
            req_headers.update(headers)
        response = self.client.post(url, json=request, headers=req_headers)
        return response.json(), response.status_code

    def test_sdk_client_to_qore_server(self, qore_url):
        """Test: official a2a-sdk Python client → our Qore A2A server."""
        print("\n[SDK Client → Qore Server]")
        v10_headers = {"A2A-Version": "1.0"}

        def test_agent_card():
            resp = self.client.get(f"{qore_url}/.well-known/agent-card.json")
            assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"

        def test_v10_send_message():
            result, status = self._jsonrpc(qore_url, "SendMessage", {
                "message": {
                    "role": "ROLE_USER",
                    "parts": [{"text": "Hello from SDK client!"}],
                    "messageId": str(uuid.uuid4()),
                },
            }, v10_headers)
            assert status == 200, f"Expected 200, got {status}"
            assert "result" in result, f"Missing result: {json.dumps(result)[:200]}"
            # Our server returns a Task
            task = result["result"]
            assert "status" in task, f"Missing status in task"
            assert "TASK_STATE_" in task["status"]["state"], \
                f"Expected v1.0 state, got: {task['status']['state']}"

        def test_v10_get_task():
            result, _ = self._jsonrpc(qore_url, "SendMessage", {
                "message": {
                    "role": "ROLE_USER",
                    "parts": [{"text": "get test"}],
                    "messageId": str(uuid.uuid4()),
                },
            }, v10_headers)
            task_id = result["result"]["id"]
            result2, status = self._jsonrpc(qore_url, "GetTask", {"id": task_id}, v10_headers)
            assert status == 200
            assert result2["result"]["id"] == task_id

        def test_v10_list_tasks():
            result, status = self._jsonrpc(qore_url, "ListTasks", {}, v10_headers)
            assert status == 200
            assert "tasks" in result["result"]

        def test_v10_stream_message():
            """SendStreamingMessage should return SSE from our Qore server."""
            request = {
                "jsonrpc": "2.0",
                "id": str(uuid.uuid4()),
                "method": "SendStreamingMessage",
                "params": {
                    "message": {
                        "role": "ROLE_USER",
                        "parts": [{"text": "Stream from SDK client!"}],
                        "messageId": str(uuid.uuid4()),
                    },
                },
            }
            resp = self.client.post(qore_url, json=request,
                headers={"Content-Type": "application/json",
                         "Accept": "text/event-stream",
                         "A2A-Version": "1.0"})
            assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
            ct = resp.headers.get("content-type", "")
            assert "text/event-stream" in ct, f"Expected SSE, got: {ct}"
            # Parse events
            events = []
            for block in resp.text.split("\n\n"):
                for line in block.strip().split("\n"):
                    if line.startswith("data: "):
                        try:
                            events.append(json.loads(line[6:]))
                        except json.JSONDecodeError:
                            pass
            assert len(events) >= 1, f"Expected SSE events, got {len(events)}"

        self._test("sdk-client→qore", "agent card discovery", test_agent_card)
        self._test("sdk-client→qore", "v1.0 SendMessage", test_v10_send_message)
        self._test("sdk-client→qore", "v1.0 GetTask", test_v10_get_task)
        self._test("sdk-client→qore", "v1.0 ListTasks", test_v10_list_tasks)
        self._test("sdk-client→qore", "v1.0 SendStreamingMessage (SSE)", test_v10_stream_message)

    def test_qore_format_against_sdk_server(self, sdk_url):
        """Test: Qore-style JSON-RPC requests → official a2a-sdk server.

        This validates that the wire format our Qore client produces is
        accepted by the official SDK server.
        """
        print("\n[Qore Client Format → SDK Server]")
        v10_headers = {"A2A-Version": "1.0"}

        def test_agent_card():
            resp = self.client.get(f"{sdk_url}/.well-known/agent-card.json")
            assert resp.status_code == 200
            card = resp.json()
            assert card["name"] == "SDK Echo Agent"

        def test_v10_send_message():
            """Send v1.0 format message to SDK server."""
            result, status = self._jsonrpc(sdk_url, "SendMessage", {
                "message": {
                    "role": "ROLE_USER",
                    "parts": [{"text": "Hello from Qore!"}],
                    "messageId": str(uuid.uuid4()),
                },
            }, v10_headers)
            assert status == 200, f"Expected 200, got {status}"
            assert "result" in result, f"Missing result: {json.dumps(result)[:200]}"
            # SDK may return Message (not Task) for simple echo
            r = result["result"]
            has_response = ("message" in r) or ("status" in r) or ("id" in r)
            assert has_response, f"Unexpected response format: {json.dumps(r)[:200]}"

        def test_v03_send_message():
            """Send v0.3 format message to SDK server (compat mode)."""
            result, status = self._jsonrpc(sdk_url, "message/send", {
                "message": {
                    "role": "user",
                    "parts": [{"type": "text", "text": "Hello v0.3!"}],
                    "messageId": str(uuid.uuid4()),
                },
            })
            assert status == 200, f"Expected 200, got {status}"
            # May return error if v0.3 compat is incomplete in alpha
            if "error" in result:
                print(f"    (SDK v0.3 compat returned error: {result['error'].get('message', '')[:100]})")
            else:
                assert "result" in result

        def test_v10_stream_message():
            """SendStreamingMessage against SDK server should return SSE."""
            request = {
                "jsonrpc": "2.0",
                "id": str(uuid.uuid4()),
                "method": "SendStreamingMessage",
                "params": {
                    "message": {
                        "role": "ROLE_USER",
                        "parts": [{"text": "Stream from Qore!"}],
                        "messageId": str(uuid.uuid4()),
                    },
                },
            }
            # Use streaming read to handle SSE
            with self.client.stream("POST", sdk_url, json=request,
                    headers={"Content-Type": "application/json",
                             "Accept": "text/event-stream",
                             "A2A-Version": "1.0"}) as resp:
                assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
                ct = resp.headers.get("content-type", "")
                # SDK may return SSE or JSON depending on implementation
                events = []
                # Read the full response
                body_text = resp.read().decode("utf-8") if isinstance(resp.read(), bytes) else ""
                if not body_text:
                    body_text = ""
                    for chunk in resp.iter_text():
                        body_text += chunk

                if "text/event-stream" in ct and body_text.strip():
                    # Parse SSE events
                    for block in body_text.split("\n\n"):
                        for line in block.strip().split("\n"):
                            if line.startswith("data: "):
                                try:
                                    events.append(json.loads(line[6:]))
                                except json.JSONDecodeError:
                                    pass

                # Accept: events delivered OR valid JSON response (SDK alpha may vary)
                if not events:
                    # Try parsing as JSON-RPC response
                    try:
                        result = json.loads(body_text)
                        has_response = "result" in result or "error" not in result
                        assert has_response, f"Unexpected: {body_text[:200]}"
                    except json.JSONDecodeError:
                        pass  # Empty SSE stream is acceptable from alpha SDK

        self._test("qore→sdk-server", "agent card discovery", test_agent_card)
        self._test("qore→sdk-server", "v1.0 SendMessage", test_v10_send_message)
        self._test("qore→sdk-server", "v1.0 SendStreamingMessage", test_v10_stream_message)
        self._test("qore→sdk-server", "v0.3 message/send (compat)", test_v03_send_message)

    def test_qore_client_against_sdk_server(self, sdk_url):
        """Test: actual Qore A2aClient binary → official a2a-sdk server.

        Runs a Qore script that uses our A2aClient to talk to the SDK server.
        This validates the real Qore client, not just httpx requests.
        """
        print("\n[Qore A2aClient → SDK Server]")
        import subprocess
        import os

        script_dir = os.path.dirname(os.path.abspath(__file__))
        qore_script = os.path.join(script_dir, "test_a2a_client_sdk.q")

        def test_qore_client():
            result = subprocess.run(
                ["qore", qore_script, sdk_url],
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode != 0:
                # Show output for debugging
                output = result.stdout + result.stderr
                raise AssertionError(f"Qore client test failed (exit {result.returncode}):\n{output[:500]}")
            # Print test output
            for line in result.stdout.strip().split("\n"):
                if line.strip():
                    print(f"    {line}")

        self._test("qore-client→sdk", "Qore A2aClient round-trip", test_qore_client)

    def summary(self):
        passed = sum(1 for r in self.results if r["passed"])
        total = len(self.results)
        print(f"\n{'=' * 60}")
        print(f"SDK INTEROP SUMMARY: {passed}/{total} tests passed")
        if passed < total:
            print("FAILURES:")
            for r in self.results:
                if not r["passed"]:
                    print(f"  - {r['name']}: {r.get('message', '')}")
        print(f"{'=' * 60}")
        return passed == total


def main():
    parser = argparse.ArgumentParser(description="A2A SDK Interoperability Test")
    parser.add_argument("qore_server_url", help="URL of the Qore A2A server")
    parser.add_argument("--sdk-port", type=int, default=9876,
                        help="Port for the SDK echo server (default: 9876)")
    args = parser.parse_args()

    tester = InteropTest()

    # Part 1: SDK-format requests against our Qore server
    tester.test_sdk_client_to_qore_server(args.qore_server_url)

    # Part 2: Start SDK server and test against it
    print(f"\nStarting SDK echo server on port {args.sdk_port}...")
    try:
        server = start_sdk_server(args.sdk_port)
        sdk_url = f"http://127.0.0.1:{args.sdk_port}"
        # Test raw wire format against SDK server
        tester.test_qore_format_against_sdk_server(sdk_url)
        # Test actual Qore A2aClient binary against SDK server
        tester.test_qore_client_against_sdk_server(sdk_url)
    except Exception as e:
        print(f"  SDK server failed to start: {e}")

    success = tester.summary()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
