# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file McpClient.qc @brief MCP Client class implementation

/*  McpClient.qc Copyright (C) 2026 Qore Technologies, s.r.o.

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

#! the %McpClient namespace holds all public definitions in the %McpClient module
public namespace McpClient {

#! MCP protocol version enum
/** @since json 1.11
*/
public enum McpVersion : string {
    #! Protocol version 2024-11-05 (initial version)
    V2024_11_05 = "2024-11-05",
    #! Protocol version 2025-03-26 (March 2025)
    V2025_03_26 = "2025-03-26",
    #! Protocol version 2025-06-18 (June 2025 - Enterprise readiness)
    V2025_06_18 = "2025-06-18",
    #! Protocol version 2025-11-25 (November 2025 - Tasks, Extensions)
    V2025_11_25 = "2025-11-25",
}

#! Latest MCP protocol version
public const MCP_Version_Latest = McpVersion::V2025_11_25;

#! Map of all known versions for validation
public const AllMcpVersions = {
    McpVersion::V2024_11_05: True,
    McpVersion::V2025_03_26: True,
    McpVersion::V2025_06_18: True,
    McpVersion::V2025_11_25: True,
};

#! MCP Session header name
public const McpSessionHeader = "Mcp-Session-Id";

#! MCP log level enum
/** Standard syslog-style log levels for MCP logging protocol.

    @since json 1.11
*/
public enum McpLogLevel : string {
    #! Debug-level messages for detailed troubleshooting
    Debug = "debug",
    #! Informational messages about normal operation
    Info = "info",
    #! Normal but significant conditions
    Notice = "notice",
    #! Warning conditions that may need attention
    Warning = "warning",
    #! Error conditions
    Error = "error",
    #! Critical conditions requiring immediate attention
    Critical = "critical",
    #! Alert conditions requiring action
    Alert = "alert",
    #! Emergency: system is unusable
    Emergency = "emergency",
}

#! Valid log levels for validation
public const AllMcpLogLevels = {
    McpLogLevel::Debug: True,
    McpLogLevel::Info: True,
    McpLogLevel::Notice: True,
    McpLogLevel::Warning: True,
    McpLogLevel::Error: True,
    McpLogLevel::Critical: True,
    McpLogLevel::Alert: True,
    McpLogLevel::Emergency: True,
};

#! MCP completion reference type enum
/** @since json 1.11
*/
public enum McpCompletionRefType : string {
    #! Reference a prompt by name
    Prompt = "ref/prompt",
    #! Reference a resource by URI
    Resource = "ref/resource",
}

#! Client info for the MCP client
public hashdecl McpClientInfo {
    #! The name of the client
    string name;

    #! The version of the client
    string version;
}

#! MCP Client options
public hashdecl McpClientOptions {
    #! Connection timeout in milliseconds
    *int connect_timeout;

    #! Request timeout in milliseconds
    *int timeout;

    #! Preferred protocol version (defaults to latest)
    *string protocol_version;

    #! Logger interface
    *LoggerInterface logger;

    #! Enable SSE for server notifications (default: False)
    *bool enable_sse;

    #! SSE reconnect on disconnect (default: True)
    *bool sse_reconnect;

    #! Enable streamable HTTP transport (default: True)
    *bool enable_streamable;

    #! Allow legacy HTTP + SSE fallback (default: True)
    *bool allow_legacy_fallback;

    #! Reconnect streamable GET listener on disconnect (default: True)
    *bool streamable_reconnect;

    #! Default read timeout for streamable HTTP (default: 30s)
    *timeout streamable_read_timeout;

    #! Read timeout for streamable HTTP notification listener (default: 250ms)
    *timeout streamable_listener_timeout;

    #! Enable streamable HTTP GET listener for notifications (default: True)
    *bool enable_streamable_listener;
}

#! Tool information from server
public hashdecl McpToolResult {
    #! The name of the tool
    string name;

    #! The description of the tool
    *string description;

    #! The input schema (JSON Schema)
    *hash<auto> inputSchema;
}

#! Resource information from server
public hashdecl McpResourceResult {
    #! The URI of the resource
    string uri;

    #! The name of the resource
    string name;

    #! The description of the resource
    *string description;

    #! The MIME type of the resource
    *string mimeType;
}

#! Prompt information from server
public hashdecl McpPromptResult {
    #! The name of the prompt
    string name;

    #! The description of the prompt
    *string description;

    #! The arguments to the prompt
    *list<hash<auto>> arguments;
}

