#include "launch/LaunchCrashAnalyzer.h"

#include <QRegularExpression>

namespace {

bool containsAny(const QString &text, const QStringList &needles) {
    for (const QString &needle : needles) {
        if (text.contains(needle, Qt::CaseInsensitive)) return true;
    }
    return false;
}

} // namespace

namespace LaunchCrashAnalyzer {

Result analyze(const QString &logText, int exitCode) {
    Result result;

    // Port of HMCL CrashReportAnalyzer.GRAPHICS_DRIVER.
    if (containsAny(logText, {
            QStringLiteral("GLX: Failed to create context: GLXBadFBConfig"),
            QStringLiteral("Pixel format not accelerated"),
            QStringLiteral("Couldn't set pixel format"),
            QStringLiteral("org.lwjgl.LWJGLException")
        })) {
        result.matched = true;
        result.category = QStringLiteral("graphics_driver");
        result.title = QStringLiteral("图形驱动异常");
        result.message = QStringLiteral(
            "Minecraft 进程已经创建，但 GLFW 无法建立 OpenGL/GLX 上下文。\n"
            "这不是 Java 启动参数或游戏文件缺失。请检查显卡驱动与当前桌面会话，"
            "并在“游戏设置 → 高级 → OpenGL 渲染器”中先使用“默认”；"
            "系统 OpenGL 不可用时可临时测试 LLVMpipe 软件渲染。"
        );
        return result;
    }

    if (containsAny(logText, {
            QStringLiteral("Could not create the Java Virtual Machine."),
            QStringLiteral("Error occurred during initialization of VM"),
            QStringLiteral("A fatal exception has occurred. Program will exit.")
        })) {
        result.matched = true;
        result.category = QStringLiteral("jvm_error");
        result.title = QStringLiteral("Java 虚拟机启动失败");
        result.message = QStringLiteral(
            "Java 虚拟机未能初始化。请检查所选 Java 版本、内存大小和自定义 JVM 参数。"
        );
        return result;
    }

    if (containsAny(logText, {
            QStringLiteral("UnsupportedClassVersionError"),
            QStringLiteral("has been compiled by a more recent version of the Java Runtime")
        })) {
        result.matched = true;
        result.category = QStringLiteral("java_version");
        result.title = QStringLiteral("Java 版本不兼容");
        result.message = QStringLiteral("当前 Java 版本无法运行该 Minecraft 或加载器版本。");
        return result;
    }

    if (containsAny(logText, {
            QStringLiteral("OutOfMemoryError"),
            QStringLiteral("Could not reserve enough space for object heap")
        })) {
        result.matched = true;
        result.category = QStringLiteral("out_of_memory");
        result.title = QStringLiteral("内存不足");
        result.message = QStringLiteral("Java 无法分配所需内存，请降低最大内存或关闭其他程序。");
        return result;
    }

    if (exitCode == 137) {
        result.matched = true;
        result.category = QStringLiteral("sigkill");
        result.title = QStringLiteral("游戏进程被系统终止");
        result.message = QStringLiteral("游戏进程收到 SIGKILL，通常与系统内存不足或外部终止有关。");
    }

    return result;
}

} // namespace LaunchCrashAnalyzer
