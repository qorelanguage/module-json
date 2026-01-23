/* -*- mode: c++; indent-tabs-mode: nil -*- */
/** @file JsonSchemaImpl.cpp JSON Schema validation implementation */
/*
    Qore Programming Language - JSON Module

    Copyright (C) 2026 Qore Technologies, s.r.o.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

#include "QC_JsonSchema.h"

#include <sstream>
#include <cassert>

const TypedHashDecl* hashdeclJsonSchemaValidationError = nullptr;
const TypedHashDecl* hashdeclJsonSchemaValidationResult = nullptr;

JsonSchemaValidator::JsonSchemaValidator(const QoreStringNode* schema_json, ExceptionSink* xsink)
    : valid(false) {
    if (!schema_json) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Schema string cannot be null");
        return;
    }
    initFromJsonString(schema_json->c_str(), xsink);
}

JsonSchemaValidator::JsonSchemaValidator(const QoreHashNode* schema_hash, ExceptionSink* xsink)
    : valid(false) {
    if (!schema_hash) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Schema hash cannot be null");
        return;
    }

    // Convert Qore hash to JSON
    try {
        jsoncons::json json_schema = qoreToJson(schema_hash, xsink);
        if (*xsink) {
            return;
        }

        // Compile the schema
        schema = std::make_shared<JsonSchemaType>(jsoncons::jsonschema::make_json_schema(json_schema));
        valid = true;
    } catch (const jsoncons::jsonschema::schema_error& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Invalid JSON Schema: %s", e.what());
    } catch (const std::exception& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Error compiling schema: %s", e.what());
    }
}

JsonSchemaValidator::~JsonSchemaValidator() {
}

void JsonSchemaValidator::initFromJsonString(const std::string& json_str, ExceptionSink* xsink) {
    try {
        // Parse the JSON string
        jsoncons::json json_schema = jsoncons::json::parse(json_str);

        // Compile the schema
        schema = std::make_shared<JsonSchemaType>(jsoncons::jsonschema::make_json_schema(json_schema));
        valid = true;
    } catch (const jsoncons::ser_error& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Invalid JSON in schema: %s", e.what());
    } catch (const jsoncons::jsonschema::schema_error& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Invalid JSON Schema: %s", e.what());
    } catch (const std::exception& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Error compiling schema: %s", e.what());
    }
}

jsoncons::json JsonSchemaValidator::qoreToJson(QoreValue val, ExceptionSink* xsink) const {
    if (val.isNullOrNothing()) {
        return jsoncons::json::null();
    }

    switch (val.getType()) {
        case NT_INT:
            return jsoncons::json(val.getAsBigInt());

        case NT_FLOAT:
            return jsoncons::json(val.getAsFloat());

        case NT_BOOLEAN:
            return jsoncons::json(val.getAsBool());

        case NT_STRING: {
            const QoreStringNode* str = val.get<const QoreStringNode>();
            return jsoncons::json(str->c_str());
        }

        case NT_LIST: {
            const QoreListNode* list = val.get<const QoreListNode>();
            jsoncons::json arr = jsoncons::json::array();
            ConstListIterator it(list);
            while (it.next()) {
                arr.push_back(qoreToJson(it.getValue(), xsink));
                if (*xsink) {
                    return jsoncons::json::null();
                }
            }
            return arr;
        }

        case NT_HASH: {
            const QoreHashNode* hash = val.get<const QoreHashNode>();
            jsoncons::json obj = jsoncons::json::object();
            ConstHashIterator it(hash);
            while (it.next()) {
                obj[it.getKey()] = qoreToJson(it.get(), xsink);
                if (*xsink) {
                    return jsoncons::json::null();
                }
            }
            return obj;
        }

        case NT_NUMBER: {
            const QoreNumberNode* num = val.get<const QoreNumberNode>();
            QoreString str;
            num->toString(str);
            // Try to parse as a decimal number
            try {
                return jsoncons::json::parse(str.c_str());
            } catch (...) {
                return jsoncons::json(num->getAsFloat());
            }
        }

        case NT_DATE: {
            const DateTimeNode* dt = val.get<const DateTimeNode>();
            QoreString str;
            dt->format(str, "YYYY-MM-DDTHH:mm:SS.xxZ");
            return jsoncons::json(str.c_str());
        }

        case NT_BINARY: {
            const BinaryNode* bin = val.get<const BinaryNode>();
            // Encode as base64 using Qore's built-in function
            SimpleRefHolder<QoreStringNode> b64(new QoreStringNode());
            b64->concatBase64(bin);
            return jsoncons::json(b64->c_str());
        }

        default:
            // For unknown types, try to get a string representation
            return jsoncons::json::null();
    }
}

QoreValue JsonSchemaValidator::jsonToQore(const jsoncons::json& j, ExceptionSink* xsink) const {
    switch (j.type()) {
        case jsoncons::json_type::null_value:
            return QoreValue();

        case jsoncons::json_type::bool_value:
            return QoreValue(j.as_bool());

        case jsoncons::json_type::int64_value:
            return QoreValue(j.as<int64_t>());

        case jsoncons::json_type::uint64_value:
            return QoreValue(static_cast<int64_t>(j.as<uint64_t>()));

        case jsoncons::json_type::half_value:
        case jsoncons::json_type::double_value:
            return QoreValue(j.as_double());

        case jsoncons::json_type::string_value:
            return new QoreStringNode(j.as_string().c_str());

        case jsoncons::json_type::array_value: {
            ReferenceHolder<QoreListNode> list(new QoreListNode(autoTypeInfo), xsink);
            for (const auto& item : j.array_range()) {
                list->push(jsonToQore(item, xsink), xsink);
                if (*xsink) {
                    return QoreValue();
                }
            }
            return list.release();
        }

        case jsoncons::json_type::object_value: {
            ReferenceHolder<QoreHashNode> hash(new QoreHashNode(autoTypeInfo), xsink);
            for (const auto& kv : j.object_range()) {
                hash->setKeyValue(kv.key().c_str(), jsonToQore(kv.value(), xsink), xsink);
                if (*xsink) {
                    return QoreValue();
                }
            }
            return hash.release();
        }

        default:
            return QoreValue();
    }
}

bool JsonSchemaValidator::validate(QoreValue data, ExceptionSink* xsink) const {
    if (!valid || !schema) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Schema is not valid");
        return false;
    }

    try {
        jsoncons::json json_data = qoreToJson(data, xsink);
        if (*xsink) {
            return false;
        }

        // Create an error handler that tracks errors
        std::vector<JsonSchemaError> errors;
        auto reporter = [&errors](const jsoncons::jsonschema::validation_message& msg) {
            JsonSchemaError err;
            err.path = msg.instance_location().string();
            err.schema_path = msg.schema_location().string();
            err.keyword = msg.keyword();
            err.message = msg.message();
            errors.push_back(err);
            return jsoncons::jsonschema::walk_result::advance;
        };

        schema->validate(json_data, reporter);
        return errors.empty();
    } catch (const std::exception& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Validation error: %s", e.what());
        return false;
    }
}

QoreHashNode* JsonSchemaValidator::validateWithErrors(QoreValue data, ExceptionSink* xsink) const {
    assert(hashdeclJsonSchemaValidationError);
    assert(hashdeclJsonSchemaValidationResult);

    ReferenceHolder<QoreHashNode> result(new QoreHashNode(hashdeclJsonSchemaValidationResult, xsink), xsink);

    if (!valid || !schema) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Schema is not valid");
        return nullptr;
    }

    try {
        jsoncons::json json_data = qoreToJson(data, xsink);
        if (*xsink) {
            return nullptr;
        }

        // Create an error handler that collects all errors
        ReferenceHolder<QoreListNode> error_list(
            new QoreListNode(hashdeclJsonSchemaValidationError->getTypeInfo()), xsink
        );
        auto reporter = [&error_list, xsink](const jsoncons::jsonschema::validation_message& msg) {
            ReferenceHolder<QoreHashNode> err(new QoreHashNode(hashdeclJsonSchemaValidationError, xsink), xsink);
            err->setKeyValue("path", new QoreStringNode(msg.instance_location().string()), xsink);
            err->setKeyValue("schema_path", new QoreStringNode(msg.schema_location().string()), xsink);
            err->setKeyValue("keyword", new QoreStringNode(msg.keyword()), xsink);
            err->setKeyValue("message", new QoreStringNode(msg.message()), xsink);
            error_list->push(err.release(), xsink);
            return jsoncons::jsonschema::walk_result::advance;
        };

        schema->validate(json_data, reporter);

        result->setKeyValue("valid", error_list->size() == 0, xsink);
        result->setKeyValue("errors", error_list.release(), xsink);

        return result.release();
    } catch (const std::exception& e) {
        xsink->raiseException("JSON-SCHEMA-ERROR", "Validation error: %s", e.what());
        return nullptr;
    }
}