#! Resource content from server
public hashdecl McpResourceContent {
    #! The URI of the resource
    string uri;

    #! The MIME type (if provided)
    *string mimeType;

    #! Text content (for text resources)
    *string text;

    #! Binary content as base64 (for binary resources)
    *string blob;
}

#! Prompt message from server
public hashdecl McpPromptMessage {
    #! The role (user or assistant)
    string role;

    #! The content of the message
    hash<auto> content;
}

#! Tool call result
public hashdecl McpToolCallResult {
    #! The content returned by the tool
    list<hash<auto>> content;

    #! Whether the tool call resulted in an error
    *bool isError;
}

#! MCP Client class for connecting to MCP servers
/**
    This class provides a client implementation for the Model Context Protocol (MCP).
    It allows connecting to MCP servers over HTTP with JSON-RPC 2.0 protocol.

    @par Example:
    @code
    McpClient client("http://localhost:8080/mcp");

    # Initialize connection
    hash<auto> info = client.initialize({
        "name": "MyApp",
        "version": "1.0",
    });

    # Call a tool
    hash<auto> result = client.callTool("echo", {"message": "Hello"});

    client.close();
    @endcode
*/
public class McpClient {
    public {
        #! Default connection timeout (30 seconds)
        const DefaultConnectTimeout = 30000;

        #! Default request timeout (60 seconds)
        const DefaultTimeout = 60000;

        #! JSON-RPC version
        const JsonRpcVersion = "2.0";
    }

    private {
        #! The server URL
        string url;

        #! HTTP client for requests
        HTTPClient http;

        #! HTTP client for streamable GET listener
        HTTPClient stream_http;

        #! MCP session ID
        *string session_id;

        #! Negotiated protocol version
        *string protocol_version;

        #! Server info after initialization
        *hash<auto> server_info;

        #! Server capabilities
        *hash<auto> server_capabilities;

        #! Whether we're initialized
        bool initialized = False;

        #! Request ID counter
        int request_id = 0;

        #! Lock for thread safety
        Mutex lck();

        #! Logger interface
        *LoggerInterface logger;

        #! Event callbacks
        hash<string, code> callbacks;

        #! SSE client for receiving server messages
        *ServerSentEventClient::ServerSentEventClient sse_client;

        #! SSE options
        bool sse_reconnect = True;

        #! SSE shutdown counter
        Counter sse_cnt(0);

        #! SSE stopping flag
        bool sse_stopping = False;

        #! Streamable HTTP enabled
        bool streamable_enabled = True;

        #! Allow legacy fallback
        bool allow_legacy_fallback = True;

        #! Streamable GET reconnect
        bool streamable_reconnect = True;

        #! Streamable read timeout
        timeout streamable_read_timeout = 30s;
        timeout streamable_listener_timeout = 250ms;

        #! Streamable GET listener thread pool
        ThreadPool stream_tp;

        #! Streamable GET listener enabled
        bool streamable_listener_enabled = True;

        #! Streamable GET response stream
        *HttpStreamClient::HTTPResponseStream streamable_stream;

        #! Streamable GET listener state
        bool streamable_listener_started = False;
        bool streamable_stop_flag = False;

        #! Streamable listener counter
        Counter streamable_cnt();

        #! Streamable listener lock
        Mutex streamable_lck();

        #! Pending requests waiting for responses
        hash<string, hash<auto>> pending_requests;
    }

    #! Creates the MCP client
    /**
        @param url the URL of the MCP server endpoint
        @param opts optional client options

        @throw MCP-CLIENT-ERROR if URL is invalid
    */
    constructor(string url, *hash<auto> opts) {
        self.url = url;

        # Parse options
        int connect_timeout = opts.connect_timeout ?? DefaultConnectTimeout;
        int timeout = opts.timeout ?? DefaultTimeout;
        self.logger = opts.logger;
        if (exists opts.sse_reconnect) {
            sse_reconnect = opts.sse_reconnect;
        }
        if (exists opts.enable_streamable) {
            streamable_enabled = opts.enable_streamable;
        }
        if (exists opts.allow_legacy_fallback) {
            allow_legacy_fallback = opts.allow_legacy_fallback;
        }
        if (exists opts.streamable_reconnect) {
            streamable_reconnect = opts.streamable_reconnect;
        }
        if (exists opts.streamable_read_timeout) {
            streamable_read_timeout = opts.streamable_read_timeout;
        }
        if (exists opts.streamable_listener_timeout) {
            streamable_listener_timeout = opts.streamable_listener_timeout;
        }
        if (exists opts.enable_streamable_listener) {
            streamable_listener_enabled = opts.enable_streamable_listener;
        }

        # Initialize HTTP client with default headers
        http = new HTTPClient({
            "url": url,
            "connect_timeout": connect_timeout,
            "timeout": timeout,
            "headers": {
                "Content-Type": "application/json",
                "Accept": "application/json, text/event-stream",
            },
        });

        stream_http = new HTTPClient({
            "url": url,
            "connect_timeout": connect_timeout,
            "timeout": timeout,
            "headers": {
                "Accept": "text/event-stream",
            },
        });

        stream_tp = new ThreadPool();

        logDebug("McpClient created for URL: %s", url);
    }

