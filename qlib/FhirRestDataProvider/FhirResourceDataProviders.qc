# -*- mode: qore; indent-tabs-mode: nil -*-
#! Qore FHIR resource operation data providers

/*  Copyright (C) 2026 Qore Technologies, s.r.o.

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

#! contains all public definitions in the FhirRestDataProvider module
public namespace FhirRestDataProvider {
#! Read FHIR resource data provider
public class FhirReadResourceDataProvider inherits FhirRestDataProviderBase {
    public {
        const ProviderInfo = <DataProviderInfo>{
            "name": "read",
            "desc": "Reads a FHIR resource by type and ID",
            "type": "FhirReadResourceDataProvider",
            "supports_request": True,
        };
    }

    constructor(FhirRestClient::FhirRestClient fhir) : FhirRestDataProviderBase(fhir) {
    }

    string getName() {
        return "read";
    }

    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return FhirReadResourceRequestDataType;
    }

    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return FhirResourceDataType;
    }

    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        return fhir.readResource(assertFhirR4ResourceType(req.resource_type), req.id);
    }

    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}

#! Search FHIR resources data provider
public class FhirSearchResourcesDataProvider inherits FhirRestDataProviderBase {
    public {
        const ProviderInfo = <DataProviderInfo>{
            "name": "search",
            "desc": "Searches FHIR resources",
            "type": "FhirSearchResourcesDataProvider",
            "supports_request": True,
        };
    }

    constructor(FhirRestClient::FhirRestClient fhir) : FhirRestDataProviderBase(fhir) {
    }

    string getName() {
        return "search";
    }

    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return FhirSearchResourcesRequestDataType;
    }

    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return FhirBundleDataType;
    }

    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        return fhir.searchResources(assertFhirR4ResourceType(req.resource_type), req.params);
    }

    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}

#! Create FHIR resource data provider
public class FhirCreateResourceDataProvider inherits FhirRestDataProviderBase {
    public {
        const ProviderInfo = <DataProviderInfo>{
            "name": "create",
            "desc": "Creates a FHIR resource",
            "type": "FhirCreateResourceDataProvider",
            "supports_request": True,
        };
    }

    constructor(FhirRestClient::FhirRestClient fhir) : FhirRestDataProviderBase(fhir) {
    }

    string getName() {
        return "create";
    }

    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return FhirCreateResourceRequestDataType;
    }

    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return FhirRestResponseDataType;
    }

    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        return getResponseData(fhir.createResource(assertFhirR4ResourceRequestType(req.resource_type, req.resource),
            req.resource, req.if_none_exist));
    }

    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}

#! Update FHIR resource data provider
public class FhirUpdateResourceDataProvider inherits FhirRestDataProviderBase {
    public {
        const ProviderInfo = <DataProviderInfo>{
            "name": "update",
            "desc": "Updates a FHIR resource",
            "type": "FhirUpdateResourceDataProvider",
            "supports_request": True,
        };
    }

    constructor(FhirRestClient::FhirRestClient fhir) : FhirRestDataProviderBase(fhir) {
    }

    string getName() {
        return "update";
    }

    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return FhirUpdateResourceRequestDataType;
    }

    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return FhirRestResponseDataType;
    }

    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        return getResponseData(fhir.updateResource(assertFhirR4ResourceRequestType(req.resource_type, req.resource),
            req.id, req.resource, req.etag));
    }

    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}

#! Delete FHIR resource data provider
public class FhirDeleteResourceDataProvider inherits FhirRestDataProviderBase {
    public {
        const ProviderInfo = <DataProviderInfo>{
            "name": "delete",
            "desc": "Deletes a FHIR resource",
            "type": "FhirDeleteResourceDataProvider",
            "supports_request": True,
        };
    }

    constructor(FhirRestClient::FhirRestClient fhir) : FhirRestDataProviderBase(fhir) {
    }

    string getName() {
        return "delete";
    }

    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return FhirDeleteResourceRequestDataType;
    }

    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return FhirRestResponseDataType;
    }

    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        return getResponseData(fhir.deleteResource(assertFhirR4ResourceType(req.resource_type), req.id, req.etag));
    }

    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}

#! Validate FHIR resource data provider
public class FhirValidateResourceDataProvider inherits FhirRestDataProviderBase {
    public {
        const ProviderInfo = <DataProviderInfo>{
            "name": "validate",
            "desc": "Validates a FHIR resource through $validate",
            "type": "FhirValidateResourceDataProvider",
            "supports_request": True,
        };
    }

    constructor(FhirRestClient::FhirRestClient fhir) : FhirRestDataProviderBase(fhir) {
    }

    string getName() {
        return "validate";
    }

    private *DataProvider::AbstractDataProviderType getRequestTypeImpl() {
        return FhirValidateResourceRequestDataType;
    }

    private *DataProvider::AbstractDataProviderType getResponseTypeImpl() {
        return FhirOperationOutcomeDataType;
    }

    private auto doRequestImpl(auto req, *hash<auto> request_options) {
        if (req.resource_type != NOTHING) {
            assertFhirR4ResourceRequestType(req.resource_type, req.resource);
        } else {
            assertFhirR4ResourceBodyType(req.resource);
        }
        return fhir.validateResource(req.resource, req.resource_type, req.id);
    }

    private hash<DataProviderInfo> getStaticInfoImpl() {
        return ProviderInfo;
    }
}
}
