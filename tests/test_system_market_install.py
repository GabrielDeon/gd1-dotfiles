import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ID = 'gd1.system-market'


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        self.config = self.home / '.config/omarchy'
        self.config.mkdir(parents=True)
        self.settings = self.config / 'shell.json'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        # Keep validation real; prevent desktop IPC and package installation.
        self.executable('omarchy', '#!/bin/bash\n[[ $1 == plugin && $2 == validate ]] || exit 99\nexec omarchy-plugin-validate "$3"\n')
        self.executable('omarchy-shell', '#!/bin/bash\nexit 1\n')
        self.defaults = self.base / 'omarchy/config/omarchy'
        self.defaults.mkdir(parents=True)
        self.initial = {'version': 1, 'idle': {'lock': 600}, 'bar': {'layout': {'left': [{'id': 'omarchy.menu'}], 'right': [{'id': 'omarchy.audio'}, {'id': 'omarchy.monitor'}]}}}
        (self.defaults / 'shell.json').write_text(json.dumps(self.initial))
        self.env = dict(os.environ, HOME=str(self.home), OMARCHY_PATH=str(self.base / 'omarchy'), PATH=str(self.bin) + ':' + os.environ['PATH'])

    def executable(self, name, text):
        p = self.bin / name
        p.write_text(text)
        p.chmod(0o755)

    def run_install(self, success=True):
        result = subprocess.run(['bash', str(ROOT / 'scripts/units/install-system-market.sh')], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_fresh_install_preserves_defaults(self):
        self.run_install()
        settings = json.loads(self.settings.read_text())
        self.assertEqual(settings['idle'], self.initial['idle'])
        self.assertEqual(settings['bar']['layout']['left'], self.initial['bar']['layout']['left'])
        self.assertEqual([p['id'] for p in settings['bar']['layout']['right']], ['omarchy.audio', ID, 'omarchy.monitor'])
        self.assertFalse(any(p.is_symlink() for p in (self.config / 'plugins' / ID).rglob('*')))

    def test_repeated_install_preserves_preferences_and_is_unchanged(self):
        self.run_install()
        settings = json.loads(self.settings.read_text())
        settings['bar']['layout']['right'][1]['pricesEnabled'] = False
        self.settings.write_text(json.dumps(settings))
        before = self.settings.read_bytes()
        self.run_install()
        self.run_install()
        self.assertEqual(self.settings.read_bytes(), before)
        self.assertEqual(list(self.config.glob('system-market-*')), [])

    def test_existing_plugin_and_settings_are_backed_up(self):
        self.settings.write_text(json.dumps(self.initial))
        target = self.config / 'plugins' / ID
        target.mkdir(parents=True)
        (target / 'Dashboard.qml').write_text('local customization')
        self.run_install()
        backups = list(self.config.glob('system-market-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / ID / 'Dashboard.qml').read_text(), 'local customization')
        self.assertEqual(json.loads((backups[0] / 'shell.json').read_text()), self.initial)

    def test_malformed_config_fails_before_install(self):
        self.settings.write_text('{broken')
        self.run_install(success=False)
        self.assertFalse((self.config / 'plugins' / ID).exists())
        self.assertEqual(self.settings.read_text(), '{broken')

    def test_stowed_settings_link_is_preserved(self):
        real = self.base / 'managed-shell.json'
        real.write_text(json.dumps(self.initial))
        self.settings.symlink_to(real)
        self.run_install()
        self.assertTrue(self.settings.is_symlink())
        self.assertIn(ID, real.read_text())


if __name__ == '__main__':
    unittest.main()
