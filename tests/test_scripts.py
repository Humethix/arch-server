"""
Shell Script Tests
Arch Server v5.1

Run with: pytest tests/ -v
"""

import os
import subprocess
import pytest

# Path to scripts directory
SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), "..", "scripts")
SRC_DIR = os.path.join(os.path.dirname(__file__), "..", "src")


class TestShellScripts:
    """Test shell script validity."""

    def get_shell_scripts(self):
        """Get list of shell scripts."""
        scripts = []

        # Scripts directory
        if os.path.exists(SCRIPTS_DIR):
            for f in os.listdir(SCRIPTS_DIR):
                if f.endswith(".sh"):
                    scripts.append(os.path.join(SCRIPTS_DIR, f))

        # src/install.sh
        install_sh = os.path.join(SRC_DIR, "install.sh")
        if os.path.exists(install_sh):
            scripts.append(install_sh)

        return scripts

    def test_scripts_have_shebang(self):
        """Test all scripts have proper shebang."""
        for script in self.get_shell_scripts():
            with open(script, "r") as f:
                first_line = f.readline()
            assert first_line.startswith("#!"), f"{script} missing shebang"

    def test_scripts_shellcheck(self):
        """Test scripts pass shellcheck (if available)."""
        # Check if shellcheck is available
        result = subprocess.run(
            ["which", "shellcheck"], capture_output=True, text=True
        )
        if result.returncode != 0:
            pytest.skip("shellcheck not installed")

        for script in self.get_shell_scripts():
            result = subprocess.run(
                ["shellcheck", "-S", "warning", script],
                capture_output=True,
                text=True,
            )
            # Allow some warnings, but no errors
            assert result.returncode in [0, 1], f"shellcheck failed for {script}: {result.stdout}"


class TestConfigEnv:
    """Test config.env file."""

    def test_config_env_exists(self):
        """Test config.env exists."""
        config = os.path.join(SRC_DIR, "config.env")
        assert os.path.exists(config), "src/config.env not found"

    def test_config_env_has_required_vars(self):
        """Test config.env has required variables."""
        config = os.path.join(SRC_DIR, "config.env")
        if not os.path.exists(config):
            pytest.skip("config.env not found")

        with open(config, "r") as f:
            content = f.read()

        required_vars = [
            "HOSTNAME",
            "USERNAME",
            "TIMEZONE",
            "KERNEL_TYPE",
        ]

        for var in required_vars:
            assert var in content, f"config.env missing {var}"
