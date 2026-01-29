# AI Agents Guidelines

This document provides guidelines for AI agents (like GitHub Copilot, Claude, ChatGPT) working with this codebase.

## Project Overview

**Arch Server v5.1** is an automated Arch Linux server deployment system featuring:
- LUKS2 full disk encryption with TPM auto-unlock
- systemd-boot with Unified Kernel Images (UKI)
- Btrfs filesystem with snapshots
- Ansible-based configuration management
- Security-first design (nftables, AppArmor, auditd)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      INSTALLATION FLOW                       │
├─────────────────────────────────────────────────────────────┤
│  1. install.sh    →  Disk setup, encryption, base system    │
│  2. reboot        →  Boot into new system                   │
│  3. deploy.sh     →  Run Ansible playbooks                  │
│  4. cloudflare.sh →  Setup Cloudflare Tunnel                │
└─────────────────────────────────────────────────────────────┘
```

## Key Files

| File | Purpose |
|------|---------|
| `src/install.sh` | Main installer script |
| `src/ansible/playbooks/site.yml` | Primary Ansible playbook |
| `config.env` | User configuration |
| `scripts/deploy.sh` | Deployment automation |

## Coding Standards

### Bash Scripts
- Always use `set -euo pipefail`
- Quote all variables: `"$var"`
- Use `[[ ]]` for tests
- Add descriptive comments
- Use functions for repeated code

### Ansible
- Use FQCN (Fully Qualified Collection Names): `community.general.pacman`
- Include `failed_when: false` for optional tasks
- Use meaningful task names
- Keep roles focused and single-purpose

## Common Tasks

### Adding a new Ansible role

```bash
# Create role structure
mkdir -p src/ansible/roles/new_role/{tasks,handlers,defaults,files,templates}

# Create main.yml
cat > src/ansible/roles/new_role/tasks/main.yml << 'EOF'
---
- name: Description of task
  debug:
    msg: "New role task"
EOF
```

### Testing changes

```bash
# Lint bash scripts
shellcheck src/install.sh scripts/*.sh

# Lint Ansible
ansible-lint src/ansible/

# Run tests
task test
```

## Security Considerations

1. **Never commit secrets** - Use environment variables or separate config
2. **SSH keys in `keys/`** - This directory is gitignored
3. **Passwords in `config.env`** - Keep secure, don't commit real values
4. **LUKS passwords** - Always generated or user-provided, never hardcoded

## Important Patterns

### Error Handling in Bash
```bash
command || {
    error "Command failed"
    exit 1
}
```

### Conditional Ansible Tasks
```yaml
- name: Task that might fail
  command: some_command
  register: result
  failed_when: false
  changed_when: result.rc == 0
```

### Service Checks
```yaml
- name: Check if service exists
  systemd:
    name: service_name
    state: started
  failed_when: false
```

## Do's and Don'ts

### Do ✅
- Follow existing code style
- Add error handling
- Update documentation
- Test on actual Arch Linux
- Use idempotent operations

### Don't ❌
- Hardcode passwords or secrets
- Skip error handling
- Assume packages are in official repos (check AUR)
- Use deprecated Ansible syntax
- Forget to update CHANGELOG.md

## Frequently Changed Areas

1. **Ansible roles** - Most common changes
2. **Security hardening** - Sysctl, firewall rules
3. **Package lists** - Adding/removing packages
4. **SSH configuration** - Authentication methods

## Testing Environment

For development, use:
- QEMU/KVM virtual machine
- Arch Linux ISO
- Test with `AUTO_INSTALL=true` in config.env

## Contact

- **Author**: Mike Holmsted (Humethix)
- **Repository**: github.com/humethix/arch-server
- **License**: MIT
