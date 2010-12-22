/*
  QC_JsonRpcClient.cpp

  Qore Programming Language

  Copyright (C) 2006 - 2010 Qore Technologies

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

//! @file JsonRpcClient.qc defines the JsonRpcClient class

#include "qore-json-module.h"

#include <qore/QoreHTTPClient.h>
#include <qore/ReferenceHolder.h>

#include "ql_json.h"

qore_classid_t CID_JSONRPCCLIENT;
QoreClass *QC_JSONRPCCLIENT;

class HTTPInfoRefHelper {
protected:
   const ReferenceNode *ref;
   ExceptionSink *xsink;
   ReferenceHolder<QoreHashNode> info;

public:
   DLLLOCAL HTTPInfoRefHelper(const ReferenceNode *n_ref, QoreStringNode *msg, ExceptionSink *n_xsink) : ref(n_ref), xsink(n_xsink), info(new QoreHashNode, xsink) {
      info->setKeyValue("request", msg, xsink);
   }
   DLLLOCAL ~HTTPInfoRefHelper() {
      // we have to create a temporary ExceptionSink if there is
      // an active exception, otherwise writing back the reference will fail
      ExceptionSink *txsink = *xsink ? new ExceptionSink : xsink;
      
      // write info hash to reference
      AutoVLock vl(txsink);
      QoreTypeSafeReferenceHelper rh(ref, vl, txsink);
      if (!rh)
         return;

      if (rh.assign(info.release(), txsink))
         return;   

      if (txsink != xsink)
         xsink->assimilate(txsink);
   }
   DLLLOCAL QoreHashNode *operator*() {
      return *info;
   }
};

static void set_jrc_defaults(QoreHTTPClient &client) {
   // set encoding to UTF-8
   client.setEncoding(QCS_UTF8);

   // set options for JSON-RPC communication
   client.setDefaultPath("JSON");
   client.setDefaultHeaderValue("Content-Type", "application/json");
   client.setDefaultHeaderValue("Accept", "application/json");
   client.setDefaultHeaderValue("User-Agent", "Qore JSON-RPC Client v" PACKAGE_VERSION);

   client.addProtocol("jsonrpc", 80, false);
   client.addProtocol("jsonrpcs", 443, true);
}

//! main Qore Programming Language namespace
/** main Qore Programming Language namespace
 */
//# namespace Qore {
//! The JsonRpcClient class provides easy access to JSON-RPC web services
/** This class inherits all public methods of the HTTPClient class. The inherited HTTPClient methods are not listed in this section, see the documentation for the HTTPClient class for more information on methods provided by the parent class.  For a list of low-level JSON-RPC functions, see @ref JSONRPC.

    The JsonRpcClient class understands the following protocols in addition to the protocols supported by the HTTPClient class:

    <b>JsonRpcClient Class Protocols</b>
    |!Protocol|!Default Port|!SSL?|!Description
    |\c jsonrpc|\c 80|No|Unencrypted JSON-RPC protocol over HTTP
    |\c jsonrpcs|\c 443|Yes|JSON-RPC protocol over HTTP with SSL/TLS encryption

    The JsonRpcClient supplies default values for HTTP headers as follows:

    <b>JsonRpcClient Default, but Overridable Headers</b>
    |!Header|!Default Value
    |\c Accept|\c text/json
    |\c Content-Type|\c text/json
    |\c User-Agent|\c Qore JSON-RPC Client v1.0
    |\c Connection|\c Keep-Alive

    @note This class is not available with the PO_NO_NETWORK parse option.
*/
/**# class JsonRpcClient : Qore::HTTPClient {
public:
   constructor();
   constructor(hash $opts, softbool $no_connect = False);
   JsonRpcClient copy();
   hash callArgs(string $method, any $args);
   hash call(string $method, ...);
   hash callArgsWithInfo(reference $info, string $method, any $args);
   hash callWithInfo(reference $info, string $method, ...);
   nothing setEventQueue();
   nothing setEventQueue(Queue $queue);
};
};
*/

//! Creates the JsonRpcClient object based on the parameters passed
/** No connection is made because no connection parameters are set with this call; connection parameters must be set afterwards using the appropriate HTTPClient methods.
    @par Example:
    @code
my JsonRpcClient $jrc();
$jrc.setURL("http://localhost:8080");@endcode
*/
//# Qore::JsonRpcClient::constructor() {}
static void JRC_constructor(QoreObject *self, const QoreListNode *params, ExceptionSink *xsink) {
   // get HTTPClient object
   ReferenceHolder<QoreHTTPClient> client((QoreHTTPClient *)self->getReferencedPrivateData(CID_HTTPCLIENT, xsink), xsink);
   if (!client)
      return;

   set_jrc_defaults(*(*client));
}

