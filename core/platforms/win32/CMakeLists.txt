#   BAREOS® - Backup Archiving REcovery Open Sourced
#
#   Copyright (C) 2023-2024 Bareos GmbH & Co. KG
#
#   This program is Free Software; you can redistribute it and/or
#   modify it under the terms of version three of the GNU Affero General Public
#   License as published by the Free Software Foundation and included
#   in the file LICENSE.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
#   02110-1301, USA.
message("Entering ${CMAKE_CURRENT_SOURCE_DIR}")

install(FILES winbareos-native.nsi DESTINATION "." COMPONENT common)
install(FILES bareos.ico bareos-config-deploy.bat fillup.sed clientdialog.ini
              databasedialog.ini directordialog.ini storagedialog.ini
        DESTINATION "win32" COMPONENT common
)

# --- CPack NSIS Configuration ---
if(HAVE_WIN32)
  set(CPACK_GENERATOR "NSIS")
  set(CPACK_PACKAGE_VENDOR "Bareos GmbH & Co. KG")
  set(CPACK_PACKAGE_NAME "Bareos")
  set(CPACK_PACKAGE_HOMEPAGE_URL "https://www.bareos.com/")
  set(CPACK_PACKAGE_VERSION_MAJOR "${BAREOS_VERSION_MAJOR}")
  set(CPACK_PACKAGE_VERSION_MINOR "${BAREOS_VERSION_MINOR}")
  set(CPACK_PACKAGE_VERSION_PATCH "${BAREOS_VERSION_PATCH}")
  set(CPACK_PACKAGE_FILE_NAME
      "Bareos-${BAREOS_FULL_VERSION}-win64"
  )
  set(CPACK_PACKAGE_INSTALL_DIRECTORY "Bareos")
  set(CPACK_PACKAGE_DESCRIPTION_SUMMARY
      "Bareos - Backup Archiving Recovery Open Sourced"
  )
  set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/AGPL-3.0.txt")
  # NSIS specific settings
  set(CPACK_NSIS_DISPLAY_NAME "Bareos ${BAREOS_FULL_VERSION}")
  set(CPACK_NSIS_PACKAGE_NAME "Bareos")
  set(CPACK_NSIS_URL_INFO_ABOUT "https://www.bareos.com")
  set(CPACK_NSIS_HELP_LINK "https://docs.bareos.org")
  set(CPACK_NSIS_MUI_ICON "${CMAKE_CURRENT_SOURCE_DIR}\\\\bareos.ico")
  set(CPACK_NSIS_MUI_UNIICON "${CMAKE_CURRENT_SOURCE_DIR}\\\\bareos.ico")
  set(CPACK_PACKAGE_ICON "${CMAKE_CURRENT_SOURCE_DIR}\\\\header.bmp")
  set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
  set(CPACK_NSIS_MODIFY_PATH OFF)

  # Component-based install
  set(CPACK_MONOLITHIC_INSTALL FALSE)
  set(CPACK_COMPONENTS_ALL common filedaemon director storagedaemon bconsole)

  # Component descriptions
  set(CPACK_COMPONENT_COMMON_DISPLAY_NAME "Common Libraries")
  set(CPACK_COMPONENT_COMMON_DESCRIPTION
      "Shared libraries required by all Bareos components"
  )
  set(CPACK_COMPONENT_COMMON_REQUIRED TRUE)

  set(CPACK_COMPONENT_FILEDAEMON_DISPLAY_NAME "File Daemon")
  set(CPACK_COMPONENT_FILEDAEMON_DESCRIPTION
      "Bareos File Daemon - backup agent that runs on each client"
  )
  set(CPACK_COMPONENT_FILEDAEMON_DEPENDS common)

  set(CPACK_COMPONENT_DIRECTOR_DISPLAY_NAME "Director")
  set(CPACK_COMPONENT_DIRECTOR_DESCRIPTION
      "Bareos Director - central management and scheduling"
  )
  set(CPACK_COMPONENT_DIRECTOR_DISABLED TRUE)
  set(CPACK_COMPONENT_DIRECTOR_DEPENDS common)

  set(CPACK_COMPONENT_STORAGEDAEMON_DISPLAY_NAME "Storage Daemon")
  set(CPACK_COMPONENT_STORAGEDAEMON_DESCRIPTION
      "Bareos Storage Daemon - manages backup storage devices"
  )
  set(CPACK_COMPONENT_STORAGEDAEMON_DISABLED TRUE)
  set(CPACK_COMPONENT_STORAGEDAEMON_DEPENDS common)

  set(CPACK_COMPONENT_BCONSOLE_DISPLAY_NAME "Text Console (bconsole)")
  set(CPACK_COMPONENT_BCONSOLE_DESCRIPTION
      "Command-line console for interacting with the Bareos Director"
  )
  set(CPACK_COMPONENT_BCONSOLE_DISABLED TRUE)

  # Desktop shortcut for bconsole
  set(CPACK_NSIS_CREATE_ICONS_EXTRA
      "CreateShortCut '$DESKTOP\\\\bconsole.lnk' '$INSTDIR\\\\bin\\\\bconsole.exe'"
  )
  set(CPACK_NSIS_DELETE_ICONS_EXTRA
      "Delete '$DESKTOP\\\\bconsole.lnk'"
  )

  # Register daemons as Windows services
  set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS "
    ExecWait '\\\"$INSTDIR\\\\sbin\\\\bareos-fd.exe\\\" /install'
    ExecWait 'net start bareos-fd'
  ")
  set(CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS "
    ExecWait 'net stop bareos-fd'
    ExecWait '\\\"$INSTDIR\\\\sbin\\\\bareos-fd.exe\\\" /remove'
  ")

  include(CPack)
endif()

# --- NSIS Installer target ---
find_program(MAKENSIS_EXECUTABLE makensis
  PATHS "C:/Program Files (x86)/NSIS" "C:/Program Files/NSIS"
)
if(MAKENSIS_EXECUTABLE AND HAVE_WIN32)
  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(WINDOWS_INSTALLER_PLATFORM "64")
  else()
    set(WINDOWS_INSTALLER_PLATFORM "32")
  endif()

  if(NOT DEFINED ENABLE_SUBSCRIPTION_FEATURES)
    set(ENABLE_SUBSCRIPTION_FEATURES 0)
  endif()

  add_custom_target(windows-installer
    COMMAND "${MAKENSIS_EXECUTABLE}"
      "/DPRODUCT_VERSION=${BAREOS_FULL_VERSION}"
      "/DPRODUCT_PLATFORM=${WINDOWS_INSTALLER_PLATFORM}"
      "/DCMAKE_CONFIG_TYPE=$<CONFIG>"
      "/DENABLE_SUBSCRIPTION_FEATURES=${ENABLE_SUBSCRIPTION_FEATURES}"
      "${CMAKE_CURRENT_SOURCE_DIR}/winbareos-native.nsi"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    COMMENT "Building NSIS installer"
    VERBATIM
  )
  message("   NSIS installer:               ${MAKENSIS_EXECUTABLE}")
else()
  if(HAVE_WIN32 AND NOT MAKENSIS_EXECUTABLE)
    message("   NSIS installer:               makensis not found (skipped)")
  endif()
endif()
