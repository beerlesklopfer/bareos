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

install(FILES winbareos-native.nsi DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES bareos.ico bareos-config-deploy.bat fillup.sed clientdialog.ini
              databasedialog.ini directordialog.ini storagedialog.ini
        DESTINATION "${CMAKE_INSTALL_PREFIX}/win32"
)

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