    #! Destructor - closes the connection
    destructor() {
        close();
    }

    #! Returns the server URL
    string getUrl() {
        return url;
    }

    #! Initializes the MCP connection
    /**
        @param client_info information about this client
        @return server information including capabilities and protocol version

        @throw MCP-INIT-ERROR if initialization fails
        @throw MCP-VERSION-ERROR if no compatible protocol version is available
    */
    hash<auto> initialize(hash<McpClientInfo> client_info) {
        if (initialized) {
            throw "MCP-INIT-ERROR", "Client is already initialized";
        }

        # Build initialize request
        hash<auto> params += {
            "protocolVersion": MCP_Version_Latest,
            "capabilities": {
                # Client capabilities
            },
            "clientInfo": {
                "name": client_info.name,
                "version": client_info.version,
            },
        };

        logDebug("Sending initialize request");

        hash<auto> response = sendRequest("initialize", params);

        if (response.error) {
            throw "MCP-INIT-ERROR", sprintf("Initialize failed: %s", response.error.message);
        }

        hash<auto> result = response.result;

        # Store server info
        server_info = result.serverInfo;
        server_capabilities = result.capabilities;

        # Negotiate protocol version
        string server_version = result.protocolVersion;
        if (!AllMcpVersions{server_version}) {
            throw "MCP-VERSION-ERROR", sprintf("Server returned unsupported protocol version: %s", server_version);
        }
        protocol_version = server_version;

        # Send initialized notification
        sendNotification("notifications/initialized");

        initialized = True;
        logDebug("MCP client initialized with protocol version: %s", protocol_version);

        return result;
    }

    #! Checks if the client is initialized
    /**
        @return True if initialized, False otherwise
    */
    bool isInitialized() {
        return initialized;
    }

    #! Gets the negotiated protocol version
    /**
        @return the protocol version string or NOTHING if not initialized
    */
    *string getProtocolVersion() {
        return protocol_version;
    }

    #! Gets server information
    /**
        @return server info hash or NOTHING if not initialized
    */
    *hash<auto> getServerInfo() {
        return server_info;
    }

    #! Gets server capabilities
    /**
        @return server capabilities hash or NOTHING if not initialized
    */
    *hash<auto> getServerCapabilities() {
        return server_capabilities;
    }

    #! Sends a ping request to check server health
    /**
        @return True if server responds successfully

        @throw MCP-PING-ERROR if ping fails
    */
    bool ping() {
        ensureInitialized();

        hash<auto> response = sendRequest("ping");

        if (response.error) {
            throw "MCP-PING-ERROR", sprintf("Ping failed: %s", response.error.message);
        }

        return True;
    }

    #! Lists available tools from the server
    /**
        @return list of tool information

        @throw MCP-ERROR if the request fails
    */
    list<auto> listTools() {
        ensureInitialized();

        hash<auto> response = sendRequest("tools/list");

        if (response.error) {
            throw "MCP-ERROR", sprintf("tools/list failed: %s", response.error.message);
        }

        return response.result.tools ?? ();
    }

    #! Calls a tool on the server
    /**
        @param name the name of the tool to call
        @param arguments optional arguments for the tool
        @return the tool call result

        @throw MCP-ERROR if the tool call fails
        @throw MCP-TOOL-ERROR if the tool returns an error
    */
    hash<auto> callTool(string name, *hash<auto> arguments) {
        ensureInitialized();

        hash<auto> params += {
            "name": name,
        };
        if (arguments) {
            params.arguments = arguments;
        }

        hash<auto> response = sendRequest("tools/call", params);

        if (response.error) {
            throw "MCP-ERROR", sprintf("tools/call failed: %s", response.error.message);
        }

        hash<auto> result = response.result;

        # Check for error at result level (MCP spec)
        if (result.isError) {
            throw "MCP-ERROR", sprintf("Tool '%s' returned an error", name), result;
        }

        # Also check for error in content items
        if (result.content) {
            foreach hash<auto> item in (result.content) {
                if (item.isError) {
                    throw "MCP-ERROR", sprintf("Tool '%s' returned an error: %s", name, item.text ?? "unknown error"),
                        result;
                }
            }
        }

        return result;
    }