//! Creates the JsonRpcClient object based on the parameters passed
/** By default the object will immediately attempt to establish a connection to the server
    @param $opts HTTPClient constructor options:
    - \c url: A string giving the URL to connect to.
    - \c default_port: The default port number to connect to if none is given in the URL.
    - \c protocols: A hash describing new protocols, the key is the protocol name and the value is either an integer giving the default port number or a hash with \c 'port' and \c 'ssl' keys giving the default port number and a boolean value to indicate that an SSL connection should be established.
    - \c http_version: Either \c '1.0' or \c '1.1' for the claimed HTTP protocol version compliancy in outgoing message headers.
    - \c default_path: The default path to use for new connections if a path is not otherwise specified in the connection URL.
    - \c max_redirects: The maximum number of redirects before throwing an exception (the default is 5).
    - \c proxy: The proxy URL for connecting through a proxy.
    - \c timeout: The timeout value in milliseconds (also can be a relative date-time value for clarity, ex: \c 5m)
    - \c connect_timeout: The timeout value in milliseconds for establishing a new socket connection (also can be a relative date-time value for clarity, ex: \c 30s)
    @param $no_connect pass a boolean True value argument to suppress the automatic connection and establish a connection on demand with the first request
    @see HTTPClient::constructor() and HTTPClient::connect() for information on possible exceptions
    @par Example:
    @code my JsonRpcClient $jrc(("url": "http://authuser:authpass@otherhost:8080/JSONRPC"));@endcode
*/
//# Qore::JsonRpcClient::constructor(hash $opts, softbool $no_connect = False) {}
static void JRC_constructor_hash_bool(QoreObject *self, const QoreListNode *params, ExceptionSink *xsink) {
   // get HTTPClient object
   ReferenceHolder<QoreHTTPClient> client((QoreHTTPClient *)self->getReferencedPrivateData(CID_HTTPCLIENT, xsink), xsink);
   if (!client)
      return;

   set_jrc_defaults(*(*client));

   const QoreHashNode* n = HARD_QORE_HASH(params, 0);
   if (client->setOptions(n, xsink))
      return;

   // do not connect immediately if the second argument is True
   if (!HARD_QORE_BOOL(params, 1))
      client->connect(xsink); 
}

//! Throws an exception; copying JsonRpcClient objects is currently not supported
/** @throw JSONRPCCLIENT-COPY-ERROR copying JsonRpcClient objects is currently not supported
*/
//# Qore::JsonRpcClient Qore::JsonRpcClient::copy() {}
static void JRC_copy(QoreObject *self, QoreObject *old, QoreHTTPClient* client, ExceptionSink *xsink) {
   xsink->raiseException("JSONRPCCLIENT-COPY-ERROR", "copying JsonRpcClient objects is not yet supported.");
}

static AbstractQoreNode *make_jsonrpc_call(QoreHTTPClient *client, QoreStringNode *msg, QoreHashNode *info, ExceptionSink *xsink) {
   ReferenceHolder<QoreHashNode> response(client->send("POST", 0, 0, msg->getBuffer(), msg->strlen(), true, info, xsink), xsink);
   if (!response)
      return 0;

   ReferenceHolder<AbstractQoreNode> ans(response->takeKeyValue("body"), xsink);

   if (!ans)
      return 0;

   AbstractQoreNode *ah = *ans;
   if (info) {
      info->setKeyValue("response", ans.release(), xsink);
      info->setKeyValue("response_headers", response.release(), xsink);
   }
   
   if (ah->getType() != NT_STRING) {
      xsink->raiseException("JSONRPCCLIENT-RESPONSE-ERROR", "undecoded binary response received from remote server");
      return 0;
   }

   // parse JSON-RPC response   
   return parseJSONValue(reinterpret_cast<QoreStringNode *>(ah), xsink);
}

static AbstractQoreNode *JRC_callArgs(QoreObject *self, QoreHTTPClient *client, const QoreListNode *params, ExceptionSink *xsink) {
   // create the outgoing message in JSON-RPC call format
   SimpleRefHolder<QoreStringNode> msg(makeJSONRPC11RequestStringArgs(params, xsink));
   if (!msg)
      return 0;

   return make_jsonrpc_call(client, *msg, 0, xsink);
}

