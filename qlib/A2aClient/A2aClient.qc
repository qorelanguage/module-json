# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file A2aClient.qc @brief A2A Client class implementation

/*  A2aClient.qc Copyright (C) 2026 Qore Technologies, s.r.o.

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

#! the %A2aClient namespace holds all public definitions in the %A2aClient module
public namespace A2aClient {

#! A2A task state enum
/** @since json 1.11
*/
public enum A2aTaskState : string {
    #! Task is waiting to be processed
    Pending = "pending",
    #! Task is currently being processed
    Active = "active",
    #! Task requires additional user input
    InputRequired = "input-required",
    #! Task requires authentication
    AuthRequired = "auth-required",
    #! Task completed successfully
    Completed = "completed",
    #! Task failed with an error
    Failed = "failed",
    #! Task was canceled
    Canceled = "canceled",
    #! Task was rejected by the agent
    Rejected = "rejected",
}

#! A2A message role enum
/** @since json 1.11
*/
public enum A2aMessageRole : string {
    #! Message from the user
    User = "user",
    #! Message from the agent
    Agent = "agent",
}

#! A2A part type enum
/** @since json 1.11
*/
public enum A2aPartType : string {
    #! Text content
    TextPart = "text",
    #! File content (inline or URI)
    FilePart = "file",
    #! Structured data content
    DataPart = "data",
}

#! A2A security scheme type enum
/** @since json 1.11
*/
public enum A2aSecuritySchemeType : string {
    #! API key authentication
    ApiKey = "apiKey",
    #! HTTP authentication (e.g. Bearer, Basic)
    Http = "http",
    #! OAuth 2.0
    OAuth2 = "oauth2",
    #! OpenID Connect
    OpenIdConnect = "openIdConnect",
    #! Mutual TLS
    MutualTls = "mutualTLS",
}

#! A2A error codes per specification
public const A2A_ERR_UNAUTHORIZED = -32000;
public const A2A_ERR_FORBIDDEN = -32001;
public const A2A_ERR_NOT_FOUND = -32002;
public const A2A_ERR_CONFLICT = -32003;
public const A2A_ERR_INVALID_ARGUMENT = -32004;
public const A2A_ERR_SERVICE_UNAVAILABLE = -32005;
public const A2A_ERR_REQUEST_TIMEOUT = -32006;

#! Valid task state transitions
public const A2aValidTransitions = {
    A2aTaskState::Pending: {
        A2aTaskState::Active: True,
        A2aTaskState::Canceled: True,
        A2aTaskState::Rejected: True,
    },
    A2aTaskState::Active: {
        A2aTaskState::InputRequired: True,
        A2aTaskState::AuthRequired: True,
        A2aTaskState::Completed: True,
        A2aTaskState::Failed: True,
        A2aTaskState::Canceled: True,
    },
    A2aTaskState::InputRequired: {
        A2aTaskState::Active: True,
        A2aTaskState::Completed: True,
        A2aTaskState::Failed: True,
        A2aTaskState::Canceled: True,
    },
    A2aTaskState::AuthRequired: {
        A2aTaskState::Active: True,
        A2aTaskState::Completed: True,
        A2aTaskState::Failed: True,
        A2aTaskState::Canceled: True,
    },
};

#! A2A Agent Card information
public hashdecl A2aAgentCard {
    #! Agent name
    string name;

    #! Agent description
    *string description;

    #! Agent URL
    string url;

    #! Agent version
    *string version;

    #! Provider information
    *hash<auto> provider;

    #! Agent skills
    *list<hash<A2aAgentSkill>> skills;

    #! Agent capabilities
    *hash<A2aAgentCapabilities> capabilities;

    #! Security schemes
    *hash<auto> securitySchemes;

    #! Security requirements
    *list<auto> security;

    #! Default input MIME types
    *list<string> defaultInputModes;

    #! Default output MIME types
    *list<string> defaultOutputModes;

    #! Supported interfaces
    *hash<auto> interfaces;

    #! Whether the agent supports authenticated extended card
    *bool supportsAuthenticatedExtendedCard;
}

