# CMakeList.txt : CMake project for GlitchyEngineHelper, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.15)

project(GlitchyEngineHelper)

include(FetchContent)

FetchContent_Declare(
	lz4
	GIT_REPOSITORY	https://github.com/lz4/lz4.git
	GIT_TAG			dev
)

FetchContent_MakeAvailable(lz4)

# Add source to this project's executable.
add_library(GlitchyEngineHelper STATIC
	"GlitchyEngineHelper.cpp"
	"GlitchyEngineHelper.h"
	"vendor/xxHash/xxhash.c"
	"vendor/xxHash/xxhash.h"
	"vendor/DirectXTK/Src/DDSTextureLoader.cpp"
)

include_directories("vendor/DirectXTK/Inc")

target_sources(GlitchyEngineHelper PRIVATE 
    ${lz4_SOURCE_DIR}/lib/lz4.c
    ${lz4_SOURCE_DIR}/lib/lz4frame.c
    ${lz4_SOURCE_DIR}/lib/lz4hc.c
#    ${lz4_SOURCE_DIR}/lib/xxhash.c
)

#include_directories(${lz4_SOURCE_DIR}/lib)

target_link_libraries(GlitchyEngineHelper PRIVATE lz4)

target_include_directories(GlitchyEngineHelper
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
    $<BUILD_INTERFACE:${lz4_SOURCE_DIR}/lib>
)

# Use statically linked multithreaded MSVC runtime
set_property(TARGET GlitchyEngineHelper PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
