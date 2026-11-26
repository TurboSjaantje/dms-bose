pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string helperPath: Qt.resolvedUrl("bose-helper.py").toString().replace("file://", "")
    property var headset: ({ connected: false, error: "" })
    readonly property bool connected: headset.connected === true
    readonly property var modeNames: (headset.modes ?? []).map(mode => mode.name)

    property var applying: ({})
    property var justApplied: ({})
    property int nextRequestId: 1
    property var requests: ({})

    function sameValue(first, second) {
        if (typeof first === "string" && typeof second === "string")
            return first.toLowerCase() === second.toLowerCase();
        return JSON.stringify(first) === JSON.stringify(second);
    }

    function isApplying(field, value) {
        return field in applying && sameValue(applying[field], value);
    }

    function isJustApplied(field, value) {
        return field in justApplied && sameValue(justApplied[field], value);
    }

    function withField(object, field, value) {
        const copy = Object.assign({}, object);
        if (value === undefined)
            delete copy[field];
        else
            copy[field] = value;
        return copy;
    }

    signal changeConfirmed(string field)
    signal changeRefused(string field, string error)

    function change(field, value, command, args, kwargs) {
        if (!connected)
            return;
        const requestId = nextRequestId++;
        requests[requestId] = { field: field, value: value };
        applying = withField(applying, field, value);
        justApplied = withField(justApplied, field, undefined);
        headset = withField(headset, "error", "");
        helper.write(JSON.stringify({ id: requestId, cmd: command, args: args, kwargs: kwargs ?? {} }) + "\n");
    }

    function powerOff() {
        if (connected)
            helper.write(JSON.stringify({ id: nextRequestId++, cmd: "power_off", args: [] }) + "\n");
    }

    function openDetails() {
        detailWindow.visible = true;
    }

    function handleAck(message) {
        const request = requests[message.ack];
        delete requests[message.ack];
        if (!request)
            return;
        const isLatest = sameValue(applying[request.field], request.value);
        if (isLatest)
            applying = withField(applying, request.field, undefined);
        if (!message.ok) {
            headset = withField(headset, "error", message.error);
            changeRefused(request.field, message.error);
            return;
        }
        if (request.field in headset)
            headset = withField(headset, request.field, request.value);
        changeConfirmed(request.field);
        if (isLatest) {
            justApplied = withField(justApplied, request.field, request.value);
            appliedFade.restart();
        }
    }

    function handleMessage(message) {
        if (message.ack !== undefined) {
            handleAck(message);
        } else if (message.patch) {
            headset = Object.assign({}, headset, message.patch);
        } else {
            headset = message;
            if (!message.connected) {
                applying = {};
                requests = {};
            }
        }
    }

    Timer {
        id: appliedFade

        interval: 1500
        onTriggered: root.justApplied = {}
    }

    Process {
        id: helper

        command: ["python3", "-I", "-B", root.helperPath]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (parseError) {
                    console.warn("BoseService: unreadable helper output:", line);
                    return;
                }
                root.handleMessage(message);
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("BoseService helper:", line)
        }

        onExited: exitCode => {
            root.handleMessage({ connected: false, error: "Helper stopped (exit code " + exitCode + ")" });
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer

        interval: 5000
        onTriggered: helper.running = true
    }

    BoseDetailWindow {
        id: detailWindow
    }
}
