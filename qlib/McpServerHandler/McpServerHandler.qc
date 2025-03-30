# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file McpServerHandler.qc @brief MCP Server class definition for the HttpServer module

/*  McpServerHandler.qc Copyright (C) 2025 Qore Technologies, s.r.o.

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

#! the %McpServerHandler namespace holds all public definitions in the %McpServerHandler module
public namespace McpServerHandler {
#! McpServer class definition; to be registered as a handler in the HttpServer class
/**
*/
public class McpServerHandler inherits JsonRpcHandler, ServerSentEventHandler {
    public {
        const IdTypeMap = {
            NT_STRING: True,
            NT_NUMBER: True,
            NT_FLOAT: True,
        };

        const ProtocolMap = {
            "2024-11-05": True,
        };

        const McpSessionHeader = "mcp-session-id";

        const Methods = (
            {
                "name": "^initialize$",
                "text": "initialize",
                "function": \McpServerHandler::initialize(),
                "help": "MCP server initialization request handler",
            },
            {
                "name": "^notifications/initialized$",
                "text": "notifications/initialized",
                "function": \McpServerHandler::initialized(),
                "help": "MCP server client initialized notification",
            },
            {
                "name": "^ping$",
                "text": "ping",
                "function": \McpServerHandler::ping(),
                "help": "MCP server client ping",
            },
        );

        const ServerInfo = {
            "protocolVersion": ProtocolMap.lastKey(),
            "capabilities": {
                "logging": {},
                "prompts": {
                    #"listChanged": true
                },
                "resources": {
                    #"subscribe": true,
                    #"listChanged": true
                },
                "tools": {
                    #"listChanged": true
                },
            },
            "serverInfo": {
                "name": McpServerName,
                "version": McpServerVersion,
            }
        };
    }

    private {
        #! Session map; session ID -> connection
        hash<string, McpServerConnection> smap;
    }

    #! Creates the handler
    /**
    */
    constructor(Logger::LoggerInterface logger, HttpServer::AbstractAuthenticator auth)
            : JsonRpcHandler(logger, auth) {
        addMethods(Methods);
    }

    #! Creates the handler
    /**
    */
    constructor(HttpServer::AbstractAuthenticator auth) : JsonRpcHandler(auth) {
        addMethods(Methods);
    }

    #! Creates the handler
    /**
    */
    constructor() {
        addMethods(Methods);
    }

    hash<auto> handleRequest(hash<auto> cx, hash<auto> hdr, *data b) {
        if (False) {
            return ServerSentEventHandler::handleRequest(cx, hdr, b);
        }
        return JsonRpcHandler::handleRequest(cx, hdr, b);
    }

    #! Called when a connection is established; the default implementation creates a ServerSentEventConnection object
    ServerSentEventConnection getConnectionImpl(Socket sock, hash<auto> cx, hash<auto> hdr, string cid) {
%ifdef NoUuid
        string session = get_random_string(50);
%else
        string session = UUID::get();
%endif
        McpServerConnection conn(self, sock, cid, session);
        # register session
        return conn;
    }

    static hash<auto> initialize(*hash<auto> params) {
        if (params.protocolVersion.typeCode() != NT_STRING) {
            throw "JSONRPC-ERROR", "Missing or invalid protocolVersion";
        }
        hash<auto> rv = ServerInfo;
        if (ProtocolMap{params.protocolVersion}) {
            rv.serverInfo.version = params.protocolVersion;
        }

        return rv;
    }

    static *hash<auto> initialized() {
    }

    static hash<auto> ping() {
        return {};
    }
}
}