    #! Lists available resources from the server
    /**
        @return list of resource information

        @throw MCP-ERROR if the request fails
    */
    list<auto> listResources() {
        ensureInitialized();

        hash<auto> response = sendRequest("resources/list");

        if (response.error) {
            throw "MCP-ERROR", sprintf("resources/list failed: %s", response.error.message);
        }

        return response.result.resources ?? ();
    }

    #! Reads a resource from the server
    /**
        @param uri the URI of the resource to read
        @return the resource content

        @throw MCP-ERROR if the request fails
    */
    hash<auto> readResource(string uri) {
        ensureInitialized();

        hash<auto> params += {
            "uri": uri,
        };

        hash<auto> response = sendRequest("resources/read", params);

        if (response.error) {
            throw "MCP-ERROR", sprintf("resources/read failed: %s", response.error.message);
        }

        return response.result;
    }

    #! Lists available prompts from the server
    /**
        @return list of prompt information

        @throw MCP-ERROR if the request fails
    */
    list<auto> listPrompts() {
        ensureInitialized();

        hash<auto> response = sendRequest("prompts/list");

        if (response.error) {
            throw "MCP-ERROR", sprintf("prompts/list failed: %s", response.error.message);
        }

        return response.result.prompts ?? ();
    }

    #! Gets a prompt from the server
    /**
        @param name the name of the prompt
        @param arguments optional arguments for the prompt
        @return the prompt with messages

        @throw MCP-ERROR if the request fails
    */
    hash<auto> getPrompt(string name, *hash<auto> arguments) {
        ensureInitialized();

        hash<auto> params += {
            "name": name,
        };
        if (arguments) {
            params.arguments = arguments;
        }

        hash<auto> response = sendRequest("prompts/get", params);

        if (response.error) {
            throw "MCP-ERROR", sprintf("prompts/get failed: %s", response.error.message);
        }

        return response.result;
    }

    #! Requests completion suggestions
    /**
        @param ref the reference (prompt or resource) to complete for
        @param argument the argument being completed
        @return completion suggestions

        @throw MCP-ERROR if the request fails
    */
    hash<auto> complete(hash<auto> ref, hash<auto> argument) {
        ensureInitialized();

        hash<auto> params += {
            "ref": ref,
            "argument": argument,
        };

        hash<auto> response = sendRequest("completion/complete", params);

        if (response.error) {
            throw "MCP-ERROR", sprintf("completion/complete failed: %s", response.error.message);
        }

        return response.result;
    }

    #! Sets the server log level
    /**
        @param level the log level to set

        @throw MCP-ERROR if the request fails
        @throw MCP-INVALID-LOG-LEVEL if the level is not valid
    */
    setLogLevel(string level) {
        ensureInitialized();

        if (!AllMcpLogLevels{level}) {
            throw "MCP-INVALID-LOG-LEVEL", sprintf("Invalid log level: %s", level);
        }

        hash<auto> params += {
            "level": level,
        };

        hash<auto> response = sendRequest("logging/setLevel", params);

        if (response.error) {
            throw "MCP-ERROR", sprintf("logging/setLevel failed: %s", response.error.message);
        }
    }

    #! Registers an event callback
    /**
        @param event the event name (onToolsChanged, onResourcesChanged, onPromptsChanged, onLogMessage, onError)
        @param callback the callback code to invoke

        Supported events:
        - onToolsChanged: called when the server's tool list changes
        - onResourcesChanged: called when the server's resource list changes
        - onPromptsChanged: called when the server's prompt list changes
        - onLogMessage: called when the server sends a log message (receives: string level, *auto data, *string logger)
        - onError: called when an error occurs (receives: string error_message)
        - onConnected: called when SSE connection is established
        - onDisconnected: called when SSE connection is closed
    */
    setCallback(string event, code callback) {
        lck.lock();
        on_exit lck.unlock();

        callbacks{event} = callback;
    }

    #! Removes an event callback
    /**
        @param event the event name to remove
    */
    removeCallback(string event) {
        lck.lock();
        on_exit lck.unlock();

        remove callbacks{event};
    }