//! Calls a remote method using a single value after the method name for the method arguments and returns the response as qore data structure
/** @param $method The JSON-RPC method name to call
    @param $args An optional list of arguments (or single argument) for the method

    @return a data structure corresponding to the JSON data returned by the JSON-RPC server

    @throw JSON-SERIALIZATION-ERROR cannot serialize value passed (ex: binary, object)
    @throw JSON-PARSE-ERROR syntax error parsing JSON string
    @throw HTTP-CLIENT-TIMEOUT timeout on response from HTTP server
    @throw HTTP-CLIENT-RECEIVE-ERROR error communicating with HTTP server

    @note other exceptions may be thrown related to communication errors (ex: SSL errors, etc)

    @par Example:
    @code my hash $result = $jrc.callArgs("method.name", $arg_list); @endcode
*/
//# hash Qore::JsonRpcClient::callArgs(string $method, any $args) {}
static AbstractQoreNode *JRC_call(QoreObject *self, QoreHTTPClient *client, const QoreListNode *params, ExceptionSink *xsink) {
   // create the outgoing message in JSON-RPC call format
   SimpleRefHolder<QoreStringNode> msg(makeJSONRPC11RequestString(params, xsink));
   if (!msg)
      return 0;

   return make_jsonrpc_call(client, *msg, 0, xsink);
}

//! Calls a remote method using a single value after the method name for the method arguments and returns the response as qore data structure, accepts a reference to a hash as the first argument to give technical information about the call
/** @param $info a reference to a hash that provides the following keys on output giving technical information about the HTTP call:
    - \c request: the literal outgoing request body sent
    - \c request-uri: the first line of the HTTP request
    - \c headers: a hash of HTTP headers in the outgoing request
    - \c response-uri: the first line of the HTTP response
    - \c response: the literal response body received from the server
    - \c response_headers: a hash of headers received in the response
    @param $method The JSON-RPC method name to call
    @param $args An optional list of arguments (or single argument) for the method

    @return a data structure corresponding to the JSON data returned by the JSON-RPC server

    @throw JSON-SERIALIZATION-ERROR cannot serialize value passed (ex: binary, object)
    @throw JSON-PARSE-ERROR syntax error parsing JSON string
    @throw HTTP-CLIENT-TIMEOUT timeout on response from HTTP server
    @throw HTTP-CLIENT-RECEIVE-ERROR error communicating with HTTP server

    @note other exceptions may be thrown related to communication errors (ex: SSL errors, etc)

    @par Example:
    @code
my hash $info;
my hash $result = $jrc.callArgsWithInfo(\$info, "method.name", $arg_list);@endcode
*/
//# hash Qore::JsonRpcClient::callArgsWithInfo(reference $info, string $method, any $args) {}
static AbstractQoreNode *JRC_callArgsWithInfo(QoreObject *self, QoreHTTPClient *client, const QoreListNode *params, ExceptionSink *xsink) {
   // get info reference
   const ReferenceNode *ref = HARD_QORE_REF(params, 0);

   // get arguments
   ReferenceHolder<QoreListNode> args(params->copyListFrom(1), xsink);

   // create the outgoing message in JSON-RPC call format
   QoreStringNode *msg = makeJSONRPC11RequestStringArgs(*args, xsink);
   if (!msg)
      return 0;

   HTTPInfoRefHelper irh(ref, msg, xsink);

   // send the message to the server and get the response as a JSON string
   ReferenceHolder<AbstractQoreNode> rv(make_jsonrpc_call(client, msg, *irh, xsink), xsink);

   return *xsink ? 0 : rv.release();
}

//! Calls a remote method taking all arguments after the method name for the method arguments and returns the response as qore data structure, accepts a reference to a hash as the first argument to give technical information about the call
/** @param $info a reference to a hash that provides the following keys on output giving technical information about the HTTP call:
    - \c request: the literal outgoing request body sent
    - \c request-uri: the first line of the HTTP request
    - \c headers: a hash of HTTP headers in the outgoing request
    - \c response-uri: the first line of the HTTP response
    - \c response: the literal response body received from the server
    - \c response_headers: a hash of headers received in the response
    @param $method The JSON-RPC method name to call

    @return a data structure corresponding to the JSON data returned by the JSON-RPC server

    @throw JSON-SERIALIZATION-ERROR cannot serialize value passed (ex: binary, object)
    @throw JSON-PARSE-ERROR syntax error parsing JSON string
    @throw HTTP-CLIENT-TIMEOUT timeout on response from HTTP server
    @throw HTTP-CLIENT-RECEIVE-ERROR error communicating with HTTP server

    @note other exceptions may be thrown related to communication errors (ex: SSL errors, etc)

    @par Example:
    @code
my hash $info;
my hash $result = $jrc.callWithInfo(\$info, "method.name", $arg1, $arg2);@endcode
*/
//# hash Qore::JsonRpcClient::callWithInfo(reference $info, string $method, ...) {}
static AbstractQoreNode *JRC_callWithInfo(QoreObject *self, QoreHTTPClient *client, const QoreListNode *params, ExceptionSink *xsink) {
   // get info reference
   const ReferenceNode *ref = HARD_QORE_REF(params, 0);

   // get arguments
   ReferenceHolder<QoreListNode> args(params->copyListFrom(1), xsink);

   // create the outgoing message in JSON-RPC call format
   QoreStringNode *msg = makeJSONRPC11RequestString(*args, xsink);
   if (!msg)
      return 0;

   HTTPInfoRefHelper irh(ref, msg, xsink);

   // send the message to the server and get the response as a JSON string
   ReferenceHolder<AbstractQoreNode> rv(make_jsonrpc_call(client, msg, *irh, xsink), xsink);

   return *xsink ? 0 : rv.release();
}

