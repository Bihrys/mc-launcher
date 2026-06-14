use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("com.bihrys.launcher").qml_files([
            "qml/main.qml",
            "qml/Style.qml",
            "qml/RootShell.qml",
            "qml/components/TitleBar.qml",
            "qml/components/Sidebar.qml",
            "qml/components/SectionTitle.qml",
            "qml/components/NavItem.qml",
            "qml/components/SplitLaunchButton.qml",
            "qml/pages/MainPage.qml",
            "qml/pages/PlaceholderPage.qml",
        ]),
    )
    .qt_module("Network")
    .files(["src/backend.rs"])
    .build();
}