    #! Starts the SSE listener for server notifications
    /**
        This starts a background thread that listens for Server-Sent Events
        from the MCP server. Call this after initialize() to receive notifications.

        @throw MCP-NOT-INITIALIZED if client is not initialized
    */
    startSseListener() {
        ensureInitialized();

        if (streamable_enabled && streamable_listener_enabled) {
            if (startStreamableListener()) {
                return;
            }
            logDebug("Streamable HTTP listener unavailable; falling back to legacy SSE listener");
        }

        startLegacySseListener();
    }

    #! Stops the SSE listener
    stopSseListener() {
        stopStreamableListener();
        stopLegacySseListener();
    }

    #! Checks if SSE listener is running
    /**
        @return True if SSE listener is active
    */
    bool isSseListenerRunning() {
        if (streamable_listener_started) {
            return True;
        }
        return exists sse_client && sse_client.isOpen();
    }

    #! Starts the legacy SSE listener
    private startLegacySseListener() {
        if (sse_client) {
            logDebug("Legacy SSE listener already running");
            return;
        }

        sse_stopping = False;
        sse_cnt.inc();

        # Create SSE client - convert URL scheme if needed
        string sse_url = url;
        if (sse_url =~ /^http:/) {
            sse_url = regex_subst(sse_url, "^http:", "sse:");
        } else if (sse_url =~ /^https:/) {
            sse_url = regex_subst(sse_url, "^https:", "sses:");
        }

        hash<auto> sse_opts = {
            "url": sse_url,
            "reconnect": sse_reconnect,
            "data": "json",
            "logger": logger,
        };

        sse_opts.headers."Accept" = "text/event-stream";

        # Add session ID header if we have one
        if (session_id) {
            sse_opts.headers{McpSessionHeader} = session_id;
        }

        sse_client = new ServerSentEventClient::ServerSentEventClient(sse_opts);

        # Register ourselves as the observer
        sse_client.registerObserver(self);

        # Connect and start receiving events
        sse_client.connect();

        logDebug("Legacy SSE listener started");
    }

    #! Stops the legacy SSE listener
    private stopLegacySseListener() {
        if (sse_client) {
            sse_stopping = True;
            sse_client.disconnect();
            sse_cnt.waitForZero();
            date start = now_us();
            while (sse_client.isOpen() || sse_client.isReconnecting()) {
                if ((now_us() - start) > 5s) {
                    break;
                }
                sleep(100ms);
            }
            sse_client.deregisterObserver(self);
            sse_client = NOTHING;
            sse_stopping = False;
            logDebug("Legacy SSE listener stopped");
        }
    }

    #! Starts the streamable HTTP GET listener
    private bool startStreamableListener() {
        {
            streamable_lck.lock();
            on_exit streamable_lck.unlock();
            if (streamable_listener_started) {
                logDebug("Streamable HTTP listener already running");
                return True;
            }
        }

        *HttpStreamClient::HTTPResponseStream stream = openStreamableGet();
        if (!stream) {
            return False;
        }

        {
            streamable_lck.lock();
            on_exit streamable_lck.unlock();
            streamable_stream = stream;
            streamable_stop_flag = False;
            streamable_listener_started = True;
        }

        streamable_cnt.inc();
        on_error streamable_cnt.dec();
        stream_tp.submit(sub () {
            streamableEventLoop();
        });

        return True;
    }

    #! Stops the streamable HTTP GET listener
    private stopStreamableListener() {
        bool wait = False;
        {
            streamable_lck.lock();
            on_exit streamable_lck.unlock();
            if (streamable_listener_started) {
                streamable_stop_flag = True;
                if (streamable_stream) {
                    streamable_stream.setReadTimeout(0ms);
                    streamable_stream.close();
                }
                wait = True;
            }
        }

        if (wait) {
            streamable_cnt.waitForZero();
        }
    }

    #! Opens a streamable HTTP GET event stream
    private *HttpStreamClient::HTTPResponseStream openStreamableGet() {
        hash<auto> headers = {};
        if (session_id) {
            headers{McpSessionHeader} = session_id;
        }

        hash<auto> info;
        HttpStreamClient::HTTPResponseStream stream;
        try {
            stream = HttpStreamClient::sendAndStream(stream_http, "GET", "", NOTHING, headers, \info,
                streamable_read_timeout);
        } catch (hash<ExceptionInfo> ex) {
            logDebug("Streamable GET failed: %s: %s", ex.err, ex.desc);
            return;
        }

        hash<HttpStreamClient::HTTPResponseStreamInfo> resp = stream.getInfo();
        if (resp.headers{McpSessionHeader.lwr()}) {
            session_id = resp.headers{McpSessionHeader.lwr()};
            logDebug("Received session ID: %s", session_id);
        }

        if ((resp.status_code / 100) != 2) {
            stream.close();
            return;
        }

        if (resp.content_type != "text/event-stream") {
            stream.close();
            return;
        }

        return stream;
    }

