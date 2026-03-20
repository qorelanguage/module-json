# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file A2aServerHandler.qc @brief A2A Server class definition for the HttpServer module

/*  A2aServerHandler.qc Copyright (C) 2026 Qore Technologies, s.r.o.

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

#! A2A task information
public hashdecl A2aTaskInfo {
    #! Unique task identifier
    string id;

    #! Context identifier
    *string contextId;

    #! Current state
    string state;

    #! Status message (JSON-serialized)
    *string statusMessage;

    #! Message history
    list<hash<auto>> history;

    #! Task artifacts
    list<hash<auto>> artifacts;

    #! Task metadata
    *hash<auto> metadata;

    #! When the task was created
    date createdAt;

    #! When the task was last updated
    date lastUpdatedAt;

    #! Session ID
    *string sessionId;

    #! Condition variable for blocking waits
    Qore::Thread::Condition cond;

    #! Mutex for condition variable
    Qore::Thread::Mutex lck;
}

#! A2aServerHandler class definition; to be registered as a handler in the HttpServer class
/**
*/
public class A2aServerHandler inherits JsonRpcHandler, ServerSentEventHandler {
    public {
        #! Default SSE handler options
        const SseHandlerOpts = {
            # JSON serialization is performed by this object when needed
            "data": "none",
        };

        #! Default session timeout in seconds (1 hour)
        const DefaultSessionTimeoutSecs = 3600;
    }

    private {
        #! Agent card metadata
        hash<auto> agent_card;

        #! Extended agent card (optional)
        *hash<auto> extended_agent_card;

        #! Registered skills: id -> skill info
        hash<string, hash<A2aAgentSkill>> skill_map;

        #! Session map; session ID -> session info
        hash<string, hash<A2aSessionInfo>> smap;

        #! Task map; task ID -> task info (global, not per-session)
        hash<string, hash<A2aTaskInfo>> task_map;

        #! Push notification configs; task ID -> list of configs
        hash<string, list<hash<auto>>> push_configs;

        #! Application-level message handler callback
        *code<auto (hash<A2aTaskInfo>, hash<auto>)> message_handler;

        #! Session timeout in seconds
        int session_timeout_secs = DefaultSessionTimeoutSecs;

        #! Task ID counter
        int task_id_counter = 0;

        #! Request ID counter
        int rpc_rid = 0;

        #! Per-session ID counter
        hash<string, int> sidmap;

        #! Push notification config ID counter
        int push_config_id_counter = 0;
    }

    #! Creates the handler with a logger, agent card, and authenticator
    constructor(Logger::LoggerInterface logger, hash<auto> agent_card,
            HttpServer::AbstractAuthenticator auth)
            : JsonRpcHandler(logger, auth), ServerSentEventHandler(auth, SseHandlerOpts) {
        self.agent_card = agent_card;
        if (agent_card.skills) {
            foreach hash<auto> skill in (agent_card.skills) {
                skill_map{skill.id} = cast<hash<A2aAgentSkill>>(skill);
            }
        }
        setupMethods();
    }

    #! Creates the handler with a logger and agent card (no auth)
    constructor(Logger::LoggerInterface logger, hash<auto> agent_card)
            : JsonRpcHandler(logger, new PermissiveAuthenticator()),
              ServerSentEventHandler(new PermissiveAuthenticator(), SseHandlerOpts) {
        self.agent_card = agent_card;
        if (agent_card.skills) {
            foreach hash<auto> skill in (agent_card.skills) {
                skill_map{skill.id} = cast<hash<A2aAgentSkill>>(skill);
            }
        }
        setupMethods();
    }

    #! Sets the message handler callback
    /** @param handler the callback to handle incoming messages; receives:
            - \c hash<A2aTaskInfo> task_info: the task associated with this message
            - \c hash<auto> message: the A2A message
        and should return a response message hash or NOTHING
    */
    setMessageHandler(code<auto (hash<A2aTaskInfo>, hash<auto>)> handler) {
        message_handler = handler;
    }

    #! Sets the agent card
    setAgentCard(hash<auto> card) {
        AutoWriteLock al(rwl);
        agent_card = card;
        if (card.skills) {
            skill_map = {};
            foreach hash<auto> skill in (card.skills) {
                skill_map{skill.id} = cast<hash<A2aAgentSkill>>(skill);
            }
        }
    }

