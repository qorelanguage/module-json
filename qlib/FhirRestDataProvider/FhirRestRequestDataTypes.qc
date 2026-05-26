# -*- mode: qore; indent-tabs-mode: nil -*-
#! Qore FHIR REST data provider request data types

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
#! Read resource request data type
public class FhirReadResourceRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "resource_type": {
                "type": StringType,
                "display_name": "Resource Type",
                "short_desc": "FHIR resource type",
                "desc": "FHIR resource type, for example `Patient` or `Observation`",
                "example_value": "Patient",
            },
            "id": {
                "type": StringType,
                "display_name": "ID",
                "short_desc": "FHIR logical ID",
                "desc": "FHIR logical ID of the resource instance",
                "example_value": "example",
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Search resources request data type
public class FhirSearchResourcesRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "resource_type": {
                "type": StringType,
                "display_name": "Resource Type",
                "short_desc": "FHIR resource type",
                "desc": "FHIR resource type to search",
                "example_value": "Patient",
            },
            "params": {
                "type": AutoHashOrNothingType,
                "display_name": "Search Parameters",
                "short_desc": "FHIR search parameters",
                "desc": "FHIR search parameters. List values are sent as repeated query parameters, which "
                    "supports `_include`, `_revinclude`, and other repeated FHIR search parameters.",
                "example_value": {"family": "Smith"},
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Create resource request data type
public class FhirCreateResourceRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "resource_type": {
                "type": StringType,
                "display_name": "Resource Type",
                "short_desc": "FHIR resource type",
                "desc": "FHIR resource type to create",
                "example_value": "Patient",
            },
            "resource": {
                "type": AutoHashType,
                "display_name": "Resource",
                "short_desc": "FHIR resource body",
                "desc": "FHIR resource body as a JSON-compatible hash",
                "example_value": {"resourceType": "Patient", "name": ({"family": "Jones"},)},
            },
            "if_none_exist": {
                "type": StringOrNothingType,
                "display_name": "If-None-Exist",
                "short_desc": "Conditional create criteria",
                "desc": "FHIR conditional create search expression sent in the `If-None-Exist` header",
                "example_value": "identifier=http://hospital.example/mrn|12345",
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Update resource request data type
public class FhirUpdateResourceRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "resource_type": {
                "type": StringType,
                "display_name": "Resource Type",
                "short_desc": "FHIR resource type",
                "desc": "FHIR resource type to update",
                "example_value": "Patient",
            },
            "id": {
                "type": StringType,
                "display_name": "ID",
                "short_desc": "FHIR logical ID",
                "desc": "FHIR logical ID of the resource instance",
                "example_value": "example",
            },
            "resource": {
                "type": AutoHashType,
                "display_name": "Resource",
                "short_desc": "FHIR resource body",
                "desc": "FHIR resource body as a JSON-compatible hash",
                "example_value": {"resourceType": "Patient", "id": "example", "active": True},
            },
            "etag": {
                "type": StringOrNothingType,
                "display_name": "ETag",
                "short_desc": "FHIR version ETag",
                "desc": "ETag value sent in the `If-Match` header for optimistic concurrency",
                "example_value": "W/\"1\"",
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Delete resource request data type
public class FhirDeleteResourceRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "resource_type": {
                "type": StringType,
                "display_name": "Resource Type",
                "short_desc": "FHIR resource type",
                "desc": "FHIR resource type to delete",
                "example_value": "Patient",
            },
            "id": {
                "type": StringType,
                "display_name": "ID",
                "short_desc": "FHIR logical ID",
                "desc": "FHIR logical ID of the resource instance",
                "example_value": "example",
            },
            "etag": {
                "type": StringOrNothingType,
                "display_name": "ETag",
                "short_desc": "FHIR version ETag",
                "desc": "ETag value sent in the `If-Match` header for optimistic concurrency",
                "example_value": "W/\"1\"",
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Validate resource request data type
public class FhirValidateResourceRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "resource": {
                "type": AutoHashType,
                "display_name": "Resource",
                "short_desc": "FHIR resource body",
                "desc": "FHIR resource body to validate",
                "example_value": {"resourceType": "Patient", "id": "example"},
            },
            "resource_type": {
                "type": StringOrNothingType,
                "display_name": "Resource Type",
                "short_desc": "FHIR resource type",
                "desc": "Optional FHIR resource type for type-level or instance-level validation",
                "example_value": "Patient",
            },
            "id": {
                "type": StringOrNothingType,
                "display_name": "ID",
                "short_desc": "FHIR logical ID",
                "desc": "Optional FHIR logical ID for instance-level validation",
                "example_value": "example",
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Validate code request data type
public class FhirValidateCodeRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "path": {
                "type": StringType,
                "display_name": "Path",
                "short_desc": "CodeSystem or ValueSet path",
                "desc": "Relative FHIR path to a CodeSystem or ValueSet endpoint",
                "example_value": "CodeSystem/example",
            },
            "params": {
                "type": AutoHashType,
                "display_name": "Parameters",
                "short_desc": "Operation parameters",
                "desc": "FHIR `$validate-code` operation parameters",
                "example_value": {"code": "abc"},
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

#! Expand ValueSet request data type
public class FhirExpandValueSetRequestDataType inherits HashDataType {
    public {
        const Fields = {
            "path": {
                "type": StringType,
                "display_name": "Path",
                "short_desc": "ValueSet path",
                "desc": "Relative FHIR path to a ValueSet endpoint",
                "example_value": "ValueSet/example",
            },
            "params": {
                "type": AutoHashOrNothingType,
                "display_name": "Parameters",
                "short_desc": "Operation parameters",
                "desc": "Optional FHIR `$expand` operation parameters",
                "example_value": {"filter": "smi"},
            },
        };
    }

    #! Creates the object
    constructor() {
        addQoreFields(Fields);
    }
}

public const FhirReadResourceRequestDataType = new FhirReadResourceRequestDataType();
public const FhirSearchResourcesRequestDataType = new FhirSearchResourcesRequestDataType();
public const FhirCreateResourceRequestDataType = new FhirCreateResourceRequestDataType();
public const FhirUpdateResourceRequestDataType = new FhirUpdateResourceRequestDataType();
public const FhirDeleteResourceRequestDataType = new FhirDeleteResourceRequestDataType();
public const FhirValidateResourceRequestDataType = new FhirValidateResourceRequestDataType();
public const FhirValidateCodeRequestDataType = new FhirValidateCodeRequestDataType();
public const FhirExpandValueSetRequestDataType = new FhirExpandValueSetRequestDataType();
}
