# Contributing to Gemini Oddity

Thank you for your interest in contributing to Gemini Oddity! This document provides comprehensive guidelines for contributing to our OAuth-enhanced Claude Code and Google Gemini integration bridge.

## 🚀 Getting Started

### Prerequisites

- Bash 4.0+
- Claude Code CLI
- Google Gemini CLI
- `jq` for JSON processing
- `git` for version control

### Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/your-username/gemini-oddity.git
   cd gemini-oddity
   ```

2. **Set up development environment**
   ```bash
   # Install development tools (macOS)
   brew install shellcheck shfmt

   # Make scripts executable
   chmod +x hooks/*.sh test/*.sh
   
   # Run initial tests
   ./test/test-runner.sh
   ```

3. **Create a development branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📝 Code Standards

### Shell Script Guidelines

- **Shebang**: Always use `#!/bin/bash`
- **ABOUTME**: Include single-line comment explaining file purpose
- **Functions**: Document with inline comments
- **Variables**: Use `local` for function variables
- **Error Handling**: Always check exit codes and handle errors

#### Example:
```bash
#!/bin/bash
# ABOUTME: Example script demonstrating code standards

# Global configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Example function with proper documentation
process_files() {
    local input_dir="$1"
    local output_file="$2"
    
    # Validate inputs
    if [ ! -d "$input_dir" ]; then
        echo "Error: Directory not found: $input_dir" >&2
        return 1
    fi
    
    # Process files
    find "$input_dir" -name "*.txt" > "$output_file"
    
    return 0
}
```

### Code Style

- **Indentation**: 4 spaces (no tabs)
- **Line Length**: Maximum 100 characters
- **Comments**: English only
- **Naming**: Use snake_case for variables and functions
- **Constants**: Use UPPER_CASE for constants

### Testing Requirements

Every new feature must include:

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test component interactions
3. **Mock Data**: Provide test inputs when needed

Example test structure:
```bash
test_new_feature() {
    echo "Testing new feature..."
    
    # Test 1: Normal case
    local result=$(your_function "normal_input")
    if [ "$result" != "expected_output" ]; then
        echo "❌ Test 1 failed"
        return 1
    fi
    
    # Test 2: Error case
    your_function "invalid_input" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "❌ Test 2 failed: Should have returned error"
        return 1
    fi
    
    echo "✅ All tests passed"
    return 0
}
```

## 🔧 Development Workflow

### 1. Issue Identification

- Check existing issues before creating new ones
- Use issue templates when available
- Include minimal reproduction steps
- Specify environment details (OS, Claude version, etc.)

### 2. Feature Development

- Create feature branch from `main`
- Implement changes with tests
- Update documentation as needed
- Ensure all tests pass

### 3. Testing

```bash
# Run all tests
./test/test-runner.sh

# Run specific test suites
./test/unit/test-oauth-handler.sh
./test/unit/test-secure-token-storage.sh
./test/integration/test-oauth-flow.sh
./test/security/test-security-audit.sh

# Test specific components
./hooks/lib/path-converter.sh
./hooks/lib/json-parser.sh
./hooks/lib/oauth-handler.sh

# Interactive testing
./test/manual-test.sh

# Check shell script quality
shellcheck hooks/*.sh hooks/lib/*.sh

# Run security audit
./hooks/lib/security-audit.sh

# Performance benchmarks
./test/performance/test-performance-benchmarks.sh
```

### 4. Documentation

Update documentation for:
- New configuration options
- API changes
- New features
- Breaking changes

### 5. Pull Request

- Use descriptive PR titles
- Include detailed description
- Reference related issues
- Ensure CI passes

## 🐛 Bug Reports

### Before Reporting

1. **Search existing issues** for duplicates
2. **Test with latest version**
3. **Check troubleshooting guide**
4. **Enable debug logging** (`DEBUG_LEVEL=3`)

### Bug Report Template

```markdown
**Bug Description**
Clear description of the issue

**Environment**
- OS: macOS 14.5 / Ubuntu 20.04 / etc.
- Claude Code Version: 1.0.40
- Gemini CLI Version: 1.2.3
- Bridge Version: commit hash

**Reproduction Steps**
1. Step one
2. Step two
3. ...

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Debug Logs**
```
Paste relevant logs here
```

**Additional Context**
Any other relevant information
```

## 🚀 Feature Requests

### Feature Request Template

```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed? What problem does it solve?

**Proposed Implementation**
High-level approach to implementing the feature

**Alternatives Considered**
Other approaches that were considered

**Additional Context**
Screenshots, examples, references, etc.
```

## 📋 Component Overview

Understanding the codebase structure:

```
gemini-oddity/
├── gemini-oddity              # Main CLI entry point
├── install.sh                 # Global installation script
├── project-uninstall.sh       # Per-project uninstallation
├── .gemini-oddity/            # Per-project installation directory
├── hooks/
│   ├── gemini-bridge.sh       # Main delegation hook
│   ├── unified-automation.sh  # PR automation system
│   ├── universal-router.sh    # Multi-provider routing
│   ├── lib/
│   │   ├── oauth-handler.sh   # OAuth 2.0 implementation
│   │   ├── token-storage.sh   # Secure token management
│   │   ├── encryption-core.sh # AES-256 encryption
│   │   ├── path-converter.sh  # @ path conversion
│   │   ├── json-parser.sh     # JSON handling
│   │   ├── config-manager.sh  # Configuration management
│   │   ├── security-audit.sh  # Security validation
│   │   ├── debug-helpers.sh   # Logging/debugging
│   │   └── gemini-wrapper.sh  # Gemini API interface
│   ├── providers/
│   │   ├── base-provider.sh   # Provider interface
│   │   └── gemini-cli-provider.sh # Gemini CLI implementation
│   └── config/
│       └── debug.conf         # Debug configuration
├── test/
│   ├── unit/                  # Unit tests
│   ├── integration/           # Integration tests
│   ├── security/              # Security audits
│   ├── performance/           # Performance benchmarks
│   ├── test-runner.sh         # Main test executor
│   ├── manual-test.sh         # Interactive testing
│   └── mock-tool-calls/       # Test data
├── docs/
│   ├── API.md                 # API documentation
│   ├── SECURITY.md            # Security guidelines
│   ├── MIGRATION_GUIDE.md     # Migration from v1
│   ├── ENHANCED-INSTALLER.md  # Installation guide
│   ├── ADVANCED_HOOKS.md      # Advanced features
│   └── TROUBLESHOOTING.md     # Debug guide
└── scripts/
    ├── init-gemini-delegation.sh # Setup helpers
    └── install-bridge.sh      # Bridge installer
```

## 🔍 Debugging Guidelines

### Debug Levels

- **Level 0**: No debug output
- **Level 1**: Basic information (default)
- **Level 2**: Detailed information
- **Level 3**: Full tracing

### Debugging Tools

```bash
# Enable maximum debugging
echo "DEBUG_LEVEL=3" >> hooks/config/debug.conf

# Capture all inputs
echo "CAPTURE_INPUTS=true" >> hooks/config/debug.conf

# Test mode (no actual Gemini calls)
echo "DRY_RUN=true" >> hooks/config/debug.conf

# View logs in real-time
tail -f logs/debug/$(date +%Y%m%d).log
```

### Common Debug Scenarios

1. **Hook not executing**: Check Claude settings and permissions
2. **Path conversion issues**: Test path-converter.sh directly
3. **Gemini API problems**: Verify CLI setup and credentials
4. **Cache problems**: Clear cache and check file permissions

## 🎯 Pull Request Guidelines

### PR Checklist

- [ ] Tests pass (`./test/test-runner.sh`)
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] CHANGELOG.md updated (if applicable)
- [ ] Commit messages are descriptive
- [ ] No unnecessary files included

### Commit Message Format

```
type(scope): description

Body explaining the change in detail.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Maintenance tasks

Examples:
```
feat(cache): add content-aware cache invalidation

Implement cache key generation based on file contents and metadata
to ensure cache invalidation when files are modified.

Fixes #45
```

## 🏆 Recognition

Contributors will be recognized in:
- README.md acknowledgments
- Release notes
- GitHub contributor graphs
- Optional social media mentions

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and community chat
- **Documentation**: Check TROUBLESHOOTING.md first
- **Code Review**: Tag maintainers for review assistance

## 🎨 Code of Conduct

We are committed to providing a welcoming and inclusive environment. Please:

- Be respectful and constructive
- Focus on the technical aspects
- Help others learn and grow
- Report any inappropriate behavior

## 📈 Release Process

### Versioning

We use [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features
- PATCH: Bug fixes

### Release Checklist

1. Update version numbers
2. Update CHANGELOG.md
3. Create release PR
4. Tag release after merge
5. Update installation documentation

## 🔐 Security Considerations

When contributing code that handles sensitive data:

1. **OAuth Tokens**: Never log or expose OAuth tokens
2. **Encryption**: Use the provided encryption-core.sh for sensitive data
3. **File Exclusions**: Respect the security patterns (*.secret, *.key, etc.)
4. **Token Storage**: Always use token-storage.sh for credential management
5. **Audit Trail**: Ensure security-audit.sh passes for your changes

## 🚢 New Features Checklist

For major feature additions:

- [ ] Feature documented in docs/
- [ ] Unit tests with >80% coverage
- [ ] Integration tests for external interactions
- [ ] Security audit passed
- [ ] Performance benchmarks included
- [ ] Migration guide updated (if breaking changes)
- [ ] CLAUDE.md updated for AI assistant context
- [ ] Example usage in README.md

Thank you for contributing to Gemini Oddity! 🎉