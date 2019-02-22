/* -*- mode: c++; indent-tabs-mode: nil -*- */
/*
    QC_JsonRpcClient.h

    Qore Programming Language

    Copyright (C) 2006 - 2018 Qore Technologies, s.r.o.

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

#ifndef _QORE_CLASS_JSONRPCCLIENT_H
#define _QORE_CLASS_JSONRPCCLIENT_H

#include "qore-json-module.h"

#include <qore/QoreHttpClientObject.h>

#include <string>

DLLEXPORT extern qore_classid_t CID_JSONRPCCLIENT;
DLLEXPORT extern QoreClass *QC_JSONRPCCLIENT;

DLLLOCAL QoreClass *initJsonRpcClientClass(QoreNamespace& ns);

class JsonRpcClient : public QoreHttpClientObject {
private:
    mutable QoreThreadLock m;
    std::string jsonrpc_version = "2.0";

public:
    DLLLOCAL JsonRpcClient() {
        // set encoding to UTF-8
        setEncoding(QCS_UTF8);

        // set options for JSON-RPC communication
        setDefaultPath("JSON");
        setDefaultHeaderValue("Content-Type", "application/json;charset=utf-8");
        setDefaultHeaderValue("Accept", "application/json");
        setDefaultHeaderValue("User-Agent", "Qore-JSON-RPC-Client/" PACKAGE_VERSION);

        addProtocol("jsonrpc", 80, false);
        addProtocol("jsonrpcs", 443, true);
    }

    DLLLOCAL JsonRpcClient(const QoreHashNode* opts, bool no_connect, ExceptionSink* xsink) : JsonRpcClient() {
        // set json-rpc version if possible
        QoreValue vstr = opts->getKeyValue("version");
        if (vstr.getType() == NT_STRING)
            jsonrpc_version = vstr.get<const QoreStringNode>()->c_str();

        // set HTTPClient options
        if (setOptions(opts, xsink))
            return;

        // do not connect immediately if the second argument is True
        if (!no_connect)
            connect(xsink);
    }

    DLLLOCAL QoreValue call(QoreStringNode *msg, QoreHashNode *info, ExceptionSink *xsink);

    DLLLOCAL void getVersion(QoreString& str) const {
        AutoLocker al(m);
        str.concat(jsonrpc_version);
    }

    DLLLOCAL void setVersion(const char* str) {
        AutoLocker al(m);
        jsonrpc_version = str;
    }

    DLLLOCAL const std::string& getVersionStr() const {
        return jsonrpc_version;
    }
};

#endif
