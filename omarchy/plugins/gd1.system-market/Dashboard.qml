import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Panel {
    id: root
    moduleName: "gd1.system-market"
    ipcTarget: moduleName
    manageIpc: false
    ShellIpc {
        target: root.moduleName
        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function refresh(): void { root.refreshQuotes(true) }
        function state(): string { return JSON.stringify({opened: root.opened, hardware: root.hardware, quotes: root.quotes, quoteError: root.quoteError, pricesEnabled: root.pricesEnabled, contentLoaded: popup.loadedContent !== null}) }
    }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    property var hardware: ({})
    property var quotes: ({})
    property bool quoteError: false
    property double now: Date.now()
    property double lastAttempt: 0
    readonly property bool pricesEnabled: setting("pricesEnabled", true) !== false
    readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    function metric(value, suffix) {
        return typeof value === "number" && isFinite(value)
            ? Commons.I18n.formatNumber(value, 1) + suffix : strings.t("unavailable")
    }
    function utilizationColor(value) {
        if (typeof value !== "number" || !isFinite(value)) return root.foreground
        return value < 50 ? "#8bd49c" : value < 80 ? "#f5d76e" : "#ff9b9b"
    }
    function price(value, prefix, decimals) {
        return typeof value === "number" && isFinite(value)
            ? prefix + Commons.I18n.formatNumber(value, decimals) : strings.t("unavailable")
    }
    function quoteTime(value) {
        return value ? strings.t("updated").arg(new Date(value).toLocaleString(Qt.locale(Commons.I18n.formatLocale), "dd MMM HH:mm")) : ""
    }
    function refreshHardware() { if (!hwProc.running) hwProc.running = true }
    function refreshQuotes(manual) {
        if (marketProc.running) return
        if (manual !== true && (!pricesEnabled || Date.now() - lastAttempt < 300000)) return
        lastAttempt = Date.now()
        marketProc.running = true
    }
    function togglePrices() {
        var entry = { id: moduleName }
        for (var key in settings) entry[key] = settings[key]
        entry.pricesEnabled = !pricesEnabled
        settings = entry
        if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, entry)
    }
    onPricesEnabledChanged: {
        if (pricesEnabled && opened) refreshQuotes()
    }
    onOpenedChanged: if (opened) { now = Date.now(); refreshHardware(); refreshQuotes() }
    Timer { interval: 2000; repeat: true; running: root.opened; onTriggered: { root.now = Date.now(); root.refreshHardware(); root.refreshQuotes() } }
    Process {
        id: hwProc
        command: ["python3", Qt.resolvedUrl("probe.py").toString().replace("file://", ""), "hardware"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { var data = JSON.parse(text); root.hardware = data.error ? ({}) : data } catch (e) { root.hardware = ({}) }
            }
        }
    }
    Process {
        id: marketProc
        command: ["python3", Qt.resolvedUrl("probe.py").toString().replace("file://", ""), "markets"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    root.quoteError = data.error === true
                    if (!root.quoteError) root.quotes = data
                } catch (e) { root.quoteError = true }
            }
        }
    }
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰨇"
        tooltipText: ""
        onPressed: root.toggle()
    }
    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: popup.loadedContent
        contentWidth: popup.fittedContentWidth(Style.space(370))
        contentHeight: popup.fittedContentHeight(popup.loadedContentHeight, Style.space(640))
        content: PanelKeyCatcher {
            implicitHeight: column.implicitHeight
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }
            onActivateRequested: root.togglePrices()
            Column {
                id: column
                width: parent.width
                spacing: Style.space(10)
                PlainText { text: strings.t("title"); font.pixelSize: Style.font.title; font.bold: true }
                PlainText { text: strings.t("hardware"); opacity: 0.6 }
                MetricRow { label: strings.t("ram"); value: root.metric(root.hardware.ram, "%"); valueColor: root.utilizationColor(root.hardware.ram); temperature: "— °C" }
                MetricRow { label: strings.t("cpu"); value: root.metric(root.hardware.cpu, "%"); valueColor: root.utilizationColor(root.hardware.cpu); temperature: root.metric(root.hardware.cpuTemp, " °C") }
                MetricRow { label: strings.t("gpu"); value: root.metric(root.hardware.gpu, "%"); valueColor: root.utilizationColor(root.hardware.gpu); temperature: root.metric(root.hardware.gpuTemp, " °C") }
                Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: 0.15 }
                PlainText { text: strings.t("markets"); opacity: 0.6 }
                MetricRow { label: strings.t("btc"); value: root.price(root.quotes.btc, "$ ", 2) }
                PlainText { text: root.quoteTime(root.quotes.requestedAt); visible: text !== ""; font.pixelSize: Style.font.caption; opacity: 0.6 }
                MetricRow { label: strings.t("usd"); value: root.price(root.quotes.usd, "R$ ", 4) }
                PlainText { text: root.quoteTime(root.quotes.requestedAt); visible: text !== ""; font.pixelSize: Style.font.caption; opacity: 0.6 }
                PlainText {
                    text: strings.t("stale")
                    visible: !!root.quotes.btcTime && (root.now-root.quotes.btcTime > 900000 || root.now-root.quotes.usdTime > 900000)
                    font.pixelSize: Style.font.caption
                    color: Commons.Color.accent
                }
                PlainText {
                    text: marketProc.running ? strings.t("refreshing") : root.quoteError ? strings.t("offline") : !root.pricesEnabled ? strings.t("paused") : strings.t("source")
                    font.pixelSize: Style.font.caption
                    opacity: 0.65
                    wrapMode: Text.WordWrap
                }
                RowLayout {
                    width: parent.width
                    spacing: Style.space(8)
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        fontSize: Style.font.caption
                        horizontalPadding: Style.space(8)
                        text: marketProc.running ? strings.t("refreshing") : strings.t("refresh")
                        iconText: "\uf021"
                        enabled: !marketProc.running
                        opacity: enabled ? 1 : 0.6
                        foreground: root.foreground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        bordered: true
                        onClicked: root.refreshQuotes(true)
                    }
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        fontSize: Style.font.caption
                        horizontalPadding: Style.space(8)
                        text: root.pricesEnabled ? strings.t("pause") : strings.t("resume")
                        iconText: root.pricesEnabled ? "\uf04c" : "\uf04b"
                        foreground: root.foreground
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        bordered: true
                        onClicked: root.togglePrices()
                    }
                }
            }
        }
    }
    component PlainText: Text {
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        width: parent.width
        elide: Text.ElideRight
    }
    component MetricRow: Item {
        property string label
        id: metricRow
        property string value
        property color valueColor: root.foreground
        property string temperature: ""
        width: parent.width
        implicitHeight: Math.max(labelText.implicitHeight, values.implicitHeight)
        PlainText { id: labelText; width: Math.max(0, parent.width - values.width - Style.space(12)); text: metricRow.label; opacity: 0.8 }
        Row {
            id: values
            anchors.right: parent.right
            spacing: Style.space(12)
            PlainText { width: metricRow.temperature !== "" ? Style.space(64) : implicitWidth; horizontalAlignment: Text.AlignRight; text: metricRow.value; color: metricRow.valueColor; font.bold: true }
            PlainText { width: implicitWidth; text: "·"; visible: metricRow.temperature !== ""; opacity: 0.4 }
            PlainText { width: Style.space(76); horizontalAlignment: Text.AlignRight; text: metricRow.temperature; visible: text !== ""; opacity: 0.8 }
        }
    }
}
