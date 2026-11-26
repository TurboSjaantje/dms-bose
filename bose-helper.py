#!/usr/bin/env python3
"""Holds the one BMAP connection to the Bose headset for the DMS plugin.

Reads one JSON command per line on stdin: {"cmd": "set_cnc", "args": [3]}.
Writes one JSON state object per line on stdout after every change and poll.
"""
import json
import os
import select
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.realpath(__file__)), "lib", "bosectl", "python"))

import pybmap
from pybmap import discovery

POLL_SECONDS = 30
RETRY_SECONDS = 10
SPATIAL_NAMES = {0: "off", 1: "room", 2: "head"}
ALLOWED_COMMANDS = {
    "set_mode", "set_cnc", "set_anc", "set_wind", "set_spatial", "set_eq",
    "set_sidetone", "set_multipoint", "set_auto_pause", "set_name", "power_off",
    "create_profile", "update_profile", "delete_profile",
}


def emit(state):
    print(json.dumps(state), flush=True)


def find_connected_headset():
    for mac, device_type, connected in discovery._scan_paired_devices():
        if connected and device_type:
            return mac, device_type
    return None, None


def read_or_none(read):
    try:
        return read()
    except pybmap.BmapConnectionError:
        raise
    except pybmap.BmapError:
        return None


def read_modes(device):
    modes = read_or_none(device.modes) or {}
    return [
        {
            "name": mode.name,
            "editable": mode.editable,
            "cnc": mode.cnc_level,
            "spatial": SPATIAL_NAMES.get(mode.spatial, "off"),
            "wind": bool(mode.wind_block),
            "anc": bool(mode.anc_toggle),
        }
        for _, mode in sorted(modes.items())
        if mode.name and mode.name != "None"
    ]


def read_state(device):
    status = device.status()
    return {
        "connected": True,
        "error": "",
        "name": status.name,
        "firmware": status.firmware,
        "battery": status.battery,
        "mode": status.mode,
        "modes": read_modes(device),
        "cnc": status.cnc_level,
        "cncMax": status.cnc_max,
        "eq": [band.current for band in status.eq],
        "sidetone": status.sidetone,
        "multipoint": status.multipoint,
        "autoPause": status.auto_pause,
        **read_audio(device),
    }


def read_audio(device):
    audio = read_or_none(device.audio_settings)
    if not audio:
        return {}
    return {
        "cnc": audio.cnc_level,
        "anc": bool(audio.anc_toggle),
        "wind": bool(audio.wind_block),
        "spatial": SPATIAL_NAMES.get(audio.spatial, "off"),
    }


def read_mode(device):
    return {"mode": device.mode(), **read_audio(device)}


def read_modes_and_mode(device):
    return {"modes": read_modes(device), **read_mode(device)}


READS_AFTER_COMMAND = {
    "set_mode": read_mode,
    "set_cnc": read_audio,
    "set_anc": read_audio,
    "set_wind": read_audio,
    "set_spatial": read_audio,
    "set_eq": lambda device: {"eq": [band.current for band in device.eq()]},
    "set_sidetone": lambda device: {"sidetone": device.sidetone()},
    "set_multipoint": lambda device: {"multipoint": device.multipoint()},
    "set_auto_pause": lambda device: {"autoPause": device.auto_pause()},
    "set_name": lambda device: {"name": device.name()},
    "create_profile": read_modes_and_mode,
    "update_profile": read_modes_and_mode,
    "delete_profile": read_modes_and_mode,
}

CONNECTION_ERRORS = (pybmap.BmapConnectionError, pybmap.BmapTimeoutError, OSError)


def handle_line(device, line):
    request = json.loads(line)
    request_id = request.get("id")
    command = request.get("cmd")
    try:
        if command not in ALLOWED_COMMANDS:
            raise pybmap.BmapInvalidArgError("Unknown command: %s" % command)
        getattr(device, command)(*request.get("args", []), **request.get("kwargs", {}))
    except CONNECTION_ERRORS:
        raise
    except (pybmap.BmapError, ValueError, TypeError) as command_error:
        emit({"ack": request_id, "ok": False, "error": str(command_error)})
        return
    emit({"ack": request_id, "ok": True})
    if command == "power_off":
        raise pybmap.BmapConnectionError("Headset powered off")
    emit({"patch": READS_AFTER_COMMAND[command](device)})


class Session:
    def __init__(self):
        self.device = None
        self.last_reported_error = None

    def report_disconnected(self, error):
        if error != self.last_reported_error:
            emit({"connected": False, "error": error})
            self.last_reported_error = error

    def try_connect(self):
        mac, device_type = find_connected_headset()
        if not mac:
            self.report_disconnected("No Bose headset connected")
            return
        try:
            self.device = pybmap.connect(mac, device_type)
            emit(read_state(self.device))
            self.last_reported_error = None
        except (pybmap.BmapError, OSError) as connect_error:
            self.drop(str(connect_error))

    def drop(self, error):
        if self.device:
            self.device.close()
        self.device = None
        self.report_disconnected(error)

    def serve(self, line):
        try:
            if line.strip():
                handle_line(self.device, line)
            else:
                emit(read_state(self.device))
        except CONNECTION_ERRORS as connection_error:
            self.drop(str(connection_error))


def main():
    session = Session()
    while True:
        if session.device is None:
            session.try_connect()
        timeout = POLL_SECONDS if session.device else RETRY_SECONDS
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        line = sys.stdin.readline() if ready else ""
        if ready and not line:
            break
        if session.device:
            session.serve(line)
    session.drop("Helper stopped")


if __name__ == "__main__":
    main()
