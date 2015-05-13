cmake_minimum_required(VERSION 2.8.3)

project(qore-json-module)

set (VERSION_MAJOR 1)
set (VERSION_MINOR 5)
set (VERSION_PATCH 0)


find_package(Qore REQUIRED)

include_directories( ${CMAKE_SOURCE_DIR}/src )

set(QPP_SRC
    src/QC_JsonRpcClient.qpp
    src/ql_json.qpp
)

set(CPP_SRC
    src/json-module.cpp
)

set(QMOD
    qlib/JsonRpcHandler.qm
)

qore_wrap_qpp(QPP_SOURCES ${QPP_SRC})

SET (module_name "json")

add_library(${module_name} SHARED ${CPP_SRC} ${QPP_SOURCES} ${CPP_SRC})

qore_binary_module(${module_name} "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
qore_user_modules("${QMOD}")

qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

qore_config_info()


