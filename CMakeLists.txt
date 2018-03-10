cmake_minimum_required(VERSION 2.8.3)

project(qore-json-module)

set (VERSION_MAJOR 1)
set (VERSION_MINOR 8)
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

add_library(${module_name} SHARED ${CPP_SRC} ${QPP_SOURCES} ${CPP_SRC})

if (WIN32 AND MINGW AND MSYS)
    target_compile_definitions(${module_name} PUBLIC BUILDING_DLL)
endif (WIN32 AND MINGW AND MSYS)

qore_binary_module(${module_name} "${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")
qore_user_modules("${QMOD}")

qore_dist("${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_PATCH}")

qore_config_info()


