# Install script for directory: C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "$<TARGET_FILE_DIR:mobile>")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/flutter/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/connectivity_plus/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/flutter_secure_storage_windows/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/printing/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/share_plus/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/cmake_install.cmake")
endif()

if(NOT CMAKE_INSTALL_LOCAL_ONLY)
  # Include the install script for the subdirectory.
  include("C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/url_launcher_windows/cmake_install.cmake")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/mobile.exe")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug" TYPE EXECUTABLE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/mobile.exe")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/mobile.exe")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile" TYPE EXECUTABLE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/mobile.exe")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/mobile.exe")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release" TYPE EXECUTABLE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/mobile.exe")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/data/icudtl.dat")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/data" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows/flutter/ephemeral/icudtl.dat")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data/icudtl.dat")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows/flutter/ephemeral/icudtl.dat")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data/icudtl.dat")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows/flutter/ephemeral/icudtl.dat")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/flutter_windows.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows/flutter/ephemeral/flutter_windows.dll")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/flutter_windows.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows/flutter/ephemeral/flutter_windows.dll")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/flutter_windows.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/windows/flutter/ephemeral/flutter_windows.dll")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/connectivity_plus_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/flutter_secure_storage_windows_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/printing_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/pdfium.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/share_plus_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/sqlite3_flutter_libs_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/sqlite3.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/url_launcher_windows_plugin.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug" TYPE FILE FILES
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/connectivity_plus/Debug/connectivity_plus_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/flutter_secure_storage_windows/Debug/flutter_secure_storage_windows_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/printing/Debug/printing_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/pdfium-src/bin/pdfium.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/share_plus/Debug/share_plus_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/Debug/sqlite3_flutter_libs_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/Debug/sqlite3.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/url_launcher_windows/Debug/url_launcher_windows_plugin.dll"
      )
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/connectivity_plus_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/flutter_secure_storage_windows_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/printing_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/pdfium.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/share_plus_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/sqlite3_flutter_libs_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/sqlite3.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/url_launcher_windows_plugin.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile" TYPE FILE FILES
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/connectivity_plus/Profile/connectivity_plus_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/flutter_secure_storage_windows/Profile/flutter_secure_storage_windows_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/printing/Profile/printing_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/pdfium-src/bin/pdfium.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/share_plus/Profile/share_plus_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/Profile/sqlite3_flutter_libs_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/Profile/sqlite3.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/url_launcher_windows/Profile/url_launcher_windows_plugin.dll"
      )
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/connectivity_plus_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/flutter_secure_storage_windows_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/printing_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/pdfium.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/share_plus_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/sqlite3_flutter_libs_plugin.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/sqlite3.dll;C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/url_launcher_windows_plugin.dll")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release" TYPE FILE FILES
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/connectivity_plus/Release/connectivity_plus_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/flutter_secure_storage_windows/Release/flutter_secure_storage_windows_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/printing/Release/printing_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/pdfium-src/bin/pdfium.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/share_plus/Release/share_plus_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/Release/sqlite3_flutter_libs_plugin.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/sqlite3_flutter_libs/Release/sqlite3.dll"
      "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/plugins/url_launcher_windows/Release/url_launcher_windows_plugin.dll"
      )
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug" TYPE DIRECTORY FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build/native_assets/windows/")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile" TYPE DIRECTORY FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build/native_assets/windows/")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release" TYPE DIRECTORY FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build/native_assets/windows/")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    
  file(REMOVE_RECURSE "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/data/flutter_assets")
  
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    
  file(REMOVE_RECURSE "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data/flutter_assets")
  
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    
  file(REMOVE_RECURSE "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data/flutter_assets")
  
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/data/flutter_assets")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Debug/data" TYPE DIRECTORY FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build//flutter_assets")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data/flutter_assets")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data" TYPE DIRECTORY FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build//flutter_assets")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data/flutter_assets")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data" TYPE DIRECTORY FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build//flutter_assets")
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xRuntimex" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Pp][Rr][Oo][Ff][Ii][Ll][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data/app.so")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Profile/data" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build/windows/app.so")
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    list(APPEND CMAKE_ABSOLUTE_DESTINATION_FILES
     "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data/app.so")
    if(CMAKE_WARN_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(WARNING "ABSOLUTE path INSTALL DESTINATION : ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
    if(CMAKE_ERROR_ON_ABSOLUTE_INSTALL_DESTINATION)
        message(FATAL_ERROR "ABSOLUTE path INSTALL DESTINATION forbidden (by caller): ${CMAKE_ABSOLUTE_DESTINATION_FILES}")
    endif()
file(INSTALL DESTINATION "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/runner/Release/data" TYPE FILE FILES "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/mobile/build/windows/app.so")
  endif()
endif()

if(CMAKE_INSTALL_COMPONENT)
  set(CMAKE_INSTALL_MANIFEST "install_manifest_${CMAKE_INSTALL_COMPONENT}.txt")
else()
  set(CMAKE_INSTALL_MANIFEST "install_manifest.txt")
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
       "${CMAKE_INSTALL_MANIFEST_FILES}")
file(WRITE "C:/Users/yorby/OneDrive/Desktop/TRABUNDA/build/${CMAKE_INSTALL_MANIFEST}"
     "${CMAKE_INSTALL_MANIFEST_CONTENT}")
