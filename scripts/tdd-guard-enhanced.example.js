#!/usr/bin/env node

/**
 * Enhanced TDD Guard - Foundation Layer for {{PROJECT_NAME}} Enforcement System
 * Enforces Test-Driven Development as the primary quality gate
 * 
 * This is a template - replace {{VARIABLES}} with your project-specific values
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class EnhancedTDDGuard {
  constructor() {
    this.config = this.loadConfig();
    this.enforcementLog = [];
    this.documentationSync = {
      enabled: true,
      remoteRepo: 'oppie-devkit',
      syncPaths: ['docs/', 'README.md', 'CLAUDE.md', '{{ADDITIONAL_SYNC_PATHS}}']
    };
    this.colors = {
      red: '\x1b[31m',
      green: '\x1b[32m',
      yellow: '\x1b[33m',
      blue: '\x1b[34m',
      magenta: '\x1b[35m',
      cyan: '\x1b[36m',
      reset: '\x1b[0m'
    };
  }

  loadConfig() {
    const configPath = path.join(process.cwd(), '.tdd-guard.json');
    if (!fs.existsSync(configPath)) {
      console.error('TDD Guard config not found. Create .tdd-guard.json from template');
      process.exit(1);
    }
    return JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }

  log(message, color = 'reset', indent = 0) {
    const prefix = ' '.repeat(indent);
    console.log(`${prefix}${this.colors[color]}${message}${this.colors.reset}`);
    this.enforcementLog.push({ 
      message, 
      color, 
      timestamp: new Date().toISOString(),
      project: '{{PROJECT_NAME}}'
    });
  }

  // Core TDD Enforcement
  enforceTestFirst(sourceFile) {
    const testFile = this.findTestFile(sourceFile);
    const sourceExists = fs.existsSync(sourceFile);
    const testExists = fs.existsSync(testFile);

    if (sourceExists && !testExists) {
      this.log(`❌ TDD Violation: Source exists without test: ${sourceFile}`, 'red');
      return {
        status: 'fail',
        violation: 'test-first',
        sourceFile,
        testFile,
        message: 'Test must be written before implementation',
        project: '{{PROJECT_NAME}}'
      };
    }

    if (testExists && sourceExists) {
      // Check test was created before source
      const testStat = fs.statSync(testFile);
      const sourceStat = fs.statSync(sourceFile);
      
      if (sourceStat.birthtime < testStat.birthtime) {
        this.log(`⚠️  Warning: Source might have been created before test`, 'yellow');
        return {
          status: 'warning',
          violation: 'test-timing',
          message: 'Test should be created before source file'
        };
      }
    }

    return { status: 'pass' };
  }

  // Test Quality Enforcement
  enforceTestQuality(testFile) {
    if (!fs.existsSync(testFile)) {
      return { status: 'skip', reason: 'Test file not found' };
    }

    const content = fs.readFileSync(testFile, 'utf8');
    const violations = [];

    // Check for proper test structure
    if (!content.includes('describe(')) {
      violations.push('Missing describe blocks');
    }

    if (!content.includes('it(') && !content.includes('test(')) {
      violations.push('Missing test cases');
    }

    // Check for assertions
    if (!content.includes('expect(')) {
      violations.push('Missing assertions');
    }

    // Check for test coverage directives
    if (content.includes('istanbul ignore')) {
      violations.push('Coverage ignore directives found');
    }

    // Check for skipped tests
    if (content.includes('.skip') || content.includes('xit(') || content.includes('xdescribe(')) {
      violations.push('Skipped tests found');
    }

    // Project-specific checks
    '{{CUSTOM_TEST_QUALITY_CHECKS}}'.split(',').forEach(check => {
      if (check && !content.includes(check)) {
        violations.push(`Missing required: ${check}`);
      }
    });

    return {
      status: violations.length === 0 ? 'pass' : 'fail',
      violations,
      testFile,
      project: '{{PROJECT_NAME}}'
    };
  }

  // Coverage Enforcement
  async enforceCoverage(targetFile = null) {
    try {
      const command = targetFile 
        ? `npx jest --coverage --collectCoverageFrom="${targetFile}" --testPathPattern="${this.findTestFile(targetFile)}"`
        : '{{COVERAGE_COMMAND|npm run test:coverage}}';
      
      execSync(command, { stdio: 'pipe' });
      
      // Parse coverage report
      const coveragePath = path.join(process.cwd(), '{{COVERAGE_REPORT_PATH|coverage/coverage-summary.json}}');
      if (fs.existsSync(coveragePath)) {
        const coverage = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
        const metrics = coverage.total;
        
        const violations = [];
        Object.entries(this.config.coverageThresholds).forEach(([metric, threshold]) => {
          if (metrics[metric].pct < threshold) {
            violations.push(`${metric}: ${metrics[metric].pct}% < ${threshold}%`);
          }
        });

        return {
          status: violations.length === 0 ? 'pass' : 'fail',
          coverage: metrics,
          violations,
          project: '{{PROJECT_NAME}}'
        };
      }
    } catch (error) {
      return {
        status: 'fail',
        error: error.message
      };
    }
  }

  // Documentation Sync Enforcement
  async enforceDocumentationSync() {
    this.log('\n📚 Checking Documentation Sync...', 'cyan');
    
    const violations = [];
    const syncedFiles = [];

    // Check if oppie-devkit docs need updating
    for (const docPath of this.documentationSync.syncPaths) {
      const localPath = path.join(process.cwd(), docPath);
      
      if (fs.existsSync(localPath)) {
        const localContent = fs.readFileSync(localPath, 'utf8');
        const lastModified = fs.statSync(localPath).mtime;
        
        // Check if doc mentions project-specific changes
        if (localContent.includes('{{PROJECT_NAME}}')) {
          syncedFiles.push({
            path: docPath,
            lastModified,
            requiresSync: true
          });
          
          // Create sync requirement file
          const syncReqPath = path.join(process.cwd(), '.claude/doc-sync-required.json');
          const syncReq = fs.existsSync(syncReqPath) 
            ? JSON.parse(fs.readFileSync(syncReqPath, 'utf8'))
            : { files: [] };
          
          if (!syncReq.files.find(f => f.path === docPath)) {
            syncReq.files.push({
              path: docPath,
              lastModified,
              projectSpecific: true,
              syncTo: 'oppie-devkit',
              project: '{{PROJECT_NAME}}'
            });
          }
          
          fs.writeFileSync(syncReqPath, JSON.stringify(syncReq, null, 2));
        }
      }
    }

    return {
      status: syncedFiles.length > 0 ? 'warning' : 'pass',
      syncRequired: syncedFiles,
      message: syncedFiles.length > 0 
        ? `${syncedFiles.length} documentation files need syncing to oppie-devkit`
        : 'Documentation sync not required',
      project: '{{PROJECT_NAME}}'
    };
  }

  // Test-Code Relationship Enforcement
  enforceTestCodeRelationship(sourceFile) {
    const testFile = this.findTestFile(sourceFile);
    
    if (!fs.existsSync(sourceFile) || !fs.existsSync(testFile)) {
      return { status: 'skip' };
    }

    const sourceContent = fs.readFileSync(sourceFile, 'utf8');
    const testContent = fs.readFileSync(testFile, 'utf8');

    // Extract exported functions/classes from source
    const exports = this.extractExports(sourceContent);
    const testedItems = this.extractTestedItems(testContent);

    const untestedExports = exports.filter(exp => !testedItems.includes(exp));

    return {
      status: untestedExports.length === 0 ? 'pass' : 'fail',
      exports: exports.length,
      tested: testedItems.length,
      untested: untestedExports,
      project: '{{PROJECT_NAME}}'
    };
  }

  extractExports(content) {
    const exports = [];
    const patterns = [
      /export\s+(?:async\s+)?function\s+(\w+)/g,
      /export\s+class\s+(\w+)/g,
      /export\s+const\s+(\w+)/g,
      /export\s+{\s*([^}]+)\s*}/g
    ];

    patterns.forEach(pattern => {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        if (match[1]) {
          // Handle multiple exports in braces
          if (match[1].includes(',')) {
            match[1].split(',').forEach(exp => {
              exports.push(exp.trim());
            });
          } else {
            exports.push(match[1]);
          }
        }
      }
    });

    return [...new Set(exports)];
  }

  extractTestedItems(content) {
    const tested = [];
    const patterns = [
      /describe\(['"`](\w+)/g,
      /it\(['"`].*?(\w+).*?['"`]/g,
      /test\(['"`].*?(\w+).*?['"`]/g
    ];

    patterns.forEach(pattern => {
      let match;
      while ((match = pattern.exec(content)) !== null) {
        if (match[1]) {
          tested.push(match[1]);
        }
      }
    });

    return [...new Set(tested)];
  }

  // Comprehensive Project Validation
  async validateProject() {
    this.log('🛡️  Enhanced TDD Guard - Foundation Layer Validation', 'magenta');
    this.log('Project: {{PROJECT_NAME}}', 'magenta');
    this.log('=' .repeat(60), 'magenta');
    
    const results = {
      timestamp: new Date().toISOString(),
      layer: 'TDD-Foundation',
      project: '{{PROJECT_NAME}}',
      checks: []
    };

    // 1. Test-First Compliance
    this.log('\n1️⃣  Test-First Compliance Check', 'blue');
    const sourceFiles = this.getFiles('{{SOURCE_DIR|src}}', /\.{{SOURCE_EXTENSION|ts}}$/);
    let testFirstViolations = 0;
    
    sourceFiles.forEach(file => {
      const result = this.enforceTestFirst(file);
      if (result.status === 'fail') {
        testFirstViolations++;
        this.log(`   ${result.sourceFile}`, 'red', 3);
      }
    });

    results.checks.push({
      name: 'Test-First Compliance',
      status: testFirstViolations === 0 ? 'pass' : 'fail',
      violations: testFirstViolations,
      total: sourceFiles.length
    });

    // 2. Test Quality Check
    this.log('\n2️⃣  Test Quality Check', 'blue');
    const testFiles = this.getFiles('{{TEST_DIR|tests}}', /\.test\.{{TEST_EXTENSION|ts}}$/);
    let qualityViolations = 0;
    
    testFiles.forEach(file => {
      const result = this.enforceTestQuality(file);
      if (result.status === 'fail') {
        qualityViolations++;
        this.log(`   ${file}: ${result.violations.join(', ')}`, 'red', 3);
      }
    });

    results.checks.push({
      name: 'Test Quality',
      status: qualityViolations === 0 ? 'pass' : 'fail',
      violations: qualityViolations,
      total: testFiles.length
    });

    // 3. Coverage Enforcement
    this.log('\n3️⃣  Coverage Enforcement', 'blue');
    const coverageResult = await this.enforceCoverage();
    
    if (coverageResult.status === 'fail' && coverageResult.violations) {
      coverageResult.violations.forEach(v => {
        this.log(`   ${v}`, 'red', 3);
      });
    } else if (coverageResult.status === 'pass') {
      this.log('   All coverage thresholds met!', 'green', 3);
    }

    results.checks.push({
      name: 'Coverage Thresholds',
      status: coverageResult.status,
      details: coverageResult
    });

    // 4. Test-Code Relationship
    this.log('\n4️⃣  Test-Code Relationship Check', 'blue');
    let relationshipViolations = 0;
    
    sourceFiles.forEach(file => {
      const result = this.enforceTestCodeRelationship(file);
      if (result.status === 'fail') {
        relationshipViolations++;
        this.log(`   ${file}: ${result.untested.length} untested exports`, 'red', 3);
      }
    });

    results.checks.push({
      name: 'Test-Code Relationship',
      status: relationshipViolations === 0 ? 'pass' : 'fail',
      violations: relationshipViolations
    });

    // 5. Documentation Sync Check
    this.log('\n5️⃣  Documentation Sync Check', 'blue');
    const docResult = await this.enforceDocumentationSync();
    
    if (docResult.syncRequired.length > 0) {
      this.log(`   ${docResult.message}`, 'yellow', 3);
      docResult.syncRequired.forEach(doc => {
        this.log(`   - ${doc.path}`, 'yellow', 5);
      });
    } else {
      this.log('   Documentation sync up to date', 'green', 3);
    }

    results.checks.push({
      name: 'Documentation Sync',
      status: docResult.status,
      details: docResult
    });

    // Generate Summary
    this.log('\n📊 Summary', 'cyan');
    const totalChecks = results.checks.length;
    const passedChecks = results.checks.filter(c => c.status === 'pass').length;
    const failedChecks = results.checks.filter(c => c.status === 'fail').length;
    
    this.log(`   Total Checks: ${totalChecks}`, 'cyan', 3);
    this.log(`   Passed: ${passedChecks}`, 'green', 3);
    this.log(`   Failed: ${failedChecks}`, 'red', 3);
    
    // Save results
    const resultsDir = path.join(process.cwd(), '.claude/tdd-enforcement');
    if (!fs.existsSync(resultsDir)) {
      fs.mkdirSync(resultsDir, { recursive: true });
    }
    
    const resultFile = path.join(resultsDir, `tdd-${Date.now()}.json`);
    fs.writeFileSync(resultFile, JSON.stringify(results, null, 2));
    
    // Sync results to oppie-devkit
    this.syncResultsToOppieDevkit(results);
    
    // Overall status
    const overallPass = failedChecks === 0;
    this.log(
      `\n${overallPass ? '✅' : '❌'} TDD Foundation Layer: ${overallPass ? 'PASSED' : 'FAILED'}`,
      overallPass ? 'green' : 'red'
    );
    
    return {
      pass: overallPass,
      results
    };
  }

  syncResultsToOppieDevkit(results) {
    const syncPath = path.join(process.cwd(), '.claude/oppie-sync-queue.json');
    let syncQueue = [];
    
    if (fs.existsSync(syncPath)) {
      syncQueue = JSON.parse(fs.readFileSync(syncPath, 'utf8'));
    }
    
    syncQueue.push({
      type: 'tdd-results',
      results,
      timestamp: new Date().toISOString(),
      project: '{{PROJECT_NAME}}'
    });
    
    fs.writeFileSync(syncPath, JSON.stringify(syncQueue, null, 2));
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

  findTestFile(sourceFile) {
    const relativePath = path.relative('{{SOURCE_DIR|src}}', sourceFile);
    const testPath = path.join('{{TEST_DIR|tests/unit}}', relativePath.replace(/\.{{SOURCE_EXTENSION|ts}}$/, '.test.{{TEST_EXTENSION|ts}}'));
    return testPath;
  }

  // Watch mode with enforcement
  watchWithEnforcement() {
    this.log('👁️  Starting Enhanced TDD Watch Mode...', 'green');
    this.log('Project: {{PROJECT_NAME}}', 'green');
    
    const chokidar = require('chokidar');
    
    const watcher = chokidar.watch([
      '{{SOURCE_DIR|src}}/**/*.{{SOURCE_EXTENSION|ts}}',
      '{{TEST_DIR|tests}}/**/*.test.{{TEST_EXTENSION|ts}}'
    ], {
      ignored: /node_modules/,
      persistent: true,
      ignoreInitial: true
    });

    watcher.on('change', async (filePath) => {
      console.clear();
      this.log(`\n📝 File changed: ${filePath}`, 'yellow');
      this.log(`Project: {{PROJECT_NAME}}`, 'yellow');
      
      if (filePath.includes('.test.')) {
        // Test file changed
        const result = this.enforceTestQuality(filePath);
        if (result.status === 'fail') {
          this.log('❌ Test quality issues:', 'red');
          result.violations.forEach(v => this.log(`   - ${v}`, 'red', 3));
        }
        
        // Run the test
        try {
          execSync(`{{TEST_RUNNER|npx jest}} ${filePath}`, { stdio: 'inherit' });
        } catch (error) {
          this.log('❌ Test failed!', 'red');
        }
      } else {
        // Source file changed
        const testFirstResult = this.enforceTestFirst(filePath);
        if (testFirstResult.status === 'fail') {
          this.log(`❌ ${testFirstResult.message}`, 'red');
          this.log(`   Expected test at: ${testFirstResult.testFile}`, 'yellow', 3);
        }
        
        const testFile = this.findTestFile(filePath);
        if (fs.existsSync(testFile)) {
          // Run coverage for this file
          const coverageResult = await this.enforceCoverage(filePath);
          if (coverageResult.status === 'fail') {
            this.log('❌ Coverage below thresholds:', 'red');
            coverageResult.violations?.forEach(v => this.log(`   - ${v}`, 'red', 3));
          }
        }
      }
      
      // Check documentation sync
      await this.enforceDocumentationSync();
    });

    this.log('Watching for file changes... (Press Ctrl+C to stop)', 'blue');
  }

  // Generate test template
  generateTestTemplate(sourceFile) {
    const testFile = this.findTestFile(sourceFile);
    const testDir = path.dirname(testFile);
    
    if (!fs.existsSync(testDir)) {
      fs.mkdirSync(testDir, { recursive: true });
    }

    const className = path.basename(sourceFile, '.{{SOURCE_EXTENSION|ts}}');
    const importPath = path.relative(
      path.dirname(testFile), 
      sourceFile.replace(/\.{{SOURCE_EXTENSION|ts}}$/, '')
    ).replace(/\\/g, '/');
    
    const template = `import { ${className} } from '${importPath}';

/**
 * Tests for ${className}
 * Project: {{PROJECT_NAME}}
 * 
 * TDD: Write these tests BEFORE implementing ${className}
 */
describe('${className}', () => {
  describe('initialization', () => {
    it('should create an instance', () => {
      // Write your test first!
      // This should fail until you implement ${className}
      expect(true).toBe(false);
    });
  });

  describe('{{FEATURE_1}}', () => {
    it('should {{EXPECTED_BEHAVIOR_1}}', () => {
      // Test first, then implement
      expect(true).toBe(false);
    });
  });

  describe('error handling', () => {
    it('should handle invalid input gracefully', () => {
      // Always test error cases
      expect(true).toBe(false);
    });
  });

  // Add more test cases here
  // Remember: Test-Driven Development means tests come first!
});
`;

    fs.writeFileSync(testFile, template);
    this.log(`Generated test template: ${testFile}`, 'green');
    this.log('Remember: Write tests BEFORE implementation!', 'yellow');
    
    // Sync template creation to oppie-devkit
    if (this.config.syncToOppieDevkit) {
      this.syncResultsToOppieDevkit({
        action: 'test-template-created',
        file: testFile,
        project: '{{PROJECT_NAME}}'
      });
    }
  }
}