#! A2A Agent Skill information
public hashdecl A2aAgentSkill {
    #! Unique skill identifier
    string id;

    #! Human-readable skill name
    string name;

    #! Skill description
    *string description;

    #! Supported input MIME types
    *list<string> inputModes;

    #! Supported output MIME types
    *list<string> outputModes;

    #! Tags for categorization
    *list<string> tags;

    #! Example inputs/outputs
    *list<auto> examples;
}

#! A2A Agent Capabilities
public hashdecl A2aAgentCapabilities {
    #! Whether SSE streaming is supported
    *bool streaming;

    #! Whether push notifications are supported
    *bool pushNotifications;

    #! Whether extended agent card is supported
    *bool extendedAgentCard;
}

#! A2A Task information
public hashdecl A2aTask {
    #! Unique task identifier
    string id;

    #! Context identifier for grouping related tasks
    *string contextId;

    #! Current task status
    hash<A2aTaskStatus> status;

    #! Message history
    *list<hash<A2aMessage>> history;

    #! Task artifacts
    *list<hash<A2aArtifact>> artifacts;

    #! Task metadata
    *hash<auto> metadata;
}

#! A2A Task Status
public hashdecl A2aTaskStatus {
    #! Current state
    string state;

    #! Optional status message
    *hash<A2aMessage> message;

    #! Timestamp of the status update
    *string timestamp;
}

#! A2A Message
public hashdecl A2aMessage {
    #! Unique message identifier
    *string messageId;

    #! Message role: user or agent
    string role;

    #! Message parts
    list<hash<auto>> parts;

    #! Referenced task IDs
    *list<string> referenceTaskIds;

    #! Timestamp
    *string timestamp;

    #! Message metadata
    *hash<auto> metadata;
}

#! A2A Artifact
public hashdecl A2aArtifact {
    #! Unique artifact identifier
    *string artifactId;

    #! Artifact name
    *string name;

    #! Artifact description
    *string description;

    #! Artifact parts
    list<hash<auto>> parts;

    #! Artifact metadata
    *hash<auto> metadata;
}

#! A2A Push Notification Configuration
public hashdecl A2aPushNotificationConfig {
    #! Webhook URL for push notifications
    string url;

    #! Authentication for the webhook
    *hash<auto> authentication;

    #! Token for verification
    *string token;
}

#! A2A Text Part
public hashdecl A2aTextPart {
    #! Part type: "text"
    string type = "text";

    #! Text content
    string text;

    #! Part metadata
    *hash<auto> metadata;
}

#! A2A File Part
public hashdecl A2aFilePart {
    #! Part type: "file"
    string type = "file";

    #! File information
    hash<auto> file;

    #! Part metadata
    *hash<auto> metadata;
}

#! A2A Data Part
public hashdecl A2aDataPart {
    #! Part type: "data"
    string type = "data";

    #! Structured data
    auto data;

    #! Part metadata
    *hash<auto> metadata;
}

#! A2A Client class for connecting to A2A agents
/** Provides a client for the Agent-to-Agent (A2A) protocol, enabling agent-to-agent
    collaboration via JSON-RPC 2.0 over HTTP(S) with SSE streaming.

    Unlike MCP, A2A does not require an initialize() handshake. Instead, agents
    are discovered via their Agent Card at \c /.well-known/agent-card.json.

    @par Example:
    @code{.py}
    A2aClient client("http://localhost:8080");

    # Get agent card
    hash<auto> card = client.getAgentCard();

    # Send a message
    hash<auto> task = client.sendMessage({
        "role": "user",
        "parts": ({"type": "text", "text": "Hello!"},),
    });
    @endcode

    @since json 1.11
*/
public class A2aClient {
    public {
        #! Default connect timeout (30 seconds)
        const DefaultConnectTimeout = 30000;

        #! Default I/O timeout (60 seconds)
        const DefaultTimeout = 60000;

        #! Default agent card path
        const AgentCardPath = "/.well-known/agent-card.json";

        #! JSON-RPC version
        const JsonRpcVersion = "2.0";
    }

