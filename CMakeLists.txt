cmake_minimum_required(VERSION 3.0.0)

project(qore-json-module)

set (VERSION_MAJOR 1)
set (VERSION_MINOR 8)
set (VERSION_PATCH 2)

find_package(Qore 0.9 REQUIRED)
find_package(OpenSSL REQUIRED)

include_directories( ${CMAKE_SOURCE_DIR}/src )
include_directories( ${OPENSSL_INCLUDE_DIR} )

set(QPP_SRC
    src/QC_JsonRpcClient.qpp
    src/ql_json.qpp
)

set(CPP_SRC
    src/json-module.cpp
)

set(QMOD
    qlib/JsonRpcHandler.qm
    qlib/JsonRpcConnection.qm
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

if (${VERSION_PATCH})
    qore_external_binary_module(${module_name} "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
    qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
else()
    qore_external_binary_module(${module_name} "${VERSION_MAJOR}.${VERSION_MINOR}")
    qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}")
endif()
qore_user_modules("${QMOD}")

qore_external_user_module("qlib/JsonRpcConnection.qm" "")
qore_external_user_module("qlib/JsonRpcHandler.qm" "")

qore_config_info()

if (DOXYGEN_FOUND)
    qore_wrap_dox(QORE_DOX_SRC ${QORE_DOX_TMPL_SRC})
    add_custom_target(QORE_MOD_DOX_FILES DEPENDS ${QORE_DOX_SRC})
    add_dependencies(docs-module QORE_MOD_DOX_FILES)
endif()
