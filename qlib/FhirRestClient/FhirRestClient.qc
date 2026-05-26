# -*- mode: qore; indent-tabs-mode: nil -*-
#! @file FhirRestClient.qc @brief FHIR REST client implementation

/*  FhirRestClient.qc Copyright (C) 2026 Qore Technologies, s.r.o.

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

#! the %FhirRestClient namespace holds all public definitions in the %FhirRestClient module
public namespace FhirRestClient {

#! Common FHIR REST client constants and option handling
public class FhirRestClientBase {
    public {
        #! FHIR JSON MIME type
        const MimeTypeFhirJson = "application/fhir+json";

        #! Default "data" option value
        const DefaultData = "json";

        #! Default ping method
        const DefaultPingMethod = "GET";

        #! Default FHIR metadata ping path
        const DefaultPingPath = "metadata";

        #! Default headers for FHIR JSON requests
        const DefaultHeaders = {
            "Accept": MimeTypeFhirJson,
        };

        #! Headers for requests with FHIR JSON bodies
        const FhirJsonBodyHeaders = DefaultHeaders + {
            "Content-Type": MimeTypeFhirJson,
        };

        #! Default FHIR REST client options
        const DefaultOptions = {
            "data": DefaultData,
            "error_passthru": True,
            "headers": DefaultHeaders,
            "no_charset": True,
            "ping_headers": DefaultHeaders,
            "ping_method": DefaultPingMethod,
            "ping_path": DefaultPingPath,
        };
    }

    #! Returns normalized constructor options for FHIR REST clients
    /** @param opts user-supplied @ref RestClient::RestClient constructor options
        @return FHIR-aware REST client options with JSON serialization and FHIR JSON headers applied
    */
    static hash<auto> getOptions(hash<auto> opts) {
        hash<auto> rv = DefaultOptions + opts;
        rv.headers = DefaultHeaders + opts.headers;
        rv.ping_headers = DefaultHeaders + opts.ping_headers;
        return rv;
    }

    #! Validates a FHIR resource type name
    /** @param resource_type FHIR resource type name such as \c "Patient" or \c "Observation"
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type cannot be used in a FHIR REST path
    */
    static validateResourceType(string resource_type) {
        if (resource_type !~ /^[A-Z][A-Za-z0-9]*$/) {
            throw "FHIR-RESOURCE-TYPE-ERROR", sprintf("invalid FHIR resource type: %y", resource_type);
        }
    }

    #! Validates a FHIR logical id
    /** @param id FHIR logical id
        @throw FHIR-ID-ERROR if the id does not match the FHIR logical id grammar
    */
    static validateId(string id) {
        if (id !~ /^[A-Za-z0-9\-\.]{1,64}$/) {
            throw "FHIR-ID-ERROR", sprintf("invalid FHIR resource id: %y", id);
        }
    }

    #! Validates a relative FHIR REST path
    /** @param path relative FHIR REST path, optionally with an encoded query string
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
    */
    static validateRelativePath(string path) {
        if (!path || path =~ /^(?:[A-Za-z][A-Za-z0-9+.-]*:|\/\/|\/)/ || path =~ /(?:^|\/)\.\.(?:\/|$)/
                || path =~ /[\r\n]/) {
            throw "FHIR-PATH-ERROR", sprintf("invalid FHIR REST path: %y", path);
        }
    }

    #! Returns a resource instance path
    /** @param resource_type FHIR resource type name
        @param id FHIR logical id
        @return relative FHIR REST path for the resource instance
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-ID-ERROR if the id is invalid
    */
    static string getResourcePath(string resource_type, string id) {
        validateResourceType(resource_type);
        validateId(id);
        return resource_type + "/" + id;
    }

    #! Returns a FHIR search path from a resource type and search parameters
    /** @param resource_type FHIR resource type name
        @param params optional search parameters; list values are emitted as repeated query parameters
        @return relative FHIR REST search path with an encoded query string when parameters are supplied
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
    */
    static string getSearchPath(string resource_type, *hash<auto> params) {
        validateResourceType(resource_type);
        return getPathWithParams(resource_type, params);
    }

    #! Returns a path with URI query parameters
    /** @param path relative FHIR REST path
        @param params optional query parameters; list values are emitted as repeated query parameters
        @return path with URL-encoded query parameters appended when parameters are supplied
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
    */
    static string getPathWithParams(string path, *hash<auto> params) {
        validateRelativePath(path);
        if (!params) {
            return path;
        }

        list<string> parts;
        foreach string key in (sort(keys params)) {
            auto val = params{key};
            if (!exists val) {
                continue;
            }
            if (val.typeCode() == NT_LIST) {
                foreach auto v in (val) {
                    if (exists v) {
                        parts += sprintf("%s=%s", encode_url(key, True), encode_url(string(v), True));
                    }
                }
            } else {
                parts += sprintf("%s=%s", encode_url(key, True), encode_url(string(val), True));
            }
        }

        string sep = path =~ /\?/ ? "&" : "?";
        return parts ? path + sep + parts.join("&") : path;
    }

    #! Returns the URL for a Bundle link relation, if present
    /** @param bundle FHIR Bundle resource
        @param relation link relation to find, such as \c "next"
        @return URL for the requested relation, or no value if the relation is not present
    */
    static *string getBundleLinkUrl(hash<auto> bundle, string relation) {
        foreach hash<auto> link in (bundle.link) {
            if (link.relation == relation) {
                return link.url;
            }
        }
    }

    #! Returns a readable summary from a FHIR OperationOutcome resource
    /** @param outcome FHIR OperationOutcome resource
        @return compact human-readable summary suitable for an exception description
    */
    static string getOperationOutcomeSummary(hash<auto> outcome) {
        if (outcome.resourceType != "OperationOutcome") {
            return sprintf("%y", outcome);
        }

        list<string> parts;
        foreach hash<auto> issue in (outcome.issue) {
            string text = issue.diagnostics ?? issue.details.text ?? issue.code ?? "unknown";
            string severity = issue.severity ?? "unknown";
            string code = issue.code ?? "unknown";
            parts += sprintf("%s/%s: %s", severity, code, text);
        }

        return parts ? parts.join("; ") : "FHIR OperationOutcome";
    }
}