    #! Returns the agent card
    hash<auto> getAgentCard() {
        AutoReadLock al(rwl);
        return agent_card;
    }

    #! Sets the extended agent card
    setExtendedAgentCard(hash<auto> card) {
        AutoWriteLock al(rwl);
        extended_agent_card = card;
    }

    #! Registers a skill
    registerSkill(hash<A2aAgentSkill> skill) {
        AutoWriteLock al(rwl);
        skill_map{skill.id} = skill;
        # Update agent card skills list
        if (!agent_card.skills) {
            agent_card.skills = ();
        }
        agent_card.skills += skill;
    }

    #! Unregisters a skill
    /** @param id the skill ID to unregister
        @return True if the skill was unregistered, False if not found
    */
    bool unregisterSkill(string id) {
        AutoWriteLock al(rwl);
        if (!skill_map{id}) {
            return False;
        }
        remove skill_map{id};
        # Remove from agent card skills list
        if (agent_card.skills) {
            agent_card.skills = (map $1, agent_card.skills, $1.id != id);
        }
        return True;
    }

    #! Handles HTTP requests; dispatches to Agent Card, SSE, or JSON-RPC
    hash<HttpResponseInfo> handleRequest(hash<auto> cx, hash<auto> hdr, *data b) {
        # Serve agent card via GET /.well-known/agent-card.json
        if (cx.hdr.method == "GET" && cx.url.path =~ /\.well-known\/agent-card\.json/) {
            hash<auto> card;
            {
                AutoReadLock al(rwl);
                card = agent_card;
            }
            return AbstractHttpRequestHandler::makeResponse(200, make_json(card),
                {"Content-Type": MimeTypeJson});
        }

        # SSE streaming for GET requests with Accept: text/event-stream
        if (cx.hdr.method == "GET" && clientAcceptsSse(hdr)) {
            return ServerSentEventHandler::handleRequest(cx, hdr, b);
        }

        # POST requests go to JSON-RPC handler
        if (cx.hdr.method == "POST") {
            return JsonRpcHandler::handleRequest(cx, hdr, b);
        }

        return AbstractHttpRequestHandler::makeResponse(405, "Method not allowed");
    }

    #! Creates a new task
    /** @param context_id optional context ID for grouping related tasks
        @param metadata optional task metadata
        @param session_id optional session ID to associate the task with
        @return the task info hash
    */
    hash<A2aTaskInfo> createTask(*string context_id, *hash<auto> metadata, *string session_id) {
        string task_id = generateTaskId();
        date now = now_us();

        hash<A2aTaskInfo> task = <A2aTaskInfo>{
            "id": task_id,
            "contextId": context_id,
            "state": A2aTaskState::Pending,
            "statusMessage": NOTHING,
            "history": (),
            "artifacts": (),
            "metadata": metadata,
            "createdAt": now,
            "lastUpdatedAt": now,
            "sessionId": session_id,
            "cond": new Qore::Thread::Condition(),
            "lck": new Qore::Thread::Mutex(),
        };

        {
            AutoWriteLock al(rwl);
            task_map{task_id} = task;
        }

        return task;
    }

