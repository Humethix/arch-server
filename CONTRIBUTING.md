# Contributing to Arch Server v5.1

First off, thank you for considering contributing to Arch Server! 🎉

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Style Guidelines](#style-guidelines)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

This project and everyone participating in it is governed by our commitment to creating a welcoming and inclusive environment. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Clear title** describing the issue
- **Steps to reproduce** the behavior
- **Expected behavior** vs actual behavior
- **System information** (Arch version, hardware specs)
- **Logs** from relevant services (`journalctl -u service-name`)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:

- **Use case** - Why is this enhancement needed?
- **Proposed solution** - How should it work?
- **Alternatives considered** - Other approaches you've thought about

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`task test`)
5. Commit your changes (see commit message guidelines)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

### Prerequisites

- Arch Linux (or any Linux for development)
- Ansible 2.15+
- Python 3.11+
- Task (taskfile.dev)

### Setup

```bash
# Clone the repository
git clone https://github.com/humethix/arch-server.git
cd arch-server

# Install dependencies
pip install -r requirements.txt

# Install pre-commit hooks
pre-commit install

# Run tests
task test
```

### Project Structure

```
arch-server/
├── src/                    # Source scripts
│   ├── install.sh          # Main installer
│   └── ansible/            # Ansible configuration
├── scripts/                # Utility scripts
├── templates/              # Configuration templates
├── tests/                  # Test files
├── docs/                   # Documentation
└── keys/                   # SSH keys (gitignored)
```

## Style Guidelines

### Bash Scripts

- Use `shellcheck` for linting
- Use `set -euo pipefail` at the start
- Quote all variables: `"$var"` not `$var`
- Use `[[ ]]` for conditionals, not `[ ]`
- Add comments for complex logic

```bash
#!/bin/bash
# Description of what this script does

set -euo pipefail

# Good
if [[ -f "$config_file" ]]; then
    source "$config_file"
fi

# Bad
if [ -f $config_file ]; then
    source $config_file
fi
```

### Ansible

- Use YAML syntax consistently
- Name all tasks descriptively
- Use `become: yes` only when necessary
- Include `failed_when` and `changed_when` where appropriate
- Use role defaults for configurable values

```yaml
# Good
- name: Install security packages
  community.general.pacman:
    name: "{{ security_packages }}"
    state: present
  become: yes

# Bad
- pacman:
    name: nftables
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(installer): add SSH key authentication support

fix(ansible): handle existing snapper config

docs(readme): add SSH access documentation

chore(deps): update ansible to 2.16
```

## Pull Request Process

1. **Update documentation** - Include relevant docs updates
2. **Add tests** - For new features or bug fixes
3. **Update CHANGELOG.md** - Add entry under `[Unreleased]`
4. **Pass CI checks** - All tests and linting must pass
5. **Request review** - Tag relevant maintainers

### Review Criteria

- Code follows style guidelines
- Tests pass and cover new code
- Documentation is updated
- Commit messages are clear
- No breaking changes (or clearly documented)

## Questions?

Feel free to open an issue with the `question` label or reach out to the maintainers.

Thank you for contributing! 🚀
