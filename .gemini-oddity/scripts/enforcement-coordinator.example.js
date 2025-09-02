#!/usr/bin/env node

/**
 * Enforcement Coordinator for {{PROJECT_NAME}} Project
 * Coordinates enforcement layers across TDD Foundation, Serena, SuperClaude, and Claude-Task-Master
 * 
 * This is a template - replace {{VARIABLES}} with your project-specific values
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class EnforcementCoordinator {
  constructor() {
    this.configPath = path.join(process.cwd(), '.claude/enforcement-layers.json');
    this.config = this.loadConfig();
    this.resultsDir = path.join(process.cwd(), '.claude/enforcement-results');
    this.ensureResultsDirectory();
    this.projectName = '{{PROJECT_NAME}}';
  }

  loadConfig() {
    if (!fs.existsSync(this.configPath)) {
      console.error('Enforcement layers config not found');
      console.error('Create .claude/enforcement-layers.json from template');
      process.exit(1);
    }
    return JSON.parse(fs.readFileSync(this.configPath, 'utf8'));
  }

  ensureResultsDirectory() {
    if (!fs.existsSync(this.resultsDir)) {
      fs.mkdirSync(this.resultsDir, { recursive: true });
    }
  }

  async runTDDFoundationChecks() {
    console.log('\n🛡️  Running TDD Foundation Layer Checks (Priority 1 - BLOCKING)...');
    const results = {
      layer: 'tddFoundation',
      timestamp: new Date().toISOString(),
      project: this.projectName,
      checks: []
    };

    try {
      // Run enhanced TDD validation
      const tddScript = path.join(process.cwd(), 'scripts/tdd-guard-enhanced.js');
      if (!fs.existsSync(tddScript)) {
        throw new Error('TDD Guard Enhanced script not found. Create from template.');
      }

      const output = execSync(`node ${tddScript} validate`, { 
        encoding: 'utf8',
        stdio: 'pipe'
      });

      results.checks.push({
        id: 'tdd-foundation',
        status: 'pass',
        output: output
      });
    } catch (error) {
      results.checks.push({
        id: 'tdd-foundation',
        status: 'fail',
        error: error.message,
        output: error.stdout || error.message,
        severity: 'critical'
      });
    }

    return results;
  }

  async runSerenaChecks() {
    console.log('\n🔍 Running Serena Layer Checks (Priority 2)...');
    const results = {
      layer: 'serena',
      timestamp: new Date().toISOString(),
      project: this.projectName,
      checks: []
    };

    // Symbol completeness check
    try {
      const symbols = this.analyzeSymbols();
      results.checks.push({
        id: 'symbol-completeness',
        status: symbols.undocumented.length === 0 ? 'pass' : 'fail',
        details: {
          total: symbols.total,
          documented: symbols.documented.length,
          undocumented: symbols.undocumented
        }
      });
    } catch (error) {
      results.checks.push({
        id: 'symbol-completeness',
        status: 'error',
        error: error.message
      });
    }

    // Architectural integrity check
    try {
      const violations = this.checkArchitecturalBoundaries();
      results.checks.push({
        id: 'architectural-integrity',
        status: violations.length === 0 ? 'pass' : 'fail',
        violations
      });
    } catch (error) {
      results.checks.push({
        id: 'architectural-integrity',
        status: 'error',
        error: error.message
      });
    }

    return results;
  }

  async runSuperClaudeChecks() {
    console.log('\n⚡ Running SuperClaude Layer Checks (Priority 3)...');
    const results = {
      layer: 'superClaude',
      timestamp: new Date().toISOString(),
      project: this.projectName,
      checks: []
    };

    // Quality gates validation
    const gates = this.config.layers.superClaude.enforcements[0].gates;
    for (const gate of gates) {
      try {
        const passed = await this.validateQualityGate(gate);
        results.checks.push({
          gate,
          status: passed ? 'pass' : 'fail'
        });
      } catch (error) {
        results.checks.push({
          gate,
          status: 'error',
          error: error.message
        });
      }
    }

    return results;
  }

  async runTaskMasterChecks() {
    console.log('\n📋 Running Task Master Layer Checks (Priority 4)...');
    const results = {
      layer: 'claudeTaskMaster',
      timestamp: new Date().toISOString(),
      project: this.projectName,
      checks: []
    };

    // Workflow compliance
    try {
      const taskMasterScript = path.join(process.cwd(), 'scripts/task-master.js');
      if (fs.existsSync(taskMasterScript)) {
        const workflowResult = execSync(`node ${taskMasterScript} precommit`, {
          encoding: 'utf8',
          stdio: 'pipe'
        });
        results.checks.push({
          id: 'workflow-compliance',
          status: 'pass',
          output: workflowResult
        });
      } else {
        results.checks.push({
          id: 'workflow-compliance',
          status: 'skip',
          message: 'Task Master script not found'
        });
      }
    } catch (error) {
      results.checks.push({
        id: 'workflow-compliance',
        status: 'fail',
        output: error.stdout || error.message
      });
    }

    // Template sync check
    try {
      const syncStatus = this.checkTemplateSync();
      results.checks.push({
        id: 'template-sync',
        status: syncStatus.needsSync ? 'warning' : 'pass',
        details: syncStatus
      });
    } catch (error) {
      results.checks.push({
        id: 'template-sync',
        status: 'error',
        error: error.message
      });
    }

    return results;
  }

  analyzeSymbols() {
    // Simplified symbol analysis - in real implementation would use AST
    const sourceFiles = this.getFiles('{{SOURCE_DIR|src}}', /\.{{SOURCE_EXTENSION|ts}}$/);
    const symbols = {
      total: 0,
      documented: [],
      undocumented: []
    };

    sourceFiles.forEach(file => {
      const content = fs.readFileSync(file, 'utf8');
      const exportMatches = content.match(/export\s+(class|function|interface|const|type)\s+(\w+)/g) || [];
      
      exportMatches.forEach(match => {
        const symbolName = match.split(/\s+/).pop();
        symbols.total++;
        
        // Check for JSDoc
        const hasJSDoc = content.includes(`/**`) && content.includes(`${symbolName}`);
        if (hasJSDoc) {
          symbols.documented.push(symbolName);
        } else {
          symbols.undocumented.push(`${file}:${symbolName}`);
        }
      });
    });

    return symbols;
  }

  checkArchitecturalBoundaries() {
    const violations = [];
    
    // Project-specific architectural rules
    '{{ARCHITECTURE_RULES}}'.split(';').forEach(rule => {
      if (rule) {
        // Parse and check rule
        // This is a simplified example
        const [layer, restriction] = rule.split(':');
        if (layer && restriction) {
          // Check the rule
          console.log(`Checking rule: ${layer} ${restriction}`);
        }
      }
    });

    // Check service layer doesn't import from routes
    const serviceFiles = this.getFiles('{{SERVICE_DIR|src/services}}', /\.{{SOURCE_EXTENSION|ts}}$/);
    serviceFiles.forEach(file => {
      const content = fs.readFileSync(file, 'utf8');
      if (content.includes('from \'{{ROUTES_DIR|../routes}}') || 
          content.includes('from "{{ROUTES_DIR|../routes}}')) {
        violations.push({
          file,
          rule: 'Service importing from routes',
          severity: 'high'
        });
      }
    });

    return violations;
  }

  async validateQualityGate(gate) {
    // Simplified gate validation - would integrate with actual tools
    switch (gate) {
      case 'TDD Foundation validation (from layer 1)':
        // Already validated in TDD layer
        return true;
      
      case 'Lint rules compliance':
        try {
          execSync('{{LINT_COMMAND|npm run lint}}', { stdio: 'pipe' });
          return true;
        } catch {
          return false;
        }
      
      case 'Oppie-devkit sync verification':
        return this.checkOppieDevkitSync();
      
      default:
        return true; // Placeholder for other gates
    }
  }

  checkOppieDevkitSync() {
    const syncStatusFile = path.join(process.cwd(), '.claude/doc-sync-required.json');
    if (fs.existsSync(syncStatusFile)) {
      const syncStatus = JSON.parse(fs.readFileSync(syncStatusFile, 'utf8'));
      return syncStatus.files.length === 0;
    }
    return true;
  }

  checkTemplateSync() {
    const templateFiles = [
      '.claude/enforcement-layers.json',
      'scripts/tdd-guard-enhanced.js',
      'scripts/task-master.js',
      'scripts/enforcement-coordinator.js'
    ];

    const needsSync = [];
    templateFiles.forEach(file => {
      if (fs.existsSync(file)) {
        const content = fs.readFileSync(file, 'utf8');
        const lastModified = fs.statSync(file).mtime;
        
        // Check if file has been customized
        if (!content.includes('{{') || content.includes(this.projectName)) {
          needsSync.push({
            file,
            lastModified,
            reason: 'Customized for project'
          });
        }
      }
    });

    return {
      needsSync: needsSync.length > 0,
      files: needsSync,
      project: this.projectName
    };
  }

  getCoverageMetrics() {
    // Parse coverage report if exists
    const coveragePath = path.join(process.cwd(), '{{COVERAGE_PATH|coverage/coverage-summary.json}}');
    if (fs.existsSync(coveragePath)) {
      const coverage = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
      return {
        unit: coverage.total.lines.pct || 0,
        integration: coverage.total.lines.pct || 0 // Simplified
      };
    }
    return { unit: 0, integration: 0 };
  }

  getFiles(dir, pattern) {
    const files = [];
    const walk = (directory) => {
      if (!fs.existsSync(directory)) return;
      const items = fs.readdirSync(directory);
      items.forEach(item => {
        const fullPath = path.join(directory, item);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory() && !item.includes('node_modules')) {
          walk(fullPath);
        } else if (stat.isFile() && pattern.test(item)) {
          files.push(fullPath);
        }
      });
    };
    walk(dir);
    return files;
  }

  async runAllLayers() {
    console.log('🛡️  {{PROJECT_NAME}} Enforcement Coordinator');
    console.log('================================\n');

    const allResults = {
      timestamp: new Date().toISOString(),
      project: this.projectName,
      layers: {}
    };

    // Run TDD Foundation first (blocking layer)
    allResults.layers.tddFoundation = await this.runTDDFoundationChecks();
    
    // Check if TDD failed
    const tddFailed = allResults.layers.tddFoundation.checks.some(
      check => check.status === 'fail'
    );
    
    if (tddFailed) {
      console.log('\n❌ TDD Foundation checks failed!');
      console.log('⚠️  Cannot proceed to other layers until tests are written first.');
      this.generateReport(allResults);
      
      // Save results and exit
      const resultFile = path.join(
        this.resultsDir, 
        `enforcement-${Date.now()}.json`
      );
      fs.writeFileSync(resultFile, JSON.stringify(allResults, null, 2));
      
      process.exit(1);
    }

    // Run other layers only if TDD passes
    allResults.layers.serena = await this.runSerenaChecks();
    allResults.layers.superClaude = await this.runSuperClaudeChecks();
    allResults.layers.taskMaster = await this.runTaskMasterChecks();

    // Save results
    const resultFile = path.join(
      this.resultsDir, 
      `enforcement-${Date.now()}.json`
    );
    fs.writeFileSync(resultFile, JSON.stringify(allResults, null, 2));

    // Sync results to oppie-devkit
    this.syncResultsToOppieDevkit(allResults);

    // Generate report
    this.generateReport(allResults);

    // Determine overall status
    const hasFailures = this.checkForFailures(allResults);
    
    if (hasFailures) {
      console.log('\n❌ Enforcement checks failed!');
      this.handleEscalation(allResults);
      process.exit(1);
    } else {
      console.log('\n✅ All enforcement checks passed!');
      process.exit(0);
    }
  }

  checkForFailures(results) {
    for (const layer of Object.values(results.layers)) {
      for (const check of layer.checks) {
        if (check.status === 'fail' || check.status === 'error') {
          return true;
        }
      }
    }
    return false;
  }

  generateReport(results) {
    console.log('\n📊 Enforcement Report');
    console.log('Project: {{PROJECT_NAME}}');
    console.log('====================\n');

    Object.entries(results.layers).forEach(([layerName, layerResults]) => {
      console.log(`\n${this.getLayerEmoji(layerName)} ${layerName.toUpperCase()}`);
      console.log('-'.repeat(30));

      layerResults.checks.forEach(check => {
        const status = this.getStatusEmoji(check.status);
        const checkName = check.id || check.gate || 'Unknown check';
        console.log(`  ${status} ${checkName}`);
        
        if (check.status === 'fail' && check.details) {
          console.log(`     Details: ${JSON.stringify(check.details, null, 2)}`);
        }
        if (check.violations) {
          check.violations.forEach(v => {
            console.log(`     ⚠️  ${v.file}: ${v.rule}`);
          });
        }
      });
    });
  }

  getLayerEmoji(layer) {
    const emojis = {
      tddFoundation: '🛡️',
      serena: '🔍',
      superClaude: '⚡',
      taskMaster: '📋'
    };
    return emojis[layer] || '📌';
  }

  getStatusEmoji(status) {
    const emojis = {
      pass: '✅',
      fail: '❌',
      error: '🚨',
      warning: '⚠️',
      skip: '⏭️'
    };
    return emojis[status] || '❓';
  }

  handleEscalation(results) {
    const failureCount = this.countFailures(results);
    
    // TDD failures are always critical
    const tddFailed = results.layers.tddFoundation?.checks.some(
      check => check.status === 'fail'
    );
    
    const escalationLevel = tddFailed ? 0 : 
                           failureCount > 5 ? 3 : 
                           failureCount > 2 ? 2 : 1;
    
    console.log(`\n🚨 Escalation Level ${escalationLevel}`);
    const escalation = this.config.escalation.levels[escalationLevel];
    console.log(`   Action: ${escalation.action}`);

    // Generate fix suggestions
    this.generateFixSuggestions(results);
  }

  countFailures(results) {
    let count = 0;
    for (const layer of Object.values(results.layers)) {
      for (const check of layer.checks) {
        if (check.status === 'fail' || check.status === 'error') {
          count++;
        }
      }
    }
    return count;
  }

  generateFixSuggestions(results) {
    console.log('\n💡 Fix Suggestions:');
    
    // TDD layer suggestions
    const tddChecks = results.layers.tddFoundation?.checks || [];
    tddChecks.forEach(check => {
      if (check.status === 'fail') {
        console.log('\n  🛡️  TDD Foundation (MUST FIX FIRST):');
        console.log('     - Write tests before implementation');
        console.log('     - Run: node scripts/tdd-guard-enhanced.js generate <file>');
        console.log('     - Achieve coverage thresholds');
      }
    });
    
    // Serena layer suggestions
    const serenaChecks = results.layers.serena?.checks || [];
    serenaChecks.forEach(check => {
      if (check.status === 'fail') {
        if (check.id === 'symbol-completeness' && check.details?.undocumented) {
          console.log('\n  📝 Add JSDoc comments to:');
          check.details.undocumented.slice(0, 5).forEach(symbol => {
            console.log(`     - ${symbol}`);
          });
        }
        if (check.id === 'architectural-integrity' && check.violations) {
          console.log('\n  🏗️  Fix architectural violations:');
          check.violations.forEach(v => {
            console.log(`     - ${v.file}: Move logic to appropriate layer`);
          });
        }
      }
    });

    // Template sync suggestions
    const templateSyncCheck = results.layers.taskMaster?.checks.find(
      c => c.id === 'template-sync'
    );
    if (templateSyncCheck?.status === 'warning') {
      console.log('\n  📄 Sync templates to oppie-devkit:');
      templateSyncCheck.details.files.forEach(f => {
        console.log(`     - ${f.file}`);
      });
    }
  }

  syncResultsToOppieDevkit(results) {
    const syncPath = path.join(process.cwd(), '.claude/oppie-sync-queue.json');
    let syncQueue = [];
    
    if (fs.existsSync(syncPath)) {
      syncQueue = JSON.parse(fs.readFileSync(syncPath, 'utf8'));
    }
    
    syncQueue.push({
      type: 'enforcement-results',
      results,
      timestamp: new Date().toISOString(),
      project: this.projectName
    });
    
    fs.writeFileSync(syncPath, JSON.stringify(syncQueue, null, 2));
  }
}

// CLI Interface
const coordinator = new EnforcementCoordinator();
const command = process.argv[2];

switch (command) {
  case 'check':
    coordinator.runAllLayers();
    break;
  
  case 'tdd':
    coordinator.runTDDFoundationChecks().then(results => {
      coordinator.generateReport({ layers: { tddFoundation: results } });
      const failed = results.checks.some(c => c.status === 'fail');
      process.exit(failed ? 1 : 0);
    });
    break;
  
  case 'serena':
    coordinator.runSerenaChecks().then(results => {
      coordinator.generateReport({ layers: { serena: results } });
    });
    break;
  
  case 'superclaude':
    coordinator.runSuperClaudeChecks().then(results => {
      coordinator.generateReport({ layers: { superClaude: results } });
    });
    break;
  
  case 'taskmaster':
    coordinator.runTaskMasterChecks().then(results => {
      coordinator.generateReport({ layers: { taskMaster: results } });
    });
    break;

  case 'report':
    // Show latest report
    const reports = fs.readdirSync(coordinator.resultsDir)
      .filter(f => f.startsWith('enforcement-'))
      .sort()
      .reverse();
    
    if (reports.length > 0) {
      const latest = JSON.parse(
        fs.readFileSync(path.join(coordinator.resultsDir, reports[0]), 'utf8')
      );
      coordinator.generateReport(latest);
    } else {
      console.log('No enforcement reports found');
    }
    break;

  default:
    console.log('{{PROJECT_NAME}} Enforcement Coordinator');
    console.log('\nCommands:');
    console.log('  check       - Run all enforcement layers');
    console.log('  tdd         - Run TDD Foundation layer only');
    console.log('  serena      - Run Serena layer only');
    console.log('  superclaude - Run SuperClaude layer only');
    console.log('  taskmaster  - Run Task Master layer only');
    console.log('  report      - Show latest enforcement report');
    console.log('\nExamples:');
    console.log('  node scripts/enforcement-coordinator.js check');
    console.log('  node scripts/enforcement-coordinator.js tdd');
    console.log('\nTemplate variables to replace:');
    console.log('  {{PROJECT_NAME}} - Your project name');
    console.log('  {{SOURCE_DIR}} - Source directory (default: src)');
    console.log('  {{SERVICE_DIR}} - Services directory (default: src/services)');
    console.log('  {{ROUTES_DIR}} - Routes directory (default: ../routes)');
    console.log('  {{SOURCE_EXTENSION}} - File extension (default: ts)');
    console.log('  {{LINT_COMMAND}} - Lint command (default: npm run lint)');
    console.log('  {{COVERAGE_PATH}} - Coverage report path');
    console.log('  {{ARCHITECTURE_RULES}} - Custom architectural rules');
}