//! clears the event queue for the JsonRpcClient object
/** @par Example:
    @code $jrc.setEventQueue(); @endcode
 */
//# nothing Qore::JsonRpcClient::setEventQueue() {}
static AbstractQoreNode *JRC_setEventQueue_nothing(QoreObject *self, QoreHTTPClient *client, const QoreListNode *params, ExceptionSink *xsink) {
   client->setEventQueue(0, xsink);
   return 0;
}

//! sets the event queue for the JsonRpcClient object
/** @param $queue the Queue object to receive network events from the JsonRpcClient object
    @par Example:
    @code
my Queue $queue();
$jrc.setEventQueue($queue);@endcode
 */
//# nothing Qore::JsonRpcClient::setEventQueue(Queue $queue) {}
static AbstractQoreNode *JRC_setEventQueue_queue(QoreObject *self, QoreHTTPClient *client, const QoreListNode *params, ExceptionSink *xsink) {
   HARD_QORE_OBJ_DATA(q, Queue, params, 0, CID_QUEUE, "Queue", "JsonRpcClient::setEventQueue", xsink);
   if (*xsink)
      return 0;
   // pass reference from QoreObject::getReferencedPrivateData() to function
   client->setEventQueue(q, xsink);
   return 0;
}

QoreClass *initJsonRpcClientClass(QoreClass *http_client) {
   assert(QC_QUEUE);

   QC_JSONRPCCLIENT = new QoreClass("JsonRpcClient", QDOM_NETWORK);
   CID_JSONRPCCLIENT = QC_JSONRPCCLIENT->getID();

   QC_JSONRPCCLIENT->addDefaultBuiltinBaseClass(http_client);

   QC_JSONRPCCLIENT->setConstructorExtended(JRC_constructor);
   QC_JSONRPCCLIENT->setConstructorExtended(JRC_constructor_hash_bool, false, QC_NO_FLAGS, QDOM_DEFAULT, 2, hashTypeInfo, QORE_PARAM_NO_ARG, softBoolTypeInfo, &False);

   QC_JSONRPCCLIENT->setCopy((q_copy_t)JRC_copy);
   QC_JSONRPCCLIENT->addMethodExtended("callArgs",         (q_method_t)JRC_callArgs, false, QC_NO_FLAGS, QDOM_DEFAULT, 0, 2, stringTypeInfo, QORE_PARAM_NO_ARG, anyTypeInfo, QORE_PARAM_NO_ARG);
   QC_JSONRPCCLIENT->addMethodExtended("call",             (q_method_t)JRC_call, false, QC_USES_EXTRA_ARGS, QDOM_DEFAULT, 0, 1, stringTypeInfo, QORE_PARAM_NO_ARG);
   QC_JSONRPCCLIENT->addMethodExtended("callArgsWithInfo", (q_method_t)JRC_callArgsWithInfo, false, QC_NO_FLAGS, QDOM_DEFAULT, 0, 3, referenceTypeInfo, QORE_PARAM_NO_ARG, stringTypeInfo, QORE_PARAM_NO_ARG, anyTypeInfo, QORE_PARAM_NO_ARG);
   QC_JSONRPCCLIENT->addMethodExtended("callWithInfo",     (q_method_t)JRC_callWithInfo, false, QC_USES_EXTRA_ARGS, QDOM_DEFAULT, 0, 2, referenceTypeInfo, QORE_PARAM_NO_ARG, stringTypeInfo, QORE_PARAM_NO_ARG);

   // nothing JsonRpcClient::setEventQueue()  
   QC_JSONRPCCLIENT->addMethodExtended("setEventQueue",    (q_method_t)JRC_setEventQueue_nothing, false, QC_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo);
   // nothing JsonRpcClient::setEventQueue(Queue $queue)  
   QC_JSONRPCCLIENT->addMethodExtended("setEventQueue",    (q_method_t)JRC_setEventQueue_queue, false, QC_NO_FLAGS, QDOM_DEFAULT, nothingTypeInfo, 1, QC_QUEUE->getTypeInfo(), QORE_PARAM_NO_ARG);

   return QC_JSONRPCCLIENT;
} 
