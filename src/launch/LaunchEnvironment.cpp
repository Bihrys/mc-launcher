#include "launch/LaunchEnvironment.h"

#include <QFileInfo>

namespace {

void applyRenderer(QProcessEnvironment &environment, const LaunchOptions &options) {
    const QString renderer = options.renderer.trimmed().toLower();

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

    // Match HMCL/ProcessBuilder: inherit the complete launcher environment.
    // In particular, NVIDIA/GLX/PRIME variables must remain untouched on
    // Wayland compositors. Renderer-specific values are only added below when
    // the user explicitly selects LLVMpipe or Zink.

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