    private {
        #! The server URL
        string url;

        #! HTTP client for JSON-RPC requests
        Qore::HTTPClient http;

        #! Connect timeout in milliseconds
        int connect_timeout;

        #! Transfer timeout in milliseconds
        int timeout;

        #! JSON-RPC request ID counter
        int rpc_id = 0;

        #! Cached agent card
        *hash<auto> agent_card;

        #! Logger
        *LoggerInterface logger;

        #! Mutex for thread safety
        Mutex lck();

        #! SSE stop flag for streaming operations
        bool sse_stop_flag = False;

        #! SSE listener counter
        Counter sse_cnt();

        #! Callbacks for events
        hash<string, code> callbacks;
    }

    #! Creates the A2aClient with the given URL and options
    /** @param url the URL of the A2A agent
        @param opts optional client options:
            - \c connect_timeout: connection timeout in milliseconds (default: 30000)
            - \c timeout: transfer timeout in milliseconds (default: 60000)
            - \c logger: a LoggerInterface object for logging
    */
    constructor(string url, *hash<auto> opts) {
        self.url = url;
        connect_timeout = opts.connect_timeout ?? DefaultConnectTimeout;
        timeout = opts.timeout ?? DefaultTimeout;
        logger = opts.logger;

        http = new Qore::HTTPClient({
            "url": url,
            "connect_timeout": connect_timeout,
            "timeout": timeout,
            "headers": {
                "Content-Type": MimeTypeJson,
                "Accept": MimeTypeJson,
            },
        });
    }

    #! Destroys the client and cleans up resources
    destructor() {
        close();
    }

    #! Returns the server URL
    string getUrl() {
        return url;
    }

    #! Retrieves the agent card via HTTP GET to \c /.well-known/agent-card.json
    /** @return the agent card information

        @throw A2A-HTTP-ERROR if the HTTP request fails
        @throw A2A-AGENT-CARD-ERROR if the response cannot be parsed
    */
    hash<auto> getAgentCard() {
        hash<auto> info;
        try {
            string response_body = http.get(AgentCardPath, NOTHING, \info);

            hash<auto> response_info = info."response-headers";
            int status_code = response_info.status_code ?? 0;

            if (status_code < 200 || status_code >= 300) {
                throw "A2A-HTTP-ERROR", sprintf("Failed to get agent card: HTTP %d %s",
                    status_code, response_info.status_message ?? "");
            }
            hash<auto> card = parse_json(response_body);
            lck.lock();
            on_exit lck.unlock();
            agent_card = card;
            return card;
        } catch (hash<ExceptionInfo> ex) {
            if (ex.err == "A2A-HTTP-ERROR") {
                rethrow;
            }
            throw "A2A-AGENT-CARD-ERROR", sprintf("Failed to get agent card: %s: %s", ex.err, ex.desc);
        }
    }

    #! Retrieves the authenticated extended agent card via JSON-RPC
    /** @return the extended agent card

        @throw A2A-ERROR if the JSON-RPC call fails
    */
    hash<auto> getAuthenticatedExtendedCard() {
        return doRpcCall("agent/getAuthenticatedExtendedCard");
    }

    #! Sends a message to the agent
    /** @param msg the message to send, must include \c role and \c parts
        @param config optional configuration including \c contextId, \c metadata, etc.

        @return the task resulting from the message

        @throw A2A-ERROR if the JSON-RPC call fails
    */
    hash<auto> sendMessage(hash<auto> msg, *hash<auto> config) {
        hash<auto> params = cast<hash<auto>>({
            "message": msg,
        });
        if (config) {
            params += config;
        }
        return doRpcCall("message/send", params);
    }

    #! Sends a message with SSE streaming for real-time updates
    /** @param msg the message to send
        @param on_event callback called for each SSE event; receives \c (string event_type, hash event_data)
        @param config optional configuration

        @throw A2A-ERROR if the request fails
    */
    sendMessageStream(hash<auto> msg, code<auto (string, hash<auto>)> on_event, *hash<auto> config) {
        hash<auto> params = {
            "message": msg,
        };
        if (config) {
            params += config;
        }
        doRpcStream("message/stream", params, on_event);
    }

    #! Gets task information by ID
    /** @param id the task ID
        @param opts optional parameters (e.g., \c historyLength)

        @return the task information

        @throw A2A-ERROR if the task is not found or the call fails
    */
    hash<auto> getTask(string id, *hash<auto> opts) {
        hash<auto> params = {"id": id};
        if (opts) {
            params += opts;
        }
        return doRpcCall("tasks/get", params);
    }