// CLI Interface
const guard = new EnhancedTDDGuard();
const command = process.argv[2];

switch (command) {
  case 'validate':
    guard.validateProject().then(result => {
      process.exit(result.pass ? 0 : 1);
    });
    break;

  case 'watch':
    guard.watchWithEnforcement();
    break;

  case 'test-first':
    const sourceFile = process.argv[3];
    if (!sourceFile) {
      guard.log('Usage: tdd-guard test-first <source-file>', 'red');
      process.exit(1);
    }
    const result = guard.enforceTestFirst(sourceFile);
    if (result.status === 'fail') {
      guard.log(result.message, 'red');
      guard.log(`Create test at: ${result.testFile}`, 'yellow');
      process.exit(1);
    }
    break;

  case 'generate':
    const targetFile = process.argv[3];
    if (!targetFile) {
      guard.log('Usage: tdd-guard generate <source-file>', 'red');
      process.exit(1);
    }
    guard.generateTestTemplate(targetFile);
    break;

  case 'coverage':
    guard.enforceCoverage().then(result => {
      process.exit(result.status === 'pass' ? 0 : 1);
    });
    break;

  case 'sync-docs':
    guard.enforceDocumentationSync().then(result => {
      if (result.syncRequired.length > 0) {
        guard.log('Documentation files requiring sync:', 'yellow');
        result.syncRequired.forEach(doc => {
          guard.log(`  - ${doc.path}`, 'yellow');
        });
      }
      process.exit(0);
    });
    break;

  default:
    guard.log('🛡️  Enhanced TDD Guard - Foundation Layer', 'magenta');
    guard.log('Project: {{PROJECT_NAME}}', 'magenta');
    guard.log('\nCommands:', 'blue');
    guard.log('  validate     - Full TDD validation (foundation layer)');
    guard.log('  watch        - Enhanced watch mode with enforcement');
    guard.log('  test-first   - Check test-first compliance for a file');
    guard.log('  generate     - Generate test template for a source file');
    guard.log('  coverage     - Run coverage enforcement');
    guard.log('  sync-docs    - Check documentation sync requirements');
    guard.log('\nExamples:', 'yellow');
    guard.log('  node scripts/tdd-guard-enhanced.js validate');
    guard.log('  node scripts/tdd-guard-enhanced.js watch');
    guard.log('  node scripts/tdd-guard-enhanced.js test-first src/services/MyService.ts');
    guard.log('\nTemplate variables to replace:', 'cyan');
    guard.log('  {{PROJECT_NAME}} - Your project name');
    guard.log('  {{SOURCE_DIR}} - Source directory (default: src)');
    guard.log('  {{TEST_DIR}} - Test directory (default: tests)');
    guard.log('  {{SOURCE_EXTENSION}} - Source file extension (default: ts)');
    guard.log('  {{TEST_EXTENSION}} - Test file extension (default: ts)');
    guard.log('  See more variables in the source code...');
}