#! FHIR JSON REST client
public class FhirRestClient inherits RestClient::RestClient, FhirRestClientBase {
    #! Creates the FHIR REST client
    /** @param opts valid options are all options supported by @ref RestClient::RestClient
        @param do_not_connect if False, then a connection will be established immediately
        @throw REST-CLIENT-CONSTRUCTOR-ERROR if the underlying REST client cannot be initialized
    */
    constructor(hash<auto> opts, *softbool do_not_connect)
            : RestClient(FhirRestClientBase::getOptions(opts), do_not_connect) {
        setAssumedEncoding("UTF-8");
    }

    #! Returns the server CapabilityStatement
    /** @return server \c CapabilityStatement resource
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> getCapabilityStatement() {
        return doFhirRequest("GET", "metadata").body;
    }

    #! Returns the FHIR version from the given or fetched CapabilityStatement
    /** @param capability_statement optional CapabilityStatement resource; if omitted, the server metadata
        endpoint is queried
        @return FHIR version string from \c CapabilityStatement.fhirVersion
        @throw FHIR-CAPABILITY-STATEMENT-ERROR if the CapabilityStatement has no string \c fhirVersion field
        @throw FHIR-OPERATION-OUTCOME if fetching metadata returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if fetching metadata returns another non-successful HTTP response
    */
    string getFhirVersion(*hash<auto> capability_statement) {
        hash<auto> cs = capability_statement ?? getCapabilityStatement();
        if (cs.fhirVersion.typeCode() != NT_STRING) {
            throw "FHIR-CAPABILITY-STATEMENT-ERROR", "CapabilityStatement.fhirVersion is missing or invalid";
        }
        return cs.fhirVersion;
    }