    #! Cancels a task
    /** @param id the task ID to cancel

        @return the updated task information

        @throw A2A-ERROR if the task cannot be canceled
    */
    hash<auto> cancelTask(string id) {
        return doRpcCall("tasks/cancel", {"id": id});
    }

    #! Lists tasks with optional filtering
    /** @param opts optional parameters for filtering/pagination (e.g., \c contextId, \c limit, \c offset)

        @return task list result

        @throw A2A-ERROR if the call fails
    */
    hash<auto> listTasks(*hash<auto> opts) {
        return doRpcCall("tasks/list", opts);
    }

    #! Resubscribes to SSE events for an existing task
    /** @param id the task ID
        @param on_event callback for SSE events

        @throw A2A-ERROR if the resubscription fails
    */
    resubscribe(string id, code<auto (string, hash<auto>)> on_event) {
        doRpcStream("tasks/resubscribe", {"id": id}, on_event);
    }

    #! Sets push notification configuration for a task
    /** @param task_id the task ID
        @param config the push notification configuration

        @return the result of the operation

        @throw A2A-ERROR if the call fails
    */
    hash<auto> setPushNotificationConfig(string task_id, hash<auto> config) {
        return doRpcCall("tasks/pushNotificationConfig/set", {
            "id": task_id,
            "pushNotificationConfig": config,
        });
    }

    #! Gets push notification configuration for a task
    /** @param task_id the task ID

        @return the push notification configuration

        @throw A2A-ERROR if the call fails
    */
    hash<auto> getPushNotificationConfig(string task_id) {
        return doRpcCall("tasks/pushNotificationConfig/get", {"id": task_id});
    }

    #! Lists push notification configurations for a task
    /** @param task_id the task ID

        @return list of push notification configurations

        @throw A2A-ERROR if the call fails
    */
    hash<auto> listPushNotificationConfigs(string task_id) {
        return doRpcCall("tasks/pushNotificationConfig/list", {"id": task_id});
    }

    #! Deletes push notification configuration for a task
    /** @param task_id the task ID
        @param push_id the push notification config ID to delete

        @return the result of the operation

        @throw A2A-ERROR if the call fails
    */
    hash<auto> deletePushNotificationConfig(string task_id, string push_id) {
        return doRpcCall("tasks/pushNotificationConfig/delete", {
            "id": task_id,
            "pushNotificationConfigId": push_id,
        });
    }

    #! Sets a callback for the given event
    /** @param name the callback name (e.g., \c "onTaskStatusUpdate", \c "onTaskArtifactUpdate")
        @param cb the callback code
    */
    setCallback(string name, code cb) {
        lck.lock();
        on_exit lck.unlock();
        callbacks{name} = cb;
    }

    #! Removes a callback
    /** @param name the callback name to remove
    */
    removeCallback(string name) {
        lck.lock();
        on_exit lck.unlock();
        remove callbacks{name};
    }

    #! Returns the cached agent card, if any
    *hash<auto> getCachedAgentCard() {
        lck.lock();
        on_exit lck.unlock();
        return agent_card;
    }

    #! Closes the client and releases resources
    close() {
        sse_stop_flag = True;
        # Wait for any active SSE streams to finish
        sse_cnt.waitForZero();
        lck.lock();
        on_exit lck.unlock();
        remove agent_card;
        remove callbacks;
        # Reset stop flag so client can be reused after close
        sse_stop_flag = False;
    }

