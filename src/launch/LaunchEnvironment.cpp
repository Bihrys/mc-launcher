#include "launch/LaunchEnvironment.h"

#include <QFileInfo>

namespace {

void removeRendererOverrides(QProcessEnvironment &environment) {
    // Renderer variables are launcher options in HMCL. Do not let variables
    // used to start the Qt UI silently leak into a Minecraft process when the
    // user selected the default renderer.
    static const QStringList names{
        QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"),
        QStringLiteral("LIBGL_ALWAYS_SOFTWARE"),
        QStringLiteral("MESA_LOADER_DRIVER_OVERRIDE"),
        QStringLiteral("LIBGL_KOPPER_DRI2"),
        QStringLiteral("GALLIUM_DRIVER"),
        QStringLiteral("VK_ICD_FILENAMES"),
        QStringLiteral("VK_DRIVER_FILES"),
        QStringLiteral("GBM_BACKEND"),
        QStringLiteral("__NV_PRIME_RENDER_OFFLOAD"),
        QStringLiteral("DRI_PRIME"),
        QStringLiteral("MESA_GL_VERSION_OVERRIDE")
    };
    for (const QString &name : names) environment.remove(name);
}

void applyRenderer(QProcessEnvironment &environment, const LaunchOptions &options) {
    const QString renderer = options.renderer.trimmed().toLower();
    removeRendererOverrides(environment);

#if defined(Q_OS_LINUX) || defined(Q_OS_FREEBSD)
    // HMCL DefaultLauncher#getEnvVars: Linux/BSD OpenGL renderers.
    if (renderer == QStringLiteral("llvmpipe")
            || renderer == QStringLiteral("software")) {
        environment.insert(QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"),
                           QStringLiteral("mesa"));
        environment.insert(QStringLiteral("LIBGL_ALWAYS_SOFTWARE"),
                           QStringLiteral("1"));
    } else if (renderer == QStringLiteral("zink")) {
        environment.insert(QStringLiteral("__GLX_VENDOR_LIBRARY_NAME"),
                           QStringLiteral("mesa"));
        environment.insert(QStringLiteral("MESA_LOADER_DRIVER_OVERRIDE"),
                           QStringLiteral("zink"));
        environment.insert(QStringLiteral("LIBGL_KOPPER_DRI2"),
                           QStringLiteral("1"));
    }
#else
    Q_UNUSED(renderer)
#endif
}

void insertIfNotEmpty(QProcessEnvironment &environment,
                      const QString &name,
                      const QString &value) {
    if (!value.isEmpty()) environment.insert(name, value);
}

} // namespace

namespace LaunchEnvironment {

QProcessEnvironment build(const LaunchOptions &options,
                          const QProcessEnvironment &userVariables) {
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();

    // Qt Quick rendering variables are not Minecraft renderer settings.
    // HMCL is a JavaFX process and therefore does not leak these values to the
    // child game process. Strip them before applying HMCL renderer options.
    static const QStringList qtOnlyVariables{
        QStringLiteral("QT_OPENGL"),
        QStringLiteral("QT_QUICK_BACKEND"),
        QStringLiteral("QSG_RHI_BACKEND"),
        QStringLiteral("QT_XCB_GL_INTEGRATION")
    };
    for (const QString &name : qtOnlyVariables) environment.remove(name);

    insertIfNotEmpty(environment, QStringLiteral("INST_NAME"), options.versionId);
    insertIfNotEmpty(environment, QStringLiteral("INST_ID"), options.versionId);
    insertIfNotEmpty(environment, QStringLiteral("INST_DIR"), options.instanceDirectory);
    insertIfNotEmpty(environment, QStringLiteral("INST_MC_DIR"), options.workingDirectory);
    insertIfNotEmpty(environment, QStringLiteral("INST_JAVA"), options.javaExecutable);

    for (const QString &loaderValue : options.loaderKinds) {
        const QString loader = loaderValue.trimmed().toLower();
        if (loader == QStringLiteral("forge"))
            environment.insert(QStringLiteral("INST_FORGE"), QStringLiteral("1"));
        else if (loader == QStringLiteral("neoforge"))
            environment.insert(QStringLiteral("INST_NEOFORGE"), QStringLiteral("1"));
        else if (loader == QStringLiteral("fabric"))
            environment.insert(QStringLiteral("INST_FABRIC"), QStringLiteral("1"));
        else if (loader == QStringLiteral("legacyfabric"))
            environment.insert(QStringLiteral("INST_LEGACYFABRIC"), QStringLiteral("1"));
        else if (loader == QStringLiteral("quilt"))
            environment.insert(QStringLiteral("INST_QUILT"), QStringLiteral("1"));
        else if (loader == QStringLiteral("liteloader"))
            environment.insert(QStringLiteral("INST_LITELOADER"), QStringLiteral("1"));
        else if (loader == QStringLiteral("optifine"))
            environment.insert(QStringLiteral("INST_OPTIFINE"), QStringLiteral("1"));
        else if (loader == QStringLiteral("cleanroom"))
            environment.insert(QStringLiteral("INST_CLEANROOM"), QStringLiteral("1"));
    }

    applyRenderer(environment, options);

    // User-defined variables are applied last, matching HMCL LaunchOptions.
    const QStringList keys = userVariables.keys();
    for (const QString &key : keys)
        environment.insert(key, userVariables.value(key));

    return environment;
}

} // namespace LaunchEnvironment
