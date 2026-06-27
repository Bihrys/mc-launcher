pub mod backend;
mod backend_account;
mod backend_download;
mod backend_instance;
mod backend_java;
mod backend_launch;
mod backend_settings;
mod json_models;
mod task_bridge;
mod viewmodel;
mod model;
mod bridge;
mod qml;
mod game_list_models;
mod profile_list_model;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};

fn main() {
    let mut app = QGuiApplication::new();

    if let Some(mut app_ref) = app.as_mut() {
        app_ref
            .as_mut()
            .set_application_name(&QString::from("MC Launcher"));

        app_ref
            .as_mut()
            .set_application_version(&QString::from(env!("CARGO_PKG_VERSION")));

        app_ref
            .as_mut()
            .set_organization_name(&QString::from("Bihrys"));

        app_ref
            .as_mut()
            .set_organization_domain(&QString::from("bihrys.github.io"));
    }

    let mut engine = QQmlApplicationEngine::new();

    if let Some(mut engine_ref) = engine.as_mut() {
        engine_ref
            .as_mut()
            .load(&QUrl::from("qrc:/qt/qml/com/bihrys/launcher/qml/main.qml"));
    }

    if let Some(mut app_ref) = app.as_mut() {
        app_ref.as_mut().exec();
    }
}