    #! Returns SMART on FHIR configuration from the server
    /** @return SMART on FHIR discovery document
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> getSmartConfiguration() {
        return doFhirRequest("GET", ".well-known/smart-configuration").body;
    }

    #! Reads a resource instance
    /** @param resource_type FHIR resource type name
        @param id FHIR logical id
        @return requested FHIR resource
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-ID-ERROR if the id is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> readResource(string resource_type, string id) {
        return doFhirRequest("GET", getResourcePath(resource_type, id)).body;
    }

    #! Searches a resource type
    /** @param resource_type FHIR resource type name
        @param params optional FHIR search parameters; list values are emitted as repeated query parameters
        @return FHIR Bundle search result
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> searchResources(string resource_type, *hash<auto> params) {
        return doFhirRequest("GET", getSearchPath(resource_type, params)).body;
    }

    #! Creates a resource and returns the full REST response
    /** @param resource_type FHIR resource type name
        @param resource FHIR resource body
        @param if_none_exist optional FHIR conditional create search expression for the
        \c If-None-Exist header
        @return full REST response including status, headers, and parsed body
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> createResource(string resource_type, hash<auto> resource,
            *string if_none_exist) {
        validateResourceType(resource_type);
        hash<auto> hdr = FhirJsonBodyHeaders;
        if (if_none_exist.val()) {
            hdr."If-None-Exist" = if_none_exist;
        }
        return doFhirRequest("POST", resource_type, resource, hdr);
    }

    #! Updates a resource and returns the full REST response
    /** @param resource_type FHIR resource type name
        @param id FHIR logical id
        @param resource FHIR resource body
        @param etag optional ETag for the \c If-Match header
        @return full REST response including status, headers, and parsed body
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-ID-ERROR if the id is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> updateResource(string resource_type, string id, hash<auto> resource,
            *string etag) {
        hash<auto> hdr = FhirJsonBodyHeaders;
        if (etag.val()) {
            hdr."If-Match" = etag;
        }
        return doFhirRequest("PUT", getResourcePath(resource_type, id), resource, hdr);
    }

    #! Conditionally updates a resource and returns the full REST response
    /** @param resource_type FHIR resource type name
        @param search_params FHIR conditional update search parameters
        @param resource FHIR resource body
        @return full REST response including status, headers, and parsed body
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> conditionalUpdateResource(string resource_type, hash<auto> search_params,
            hash<auto> resource) {
        return doFhirRequest("PUT", getSearchPath(resource_type, search_params), resource, FhirJsonBodyHeaders);
    }

    #! Patches a resource and returns the full REST response
    /** @param resource_type FHIR resource type name
        @param id FHIR logical id
        @param patch_body patch document body
        @param content_type patch document content type
        @param etag optional ETag for the \c If-Match header
        @return full REST response including status, headers, and parsed body
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-ID-ERROR if the id is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> patchResource(string resource_type, string id, auto patch_body,
            string content_type = "application/json-patch+json", *string etag) {
        hash<auto> hdr = DefaultHeaders + {
            "Content-Type": content_type,
        };
        if (etag.val()) {
            hdr."If-Match" = etag;
        }
        return doFhirRequest("PATCH", getResourcePath(resource_type, id), patch_body, hdr);
    }

    #! Deletes a resource and returns the full REST response
    /** @param resource_type FHIR resource type name
        @param id FHIR logical id
        @param etag optional ETag for the \c If-Match header
        @return full REST response including status, headers, and parsed body
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-ID-ERROR if the id is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> deleteResource(string resource_type, string id, *string etag) {
        hash<auto> hdr = DefaultHeaders;
        if (etag.val()) {
            hdr."If-Match" = etag;
        }
        return doFhirRequest("DELETE", getResourcePath(resource_type, id), NOTHING, hdr);
    }

    #! Calls a resource-level or type-level $validate operation
    /** @param resource FHIR resource body to validate
        @param resource_type optional FHIR resource type for type- or instance-level validation
        @param id optional FHIR logical id for instance-level validation
        @return FHIR OperationOutcome validation result
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-ID-ERROR if the id is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error response
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> validateResource(hash<auto> resource, *string resource_type, *string id) {
        string path;
        if (resource_type.val() && id.val()) {
            path = getResourcePath(resource_type, id) + "/$validate";
        } else if (resource_type.val()) {
            validateResourceType(resource_type);
            path = resource_type + "/$validate";
        } else {
            path = "$validate";
        }
        return doFhirRequest("POST", path, resource, FhirJsonBodyHeaders).body;
    }

    #! Calls a terminology $validate-code operation
    /** @param code_system_path relative path to a CodeSystem or ValueSet endpoint
        @param params FHIR operation query parameters
        @return FHIR Parameters or OperationOutcome response from the terminology operation
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error response
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> validateCode(string code_system_path, hash<auto> params) {
        return doFhirRequest("GET", getPathWithParams(code_system_path + "/$validate-code", params)).body;
    }

    #! Calls a ValueSet $expand operation
    /** @param value_set_path relative path to a ValueSet endpoint
        @param params optional FHIR operation query parameters
        @return FHIR ValueSet expansion response
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error response
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> expandValueSet(string value_set_path, *hash<auto> params) {
        return doFhirRequest("GET", getPathWithParams(value_set_path + "/$expand", params)).body;
    }

    #! Sends a FHIR REST request and maps OperationOutcome errors
    /** @param method HTTP method
        @param path relative FHIR REST path
        @param body optional request body
        @param hdr optional request headers
        @return full REST response including status, headers, and parsed body
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error response
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> doFhirRequest(string method, string path, auto body = NOTHING,
            *hash<auto> hdr) {
        validateRelativePath(path);
        try {
            hash<RestClient::RestResponseInfo> resp = restDoRequest(method, path, body, hdr);
            if (resp.status_code < 200 || resp.status_code >= 300) {
                if (resp.body.typeCode() == NT_HASH && resp.body.resourceType == "OperationOutcome") {
                    throw "FHIR-OPERATION-OUTCOME", getOperationOutcomeSummary(resp.body), {
                        "headers": resp.headers,
                        "outcome": resp.body,
                        "status_code": resp.status_code,
                    };
                }
                throw "FHIR-REST-ERROR", sprintf("FHIR REST request failed with HTTP status %d",
                    resp.status_code), resp;
            }
            return resp;
        } catch (hash<ExceptionInfo> ex) {
            if (*hash<auto> outcome = getExceptionOperationOutcome(ex)) {
                throw "FHIR-OPERATION-OUTCOME", getOperationOutcomeSummary(outcome), {
                    "headers": ex.arg - "body",
                    "outcome": outcome,
                    "status_code": ex.arg.status_code,
                };
            }
            rethrow;
        }
    }

    #! Processes the raw REST response and treats application/fhir+json as JSON
    /** @param resp raw REST response
        @param method HTTP method
        @param path relative REST path
        @param info optional response info reference
        @return processed REST response body
    */
    hash<auto> processRestResponse(hash<auto> resp, string method, string path, *reference<hash<auto>> info) {
        normalizeFhirJsonContentType(\resp);
        return RestClient::processRestResponse(resp, method, path, \info);
    }

