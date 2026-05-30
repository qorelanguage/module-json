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

        #! Bundle types that can be submitted to the FHIR service base
        const WritableBundleTypes = {
            "batch": True,
            "transaction": True,
        };

        #! HTTP verbs allowed in FHIR Bundle.entry.request.method
        const BundleRequestMethods = {
            "DELETE": True,
            "GET": True,
            "PATCH": True,
            "POST": True,
            "PUT": True,
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

    #! Builds a FHIR \c transaction or \c batch Bundle resource
    /** @param entries Bundle entries
        @param type Bundle type; must be \c "transaction" or \c "batch"
        @return FHIR Bundle resource
        @throw FHIR-BUNDLE-ERROR if \a type is not writable
    */
    static hash<auto> makeBundle(list<hash<auto>> entries, string type = "transaction") {
        validateWritableBundleType(type);
        return cast<hash<auto>>({
            "resourceType": "Bundle",
            "type": type,
            "entry": entries,
        });
    }

    #! Builds a generic FHIR transaction/batch Bundle entry
    /** @param method HTTP method for \c Bundle.entry.request.method
        @param url relative FHIR request URL for \c Bundle.entry.request.url
        @param resource optional resource body
        @param request_options optional extra request fields such as \c ifNoneExist or \c ifMatch
        @param full_url optional Bundle \c fullUrl
        @return FHIR Bundle entry
        @throw FHIR-BUNDLE-ERROR if the method is not supported
        @throw FHIR-PATH-ERROR if \a url is not a safe relative FHIR path
    */
    static hash<auto> makeBundleEntry(string method, string url, *hash<auto> resource = NOTHING,
            *hash<auto> request_options = NOTHING, *string full_url = NOTHING) {
        validateRelativePath(url);
        hash<auto> request = request_options ?? {};
        request.method = normalizeBundleRequestMethod(method);
        request.url = url;

        hash<auto> rv = cast<hash<auto>>({"request": request});
        if (resource.val()) {
            rv.resource = resource;
        }
        if (full_url.val()) {
            rv.fullUrl = full_url;
        }
        return rv;
    }

    #! Builds a conditional-create Bundle entry
    /** @param resource_type FHIR resource type to create
        @param resource FHIR resource body
        @param search_expression FHIR conditional create search expression for \c ifNoneExist
        @param full_url optional Bundle \c fullUrl
        @return FHIR Bundle entry
    */
    static hash<auto> makeConditionalCreateBundleEntry(string resource_type, hash<auto> resource,
            string search_expression, *string full_url = NOTHING) {
        validateResourceType(resource_type);
        if (!search_expression) {
            throw "FHIR-BUNDLE-ERROR", "conditional create search expression must not be empty";
        }
        return makeBundleEntry("POST", resource_type, resource, {"ifNoneExist": search_expression}, full_url);
    }

    #! Builds an update Bundle entry
    /** @param resource_type FHIR resource type to update
        @param id FHIR logical id to update
        @param resource FHIR resource body
        @param etag optional ETag for \c ifMatch
        @param full_url optional Bundle \c fullUrl
        @return FHIR Bundle entry
    */
    static hash<auto> makeUpdateBundleEntry(string resource_type, string id, hash<auto> resource,
            *string etag = NOTHING, *string full_url = NOTHING) {
        hash<auto> request_options = cast<hash<auto>>({});
        if (etag.val()) {
            request_options.ifMatch = etag;
        }
        return makeBundleEntry("PUT", getResourcePath(resource_type, id), resource, request_options, full_url);
    }

    #! Builds a conditional-update Bundle entry
    /** @param resource_type FHIR resource type to update
        @param search_params FHIR conditional update search parameters
        @param resource FHIR resource body
        @param full_url optional Bundle \c fullUrl
        @return FHIR Bundle entry
    */
    static hash<auto> makeConditionalUpdateBundleEntry(string resource_type, hash<auto> search_params,
            hash<auto> resource, *string full_url = NOTHING) {
        return makeBundleEntry("PUT", getSearchPath(resource_type, search_params), resource, NOTHING, full_url);
    }

    #! Builds a delete Bundle entry
    /** @param resource_type FHIR resource type to delete
        @param id FHIR logical id to delete
        @param etag optional ETag for \c ifMatch
        @param full_url optional Bundle \c fullUrl
        @return FHIR Bundle entry
    */
    static hash<auto> makeDeleteBundleEntry(string resource_type, string id, *string etag = NOTHING,
            *string full_url = NOTHING) {
        hash<auto> request_options = cast<hash<auto>>({});
        if (etag.val()) {
            request_options.ifMatch = etag;
        }
        return makeBundleEntry("DELETE", getResourcePath(resource_type, id), NOTHING, request_options, full_url);
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

    #! Validates a Bundle type that can be POSTed to the FHIR service base
    /** @param type Bundle type
        @throw FHIR-BUNDLE-ERROR if the type is not \c "transaction" or \c "batch"
    */
    static validateWritableBundleType(string type) {
        if (!exists WritableBundleTypes{type}) {
            throw "FHIR-BUNDLE-ERROR", sprintf("FHIR Bundle type must be \"transaction\" or \"batch\"; got %y",
                type);
        }
    }

    #! Normalizes and validates a Bundle request method
    /** @param method HTTP method
        @return uppercase method
        @throw FHIR-BUNDLE-ERROR if the method is not supported in Bundle.entry.request.method
    */
    static string normalizeBundleRequestMethod(string method) {
        string normalized = method.upr();
        if (!exists BundleRequestMethods{normalized}) {
            throw "FHIR-BUNDLE-ERROR",
                sprintf("unsupported FHIR Bundle request method: %y", method);
        }
        return normalized;
    }
}

#! FHIR JSON REST client
public class FhirRestClient inherits RestClient::RestClient, FhirRestClientBase {
    private {
        *hash<string, bool> capability_resource_type_map;
        Mutex capability_resource_type_mutex();
    }

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

    #! Returns the FHIR version parameter from a Content-Type header, if present
    /** @param content_type response Content-Type header value
        @return FHIR version parameter value or no value if the parameter is not present
    */
    static *string getFhirVersionFromContentType(string content_type) {
        *list<*string> match = regex_extract(content_type, "(?:^|;)\\s*fhirVersion\\s*=\\s*\"?([^\";\\s]+)\"?",
            RE_Caseless);
        return match ? match[0] : NOTHING;
    }

    #! Returns resource types advertised by the server CapabilityStatement
    /** @param reload if True, reloads the CapabilityStatement instead of using cached resource metadata
        @return sorted list of resource types advertised for server REST interactions

        @throw FHIR-CAPABILITY-STATEMENT-ERROR if no server resource metadata is available
        @throw FHIR-OPERATION-OUTCOME if fetching metadata returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if fetching metadata returns another non-successful HTTP response
    */
    list<string> getCapabilityStatementResourceTypes(bool reload = False) {
        return sort(keys getCapabilityStatementResourceTypeMap(reload));
    }

    #! Returns True if the server CapabilityStatement advertises \a resource_type
    /** @param resource_type FHIR resource type
        @param reload if True, reloads the CapabilityStatement instead of using cached resource metadata
    */
    bool isCapabilityStatementResourceType(string resource_type, bool reload = False) {
        validateResourceType(resource_type);
        return exists getCapabilityStatementResourceTypeMap(reload){resource_type};
    }

    #! Validates that the server CapabilityStatement advertises \a resource_type
    /** @param resource_type FHIR resource type
        @param reload if True, reloads the CapabilityStatement instead of using cached resource metadata

        @throw FHIR-CAPABILITY-RESOURCE-ERROR if \a resource_type is not advertised by the server
    */
    string assertCapabilityStatementResourceType(string resource_type, bool reload = False) {
        validateResourceType(resource_type);
        if (!exists getCapabilityStatementResourceTypeMap(reload){resource_type}) {
            throw "FHIR-CAPABILITY-RESOURCE-ERROR",
                sprintf("FHIR server CapabilityStatement does not advertise resource type %y", resource_type);
        }
        return resource_type;
    }

    #! Extracts server resource types from a CapabilityStatement resource
    /** @param capability_statement FHIR CapabilityStatement resource
        @return sorted resource type list from server-mode REST metadata
    */
    static list<string> extractCapabilityStatementResourceTypes(hash<auto> capability_statement) {
        if (capability_statement.resourceType != "CapabilityStatement") {
            throw "FHIR-CAPABILITY-STATEMENT-ERROR", "resource is not a FHIR CapabilityStatement";
        }

        hash<string, bool> resource_types = {};
        foreach hash<auto> rest in (capability_statement.rest) {
            if (rest.mode && rest.mode != "server") {
                continue;
            }
            foreach hash<auto> resource in (rest.resource) {
                if (resource.type.typeCode() != NT_STRING) {
                    continue;
                }
                validateResourceType(resource.type);
                resource_types{resource.type} = True;
            }
        }

        if (resource_types.empty()) {
            throw "FHIR-CAPABILITY-STATEMENT-ERROR",
                "CapabilityStatement does not advertise any server resource types";
        }
        return sort(keys resource_types);
    }

    #! Returns SMART on FHIR configuration from the server
    /** @return SMART on FHIR discovery document
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> getSmartConfiguration() {
        return doFhirRequest("GET", ".well-known/smart-configuration").body;
    }

    #! Returns RestClient OAuth2 options from SMART on FHIR discovery metadata
    /** @param opts caller-supplied OAuth2 options to merge with SMART discovery URLs
        @return options hash using @ref RestClient::RestClient OAuth2 option names

        @throw FHIR-SMART-CONFIGURATION-ERROR if SMART discovery metadata is missing required endpoint fields
    */
    hash<auto> getSmartOAuth2ClientOptions(*hash<auto> opts = NOTHING) {
        return makeSmartOAuth2ClientOptions(getSmartConfiguration(), opts);
    }

    #! Builds RestClient OAuth2 options from SMART on FHIR discovery metadata
    /** @param smart_configuration SMART on FHIR discovery metadata
        @param opts caller-supplied OAuth2 options to merge with SMART discovery URLs
        @return options hash using @ref RestClient::RestClient OAuth2 option names

        @throw FHIR-SMART-CONFIGURATION-ERROR if SMART discovery metadata is missing required endpoint fields
    */
    static hash<auto> makeSmartOAuth2ClientOptions(hash<auto> smart_configuration, *hash<auto> opts = NOTHING) {
        if (smart_configuration.token_endpoint.typeCode() != NT_STRING) {
            throw "FHIR-SMART-CONFIGURATION-ERROR", "SMART configuration token_endpoint is missing or invalid";
        }

        hash<auto> rv = opts ?? {};
        rv.oauth2_token_url = smart_configuration.token_endpoint;
        if (smart_configuration.authorization_endpoint.typeCode() == NT_STRING) {
            rv.oauth2_auth_url = smart_configuration.authorization_endpoint;
        }
        return rv;
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

    #! Searches a resource type and follows Bundle pagination links
    /** @param resource_type FHIR resource type name
        @param params optional FHIR search parameters; list values are emitted as repeated query parameters
        @param max_pages maximum Bundle pages to fetch
        @return FHIR Bundle search result with entries from all fetched pages

        @throw FHIR-PAGINATION-ERROR if pagination links are invalid or \a max_pages is exhausted
        @throw FHIR-RESOURCE-TYPE-ERROR if the resource type is invalid
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> searchAllResources(string resource_type, *hash<auto> params, int max_pages = 100) {
        if (max_pages < 1) {
            throw "FHIR-PAGINATION-ERROR", sprintf("max_pages must be positive; got %d", max_pages);
        }

        hash<auto> bundle = searchResources(resource_type, params);
        assertBundleSearchResult(bundle);

        list<auto> entries = bundle.entry ?? ();
        int pages = 1;
        *string next_url = getBundleLinkUrl(bundle, "next");
        while (next_url) {
            if (pages >= max_pages) {
                throw "FHIR-PAGINATION-ERROR",
                    sprintf("FHIR search pagination exceeded max_pages=%d", max_pages);
            }
            hash<auto> next_bundle = doFhirRequest("GET", getBundleLinkPath(next_url)).body;
            assertBundleSearchResult(next_bundle);
            entries += next_bundle.entry ?? ();
            bundle.link = next_bundle.link;
            next_url = getBundleLinkUrl(next_bundle, "next");
            ++pages;
        }
        bundle.entry = entries;
        return bundle;
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

    #! Submits a FHIR transaction or batch Bundle to the service base
    /** @param bundle FHIR Bundle resource with \c type \c "transaction" or \c "batch"
        @return full REST response including status, headers, and parsed body
        @throw FHIR-BUNDLE-ERROR if the Bundle cannot be submitted safely
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<RestClient::RestResponseInfo> submitBundle(hash<auto> bundle) {
        assertSubmittableBundle(bundle);
        return doCheckedFhirRequest("POST", "", bundle, FhirJsonBodyHeaders);
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

    #! Calls a CodeSystem $lookup operation
    /** @param code_system_path relative path to a CodeSystem endpoint
        @param params FHIR operation query parameters
        @return FHIR Parameters or OperationOutcome response from the terminology operation
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error response
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> lookupCode(string code_system_path, hash<auto> params) {
        return doFhirRequest("GET", getPathWithParams(code_system_path + "/$lookup", params)).body;
    }

    #! Calls a ConceptMap $translate operation
    /** @param concept_map_path relative path to a ConceptMap endpoint
        @param params FHIR operation query parameters
        @return FHIR Parameters or OperationOutcome response from the terminology operation
        @throw FHIR-PATH-ERROR if the path is empty, absolute, or contains path traversal
        @throw FHIR-OPERATION-OUTCOME if the server returns a FHIR OperationOutcome error response
        @throw FHIR-REST-ERROR if the server returns another non-successful HTTP response
    */
    hash<auto> translateCode(string concept_map_path, hash<auto> params) {
        return doFhirRequest("GET", getPathWithParams(concept_map_path + "/$translate", params)).body;
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
        return doCheckedFhirRequest(method, path, body, hdr);
    }

    private hash<RestClient::RestResponseInfo> doCheckedFhirRequest(string method, string path, auto body,
            *hash<auto> hdr) {
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

    private hash<string, bool> getCapabilityStatementResourceTypeMap(bool reload) {
        if (!reload) {
            AutoLock al(capability_resource_type_mutex);
            if (capability_resource_type_map) {
                return capability_resource_type_map;
            }
        }

        list<string> resource_types = extractCapabilityStatementResourceTypes(getCapabilityStatement());
        hash<string, bool> resource_type_map = {};
        foreach string resource_type in (resource_types) {
            resource_type_map{resource_type} = True;
        }

        AutoLock al(capability_resource_type_mutex);
        capability_resource_type_map = resource_type_map;
        return resource_type_map;
    }

    private static assertBundleSearchResult(hash<auto> bundle) {
        if (bundle.resourceType != "Bundle") {
            throw "FHIR-PAGINATION-ERROR",
                sprintf("FHIR search pagination expected a Bundle resource, got %y", bundle.resourceType);
        }
    }

    private string getBundleLinkPath(string url) {
        string path = url;
        if (url =~ /^[A-Za-z][A-Za-z0-9+.-]*:/) {
            hash<UrlInfo> link = parse_url(url);
            hash<UrlInfo> base = parse_url(getUrl());
            if (link.protocol.lwr() != base.protocol.lwr() || link.host.lwr() != base.host.lwr()
                    || getUrlPort(link) != getUrlPort(base)) {
                throw "FHIR-PAGINATION-ERROR",
                    sprintf("FHIR Bundle pagination link targets a different endpoint: %y", url);
            }

            path = link.path;
            string base_path = base.path ?? "";
            if (base_path && path.substr(0, base_path.size()) == base_path) {
                path = path.substr(base_path.size());
            }
        }
        if (path =~ /^\//) {
            path = path.substr(1);
        }
        validateRelativePath(path);
        return path;
    }

    private static int getUrlPort(hash<UrlInfo> url_info) {
        if (url_info.port) {
            return url_info.port;
        }
        switch (url_info.protocol.lwr()) {
            case "http":
                return 80;
            case "https":
                return 443;
        }
        return 0;
    }

    private static assertSubmittableBundle(hash<auto> bundle) {
        if (bundle.resourceType != "Bundle") {
            throw "FHIR-BUNDLE-ERROR", sprintf("expected FHIR Bundle resource, got %y", bundle.resourceType);
        }
        if (bundle.type.typeCode() != NT_STRING) {
            throw "FHIR-BUNDLE-ERROR", "FHIR Bundle.type is missing or invalid";
        }
        validateWritableBundleType(bundle.type);
        if (bundle.entry.typeCode() != NT_LIST) {
            throw "FHIR-BUNDLE-ERROR", "FHIR Bundle.entry must be a list for transaction or batch submission";
        }

        int index = 0;
        foreach hash<auto> entry in (bundle.entry) {
            ++index;
            if (entry.request.typeCode() != NT_HASH) {
                throw "FHIR-BUNDLE-ERROR",
                    sprintf("FHIR Bundle.entry[%d].request is missing or invalid", index);
            }
            if (entry.request.method.typeCode() != NT_STRING || !entry.request.method) {
                throw "FHIR-BUNDLE-ERROR",
                    sprintf("FHIR Bundle.entry[%d].request.method is missing or invalid", index);
            }
            entry.request.method = normalizeBundleRequestMethod(entry.request.method);
            if (entry.request.url.typeCode() != NT_STRING || !entry.request.url) {
                throw "FHIR-BUNDLE-ERROR",
                    sprintf("FHIR Bundle.entry[%d].request.url is missing or invalid", index);
            }
            validateRelativePath(entry.request.url);
            switch (entry.request.method) {
                case "POST":
                case "PUT":
                case "PATCH":
                    if (entry.resource.typeCode() != NT_HASH) {
                        throw "FHIR-BUNDLE-ERROR",
                            sprintf("FHIR Bundle.entry[%d].resource is required for %s requests", index,
                                entry.request.method);
                    }
                    break;
            }
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
