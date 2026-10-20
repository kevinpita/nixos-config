import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property string helper: "@tailnetForward@"
    readonly property string procPrefix: "tailnetPorts." + Math.random().toString(36).slice(2) + "."

    property string selectedHost: ""
    property string portsHost: ""
    property var ports: []
    property string portsError: ""
    property bool portsLoading: false
    property var forwards: []
    property var pending: ({})
    property bool popoutOpen: false

    readonly property var hosts: {
        const self = TailscaleService.selfNode;
        const names = TailscaleService.myOnlinePeers.filter(p => p.os === "linux" && !(self && p.id === self.id)).map(p => (p.dnsName || p.hostname || "").split(".")[0].toLowerCase()).filter(name => name.length > 0);
        return [...new Set(names)].sort();
    }
    readonly property string activeHost: hosts.includes(selectedHost) ? selectedHost : (hosts[0] || "")
    readonly property int upCount: forwards.filter(f => f.state === "up").length
    readonly property bool hasTrouble: forwards.some(f => f.state !== "up")
    readonly property color pillColor: hasTrouble ? Theme.warning : (upCount > 0 ? Theme.primary : Theme.widgetIconColor)

    onActiveHostChanged: {
        if (popoutOpen)
            refreshPorts();
    }

    Component.onCompleted: refreshForwards()

    Ref {
        service: TailscaleService
    }

    Timer {
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: root.popoutOpen || root.forwards.length > 0
        onTriggered: root.refreshForwards()
    }

    function setPopoutOpen(open) {
        popoutOpen = open;
        if (open) {
            refreshForwards();
            refreshPorts();
        }
    }

    function setPending(localPort, busy) {
        const next = Object.assign({}, pending);
        if (busy)
            next[localPort] = true;
        else
            delete next[localPort];
        pending = next;
    }

    function forwardFor(host, port) {
        return forwards.find(f => f.host === host && f.port === port) || null;
    }

    function lastLine(text) {
        const lines = text.trim().split("\n").filter(line => line.trim().length > 0);
        return lines.length > 0 ? lines[lines.length - 1] : "";
    }

    function parseEndpoint(endpoint) {
        const split = endpoint.lastIndexOf(":");
        let address = endpoint.slice(0, split);
        if (address.startsWith("["))
            address = address.slice(1, -1);
        return {
            "address": address.split("%")[0].replace(/^::ffff:(?=\d+\.)/, ""),
            "port": parseInt(endpoint.slice(split + 1))
        };
    }

    function parsePorts(text) {
        const byPort = {};
        for (const line of text.split("\n")) {
            const fields = line.trim().split(/\s+/);
            if (fields[0] !== "LISTEN" || fields.length < 5)
                continue;
            const local = parseEndpoint(fields[3]);
            if (isNaN(local.port) || local.address.startsWith("fe80:") || local.address === "127.0.0.53" || local.address === "127.0.0.54")
                continue;
            const entry = byPort[local.port] || (byPort[local.port] = {
                    "port": local.port,
                    "addresses": [],
                    "process": "",
                    "unit": ""
                });
            if (!entry.addresses.includes(local.address))
                entry.addresses.push(local.address);
            const process = line.match(/users:\(\("([^"]+)"/);
            const unit = line.match(/ unit=(\S+)/);
            if (process && !entry.process)
                entry.process = process[1];
            if (unit && !entry.unit)
                entry.unit = unit[1];
        }
        return Object.values(byPort).map(entry => {
            const a = entry.addresses;
            const wildcard = a.some(x => x === "0.0.0.0" || x === "*" || x === "::");
            const loopback = a.every(x => x.startsWith("127.") || x === "::1");
            const tailnet = a.every(x => /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(x) || x.startsWith("fd7a:115c:a1e0:"));
            let target = a.find(x => x === "127.0.0.1") || a.find(x => x.startsWith("127."));
            if (!target && a.some(x => x === "0.0.0.0" || x === "*"))
                target = "127.0.0.1";
            if (!target && a.some(x => x === "::" || x === "::1"))
                target = "::1";
            const service = entry.unit.endsWith(".service") ? entry.unit.slice(0, -8) : "";
            return {
                "port": entry.port,
                "target": target || a[0],
                "label": service || entry.process,
                "scope": wildcard ? "All interfaces" : (loopback ? "Localhost only" : (tailnet ? "Tailnet only" : a.join(", ")))
            };
        }).sort((x, y) => x.port - y.port);
    }

    function parseForwards(text) {
        const result = [];
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f.length < 7)
                continue;
            const target = parseEndpoint(f[2]);
            result.push({
                "localPort": parseInt(f[0]),
                "host": f[1],
                "address": target.address,
                "port": target.port,
                "state": f[3] === "active" ? "up" : (f[3] === "activating" || f[4] === "auto-restart" ? "connecting" : "down"),
                "label": f[5],
                "error": f[6]
            });
        }
        return result.sort((x, y) => x.localPort - y.localPort);
    }

    function refreshForwards() {
        Proc.runCommand(procPrefix + "list", [helper, "list"], (output, exitCode) => {
            if (exitCode === 0)
                root.forwards = root.parseForwards(output);
        }, 0);
    }

    function refreshPorts() {
        const host = activeHost;
        if (!host)
            return;
        if (portsHost !== host) {
            ports = [];
            portsError = "";
        }
        portsLoading = true;
        Proc.runCommand(procPrefix + "ports." + host, [helper, "ports", host], (output, exitCode) => {
            if (host !== root.activeHost)
                return;
            root.portsLoading = false;
            root.portsHost = host;
            if (exitCode !== 0) {
                root.ports = [];
                root.portsError = root.lastLine(output) || "Could not reach " + host;
                return;
            }
            root.portsError = "";
            root.ports = root.parsePorts(output);
        }, 0, 20000);
    }

    function startForward(host, address, port, localPort, label) {
        setPending(localPort, true);
        Proc.runCommand(procPrefix + "start." + localPort, [helper, "start", host, address, String(port), String(localPort), label || ""], (output, exitCode) => {
            root.setPending(localPort, false);
            if (exitCode !== 0)
                ToastService.showError("Could not forward " + host + ":" + port, root.lastLine(output));
            root.refreshForwards();
        }, 0, 20000);
    }

    function stopForward(localPort, onStopped) {
        setPending(localPort, true);
        Proc.runCommand(procPrefix + "stop." + localPort, [helper, "stop", String(localPort)], () => {
            root.setPending(localPort, false);
            if (onStopped)
                onStopped();
            root.refreshForwards();
        }, 0);
    }

    function retryForward(forward) {
        stopForward(forward.localPort, () => root.startForward(forward.host, forward.address, forward.port, forward.localPort, forward.label));
    }

    function openLocal(localPort) {
        Quickshell.execDetached([helper, "open", String(localPort)]);
    }

    function copyLocal(localPort) {
        Quickshell.execDetached(["dms", "cl", "copy", "http://localhost:" + localPort]);
    }

    function stateColor(state) {
        return state === "up" ? Theme.success : (state === "connecting" ? Theme.warning : Theme.error);
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "settings_ethernet"
                size: root.iconSize
                color: root.pillColor
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.forwards.length > 0
                text: root.upCount
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                color: root.pillColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DankIcon {
                name: "settings_ethernet"
                size: root.iconSize
                color: root.pillColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                visible: root.forwards.length > 0
                text: root.upCount
                font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                color: root.pillColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 440

    popoutContent: Component {
        PopoutComponent {
            id: popout

            property string query: ""
            readonly property var filteredPorts: {
                const q = query.trim().toLowerCase();
                if (!q)
                    return root.ports;
                return root.ports.filter(p => String(p.port).includes(q) || p.label.toLowerCase().includes(q));
            }
            readonly property bool showPorts: TailscaleService.available && root.hosts.length > 0

            headerText: "Tailnet Ports"
            headerActions: Component {
                DankRefreshButton {
                    busy: root.portsLoading
                    buttonSize: 32
                    iconColor: Theme.surfaceVariantText
                    tooltipText: "Refresh"
                    onClicked: root.setPopoutOpen(true)
                }
            }

            Component.onCompleted: root.setPopoutOpen(true)

            Connections {
                target: popout.parentPopout
                function onShouldBeVisibleChanged() {
                    root.setPopoutOpen(popout.parentPopout.shouldBeVisible);
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                EmptyState {
                    visible: !popout.showPorts
                    icon: TailscaleService.available ? "devices" : "vpn_key_off"
                    message: TailscaleService.available ? "No other Linux devices online" : "Tailscale not available"
                }

                DankFilterChips {
                    visible: popout.showPorts
                    width: parent.width
                    chipHeight: 30
                    showCounts: true
                    currentIndex: root.hosts.indexOf(root.activeHost)
                    model: root.hosts.map(host => ({
                                "label": host,
                                "count": root.forwards.filter(f => f.host === host).length
                            }))
                    onSelectionChanged: index => root.selectedHost = root.hosts[index]
                }

                Column {
                    visible: root.forwards.length > 0
                    width: parent.width
                    spacing: Theme.spacingXS

                    SectionLabel {
                        text: "Forwarded"
                    }

                    Repeater {
                        model: root.forwards
                        delegate: ForwardCard {}
                    }
                }

                Column {
                    visible: popout.showPorts
                    width: parent.width
                    spacing: Theme.spacingXS

                    SectionLabel {
                        text: root.portsHost === root.activeHost && root.ports.length > 0 ? "Listening on " + root.activeHost + " · " + root.ports.length : "Listening on " + root.activeHost
                    }

                    DankTextField {
                        visible: root.ports.length > 6
                        width: parent.width
                        placeholderText: "Filter by port or service"
                        leftIconName: "search"
                        showClearButton: true
                        text: popout.query
                        onTextEdited: popout.query = text
                    }

                    Item {
                        visible: root.portsLoading && root.ports.length === 0
                        width: parent.width
                        height: 96

                        DankSpinner {
                            anchors.centerIn: parent
                            size: 28
                        }
                    }

                    EmptyState {
                        visible: !root.portsLoading && root.portsError.length > 0
                        icon: "cloud_off"
                        message: root.portsError
                    }

                    EmptyState {
                        visible: !root.portsLoading && !root.portsError && root.portsHost === root.activeHost && popout.filteredPorts.length === 0
                        icon: "lan"
                        message: popout.query ? "No matching ports" : "No listening ports"
                    }

                    DankFlickable {
                        visible: popout.filteredPorts.length > 0
                        width: parent.width
                        height: Math.min(portList.implicitHeight, 360)
                        contentHeight: portList.implicitHeight
                        clip: true

                        Column {
                            id: portList
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: popout.filteredPorts
                                delegate: PortCard {}
                            }
                        }
                    }
                }
            }
        }
    }

    component SectionLabel: StyledText {
        width: parent ? parent.width : 0
        leftPadding: Theme.spacingXS
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceVariantText
        elide: Text.ElideRight
    }

    component EmptyState: Item {
        id: emptyState

        property string icon: ""
        property string message: ""

        width: parent ? parent.width : 0
        height: emptyColumn.implicitHeight + Theme.spacingL * 2

        Column {
            id: emptyColumn
            anchors.centerIn: parent
            width: parent.width - Theme.spacingL * 2
            spacing: Theme.spacingS

            DankIcon {
                name: emptyState.icon
                size: 32
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                width: parent.width
                text: emptyState.message
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
        }
    }

    component Pill: Rectangle {
        id: pill

        property string icon: ""
        property string label: ""
        signal clicked

        height: 28
        radius: 14
        width: pillRow.implicitWidth + Theme.spacingM * 2
        color: pillArea.containsMouse ? Theme.primaryHoverLight : Theme.surfaceLight

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spacingXS

            DankIcon {
                name: pill.icon
                size: Theme.fontSizeSmall
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: pill.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component PortCard: Rectangle {
        id: card

        required property var modelData
        readonly property var forward: root.forwardFor(root.activeHost, modelData.port)
        readonly property int quickPort: modelData.port
        readonly property bool busy: root.pending[quickPort] === true || root.pending[parseInt(localField.text)] === true
        property bool expanded: false

        function submit() {
            const localPort = parseInt(localField.text);
            if (!(localPort >= 1 && localPort <= 65535))
                return;
            card.expanded = false;
            root.startForward(root.activeHost, modelData.target, modelData.port, localPort, modelData.label);
        }

        width: parent ? parent.width : 0
        height: cardColumn.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: cardArea.containsMouse && !forward ? Theme.primaryContainer : Theme.surfaceContainerHighest
        border.color: forward ? Theme.primary : Theme.outlineLight
        border.width: forward ? 2 : 1

        MouseArea {
            id: cardArea
            z: -1
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.forward ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (card.forward)
                    return;
                card.expanded = !card.expanded;
                if (card.expanded)
                    localField.forceActiveFocus();
            }
        }

        Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingS

            RowLayout {
                width: parent.width
                spacing: Theme.spacingM

                Rectangle {
                    Layout.preferredWidth: Math.max(56, portText.implicitWidth + Theme.spacingM * 2)
                    Layout.preferredHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.cornerRadius
                    color: card.forward ? Theme.primary : Theme.withAlpha(Theme.primary, 0.14)

                    StyledText {
                        id: portText
                        anchors.centerIn: parent
                        text: card.modelData.port
                        font.family: Theme.monoFontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: card.forward ? Theme.primaryText : Theme.primary
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 1

                    StyledText {
                        width: parent.width
                        text: card.modelData.label || "Unknown service"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: card.modelData.label ? Theme.surfaceText : Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: card.modelData.scope
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }
                }

                Pill {
                    visible: card.forward !== null
                    Layout.alignment: Qt.AlignVCenter
                    icon: "open_in_new"
                    label: "localhost:" + (card.forward ? card.forward.localPort : "")
                    onClicked: root.openLocal(card.forward.localPort)
                }

                DankSpinner {
                    visible: card.busy && !card.forward
                    Layout.preferredWidth: 32
                    Layout.alignment: Qt.AlignVCenter
                    size: 18
                }

                DankActionButton {
                    visible: !card.forward && !card.busy
                    Layout.alignment: Qt.AlignVCenter
                    iconName: "add_link"
                    buttonSize: 32
                    iconColor: Theme.primary
                    tooltipText: "Forward to localhost:" + card.quickPort
                    onClicked: root.startForward(root.activeHost, card.modelData.target, card.modelData.port, card.quickPort, card.modelData.label)
                }
            }

            RowLayout {
                visible: card.expanded && !card.forward
                width: parent.width
                spacing: Theme.spacingS

                DankTextField {
                    id: localField
                    Layout.fillWidth: true
                    placeholderText: "Local port"
                    leftIconName: "computer"
                    text: String(card.quickPort)
                    validator: IntValidator {
                        bottom: 1
                        top: 65535
                    }
                    onAccepted: card.submit()
                }

                DankButton {
                    text: "Forward"
                    iconName: "link"
                    buttonHeight: localField.height
                    enabled: !card.busy && localField.text.length > 0
                    onClicked: card.submit()
                }
            }
        }
    }

    component ForwardCard: Rectangle {
        id: forwardCard

        required property var modelData
        readonly property bool busy: root.pending[modelData.localPort] === true
        readonly property bool up: modelData.state === "up"

        width: parent ? parent.width : 0
        height: forwardRow.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest
        border.color: up ? Theme.outlineLight : root.stateColor(modelData.state)
        border.width: 1

        RowLayout {
            id: forwardRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingS
            spacing: Theme.spacingM

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                Layout.alignment: Qt.AlignVCenter
                radius: 4
                color: root.stateColor(forwardCard.modelData.state)
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    width: parent.width
                    text: "localhost:" + forwardCard.modelData.localPort
                    font.family: Theme.monoFontFamily
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: {
                        const m = forwardCard.modelData;
                        if (m.state === "connecting")
                            return "Reconnecting to " + m.host + "…";
                        if (m.state === "down")
                            return m.error || "Stopped";
                        return [m.host + ":" + m.port, m.label].filter(part => part).join(" • ");
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: forwardCard.up ? Theme.surfaceVariantText : root.stateColor(forwardCard.modelData.state)
                    elide: Text.ElideRight
                }
            }

            DankSpinner {
                visible: forwardCard.busy
                Layout.preferredWidth: 28
                size: 16
            }

            Row {
                visible: !forwardCard.busy
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.spacingXXS

                DankActionButton {
                    visible: forwardCard.up
                    iconName: "open_in_new"
                    buttonSize: 28
                    iconSize: 16
                    iconColor: Theme.surfaceVariantText
                    tooltipText: "Open in browser"
                    onClicked: root.openLocal(forwardCard.modelData.localPort)
                }

                DankActionButton {
                    visible: forwardCard.up
                    iconName: "content_copy"
                    buttonSize: 28
                    iconSize: 16
                    iconColor: Theme.surfaceVariantText
                    tooltipText: "Copy URL"
                    onClicked: root.copyLocal(forwardCard.modelData.localPort)
                }

                DankActionButton {
                    visible: !forwardCard.up
                    iconName: "refresh"
                    buttonSize: 28
                    iconSize: 16
                    iconColor: Theme.surfaceVariantText
                    tooltipText: "Retry"
                    onClicked: root.retryForward(forwardCard.modelData)
                }

                DankActionButton {
                    iconName: "link_off"
                    buttonSize: 28
                    iconSize: 16
                    iconColor: Theme.error
                    tooltipText: "Stop forwarding"
                    onClicked: root.stopForward(forwardCard.modelData.localPort)
                }
            }
        }
    }
}
