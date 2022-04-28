# CMakeList.txt : CMake project for GlitchyEngineHelper, include source and define
# project specific logic here.
#
cmake_minimum_required (VERSION 3.15)

project ("GlitchyEngineHelper")

# DotNet Apphost:

# Base directory of dotnet app host
SET(DOTNET_APP_HOST_BASE "${CMAKE_SOURCE_DIR}/vendor/dotnetapphost")

# Construct platform specific directory
IF (WIN32)
	IF (${TARGET_ARCH} STREQUAL "amd64")
		SET(DOTNET_APP_HOST ${DOTNET_APP_HOST_BASE}/win-x64/)
	ELSE ()
		SET(DOTNET_APP_HOST ${DOTNET_APP_HOST_BASE}/win-x86/)
	ENDIF ()

	SET(NET_HOST_LIB ${DOTNET_APP_HOST}/nethost.lib)
	SET(NET_HOST_DLL_NAME "nethost.dll")
ELSE ()
	# LINUX/MAC/...
ENDIF ()

# Less sketchy way of adding a library. If the other method breaks (because it's sketchy) use this one and include nethost.lib manually in Beef-IDE
# target_link_libraries(GlitchyEngineHelper "vendor/dotnethost/nethost.lib")

# Sketchy way to compile a static library into a static target. Notice that we add the objects of this libary in add_library(GlitchyEngineHelper ...
add_library(NetHost OBJECT IMPORTED)
set_property(TARGET NetHost PROPERTY IMPORTED_OBJECTS ${NET_HOST_LIB})

# Copy nethost.dll to output directory
configure_file("${DOTNET_APP_HOST}/${NET_HOST_DLL_NAME}" "${CMAKE_CURRENT_BINARY_DIR}/${NET_HOST_DLL_NAME}" COPYONLY)

#  GlitchyEngineHelper:

# Add source to this project's executable.
add_library (GlitchyEngineHelper STATIC
	"GlitchyEngineHelper.cpp" "GlitchyEngineHelper.h" "vendor/xxHash/xxhash.c" "vendor/xxHash/xxhash.h" "vendor/DirectXTK/Src/DDSTextureLoader.cpp" 
	# Link object files from nethost into library (kinda dirty I think, but avoids linking to nethost.lib when compiling in beef)
	$<TARGET_OBJECTS:NetHost>
)

target_include_directories(GlitchyEngineHelper PRIVATE
	"vendor/DirectXTK/Inc"
	${DOTNET_APP_HOST}
)

IF (WIN32)
	add_compile_definitions(WINDOWS)
ENDIF()

# Use statically linked multithreaded MSVC runtime
set_property(TARGET GlitchyEngineHelper PROPERTY MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")