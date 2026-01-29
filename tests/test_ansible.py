"""
Ansible Playbook Tests
Arch Server v5.1

Run with: pytest tests/ -v
"""

import os
import subprocess
import pytest

# Path to ansible directory
ANSIBLE_DIR = os.path.join(os.path.dirname(__file__), "..", "src", "ansible")


class TestAnsibleSyntax:
    """Test Ansible playbook syntax."""

    def test_site_yml_syntax(self):
        """Test site.yml has valid syntax."""
        playbook = os.path.join(ANSIBLE_DIR, "playbooks", "site.yml")
        if os.path.exists(playbook):
            result = subprocess.run(
                ["ansible-playbook", "--syntax-check", playbook],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_go_live_yml_syntax(self):
        """Test go-live.yml has valid syntax."""
        playbook = os.path.join(ANSIBLE_DIR, "playbooks", "go-live.yml")
        if os.path.exists(playbook):
            result = subprocess.run(
                ["ansible-playbook", "--syntax-check", playbook],
                capture_output=True,
                text=True,
            )
            assert result.returncode == 0, f"Syntax error: {result.stderr}"


class TestAnsibleStructure:
    """Test Ansible directory structure."""

    def test_ansible_cfg_exists(self):
        """Test ansible.cfg exists."""
        cfg = os.path.join(ANSIBLE_DIR, "ansible.cfg")
        assert os.path.exists(cfg), "ansible.cfg not found"

    def test_inventory_exists(self):
        """Test inventory file exists."""
        inventory = os.path.join(ANSIBLE_DIR, "inventory", "hosts.yml")
        assert os.path.exists(inventory), "inventory/hosts.yml not found"

    def test_roles_exist(self):
        """Test required roles exist."""
        roles = [
            "base_hardening",
            "container_runtime",
            "cloudflare",
            "security_stack",
            "webserver",
            "safe_updates",
        ]
        roles_dir = os.path.join(ANSIBLE_DIR, "roles")

        for role in roles:
            role_path = os.path.join(roles_dir, role)
            assert os.path.exists(role_path), f"Role {role} not found"
            assert os.path.exists(
                os.path.join(role_path, "tasks", "main.yml")
            ), f"Role {role}/tasks/main.yml not found"


class TestHealthCheck:
    """Test health check script."""

    def test_health_check_exists(self):
        """Test health-check script exists."""
        script = os.path.join(
            ANSIBLE_DIR, "roles", "base_hardening", "files", "health-check"
        )
        assert os.path.exists(script), "health-check script not found"

    def test_health_check_executable(self):
        """Test health-check is shell script."""
        script = os.path.join(
            ANSIBLE_DIR, "roles", "base_hardening", "files", "health-check"
        )
        if os.path.exists(script):
            with open(script, "r") as f:
                first_line = f.readline()
            assert first_line.startswith("#!/bin/bash"), "health-check should be bash script"


class TestConfigValidation:
    """Test configuration validation."""

    def test_config_validate_exists(self):
        """Test config-validate.sh script exists."""
        script = os.path.join(os.path.dirname(__file__), "..", "src", "config-validate.sh")
        assert os.path.exists(script), "config-validate.sh not found"

    def test_config_validate_executable(self):
        """Test config-validate.sh is shell script."""
        script = os.path.join(os.path.dirname(__file__), "..", "src", "config-validate.sh")
        if os.path.exists(script):
            with open(script, "r") as f:
                first_line = f.readline()
            assert first_line.startswith("#!/bin/bash"), "config-validate.sh should be bash script"

    def test_config_setup_exists(self):
        """Test config-setup.sh script exists."""
        script = os.path.join(os.path.dirname(__file__), "..", "src", "config-setup.sh")
        assert os.path.exists(script), "config-setup.sh not found"

    def test_config_templates_exist(self):
        """Test config templates exist."""
        basic = os.path.join(os.path.dirname(__file__), "..", "src", "config.env.basic")
        advanced = os.path.join(os.path.dirname(__file__), "..", "src", "config.env.advanced")
        assert os.path.exists(basic), "config.env.basic not found"
        assert os.path.exists(advanced), "config.env.advanced not found"