    #! Streamable GET event loop
    private streamableEventLoop() {
        on_exit {
            streamable_lck.lock();
            on_exit streamable_lck.unlock();
            streamable_listener_started = False;
            streamable_stream = NOTHING;
            streamable_cnt.dec();
        }

        bool connected = False;
        while (True) {
            HttpStreamClient::HTTPResponseStream stream;
            {
                streamable_lck.lock();
                on_exit streamable_lck.unlock();
                stream = streamable_stream;
            }

            if (!stream) {
                break;
            }

            if (!connected) {
                connected = True;
                invokeCallback("onConnected");
            }

            while (!streamable_stop_flag && !stream.isEof()) {
                *hash<SseMessageInfo> evt;
                try {
                    evt = stream.readServerSentEvent(streamable_listener_timeout);
                } catch (hash<ExceptionInfo> ex) {
                    if (ex.err == "SOCKET-TIMEOUT") {
                        if (streamable_stop_flag) {
                            break;
                        }
                        continue;
                    }
                    logDebug("Streamable listener error: %s: %s", ex.err, ex.desc);
                    invokeCallback("onError", ("Streamable listener error: " + ex.desc));
                    break;
                }
                if (!evt) {
                    break;
                }
                if (!evt.data.val()) {
                    continue;
                }
                auto msg;
                try {
                    msg = parse_json(evt.data);
                } catch (hash<ExceptionInfo> ex) {
                    logDebug("Failed to parse streamable SSE message: %s: %s", ex.err, ex.desc);
                    invokeCallback("onError", ("Failed to parse SSE message: " + ex.desc));
                    continue;
                }
                handleStreamableMessage(msg, -1);
            }

            if (streamable_stop_flag) {
                break;
            }

            stream.close();
            invokeCallback("onDisconnected");
            connected = False;

            if (!streamable_reconnect) {
                break;
            }

            sleep(1);

            *HttpStreamClient::HTTPResponseStream new_stream = openStreamableGet();
            if (!new_stream) {
                break;
            }
            {
                streamable_lck.lock();
                on_exit streamable_lck.unlock();
                streamable_stream = new_stream;
            }
        }

        # state cleared in on_exit
    }

    #! Closes the MCP connection
    close() {
        stopSseListener();

        initialized = False;
        session_id = NOTHING;
        protocol_version = NOTHING;
        server_info = NOTHING;
        server_capabilities = NOTHING;

        logDebug("MCP client closed");
    }

    #! Gets the session ID
    /**
        @return the MCP session ID or NOTHING if not set
    */
    *string getSessionId() {
        return session_id;
    }

    #! Sets the session ID (used internally)
    setSessionId(string sid) {
        session_id = sid;
    }

    #! Internal: Ensures the client is initialized
    private ensureInitialized() {
        if (!initialized) {
            throw "MCP-NOT-INITIALIZED", "Client is not initialized. Call initialize() first.";
        }
    }

    #! Internal: Gets the next request ID
    private int getNextRequestId() {
        lck.lock();
        on_exit lck.unlock();

        return ++request_id;
    }

    #! Internal: Sends a JSON-RPC request with streamable HTTP, falling back to legacy
    private hash<auto> sendRequest(string method, *hash<auto> params) {
        if (streamable_enabled) {
            try {
                return sendRequestStreamable(method, params);
            } catch (hash<ExceptionInfo> ex) {
                if (ex.err == "MCP-STREAMABLE-UNSUPPORTED" && allow_legacy_fallback) {
                    logDebug("Streamable HTTP unsupported (%s); falling back to legacy transport", ex.desc);
                } else {
                    rethrow;
                }
            }
        }

        return sendRequestLegacy(method, params);
    }