    #! Updates a task's state with transition validation
    /** @param task_id the task ID
        @param new_state the new state
        @param message optional status message
        @return the updated task info

        @throw A2A-TASK-ERROR if the task is not found
        @throw A2A-CONFLICT if the state transition is invalid
    */
    hash<auto> updateTaskState(string task_id, string new_state, *hash<auto> message) {
        hash<auto> status_update;
        hash<auto> response;
        Qore::Thread::Condition task_cond;
        Qore::Thread::Mutex task_lck;

        {
            AutoWriteLock al(rwl);
            *hash<A2aTaskInfo> task = task_map{task_id};
            if (!task) {
                throw "A2A-TASK-ERROR", sprintf("Task %y not found", task_id);
            }

            # Validate state transition
            string current_state = task.state;
            if (A2aValidTransitions{current_state} && !A2aValidTransitions{current_state}{new_state}) {
                throw "A2A-CONFLICT", sprintf("Invalid state transition from %y to %y for task %y",
                    current_state, new_state, task_id);
            }

            # Terminal states cannot transition further
            if (current_state == A2aTaskState::Completed || current_state == A2aTaskState::Failed
                    || current_state == A2aTaskState::Canceled || current_state == A2aTaskState::Rejected) {
                throw "A2A-CONFLICT", sprintf("Cannot transition from terminal state %y for task %y",
                    current_state, task_id);
            }

            date now = now_us();
            string ts = format_date("YYYY-MM-DDTHH:mm:SS.xxZ", now);

            task_map{task_id}.state = new_state;
            if (message) {
                task_map{task_id}.statusMessage = make_json(message);
            } else {
                remove task_map{task_id}.statusMessage;
            }
            task_map{task_id}.lastUpdatedAt = now;

            status_update = cast<hash<auto>>({
                "state": new_state,
                "timestamp": ts,
            });
            if (message) {
                status_update.message = message;
            }

            task_cond = task.cond;
            task_lck = task.lck;

            response = getTaskResponse(task_map{task_id});
        }

        # Notify waiting threads (outside write lock)
        task_lck.lock();
        on_exit task_lck.unlock();
        task_cond.broadcast();

        # Send push notifications (outside write lock to avoid deadlock)
        sendTaskPushNotification(task_id, "TaskStatusUpdateEvent", status_update);

        # Notify SSE connections (outside write lock)
        notifySseConnections(task_id, "TaskStatusUpdateEvent", status_update);

        return response;
    }

    #! Adds an artifact to a task
    /** @param task_id the task ID
        @param artifact the artifact to add

        @throw A2A-TASK-ERROR if the task is not found
    */
    addArtifact(string task_id, hash<auto> artifact) {
        {
            AutoWriteLock al(rwl);
            *hash<A2aTaskInfo> task = task_map{task_id};
            if (!task) {
                throw "A2A-TASK-ERROR", sprintf("Task %y not found", task_id);
            }

            task_map{task_id}.artifacts += artifact;
            task_map{task_id}.lastUpdatedAt = now_us();
        }

        # Send push notifications (outside write lock)
        sendTaskPushNotification(task_id, "TaskArtifactUpdateEvent", artifact);

        # Notify SSE connections (outside write lock)
        notifySseConnections(task_id, "TaskArtifactUpdateEvent", artifact);
    }

    #! Returns the number of active sessions
    int getSessionCount() {
        AutoReadLock al(rwl);
        return smap.size();
    }

    #! Returns the number of active tasks
    int getTaskCount() {
        AutoReadLock al(rwl);
        return task_map.size();
    }

