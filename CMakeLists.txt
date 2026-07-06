cmake_minimum_required(VERSION 3.21)

project(mc_launcher_qt_cpp VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network)

qt_standard_project_setup(REQUIRES 6.5)

file(GLOB_RECURSE QML_ASSET_FILES CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.jpg"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.jpeg"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.svg"
    "${CMAKE_CURRENT_SOURCE_DIR}/qml/*.webp"
)

set(QRC_FILE "${CMAKE_CURRENT_BINARY_DIR}/launcher_qml.qrc")
file(WRITE "${QRC_FILE}" "<RCC>\n  <qresource prefix=\"/qt/qml/com/bihrys/launcher/qml\">\n")
foreach(asset ${QML_ASSET_FILES})
    file(RELATIVE_PATH rel "${CMAKE_CURRENT_SOURCE_DIR}/qml" "${asset}")
    file(APPEND "${QRC_FILE}" "    <file alias=\"${rel}\">${asset}</file>\n")
endforeach()
file(APPEND "${QRC_FILE}" "  </qresource>\n</RCC>\n")

qt_add_executable(mc-launcher-qt-cpp
    src/main.cpp
    src/core/LauncherPaths.cpp
    src/core/JsonUtil.cpp
    src/settings/LauncherSettings.cpp
    src/account/AccountService.cpp
    src/game/InstanceService.cpp
    src/game/VersionRules.cpp
    src/download/DownloadService.cpp
    src/download/Downloader.cpp
    src/download/GameInstaller.cpp
    src/download/hmcl/DownloadProvider.cpp
    src/download/hmcl/VersionListService.cpp
    src/download/hmcl/LoaderInstaller.cpp
    src/java/JavaService.cpp
    src/launch/LaunchService.cpp
    src/bridge/LauncherBackend.cpp
    src/models/GameListModel.cpp
    src/models/ProfileListModel.cpp
    ${QRC_FILE}
)

target_include_directories(mc-launcher-qt-cpp PRIVATE src)

target_link_libraries(mc-launcher-qt-cpp PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Network
)

install(TARGETS mc-launcher-qt-cpp
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
