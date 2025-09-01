# 🚀 Gemini Oddity — Claude ↔ Gemini Bridge with OAuth 2.0

<div align="center">

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/good-night-oppie/gemini-oddity)
[![Security](https://img.shields.io/badge/security-OAuth%202.0-green.svg)](docs/SECURITY.md)
[![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)](.github/workflows/test.yml)
[![Coverage](https://img.shields.io/badge/coverage-85%25-yellowgreen.svg)](test/reports/coverage.json)
[![License](https://img.shields.io/badge/license-MIT-purple.svg)](LICENSE)

✨ *“This is Ground Control to Major Tom…”* ✨  
**Gemini Oddity** is a secure and playful bridge between **Claude Code** and **Google Gemini** —  
forked from [tkaufmann/claude-gemini-bridge](https://github.com/tkaufmann/claude-gemini-bridge)  
and given a cosmic twist in tribute to David Bowie’s *Space Oddity*.  

🔐 Now with **enterprise-grade OAuth 2.0**, AES-256 encryption, and a colorful setup wizard.  
🛰️ Because sometimes coding in zero gravity is the only way forward.

[Quick Start](#-quick-start) • [Key Innovations](#-key-innovations) • [Security](#-security) • [Documentation](#-documentation)

</div>

---

## 🚀 What's New in v2.0

We’ve transformed the Claude–Gemini bridge into an **enterprise-ready solution** with comprehensive OAuth 2.0 authentication, replacing simple API keys with a secure, token-based system that follows industry best practices.

### Major Innovations

- **🔐 Full OAuth 2.0 Implementation**: Authorization code flow with PKCE
- **🔄 Automatic Token Management**: Seamless refresh with encrypted storage
- **🛡️ Strong Encryption**: AES-256-CBC for sensitive data
- **🎨 Interactive Setup Wizard**: ANSI-colored terminal onboarding
- **🧪 Comprehensive Tests**: 85%+ coverage with security & perf checks
- **📚 Enterprise Docs**: Setup, migration, and security guides
- **🏭 CI/CD**: Automated tests across OSes and Bash versions

## 🎯 Original Power + Enhanced Security

Gemini Oddity automatically delegates complex, large-context analysis from **Claude Code** to **Google Gemini**, combining Claude’s reasoning with Gemini’s extended context. **With OAuth 2.0, it’s now fit for enterprise deployment.**

### How It Works

```mermaid
graph TB
    subgraph "Claude Code"
        CC[Claude Code CLI]
        TC[Tool Call]
    end
    
    subgraph "OAuth-Enhanced Bridge"
        HS[Hook System]
        DE[Decision Engine]
        OM[🔐 OAuth Manager]
        EM[🔒 Encryption Module]
        PC[Path Converter]
        CH[Cache Layer]
    end
    
    subgraph "External APIs"
        GA[Google OAuth]
        GC[Gemini CLI]
        GM[Gemini API]
    end
    
    CC -->|PreToolUse Hook| HS
    HS --> PC
    PC --> DE
    DE -->|Needs Auth| OM
    OM -->|Secure Token| EM
    EM -->|Encrypted Storage| OM
    OM <-->|OAuth Flow| GA
    DE -->|Delegate?| CH
    CH -->|Authorized| GC
    GC --> GM
    GM -->|Analysis| CH
    CH -->|Response| HS
    HS -->|Result| CC
    
    style OM fill:#4CAF50
    style EM fill:#FF9800
    style GA fill:#2196F3
