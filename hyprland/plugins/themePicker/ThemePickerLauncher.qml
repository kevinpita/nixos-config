import QtQuick
import Quickshell

Item {
    id: root

    property var pluginService: null
    property string trigger: "theme:"

    signal itemsChanged

    readonly property var themes: @themes@

    function getItems(_query) {
        return themes.map(theme => ({
            id: theme.name,
            name: theme.name,
            icon: "material:palette",
            imagePath: theme.preview,
            keywords: [theme.name, "theme"],
            primaryAction: {
                name: "Apply",
                icon: "palette",
                action: "execute"
            }
        }));
    }

    function executeItem(item) {
        Quickshell.execDetached(["@themeSet@", item.id]);
    }
}
