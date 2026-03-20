# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file A2aServerConnection.qc @brief A2A Server SSE connection class

/*  A2aServerConnection.qc Copyright (C) 2026 Qore Technologies, s.r.o.

    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"),
    to deal in the Software without restriction, including without limitation
    the rights to use, copy, modify, merge, publish, distribute, sublicense,
    and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
    DEALINGS IN THE SOFTWARE.
*/

#! the %A2aServerHandler namespace holds all public definitions in the %A2aServerHandler module
public namespace A2aServerHandler {
#! A2A server SSE connection for streaming task updates
/** Provides access to the A2A session and helper methods to send task events.
*/
public class A2aServerConnection inherits ServerSentEventHandler::ServerSentEventConnection {
    private {
        #! The session identifier
        string session;
    }

    constructor(A2aServerHandler handler, Socket sock, hash<auto> cx, hash<auto> hdr, string cid)
            : ServerSentEventConnection(handler, sock, cx, hdr, cid) {
        self.session = handler.getSessionId(hdr);
    }

    string getSession() {
        return session;
    }

    #! Send a task status update event
    sendTaskStatusUpdate(string task_id, hash<auto> status) {
        send(<SseMessageInfo>{
            "event": "TaskStatusUpdateEvent",
            "data": make_json({
                "jsonrpc": "2.0",
                "method": "TaskStatusUpdateEvent",
                "params": status + {"id": task_id},
            }),
        });
    }

    #! Send a task artifact update event
    sendTaskArtifactUpdate(string task_id, hash<auto> artifact) {
        send(<SseMessageInfo>{
            "event": "TaskArtifactUpdateEvent",
            "data": make_json({
                "jsonrpc": "2.0",
                "method": "TaskArtifactUpdateEvent",
                "params": artifact + {"id": task_id},
            }),
        });
    }

    #! Send a task message update event for streaming tokens
    /** @param task_id the task ID
        @param partial the partial message data (e.g., partial text parts)
    */
    sendTaskMessageUpdate(string task_id, hash<auto> partial) {
        send(<SseMessageInfo>{
            "event": "TaskMessageUpdateEvent",
            "data": make_json({
                "jsonrpc": "2.0",
                "method": "TaskMessageUpdateEvent",
                "params": partial + {"id": task_id},
            }),
        });
    }
}
}