    #! Internal: Sends a JSON-RPC request using legacy HTTP transport
    private hash<auto> sendRequestLegacy(string method, *hash<auto> params) {
        int id = getNextRequestId();

        hash<auto> request = {
            "jsonrpc": JsonRpcVersion,
            "id": id,
            "method": method,
        };

        if (params) {
            request.params = params;
        }

        string body = make_json(request);

        logDebug("Sending request: %s", body);

        # Build headers
        hash<auto> headers = {};
        if (session_id) {
            headers{McpSessionHeader} = session_id;
        }

        hash<auto> info;
        string response_body = http.post("", body, headers, \info);

        # Get response info from the response-headers
        hash<auto> response_info = info."response-headers";
        int status_code = response_info.status_code ?? 0;
        string status_message = response_info.status_message ?? "";

        logDebug("Response status: %d, body: %s", status_code, response_body);

        # Check for session ID in response headers
        if (response_info{McpSessionHeader.lwr()}) {
            session_id = response_info{McpSessionHeader.lwr()};
            logDebug("Received session ID: %s", session_id);
        }

        if (status_code < 200 || status_code >= 300) {
            throw "MCP-HTTP-ERROR", sprintf("HTTP error: %d %s", status_code, status_message);
        }

        hash<auto> response = parse_json(response_body);
        return response;
    }

    #! Internal: Sends a JSON-RPC request using streamable HTTP
    private hash<auto> sendRequestStreamable(string method, *hash<auto> params) {
        int id = getNextRequestId();

        hash<auto> request = {
            "jsonrpc": JsonRpcVersion,
            "id": id,
            "method": method,
        };

        if (params) {
            request.params = params;
        }

        string body = make_json(request);
        logDebug("Sending streamable request: %s", body);

        hash<auto> headers = {};
        if (session_id) {
            headers{McpSessionHeader} = session_id;
        }

        hash<auto> info;
        HttpStreamClient::HTTPResponseStream stream;
        try {
            stream = HttpStreamClient::sendAndStream(http, "POST", "", body, headers, \info, streamable_read_timeout);
        } catch (hash<ExceptionInfo> ex) {
            if (ex.err == "SOCKET-CONNECT-ERROR" || ex.err == "SOCKET-ERROR" || ex.err == "SOCKET-CLOSED") {
                rethrow;
            }
            throw "MCP-STREAMABLE-ERROR", sprintf("Streamable HTTP request failed: %s: %s", ex.err, ex.desc);
        }

        hash<HttpStreamClient::HTTPResponseStreamInfo> resp = stream.getInfo();

        # Check for session ID in response headers
        if (resp.headers{McpSessionHeader.lwr()}) {
            session_id = resp.headers{McpSessionHeader.lwr()};
            logDebug("Received session ID: %s", session_id);
        }

        if ((resp.status_code / 100) != 2) {
            string error_body = readStreamableBody(stream);
            stream.close();
            if (resp.status_code == 404 || resp.status_code == 405 || resp.status_code == 415) {
                throw "MCP-STREAMABLE-UNSUPPORTED",
                    sprintf("Streamable HTTP unsupported: %d %s %s", resp.status_code, resp.status_message,
                        error_body);
            }
            throw "MCP-HTTP-ERROR", sprintf("HTTP error: %d %s %s", resp.status_code, resp.status_message,
                error_body);
        }

        if (resp.content_type == "text/event-stream") {
            hash<auto> response = readStreamableSseResponse(stream, id);
            stream.close();
            return response;
        }

        hash<auto> response = readStreamableJsonResponse(stream);
        stream.close();
        return response;
    }

    #! Internal: Reads a streamable JSON response
    private hash<auto> readStreamableJsonResponse(HttpStreamClient::HTTPResponseStream stream) {
        binary body;
        while (*binary chunk = stream.readChunk(streamable_read_timeout)) {
            body += chunk;
        }
        if (!body) {
            return {};
        }
        return parse_json(body.toString());
    }

    #! Internal: Reads a streamable SSE response and returns the matching response
    private hash<auto> readStreamableSseResponse(HttpStreamClient::HTTPResponseStream stream, int request_id) {
        while (!stream.isEof()) {
            *hash<SseMessageInfo> evt = stream.readServerSentEvent(streamable_read_timeout);
            if (!evt) {
                break;
            }
            if (!evt.data.val()) {
                continue;
            }
            auto msg;
            try {
                msg = parse_json(evt.data);
            } catch (hash<ExceptionInfo> ex) {
                logDebug("Failed to parse SSE message: %s: %s", ex.err, ex.desc);
                invokeCallback("onError", ("Failed to parse SSE message: " + ex.desc));
                continue;
            }
            *hash<auto> response = handleStreamableMessage(msg, request_id);
            if (response) {
                return response;
            }
        }

        throw "MCP-ERROR", "No response received from streamable SSE response";
    }

