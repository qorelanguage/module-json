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
#! MCP tool declaration
public hashdecl McpToolInfo {
    #! The name of the tool
    string name;

    #! The description of the tool
    string description;

    #! The input type of the tool
    *hash<auto> input;

    #! If the input type has been fully initialized
    *bool input_initialized;

    #! If the tool call requires mapping from a "data" property
    *bool needs_map;

    #! The code to call the tool
    code tool;

    #! Extra free-form info to store for the tool
    *hash<auto> extra;
}

#! MCP resource declaration
public hashdecl McpResourceInfo {
    #! The URI of the resource
    string uri;

    #! The name of the resource
    string name;

    #! The description of the resource
    string description;

    #! The MIME type of the resource
    string mimeType;
}

#! MCP prompt declaration
public hashdecl McpPromptInfo {
    #! The name of the prompt
    string name;

    #! The description of the prompt
    string description;

    #! The arguments to the prompt
    *list<hash<auto>> arguments;
}

#! MCP tool call context
public hashdecl McpToolCallContext {
    #! The name of the tool
    string name;

    #! The description of the tool
    string description;

    #! The arguments to the tool
    *hash<auto> arguments;

    #! MCP session ID
    *string sid;

    #! Network context
    hash<auto> cx;
}

#! Initial version of the MCP protocol
public const MCP_Version_2024_11_05 = "2024-11-05";

#! Second version of the MCP protocol
public const MCP_Version_2025_03_26 = "2025-03-26";

#! Latest known version of the MCP protocol
public const MCP_Version_Latest = MCP_Version_2025_03_26;

#! Map of all known versions of the MCP protocol
public const AllMcpVersions = {
    MCP_Version_2024_11_05: True,
    MCP_Version_2025_03_26: True,
};