    #! Performs a JSON-RPC call and returns the result
    /** @param method the JSON-RPC method name
        @param params optional parameters

        @return the result from the JSON-RPC response

        @throw A2A-ERROR if the JSON-RPC response contains an error
        @throw A2A-HTTP-ERROR if the HTTP request fails
    */
    private hash<auto> doRpcCall(string method, *hash<auto> params) {
        int id;
        {
            lck.lock();
            on_exit lck.unlock();
            id = ++rpc_id;
        }

        hash<auto> request = {
            "jsonrpc": JsonRpcVersion,
            "method": method,
            "id": id,
        };
        if (params) {
            request.params = params;
        }

        string body = make_json(request);
        logDebug("A2A RPC request: method=%y id=%d", method, id);

        hash<auto> info;
        try {
            string response_body = http.post("", body, {}, \info);

            hash<auto> response_info = info."response-headers";
            int status_code = response_info.status_code ?? 0;

            if (status_code < 200 || status_code >= 300) {
                throw "A2A-HTTP-ERROR", sprintf("HTTP %d %s calling %y",
                    status_code, response_info.status_message ?? "", method);
            }

            hash<auto> result = parse_json(response_body);

            if (result.error) {
                throw "A2A-ERROR", sprintf("A2A error %d: %s", result.error.code, result.error.message),
                    result.error;
            }

            return result.result ?? {};
        } catch (hash<ExceptionInfo> ex) {
            if (ex.err == "A2A-ERROR" || ex.err == "A2A-HTTP-ERROR") {
                rethrow;
            }
            throw "A2A-ERROR", sprintf("Error calling A2A method %y: %s: %s", method, ex.err, ex.desc);
        }
    }

    #! Performs a JSON-RPC call with SSE streaming response
    /** Uses HttpStreamClient for proper incremental SSE event reading so that events
        are delivered as they arrive rather than waiting for the full response.

        @param method the JSON-RPC method name
        @param params the request parameters
        @param on_event callback for each SSE event; receives (event_type, event_data)
    */
    private doRpcStream(string method, hash<auto> params, code<auto (string, hash<auto>)> on_event) {
        int id;
        {
            lck.lock();
            on_exit lck.unlock();
            id = ++rpc_id;
        }

        hash<auto> request = {
            "jsonrpc": JsonRpcVersion,
            "method": method,
            "id": id,
            "params": params,
        };

        string body = make_json(request);
        logDebug("A2A RPC stream request: method=%y id=%d", method, id);

        sse_cnt.inc();
        on_exit sse_cnt.dec();

        hash<auto> info;
        HttpStreamClient::HTTPResponseStream stream;
        try {
            stream = HttpStreamClient::sendAndStream(http, "POST", "", body,
                {"Accept": MimeTypeSse}, \info, timeout);
        } catch (hash<ExceptionInfo> ex) {
            if (ex.err == "SOCKET-CONNECT-ERROR" || ex.err == "SOCKET-ERROR"
                    || ex.err == "SOCKET-CLOSED") {
                rethrow;
            }
            throw "A2A-ERROR", sprintf("Stream request failed for %y: %s: %s", method, ex.err, ex.desc);
        }

        on_exit stream.close();

        hash<HttpStreamClient::HTTPResponseStreamInfo> resp = stream.getInfo();

        if ((resp.status_code / 100) != 2) {
            # Read error body
            string error_body = "";
            while (*binary chunk = stream.readChunk(timeout)) {
                error_body += chunk.toString();
            }
            throw "A2A-HTTP-ERROR", sprintf("HTTP %d %s streaming %y: %s",
                resp.status_code, resp.status_message, method, error_body);
        }

        if (resp.content_type == MimeTypeSse || resp.content_type =~ /text\/event-stream/) {
            # Read SSE events incrementally
            while (!stream.isEof() && !sse_stop_flag) {
                *hash<SseMessageInfo> evt = stream.readServerSentEvent(timeout);
                if (!evt || !evt.data.val()) {
                    continue;
                }
                try {
                    hash<auto> data = parse_json(evt.data);
                    string event_type = evt.event ?? "message";
                    on_event(event_type, data);
                } catch (hash<ExceptionInfo> ex) {
                    logDebug("Error parsing SSE event: %s: %s", ex.err, ex.desc);
                }
            }
        } else {
            # Non-SSE response — read full body and treat as single result
            string response_body = "";
            while (*binary chunk = stream.readChunk(timeout)) {
                response_body += chunk.toString();
            }
            if (response_body.val()) {
                hash<auto> result = parse_json(response_body);
                if (result.error) {
                    throw "A2A-ERROR", sprintf("A2A error %d: %s",
                        result.error.code, result.error.message), result.error;
                }
                on_event("result", result.result ?? {});
            }
        }
    }

    #! Logs a debug message
    private logDebug(string fmt) {
        if (logger) {
            logger.debug(vsprintf(fmt, argv));
        }
    }
}

} # namespace A2aClient