    #! Internal: Handles parsed streamable message payloads
    private *hash<auto> handleStreamableMessage(auto msg, int request_id) {
        if (msg.type() == "list") {
            foreach auto entry in (msg) {
                *hash<auto> resp = handleStreamableMessage(entry, request_id);
                if (resp) {
                    return resp;
                }
            }
            return;
        }

        if (msg.type() != "hash") {
            return;
        }

        if (exists msg.id) {
            if (string(msg.id) == string(request_id)) {
                return msg;
            }
            return;
        }

        handleNotification(msg);
        return;
    }

    #! Internal: Reads remaining stream body into a string
    private string readStreamableBody(HttpStreamClient::HTTPResponseStream stream) {
        binary body;
        while (*binary chunk = stream.readChunk(streamable_read_timeout)) {
            body += chunk;
        }
        if (!body) {
            return "";
        }
        return body.toString();
    }

    #! Internal: Sends a JSON-RPC notification (no response expected)
    private sendNotification(string method, *hash<auto> params) {
        hash<auto> request = {
            "jsonrpc": JsonRpcVersion,
            "method": method,
        };

        if (params) {
            request.params = params;
        }

        string body = make_json(request);

        logDebug("Sending notification: %s", body);

        # Build headers
        hash<auto> headers = {};
        if (session_id) {
            headers{McpSessionHeader} = session_id;
        }

        hash<auto> info;
        http.post("", body, headers, \info);

        # We don't expect a response for notifications
    }

    #! Internal: Invokes an event callback
    invokeCallback(string event, *list<auto> args) {
        *code cb;
        {
            lck.lock();
            on_exit lck.unlock();
            cb = callbacks{event};
        }

        if (cb) {
            try {
                call_function_args(cb, args);
            } catch (hash<auto> ex) {
                logDebug("Callback %s threw exception: %s: %s", event, ex.err, ex.desc);
            }
        }
    }

    #! Internal: Handles an incoming SSE message (called by observer)
    handleSseMessage(hash<auto> message) {
        logDebug("Received SSE message: %y", message);

        # Check if it's a notification (no id field)
        if (!exists message.id) {
            handleNotification(message);
        } else {
            # It's a response - check if we have a pending request
            lck.lock();
            on_exit lck.unlock();

            string id_str = string(message.id);
            if (pending_requests{id_str}) {
                pending_requests{id_str}.response = message;
                pending_requests{id_str}.cond.signal();
            }
        }
    }

    #! Internal: Handles SSE connection events
    handleSseConnected() {
        logDebug("SSE connected");
        invokeCallback("onConnected");
    }

    #! Internal: Handles SSE disconnection events
    handleSseClosed() {
        logDebug("SSE closed");
        bool do_callback = True;
        if (sse_stopping) {
            do_callback = False;
        }
        sse_cnt.dec();
        if (do_callback) {
            invokeCallback("onDisconnected");
        }
    }

    #! Observer callback for SSE client events
    update(string event_id, hash<auto> data_) {
        switch (event_id) {
            case ServerSentEventClient::EVENT_SSE_DATA:
                if (data_.data) {
                    handleSseMessage(data_.data);
                }
                break;

            case ServerSentEventClient::EVENT_SSE_CONNECTED:
                handleSseConnected();
                break;

            case ServerSentEventClient::EVENT_SSE_CLOSED:
                handleSseClosed();
                break;
        }
    }

    #! Internal: Handles a server notification
    private handleNotification(hash<auto> message) {
        string method = message.method;

        switch (method) {
            case "notifications/tools/list_changed":
                invokeCallback("onToolsChanged");
                break;

            case "notifications/resources/list_changed":
                invokeCallback("onResourcesChanged");
                break;

            case "notifications/prompts/list_changed":
                invokeCallback("onPromptsChanged");
                break;

            case "notifications/message":
                # Log message notification
                if (message.params) {
                    invokeCallback("onLogMessage", (
                        message.params.level,
                        message.params.data,
                        message.params.logger,
                    ));
                }
                break;

            default:
                logDebug("Unknown notification: %s", method);
        }
    }

    #! Internal: Logs a debug message
    private logDebug(string fmt, ...) {
        if (logger) {
            string msg = vsprintf(fmt, argv);
            logger.debug(msg);
        }
    }
}

} # namespace McpClient
