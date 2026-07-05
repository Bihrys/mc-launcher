# C++/QML patch notes

This patch fixes the first C++ skeleton runtime problems observed on Arch/fish:

1. Removed synthesized crafatar avatar URLs from the hot account/sidebar model path.
   - Reason: crafatar can return 521 repeatedly and QQuickImage retries make the UI feel stuck.
   - QML now uses the existing fallback letter avatar.

2. Made account/sidebar avatar `Image` components asynchronous.

3. Reworked launch feedback.
   - `startLaunchSelectedVersion()` now generates a command and passes it into `LaunchService`.
   - `LaunchService` calls `/bin/sh -lc <command>` through `QProcess::startDetached` and returns a visible failed/started status to the QML launch dialog.
   - Empty skeleton versions are now reported as failed instead of looking like a silent no-op.

4. Added a basic Minecraft command generator for already-complete vanilla-style installations.
   - It reads version JSON.
   - It follows `inheritsFrom` one level.
   - It builds classpath from existing libraries.
   - It expands common Mojang placeholders.

Limit: the downloader still creates a placeholder version skeleton. That skeleton is not a complete Minecraft installation. Real installing still needs the HMCL `GameInstallTask -> VersionJsonDownloadTask -> GameLibrariesTask -> GameAssetIndexDownloadTask -> GameAssetDownloadTask` equivalent in C++.
