cmake_minimum_required(VERSION 3.5.0)

project(qore-json-module)

set (VERSION_MAJOR 1)
set (VERSION_MINOR 11)
set (VERSION_PATCH 0)

find_package(Qore 2.0 REQUIRED)
find_package(OpenSSL REQUIRED)

include_directories( ${CMAKE_SOURCE_DIR}/src )
include_directories( ${OPENSSL_INCLUDE_DIR} )

# Find jsoncons (required for JSON Schema support)
find_path(JSONCONS_INCLUDE_DIR jsoncons/json.hpp
    PATHS
        /usr/include
        /usr/local/include
        ${CMAKE_SOURCE_DIR}/third-party/jsoncons/include
)

if(NOT JSONCONS_INCLUDE_DIR)
    if(EXISTS "${CMAKE_SOURCE_DIR}/third-party/jsoncons/include")
        set(JSONCONS_INCLUDE_DIR "${CMAKE_SOURCE_DIR}/third-party/jsoncons/include")
        message(STATUS "Using bundled jsoncons")
    else()
        message(FATAL_ERROR "jsoncons not found. Please install jsoncons or initialize the submodule: git submodule update --init")
    endif()
else()
    message(STATUS "Found jsoncons: ${JSONCONS_INCLUDE_DIR}")
endif()

include_directories(${JSONCONS_INCLUDE_DIR})

set(QPP_SRC
    src/QC_JsonRpcClient.qpp
    src/QC_JsonSaxParser.qpp
    src/QC_JsonSchema.qpp
    src/ql_json.qpp
)

set(CPP_SRC
    src/json-module.cpp
    src/JsonSchemaImpl.cpp
)

set(QMOD
    qlib/JsonRpcHandler.qm
    qlib/JsonRpcConnection.qm
    qlib/Jwt.qm
    qlib/McpServerHandler
    qlib/McpClient
    qlib/McpClientDataProvider
    qlib/NdjsonDataProvider
)

# Check for C++11.
include(CheckCXXCompilerFlag)
CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
if(COMPILER_SUPPORTS_CXX11)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
else()
    message(FATAL_ERROR "The compiler ${CMAKE_CXX_COMPILER} has no C++11 support. Please use a different C++ compiler.")
endif()

qore_wrap_qpp_value(QPP_SOURCES ${QPP_SRC})

SET (module_name "json")

set(QORE_DOX_TMPL_SRC
  docs/mainpage.doxygen.tmpl
)

add_library(${module_name} MODULE ${CPP_SRC} ${QPP_SOURCES} ${CPP_SRC})

if (WIN32 AND MINGW AND MSYS)
    target_compile_definitions(${module_name} PUBLIC BUILDING_DLL)
endif (WIN32 AND MINGW AND MSYS)

if (DEFINED ENV{DOXYGEN_EXECUTABLE})
    set(DOXYGEN_EXECUTABLE $ENV{DOXYGEN_EXECUTABLE})
endif()

qore_external_binary_module(${module_name} "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
qore_user_modules("${QMOD}")

qore_external_user_module("qlib/JsonRpcConnection.qm" "")
qore_external_user_module("qlib/JsonRpcHandler.qm" "")
qore_external_user_module("qlib/Jwt.qm" "")
qore_external_user_module("qlib/McpServerHandler" "JsonRpcHandler")
qore_external_user_module("qlib/McpClient" "")
qore_external_user_module("qlib/McpClientDataProvider" "McpClient")
qore_external_user_module("qlib/NdjsonDataProvider" "")

qore_config_info()

if (DOXYGEN_FOUND)
    qore_wrap_dox(QORE_DOX_SRC ${QORE_DOX_TMPL_SRC})
    add_custom_target(QORE_MOD_DOX_FILES DEPENDS ${QORE_DOX_SRC})
    add_dependencies(docs-module QORE_MOD_DOX_FILES)
endif()