    #! Processes the raw async REST response and treats application/fhir+json as JSON
    /** @param resp raw REST response
        @param method HTTP method
        @param path relative REST path
        @param info response info reference
        @param decode_errors whether error responses should be decoded by the REST client
        @return processed REST response body
    */
    hash<auto> processAsyncResponse(hash<auto> resp, string method, string path,
            reference<hash<auto>> info, bool decode_errors) {
        normalizeFhirJsonContentType(\resp);
        return RestClient::processAsyncResponse(resp, method, path, \info, decode_errors);
    }

    #! Normalizes FHIR JSON response content for RestClient deserialization
    private static normalizeFhirJsonContentType(reference<hash<auto>> resp) {
        string ct = resp."content-type" ?? "";
        if (ct =~ /^application\/fhir\+json/i) {
            resp."content-type" = MimeTypeJson;
        }
    }

    #! Extracts an OperationOutcome from an exception, if possible
    private static *hash<auto> getExceptionOperationOutcome(hash<ExceptionInfo> ex) {
        if (ex.arg.typeCode() != NT_HASH) {
            return;
        }

        if (ex.arg.body.typeCode() == NT_HASH && ex.arg.body.resourceType == "OperationOutcome") {
            return ex.arg.body;
        }

        string ct = ex.arg."content-type" ?? ex.arg.headers."content-type" ?? "";
        if (ct =~ /^application\/fhir\+json/i) {
            try {
                string desc = ex.desc;
                desc =~ s/ \(REST URL .*$//;
                hash<auto> body = parse_json(desc);
                if (body.resourceType == "OperationOutcome") {
                    return body;
                }
            } catch () {
            }
        }
    }
}

} # namespace FhirRestClient
