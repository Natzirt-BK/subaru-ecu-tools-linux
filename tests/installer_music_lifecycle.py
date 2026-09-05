"""Silent lifecycle regressions; no real installer operations or audio output."""
import os
from pathlib import Path
import pty
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


def alive(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().rsplit(") ", 1)[1].split()[0] not in ("Z", "X")
    except (FileNotFoundError, ProcessLookupError):
        return False


class MusicLifecycle(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ecu-music-test-")
        self.root = Path(self.temporary.name)
        self.master, self.slave = pty.openpty()
        self.process = None
        self.env = dict(os.environ)
        for name in list(self.env):
            if name.startswith(("SUBARU_SETUP_", "ECU_TOOLS_MUSIC_")):
                del self.env[name]
        self.env.update(
            PATH=f"{self.root}:{os.environ['PATH']}", TERM="dumb",
            XDG_RUNTIME_DIR=str(self.root), XDG_DATA_HOME=str(self.root / "data"),
            XDG_STATE_HOME=str(self.root / "state"),
            SUBARU_SETUP_INPUT_DEVICE=os.ttyname(self.slave),
            ECU_TOOLS_MUSIC_INPUT_DEVICE=os.ttyname(self.slave),
            ECU_TOOLS_SKIP_UPDATE_PROMPT="1", ECU_TOOLS_UI_WIDTH="70",
            MUSIC_TEST_ROOT=str(self.root),
        )
        self.fixture("pw-play", '''#!/bin/sh
printf '%s\\n' "$$" >>"$MUSIC_TEST_ROOT/audio-pids"
exec sleep 300
''')
        # Exercise the actual installer's completion and signal handlers, but
        # stop after logging setup, before application/system operations run.
        engine = (ROOT / "linux/install-cachyos.sh").read_text().split("\nbin_dir=", 1)[0]
        self.fixture("installer", engine + '''
ok() { :; }
summary_row() { :; }
completion_banner() { [[ "${MUSIC_TEST_FAIL_COMPLETION:-0}" != 1 ]]; }
confirm_success() { [[ "${MUSIC_TEST_BACK:-0}" != 1 ]] || return_to_setup_menu=true; }
console_footer() { :; }
log_file=synthetic.log
printf '%s\\n' "$$" >"$MUSIC_TEST_ROOT/installer-pid"
while [[ ! -e "$MUSIC_TEST_ROOT/release" ]]; do sleep 0.02; done
exit 0
''')
        self.env["ECU_TOOLS_INSTALLER"] = str(self.root / "installer")

    def fixture(self, name, contents):
        path = self.root / name
        path.write_text(contents)
        path.chmod(0o755)
        return path

    def tearDown(self):
        if self.process is not None:
            # Only the fresh process group owned by this test is terminated.
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            self.process.wait(timeout=3)
        if self.master is not None:
            os.close(self.master)
        os.close(self.slave)
        self.temporary.cleanup()

    def wait_for(self, predicate, message):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(.02)
        self.fail(message)

    def start(self, command=None):
        self.process = subprocess.Popen(
            command or [str(ROOT / "linux/setup-cachyos-gui.sh")],
            stdin=self.slave, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            env=self.env, start_new_session=True,
        )
        audio_trace = self.root / "audio-pids"
        self.wait_for(lambda: audio_trace.exists() and audio_trace.read_text().strip(), "audio did not start")
        self.audio = int(audio_trace.read_text().splitlines()[0])
        stat = Path(f"/proc/{self.audio}/stat").read_text().rsplit(") ", 1)[1].split()
        self.controller = int(stat[1])
        self.assertTrue(alive(self.controller))

    def keys(self, value):
        os.write(self.master, value.encode())

    def assert_stopped(self):
        self.wait_for(lambda: not alive(self.controller) and not alive(self.audio),
                      "music controller or audio survived closure")
        self.assertEqual([], list(self.root.glob("*.state")))

    def menu_owns_keys(self):
        # The paused state can still be left over from the previous menu while
        # its resume signal is in flight. Also require exec back into setup.
        try:
            command = Path(f"/proc/{self.process.pid}/cmdline").read_bytes()
        except (FileNotFoundError, ProcessLookupError):
            return False
        return (str(ROOT / "linux/setup-cachyos-gui.sh").encode() in command
                and any(p.read_text().strip() == "paused" for p in self.root.glob("*.state")))

    def enter_installer(self):
        self.keys("1y")
        marker = self.root / "installer-pid"
        self.wait_for(lambda: marker.exists() and marker.read_text().strip(), "installer handoff failed")
        self.assertEqual(self.process.pid, int(marker.read_text()))
        time.sleep(.2)
        self.assertTrue(alive(self.controller), "handoff stopped the controller")
        self.assertTrue(alive(self.audio), "handoff stopped the audio")

    def test_menu_quit(self):
        self.start()
        self.keys("q")
        self.assertEqual(0, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_cancel_install(self):
        self.start()
        self.keys("1n")
        self.assertEqual(0, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_menu_hangup(self):
        self.start()
        self.process.send_signal(signal.SIGHUP)
        self.process.wait(timeout=4)
        self.assert_stopped()

    def test_owner_killed_without_cleanup_even_before_reaping(self):
        self.start()
        self.process.kill()
        # Leave the owner as a zombie: kill -0 alone cannot detect this case.
        self.assert_stopped()
        self.process.wait(timeout=4)

    def test_pty_disconnect_while_keys_paused(self):
        self.start()
        os.close(self.master)
        self.master = None
        self.assert_stopped()

    def test_player_detects_pty_disconnect_while_owner_still_alive(self):
        self.env["ECU_TOOLS_MUSIC_CAPTURE_KEYS"] = "0"
        self.start(["bash", "-c", 'trap "" HUP; "$1" & wait "$!"; exec sleep 300',
                    "music-test-owner", str(ROOT / "linux/play-installer-chiptune")])
        os.close(self.master)
        self.master = None
        self.assert_stopped()
        self.assertTrue(alive(self.process.pid))

    def test_controller_term(self):
        self.start()
        os.kill(self.controller, signal.SIGTERM)
        self.assert_stopped()

    def test_installer_completion_stops_music(self):
        self.start()
        self.enter_installer()
        (self.root / "release").touch()
        self.assertEqual(0, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_installer_hangup_skips_completion_prompts(self):
        self.start()
        self.enter_installer()
        self.process.send_signal(signal.SIGHUP)
        self.assertEqual(129, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_error_in_completion_still_stops_music(self):
        self.env["MUSIC_TEST_FAIL_COMPLETION"] = "1"
        self.start()
        self.enter_installer()
        (self.root / "release").touch()
        self.assertNotEqual(0, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_return_to_menu_keeps_one_player_then_quit_stops_it(self):
        self.env["MUSIC_TEST_BACK"] = "1"
        self.start()
        self.enter_installer()
        (self.root / "release").touch()
        self.wait_for(self.menu_owns_keys,
                      "menu did not regain key ownership")
        self.assertEqual(1, len((self.root / "audio-pids").read_text().splitlines()))
        self.assertTrue(alive(self.audio))
        self.keys("q")
        self.assertEqual(0, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_menu_mute_survives_return_to_menu(self):
        self.env["MUSIC_TEST_BACK"] = "1"
        self.start()
        self.keys("m")
        self.assert_stopped()
        self.keys("1y")
        self.wait_for(lambda: (self.root / "installer-pid").exists(), "installer did not start")
        (self.root / "release").touch()
        time.sleep(.3)
        self.keys("q")
        self.assertEqual(0, self.process.wait(timeout=4))
        self.assertEqual(1, len((self.root / "audio-pids").read_text().splitlines()))

    def test_updater_child_completion_keeps_owner_music(self):
        applications = self.root / "data/applications"
        applications.mkdir(parents=True)
        (applications / "subaru-ecu-tools-setup.desktop").touch()
        self.env.pop("ECU_TOOLS_SKIP_UPDATE_PROMPT")
        self.env["ECU_TOOLS_UPDATER"] = str(self.fixture("updater", '''#!/bin/bash
set -eu
"$ECU_TOOLS_INSTALLER" --update-files
sleep 0.2
exec env ECU_TOOLS_SKIP_UPDATE_PROMPT=1 "$ECU_TOOLS_MENU_LAUNCHER"
'''))
        self.start()
        self.keys("y")
        marker = self.root / "installer-pid"
        self.wait_for(lambda: marker.exists() and marker.read_text().strip(), "updater child did not start")
        self.assertNotEqual(self.process.pid, int(marker.read_text()))
        (self.root / "release").touch()
        self.wait_for(self.menu_owns_keys,
                      "update did not return to menu with music")
        self.assertTrue(alive(self.audio))
        self.assertEqual(1, len((self.root / "audio-pids").read_text().splitlines()))
        self.keys("q")
        self.assertEqual(0, self.process.wait(timeout=4))
        self.assert_stopped()

    def test_eof_stops_direct_player(self):
        self.env["ECU_TOOLS_MUSIC_INPUT_DEVICE"] = "/dev/null"
        self.process = subprocess.Popen([str(ROOT / "linux/play-installer-chiptune")],
                                        env=self.env, start_new_session=True,
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.assertEqual(0, self.process.wait(timeout=4))


if __name__ == "__main__":
    unittest.main(verbosity=2)
