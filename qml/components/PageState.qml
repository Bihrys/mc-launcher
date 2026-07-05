import QtQuick

QtObject {
    id: root

    // 对应 HMCL DecoratorPage.State 的页面身份。
    property string key: ""
    property string title: ""

    // HMCL MainPage 使用 titleNode：icon-title.png + Metadata.FULL_TITLE。
    property bool showBrand: false

    // 标题栏动作。TitleBar 只读这些状态。
    property bool backable: true
    property bool closeable: false
    property bool homeable: false
    property bool refreshable: false

    // 页面切换动画开关。
    property bool animate: true

    // DecoratorAnimatedPage 左右分区宽度。
    // 首页是 Sidebar，普通页面是 0。
    property real leftPaneWidth: 0
}