    private hash<auto> messageSend(hash<auto> cx, *hash<auto> params) {
        try {
            return messageSendIntern(cx, params);
        } catch (hash<ExceptionInfo> ex) {
            error("Error in message/send: %s: %s", ex.err, ex.desc);
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, sprintf("%s: %s", ex.err, ex.desc));
        }
    }

    private hash<auto> messageSendIntern(hash<auto> cx, *hash<auto> params) {
        if (!params.message) {
            throw "A2A-INVALID-REQUEST", "Missing 'message' parameter";
        }

        # Create a new task
        hash<A2aTaskInfo> task = createTask(params.contextId, params.metadata, params.sessionId);
        string task_id = task.id;

        # Add the incoming message to history
        {
            AutoWriteLock al(rwl);
            task_map{task_id}.history += params.message;
        }

        # Transition to active
        updateTaskState(task_id, A2aTaskState::Active);

        # Call message handler if registered
        if (message_handler) {
            try {
                auto response = message_handler(task, params.message);
                if (response) {
                    # Add response to history and complete the task
                    {
                        AutoWriteLock al(rwl);
                        task_map{task_id}.history += response;
                    }
                    # Only complete if not already in a terminal state
                    string current_state;
                    {
                        AutoReadLock al(rwl);
                        current_state = task_map{task_id}.state;
                    }
                    if (current_state != A2aTaskState::Completed
                            && current_state != A2aTaskState::Failed
                            && current_state != A2aTaskState::Canceled
                            && current_state != A2aTaskState::Rejected) {
                        updateTaskState(task_id, A2aTaskState::Completed, response);
                    }
                }
            } catch (hash<ExceptionInfo> ex) {
                if (ex.err == "A2A-CONFLICT") {
                    # Task already in terminal state - ignore
                } else {
                    error("Message handler error: %s: %s", ex.err, ex.desc);
                    # Only fail if not already in a terminal state
                    try {
                        updateTaskState(task_id, A2aTaskState::Failed, {
                            "role": "agent",
                            "parts": ({"type": "text", "text": sprintf("Error: %s: %s", ex.err, ex.desc)},),
                        });
                    } catch () {
                        # Ignore if state transition fails
                    }
                }
            }
        }

        AutoReadLock al(rwl);
        return getTaskResponse(task_map{task_id});
    }

    private hash<auto> messageStream(hash<auto> cx, *hash<auto> params) {
        # message/stream uses the same handler as message/send; SSE streaming of task updates
        # is handled via the SSE transport layer and push notifications independently
        return messageSend(cx, params);
    }

    private hash<auto> tasksGet(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }

        AutoReadLock al(rwl);
        *hash<A2aTaskInfo> task = task_map{params.id};
        if (!task) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND, sprintf("Task %y not found", params.id));
        }

        return getTaskResponse(task, params.historyLength);
    }

    private hash<auto> tasksCancel(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }

        try {
            return updateTaskState(params.id, A2aTaskState::Canceled);
        } catch (hash<ExceptionInfo> ex) {
            if (ex.err == "A2A-TASK-ERROR") {
                return makeJsonRpcError(A2A_ERR_NOT_FOUND, ex.desc);
            }
            if (ex.err == "A2A-CONFLICT") {
                return makeJsonRpcError(A2A_ERR_CONFLICT, ex.desc);
            }
            rethrow;
        }
    }

    private hash<auto> tasksList(hash<auto> cx, *hash<auto> params) {
        AutoReadLock al(rwl);

        list<hash<auto>> tasks = ();
        foreach string task_id in (keys task_map) {
            hash<A2aTaskInfo> task = task_map{task_id};
            # Filter by contextId if provided
            if (params.contextId && task.contextId != params.contextId) {
                continue;
            }
            tasks += getTaskResponse(task);
        }

        return {"tasks": tasks};
    }

    private hash<auto> tasksResubscribe(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }

        AutoReadLock al(rwl);
        *hash<A2aTaskInfo> task = task_map{params.id};
        if (!task) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND, sprintf("Task %y not found", params.id));
        }

        return getTaskResponse(task);
    }

    private hash<auto> pushNotificationConfigSet(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }
        if (!params.pushNotificationConfig) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'pushNotificationConfig' parameter");
        }

        AutoWriteLock al(rwl);
        if (!task_map{params.id}) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND, sprintf("Task %y not found", params.id));
        }
        if (!push_configs{params.id}) {
            push_configs{params.id} = ();
        }
        hash<auto> config = params.pushNotificationConfig + {
            "id": sprintf("%d", ++push_config_id_counter),
        };
        push_configs{params.id} += config;

        return {"id": params.id, "pushNotificationConfigId": config.id};
    }

    private hash<auto> pushNotificationConfigGet(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }

        AutoReadLock al(rwl);
        if (!task_map{params.id}) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND, sprintf("Task %y not found", params.id));
        }

        return {
            "id": params.id,
            "pushNotificationConfig": push_configs{params.id}[0] ?? {},
        };
    }

    private hash<auto> pushNotificationConfigList(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }

        AutoReadLock al(rwl);
        if (!task_map{params.id}) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND, sprintf("Task %y not found", params.id));
        }

        return {
            "id": params.id,
            "pushNotificationConfigs": push_configs{params.id} ?? (),
        };
    }

    private hash<auto> pushNotificationConfigDelete(hash<auto> cx, *hash<auto> params) {
        if (!params.id) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT, "Missing 'id' parameter");
        }
        if (!params.pushNotificationConfigId) {
            return makeJsonRpcError(A2A_ERR_INVALID_ARGUMENT,
                "Missing 'pushNotificationConfigId' parameter");
        }

        AutoWriteLock al(rwl);
        if (!task_map{params.id}) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND, sprintf("Task %y not found", params.id));
        }
        *list<hash<auto>> configs = push_configs{params.id};
        if (!configs) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND,
                sprintf("No push notification configs found for task %y", params.id));
        }
        # Filter out the config with the matching ID
        list<hash<auto>> new_configs = (map $1, configs, $1.id != params.pushNotificationConfigId);
        if (new_configs.size() == configs.size()) {
            return makeJsonRpcError(A2A_ERR_NOT_FOUND,
                sprintf("Push notification config %y not found for task %y",
                    params.pushNotificationConfigId, params.id));
        }
        if (new_configs) {
            push_configs{params.id} = new_configs;
        } else {
            remove push_configs{params.id};
        }

        return {"id": params.id};
    }

    private hash<auto> getAuthenticatedExtendedCardMethod(hash<auto> cx, *hash<auto> params) {
        AutoReadLock al(rwl);
        if (extended_agent_card) {
            return extended_agent_card;
        }
        # Return the standard agent card if no extended card is set
        return agent_card;
    }

    #! Returns a task response hash suitable for JSON-RPC response
    private hash<auto> getTaskResponse(hash<A2aTaskInfo> task, *int history_length) {
        string ts = format_date("YYYY-MM-DDTHH:mm:SS.xxZ", task.lastUpdatedAt);

        hash<auto> status = cast<hash<auto>>({
            "state": task.state,
            "timestamp": ts,
        });
        if (task.statusMessage) {
            status.message = parse_json(task.statusMessage);
        }

        hash<auto> response = cast<hash<auto>>({
            "id": task.id,
            "status": status,
        });
        if (task.contextId) {
            response.contextId = task.contextId;
        }

        # Include history with optional length limit
        if (task.history) {
            if (history_length > 0 && task.history.size() > history_length) {
                response.history = task.history[(task.history.size() - history_length)..];
            } else {
                response.history = task.history;
            }
        }

        if (task.artifacts) {
            response.artifacts = task.artifacts;
        }
        if (task.metadata) {
            response.metadata = task.metadata;
        }

        return response;
    }

    #! Makes a JSON-RPC error response
    private hash<auto> makeJsonRpcError(int code, string message) {
        throw "JSONRPC-ERROR", message, code;
    }

    #! Sends push notifications for a task event
    private sendTaskPushNotification(string task_id, string event_type, hash<auto> event_data) {
        *list<hash<auto>> configs;
        {
            AutoReadLock al(rwl);
            configs = push_configs{task_id};
        }

        if (!configs) {
            return;
        }

        foreach hash<auto> config in (configs) {
            try {
                # Deliver push notification via HTTP POST
                Qore::HTTPClient push_client({"url": config.url, "timeout": 10000});
                hash<auto> payload = {
                    "jsonrpc": "2.0",
                    "method": event_type,
                    "params": event_data + {"id": task_id},
                };
                push_client.send(make_json(payload), "POST", NOTHING,
                    {"Content-Type": MimeTypeJson});
            } catch (hash<ExceptionInfo> ex) {
                error("Push notification delivery failed for task %y to %y: %s: %s",
                    task_id, config.url, ex.err, ex.desc);
            }
        }
    }

    #! Sends an event to SSE connections belonging to the task's session
    private notifySseConnections(string task_id, string event_type, hash<auto> event_data) {
        list<A2aServerConnection> conns;
        {
            AutoReadLock al(rwl);
            *string session_id = task_map{task_id}.sessionId;
            if (session_id && smap{session_id}) {
                # Only notify SSE connections in the task's session
                foreach A2aServerConnection conn in (smap{session_id}.ssemap.iterator()) {
                    conns += conn;
                }
            } else {
                # No session ID on task: broadcast to all sessions
                foreach string sid in (keys smap) {
                    foreach A2aServerConnection conn in (smap{sid}.ssemap.iterator()) {
                        conns += conn;
                    }
                }
            }
        }

        hash<auto> payload = {
            "jsonrpc": "2.0",
            "method": event_type,
            "params": event_data + {"id": task_id},
        };

        foreach A2aServerConnection conn in (conns) {
            try {
                conn.send(<SseMessageInfo>{
                    "event": event_type,
                    "data": make_json(payload),
                });
            } catch (hash<ExceptionInfo> ex) {
                error("SSE notification failed: %s: %s", ex.err, ex.desc);
            }
        }
    }

    #! Generates a unique task ID
    private string generateTaskId() {
        AutoWriteLock al(rwl);
        return sprintf("task-%d-%d", getpid(), ++task_id_counter);
    }

    #! Returns the next request ID
    string getNextRequestId() {
        AutoWriteLock al(rwl);
        return "s" + rpc_rid++;
    }

    int getNextIdForSession(string session) {
        AutoWriteLock al(rwl);
        return ++sidmap{session};
    }

    string getSessionId(hash<auto> hdr) {
        string session;
%ifdef NoUuid
        session = get_random_string(50);
%else
        session = UUID::get();
%endif
        AutoWriteLock al(rwl);
        smap{session} = <A2aSessionInfo>{
            "session": session,
            "ssemap": {},
            "last_activity": now_us(),
        };
        return session;
    }

    #! Called when an SSE connection is established
    ServerSentEventConnection getConnectionImpl(Socket sock, hash<auto> cx, hash<auto> hdr, string cid) {
        return new A2aServerConnection(self, sock, cx, hdr, cid);
    }

    private static bool clientAcceptsSse(hash<auto> hdr) {
        *string astr = hdr.accept;
        if (!astr.val()) {
            return False;
        }

        do {
            astr =~ s/;[^,]*//;
        } while (astr.rfind(";") != -1);
        astr =~ s/ +//g;
        hash<auto> aih;
        map aih.$1 = True, astr.split(",");
        return aih{MimeTypeSse} || aih."*/*";
    }

    #! Called while holding the write lock to register the new connection
    private registerNewConnectionIntern(string cid, ServerSentEventConnection conn) {
        ServerSentEventHandler::registerNewConnectionIntern(cid, conn);
        A2aServerConnection a2a_conn = cast<A2aServerConnection>(conn);
        smap{a2a_conn.getSession()}.ssemap{conn.uniqueHash()} = a2a_conn;
    }

    #! Sets up JSON-RPC method dispatch
    private setupMethods() {
        addMethods((
            {
                "name": "^message/send$",
                "text": "message/send",
                "function": \messageSend(),
                "help": "A2A send message to agent",
                "include_context": True,
            },
            {
                "name": "^message/stream$",
                "text": "message/stream",
                "function": \messageStream(),
                "help": "A2A send message with streaming response",
                "include_context": True,
            },
            {
                "name": "^tasks/get$",
                "text": "tasks/get",
                "function": \tasksGet(),
                "help": "A2A get task status",
                "include_context": True,
            },
            {
                "name": "^tasks/cancel$",
                "text": "tasks/cancel",
                "function": \tasksCancel(),
                "help": "A2A cancel a task",
                "include_context": True,
            },
            {
                "name": "^tasks/list$",
                "text": "tasks/list",
                "function": \tasksList(),
                "help": "A2A list tasks",
                "include_context": True,
            },
            {
                "name": "^tasks/resubscribe$",
                "text": "tasks/resubscribe",
                "function": \tasksResubscribe(),
                "help": "A2A resubscribe to task events",
                "include_context": True,
            },
            {
                "name": "^tasks/pushNotificationConfig/set$",
                "text": "tasks/pushNotificationConfig/set",
                "function": \pushNotificationConfigSet(),
                "help": "A2A set push notification config",
                "include_context": True,
            },
            {
                "name": "^tasks/pushNotificationConfig/get$",
                "text": "tasks/pushNotificationConfig/get",
                "function": \pushNotificationConfigGet(),
                "help": "A2A get push notification config",
                "include_context": True,
            },
            {
                "name": "^tasks/pushNotificationConfig/list$",
                "text": "tasks/pushNotificationConfig/list",
                "function": \pushNotificationConfigList(),
                "help": "A2A list push notification configs",
                "include_context": True,
            },
            {
                "name": "^tasks/pushNotificationConfig/delete$",
                "text": "tasks/pushNotificationConfig/delete",
                "function": \pushNotificationConfigDelete(),
                "help": "A2A delete push notification config",
                "include_context": True,
            },
            {
                "name": "^agent/getAuthenticatedExtendedCard$",
                "text": "agent/getAuthenticatedExtendedCard",
                "function": \getAuthenticatedExtendedCardMethod(),
                "help": "A2A get authenticated extended agent card",
                "include_context": True,
            },
        ));
    }
}

} # namespace A2aServerHandler

namespace Priv {
hashdecl A2aSessionInfo {
    # Session ID
    string session;

    # Active SSE connections
    hash<string, A2aServerConnection> ssemap;

    # Last activity timestamp
    date last_activity;

    # Task IDs associated with this session
    *list<string> task_ids;
}

}