#! MCP Session header
public const McpSessionHeader = "Mcp-Session-Id";

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

        const McpSessionHeaderLwr = McpSessionHeader.lwr();

        const ServerInfo = {
            "protocolVersion": MCP_Version_Latest,
            "capabilities": {
                #"logging": {},
                /*
                "prompts": {
                    "listChanged": False,
                },
                "resources": {
                    "subscribe": False,
                    "listChanged": False,
                },
                */
                "tools": {
                    "listChanged": True,
                },
            },
            "serverInfo": {
                "name": McpServerName,
                "version": McpServerVersion,
            }
        };

        #! The input description for tools that do not require any input
        const NoInputDescription = {
            "type": "object",
        };

        #! Default SSE handler options
        const SseHandlerOpts = {
            # JSON serialization is performed by this object when needed
            "data": "none",
        };

        #! Maximum name length for an MCP tool
        const MaxMcpToolNameLength = 64;
    }

    private {
        #! Registered tools: name -> tool
        hash<string, hash<McpToolInfo>> tmap;

        #! Registered resources: URI -> resource info
        hash<string, hash<McpResourceInfo>> rmap;

        #! Registered prompts: name -> prompt info
        hash<string, hash<McpPromptInfo>> pmap;

        #! Session map; session ID -> session info
        hash<string, hash<McpSessionInfo>> smap;

        #! Session ID map
        hash<string, int> sidmap;

        #! Request ID counter
        int rid = 0;
    }

    #! Creates the handler
    /**
    */
    constructor(Logger::LoggerInterface logger, HttpServer::AbstractAuthenticator auth)
            : JsonRpcHandler(logger, auth), ServerSentEventHandler(auth, SseHandlerOpts) {
        setupMethods();
    }

    #! Creates the handler
    /**
    */
    constructor(HttpServer::AbstractAuthenticator auth) : JsonRpcHandler(auth),
            ServerSentEventHandler(auth, SseHandlerOpts) {
        setupMethods();
    }

    #! Creates the handler
    /**
    */
    constructor() {
        setupMethods();
    }

    #! Registers a tool
    registerTool(string name, string desc, *AbstractDataProviderType input, code tool, *bool input_initialized,
            *hash<auto> extra, *AbstractDataProvider prov) {
        tmap{name} = getTool(name, desc, input, tool, input_initialized, extra, prov);
    }

    #! Registers a resource
    registerResource(string uri, string name, string desc, string mimeType) {
        rmap{uri} = <McpResourceInfo>{
            "uri": uri,
            "name": name,
            "description": desc,
            "mimeType": mimeType,
        };
    }

    #! Returns the next request ID and increments the internal counter
    int getNextRequestId() {
        return rid++;
    }

    hash<HttpResponseInfo> handleRequest(hash<auto> cx, hash<auto> hdr, *data b) {
        *string session;
        if (((cx.hdr.method == "GET") || (cx.hdr.method == "POST") || (cx.hdr.method == "DELETE"))
            && (session = hdr{McpSessionHeaderLwr}).val()) {
            AutoReadLock al(rwl);
            if (!smap{session}) {
                return AbstractHttpRequestHandler::makeResponse(404, "Session %y is invalid", session);
            }
        }
        if (!session.val && cx.url.path =~ /\?/) {
            hash<UriQueryInfo> info = parse_uri_query(cx.url.path);
            if (info.params.session.val()) {
                session = info.params.session;
            }
        }
        if (session.val()) {
            cx.mcp_session = session;
        }
        if (cx.hdr.method == "DELETE") {
            if (!session.val()) {
                return AbstractHttpRequestHandler::makeResponse(400, "Missing session ID in %y header to delete",
                    McpSessionHeader);
            }
            {
                AutoWriteLock al(rwl);
                # close all connections
                map $1.stop(), smap{session}.ssemap.iterator();
                # remove session
                remove smap{session};
            }
            return AbstractHttpRequestHandler::makeResponse(200, "Session %y deleted", session);
        }

        if (cx.hdr.method == "GET") {
            # make sure the client can accept an SSE stream response
            if (clientAcceptsSse(hdr)) {
                return ServerSentEventHandler::handleRequest(cx, hdr, b);
            }
            return AbstractHttpRequestHandler::makeResponse(405, "Client does not accept SSE responses");
        }
        hash<HttpResponseInfo> rv = JsonRpcHandler::handleRequest(cx, hdr, b);
        # return answer on SSE stream if possible
        if (rv.body.val() && session.val() && ((rv."code" / 100) == 2)) {
            AutoReadLock al(rwl);
            if (*McpServerConnection sse = smap{session}.ssemap.firstValue()) {
                sse.send(<SseMessageInfo>{
                   "data": rv.body,
                });
                remove rv{"body", "hdr"};
            }
        }
        return rv;
    }

    #! Returns the 2024-11-05 JSON-RPC compatible endpoint, if any
    *string getCompatV1Endpoint(hash<auto> cx, hash<auto> hdr) {
    }

    int getNextIdForSession(string session) {
        return ++sidmap{session};
    }

    #! Called when a connection is established; the default implementation creates a ServerSentEventConnection object
    ServerSentEventConnection getConnectionImpl(Socket sock, hash<auto> cx, hash<auto> hdr, string cid) {
        return new McpServerConnection(self, sock, cx, hdr, cid);
    }

    string getSessionId(hash<auto> hdr) {
        if ((*string s = hdr{McpSessionHeaderLwr}).val()) {
            return s;
        }
        string session;
%ifdef NoUuid
        session = get_random_string(50);
%else
        session = UUID::get();
%endif
        smap{session} = <McpSessionInfo>{
            "session": session,
        };
        return session;
    }

    #! Use MCP ping as heartbeat message
    private string getHeartbeatMessage() {
        return make_jsonrpc_request("ping", "2.0", getNextRequestId());
    }

    #! Called while holding the write lock to register the new connection
    private registerNewConnectionIntern(string cid, ServerSentEventConnection conn) {
        ServerSentEventHandler::registerNewConnectionIntern(cid, conn);
        smap{conn.getSession()}.ssemap{conn.uniqueHash()} = conn;
    }

    private static bool clientAcceptsSse(hash<auto> hdr) {
        *string astr = hdr.accept;
        hash<auto> aih;
        if (!astr.val()) {
            # http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html: If no Accept header field is present, then
            # it is assumed that the client accepts all media types
            return True;
        }

        do {
            astr =~ s/;[^,]*//;
        } while (astr.rfind(";") != -1);
        astr =~ s/ +//g;
        map aih.$1 = True, astr.split(",");
        return aih{MimeTypeSse} || aih."*/*";
    }

    private hash<auto> toolsList(hash<auto> cx, *hash<auto> params) {
        return {
            "tools": getToolList(cx),
        };
    }

    private *list<hash<auto>> getToolList(hash<auto> cx) {
        return map (
            "name": $1.name,
            "description": $1.description,
            "inputSchema": $1.input,
        ), tmap.iterator();
    }

    private *hash<auto> toolsCall(hash<auto> cx, *hash<auto> params) {
        try {
            return toolsCallIntern(cx, params);
        } catch (hash<ExceptionInfo> ex) {
            error("Error executing tool with params %y: %s", params, get_exception_string(ex));
            return {
                "content": ({
                    "type": "text",
                    "text": make_json(ex{"err", "desc"}),
                    "isError": True,
                },),
            };
        }
    }

    private hash<auto> resourcesList(hash<auto> cx, *hash<auto> params) {
        return {
            "resources": getResourceList(cx),
        };
    }

    private *list<hash<auto>> getResourceList(hash<auto> cx) {
        return map (
            "uri": $1.uri,
            "name": $1.name,
            "description": $1.description,
            "mimeType": $1.mimeType,
        ), rmap.iterator();
    }

    private hash<auto> promptsList(hash<auto> cx, *hash<auto> params) {
        return {
            "prompts": getPromptList(cx),
        };
    }

    private *list<hash<auto>> getPromptList(hash<auto> cx) {
        return map (
            "name": $1.name,
            "description": $1.description,
            "arguments": $1.arguments,
        ), pmap.iterator();
    }

    private cancelRequest(hash<auto> cx) {
        # currently requests cannot be canceled
    }

    private hash<auto> initialize(hash<auto> cx, *hash<auto> params) {
        if (params.protocolVersion.typeCode() != NT_STRING) {
            throw "MCP-SERVER-ARG-ERROR", "Missing or invalid protocolVersion";
        }
        hash<auto> rv = ServerInfo;
        if (AllMcpVersions{params.protocolVersion}) {
            rv.protocolVersion = params.protocolVersion;
        }
        return rv;
    }

    *hash<auto> initialized(hash<auto> cx, *hash<auto> params) {
    }

    hash<auto> ping(hash<auto> cx, *hash<auto> params) {
        return {};
    }

    static *hash<McpToolCallContext> getToolCallContext() {
        return McpCallContextHelper::get();
    }

    private *hash<McpToolInfo> findToolForCall(hash<auto> cx, string name) {
        return tmap{name};
    }

    private *list<string> getKnownToolNames(hash<auto> cx) {
        return keys tmap;
    }

    private *hash<auto> toolsCallIntern(hash<auto> cx, *hash<auto> params) {
        *hash<McpToolInfo> info = findToolForCall(cx, params.name);
        if (!info) {
            throw "MCP-SERVER-ARG-ERROR", sprintf("Tool %y is unknown; known tools: %y", params.name,
                getKnownToolNames(cx));
        }
        hash<McpToolCallContext> call_info = <McpToolCallContext>{
            "name": info.name,
            "description": info.description,
            "sid": cx.mcp_session,
            "arguments": params.arguments,
            "cx": cx,
        };
        McpCallContextHelper mcch(call_info);
        return makeToolCall(info, params, call_info);
    }

    private *hash<auto> makeToolCall(*hash<McpToolInfo> info, *hash<auto> params,
            *hash<McpToolCallContext> call_info) {
        try {
            auto rv = info.needs_map ? info.tool(params.arguments."data") : info.tool(params.arguments);
            return {
                "content": ({
                    "type": "text",
                    "text": rv.typeCode() == NT_STRING ? rv : make_json(rv),
                    "isError": False,
                },),
            };
        } catch (hash<ExceptionInfo> ex) {
            # put any response body data in the exception description
            if (ex.arg."response-body") {
                rethrow ex.err, sprintf("%s (%y)", ex.desc, ex.arg."response-body");
            }
            rethrow;
        }
    }

    private hash<McpToolInfo> getTool(string name, string desc, *AbstractDataProviderType input, code tool,
            *bool input_initialized, *hash<auto> extra, *AbstractDataProvider prov) {
        if (name.length() > MaxMcpToolNameLength) {
            throw "MCP-SERVER-ARG-ERROR", sprintf("Tool name %y is too long (max %y)", name,
                MaxMcpToolNameLength);
        }
        *hash<auto> input_desc;
        bool needs_map;
        if (input) {
            input_desc = getTypeDescriptionIntern("input", input, prov);
            info("Creating tool %y (%y) input: %y (%s: %y) -> %y", name, desc, input ? input.getName() : "n/a",
                input ? input.className() : "n/a", keys (input ? input.getFields() : NOTHING), input_desc);
            if (input_desc.type.val() && input_desc.type != "object") {
                needs_map = True;
                input_desc = {
                    "type": "object",
                    "properties": {
                        "data": input_desc,
                    },
                };
                if (input.isMandatory()) {
                    input_desc.required = ("data",);
                }
            }
        }
        return <McpToolInfo>{
            "name": name,
            "description": getToolDescription(name, input_initialized, extra, desc),
            "input": input_desc ?? getNoInputDescription(name, input_initialized, extra),
            "input_initialized": input_initialized,
            "needs_map": needs_map,
            "tool": tool,
            "extra": extra,
        };
    }

    private string getToolDescription(string name, *bool input_initialized, *hash<auto> extra, string desc) {
        return desc;
    }

    private hash<auto> getNoInputDescription(string name, *bool input_initialized, *hash<auto> extra) {
        return NoInputDescription;
    }

    private hash<auto> getObjectDescription(hash<string, AbstractDataField> fields, *AbstractDataProvider prov,
            *hash<string, bool> tmap) {
        hash<auto> rv += {
            "type": "object",
        };
        list<string> required;
        foreach AbstractDataField field in (fields.iterator()) {
            AbstractDataProviderType t = field.getType();
            *hash<auto> info = getTypeDescription(field.getName(), field.getShortDescription(), t, prov, tmap);
            if (!info) {
                continue;
            }
            string name = field.getName();
            if (field.isMandatory()) {
                required += name;
            }
            if (*list<hash<AllowedValueInfo>> av = getAllowedValues(field, prov)) {
                info.enum = map $1.value, av;
            }
            if (exists (auto v = field.getDefaultValue())) {
                info."default" = v;
            }
            rv.properties{name} = info;
        }
        if (required) {
            rv.required = required;
        }
        return rv;
    }

    private *list<hash<AllowedValueInfo>> getAllowedValues(AbstractDataField field,
            *AbstractDataProvider prov) {
        if ((*list<hash<AllowedValueInfo>> rv = field.getAllowedValues()) || !prov) {
            return rv;
        }
        *hash<auto> attr = field.getAttributes();
        if (attr.ref_data.val()) {
            return prov.getReferenceDataSafe(attr.ref_data);
        }
    }

    private *hash<auto> getTypeDescription(string name, *string desc, AbstractDataProviderType t,
            *AbstractDataProvider prov, *hash<string, bool> tmap) {
        *hash<auto> info += getTypeDescriptionIntern(name, t, prov, tmap);
        if (info && desc.val()) {
            info.description = desc;
        }
        return info;
    }

    private *hash<auto> getTypeDescriptionIntern(string name, AbstractDataProviderType t,
            *AbstractDataProvider prov, *hash<string, bool> tmap) {
        if (*hash<string, AbstractDataField> fields = t.getFields()) {
            string uh = t.uniqueHash();
            if (tmap{uh}) {
                return {
                    "type": "object",
                };
            }
            tmap{uh} = True;
            return getObjectDescription(fields, prov, tmap);
        }
        int type = t.getBaseTypeCode();
        if ((type == NT_LIST) && (*AbstractDataProviderType et = t.getElementType())
            && exists (*hash<auto> h = getTypeDescriptionIntern("items", et, prov, tmap))) {
            return {
                "type": "array",
                "items": getTypeDescription("items", "array items", et, prov, tmap),
            };
        }

        hash<auto> info;

        switch (type) {
            case NT_DATE:
            case NT_STRING:
                info.type = "string";
                break;

            case NT_INT:
                info.type = "integer";
                break;

            case NT_BOOLEAN:
                info.type = "boolean";
                break;

            case NT_NUMBER:
            case NT_FLOAT:
                info.type = "number";
                break;

            case NT_LIST:
                info = {
                    "type": "array",
                    "items": {
                    },
                };
                break;

            case NT_HASH:
                info.type = "object";
                break;

            case NT_BINARY:
                info = {
                    "type": "string",
                    "format": "base64",
                };
                break;

            case NT_ALL:
                info = {};

            case NT_OBJECT:
                if (!t.isMandatory()) {
                    return;
                }
                throw "TOOL-ARG-ERROR", sprintf("Tool parameter %y requires a value of type %y", name,
                    t.getBaseTypeName());

            case NT_NOTHING:
            case NT_NULL:
                return;

            default:
                throw "TOOL-ARG-ERROR", sprintf("Tool parameter %y has unsupported type %y (%s)", name,
                    t.getBaseTypeName(), t.className());
        }

        if (exists (auto v = t.getDefaultValue())) {
            info."default" = v;
        }
        return info;
    }

    private setupMethods() {
        addMethods((
            {
                "name": "^initialize$",
                "text": "initialize",
                "function": \initialize(),
                "help": "MCP server initialization request handler",
                "include_context": True,
            },
            {
                "name": "^ping$",
                "text": "ping",
                "function": \ping(),
                "help": "MCP server client ping",
                "include_context": True,
            },
            {
                "name": "^notifications/initialized$",
                "text": "notifications/initialized",
                "function": \initialized(),
                "help": "MCP server client initialized notification",
                "include_context": True,
            },
            {
                "name": "^tools/list$",
                "text": "tools/list",
                "function": \toolsList(),
                "help": "MCP server list available tools",
                "include_context": True,
            },
            {
                "name": "^tools/call$",
                "text": "tools/call",
                "function": \toolsCall(),
                "help": "MCP server call tool",
                "include_context": True,
            },
            {
                "name": "^resources/list$",
                "text": "resources/list",
                "function": \resourcesList(),
                "help": "MCP server list available resources",
                "include_context": True,
            },
            {
                "name": "^prompts/list$",
                "text": "prompts/list",
                "function": \promptsList(),
                "help": "MCP server list available prompts",
                "include_context": True,
            },
            {
                "name": "^notifications/cancelled$",
                "text": "notifications/cancelled",
                "function": \cancelRequest(),
                "help": "Try to cancel an in-progress request",
                "include_context": True,
            },
        ));
    }
}
}

namespace Priv {
hashdecl McpSessionInfo {
    # Session ID
    string session;

    # Active SSE connections; first is always primary
    hash<string, McpServerConnection> ssemap;
}

thread_local *hash<McpToolCallContext> _mcp_call_context;
class McpCallContextHelper {
    private {
        *hash<McpToolCallContext> old;
    }

    constructor(hash<McpToolCallContext> call_info) {
        old = _mcp_call_context;
        _mcp_call_context = call_info;
    }

    destructor() {
        _mcp_call_context = old;
    }

    static *hash<McpToolCallContext> get() {
        return _mcp_call_context;
    }
}
}