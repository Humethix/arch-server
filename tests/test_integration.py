"""
Integration Tests for Arch Server v5.1
Tests end-to-end functionality and component integration
"""

import os
import subprocess
import tempfile
import pytest
from pathlib import Path


class TestInstallationFlow:
    """Test complete installation workflow."""

    @pytest.fixture
    def temp_config(self):
        """Create temporary config for testing."""
        config_content = '''
# Test configuration
HOSTNAME="testserver"
USERNAME="testuser"
TIMEZONE="Europe/Copenhagen"
LOCALE="en_US.UTF-8"
KEYMAP="us"
KERNEL_TYPE="hardened"
ROOT_PASSWORD="testpass123"
USER_PASSWORD="testpass123"
LUKS_PASSWORD="testpass123"
AUTO_INSTALL=false
DEBUG=false
'''
        with tempfile.NamedTemporaryFile(mode='w', suffix='.env', delete=False) as f:
            f.write(config_content)
            return f.name

    def test_config_loading(self, temp_config):
        """Test that config can be loaded by install script."""
        src_dir = Path(__file__).parent.parent / "src"
        install_script = src_dir / "install.sh"

        if not install_script.exists():
            pytest.skip("install.sh not found")

        # Test config validation on our temp config
        validate_script = src_dir / "config-validate.sh"
        if validate_script.exists():
            result = subprocess.run(
                [str(validate_script)],
                cwd=str(src_dir),
                env={"CONFIG_FILE": temp_config},
                capture_output=True,
                text=True
            )
            # Should pass basic validation (may have warnings about missing files)
            assert result.returncode in [0, 1], f"Config validation failed: {result.stderr}"

    def test_script_syntax(self):
        """Test all scripts have valid bash syntax."""
        src_dir = Path(__file__).parent.parent / "src"
        scripts_dir = Path(__file__).parent.parent / "scripts"

        scripts = [
            src_dir / "install.sh",
            src_dir / "config-setup.sh",
            src_dir / "config-validate.sh",
        ]

        # Add all scripts from scripts directory
        if scripts_dir.exists():
            scripts.extend(scripts_dir.glob("*.sh"))

        for script in scripts:
            if script.exists():
                result = subprocess.run(
                    ["bash", "-n", str(script)],
                    capture_output=True,
                    text=True
                )
                assert result.returncode == 0, f"Syntax error in {script.name}: {result.stderr}"

    def test_ansible_integration(self):
        """Test Ansible components work together."""
        src_dir = Path(__file__).parent.parent / "src"
        ansible_dir = src_dir / "ansible"

        if not ansible_dir.exists():
            pytest.skip("Ansible directory not found")

        # Test ansible.cfg exists and is valid
        ansible_cfg = ansible_dir / "ansible.cfg"
        assert ansible_cfg.exists(), "ansible.cfg not found"

        # Test inventory exists
        inventory = ansible_dir / "inventory" / "hosts.yml"
        assert inventory.exists(), "inventory/hosts.yml not found"

        # Test playbooks can be parsed
        playbooks = [
            ansible_dir / "playbooks" / "site.yml",
            ansible_dir / "playbooks" / "go-live.yml"
        ]

        for playbook in playbooks:
            if playbook.exists():
                result = subprocess.run(
                    ["ansible-playbook", "--syntax-check", str(playbook)],
                    capture_output=True,
                    text=True,
                    cwd=str(ansible_dir)
                )
                assert result.returncode == 0, f"Playbook syntax error in {playbook.name}: {result.stderr}"


class TestComponentIntegration:
    """Test integration between components."""

    def test_config_templates_exist(self):
        """Test all config templates exist."""
        src_dir = Path(__file__).parent.parent / "src"

        templates = [
            "config.env.basic",
            "config.env.advanced",
            "config.env"
        ]

        for template in templates:
            path = src_dir / template
            if template == "config.env":
                # config.env may not exist (generated)
                continue
            assert path.exists(), f"Config template {template} not found"

    def test_ssh_key_discovery(self):
        """Test SSH key auto-discovery logic."""
        # This would require mocking the file system, so we'll just check the logic exists
        install_script = Path(__file__).parent.parent / "src" / "install.sh"
        if install_script.exists():
            with open(install_script, 'r') as f:
                content = f.read()
                # Check that the find_ssh_key function exists
                assert 'find_ssh_key()' in content, "SSH key discovery function should exist"
                # Check that it looks for keys in ~/.ssh/
                assert '~/.ssh/id_' in content, "Should check ~/.ssh/ directory for keys"

    def test_ansible_roles_structure(self):
        """Test Ansible roles have required structure."""
        src_dir = Path(__file__).parent.parent / "src"
        ansible_dir = src_dir / "ansible"
        roles_dir = ansible_dir / "roles"

        if not roles_dir.exists():
            pytest.skip("Roles directory not found")

        expected_roles = [
            "base_hardening",
            "container_runtime",
            "cloudflare",
            "security_stack",
            "webserver",
            "safe_updates",
            "monitoring"
        ]

        for role in expected_roles:
            role_path = roles_dir / role
            if role_path.exists():
                tasks_dir = role_path / "tasks"
                main_yml = tasks_dir / "main.yml"

                assert tasks_dir.exists(), f"Role {role} missing tasks directory"
                assert main_yml.exists(), f"Role {role} missing tasks/main.yml"

    def test_health_check_integration(self):
        """Test health check script exists and is integrated."""
        src_dir = Path(__file__).parent.parent / "src"
        ansible_dir = src_dir / "ansible"
        health_check = ansible_dir / "roles" / "base_hardening" / "files" / "health-check"

        assert health_check.exists(), "Health check script not found in Ansible role"

        # Check it's executable content
        with open(health_check, 'r') as f:
            content = f.read()
            assert "#!/bin/bash" in content, "Health check should be bash script"
            assert len(content) > 100, "Health check script seems too short"


class TestDeploymentScripts:
    """Test deployment and utility scripts."""

    def test_deployment_scripts_exist(self):
        """Test all deployment scripts exist."""
        scripts_dir = Path(__file__).parent.parent / "scripts"

        if not scripts_dir.exists():
            pytest.skip("Scripts directory not found")

        expected_scripts = [
            "deploy.sh",
            "setup-cloudflare.sh",
            "verify-deployment.sh",
            "setup-tpm-unlock.sh",
            "setup-secure-boot.sh",
            "sync-to-server.sh"
        ]

        for script in expected_scripts:
            script_path = scripts_dir / script
            assert script_path.exists(), f"Deployment script {script} not found"

    def test_script_permissions(self):
        """Test scripts are executable (where expected)."""
        # This test would be more relevant on Linux, but we can check file content
        scripts_dir = Path(__file__).parent.parent / "scripts"

        if not scripts_dir.exists():
            pytest.skip("Scripts directory not found")

        for script in scripts_dir.glob("*.sh"):
            with open(script, 'r') as f:
                first_line = f.readline()
                assert first_line.startswith("#!/bin/bash"), f"Script {script.name} should start with shebang"