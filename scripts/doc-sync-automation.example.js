#!/usr/bin/env node

/**
 * Documentation Sync Automation for {{PROJECT_NAME}} Project
 * Automatically syncs documentation changes to oppie-devkit repository
 * 
 * This is a template - replace {{VARIABLES}} with your project-specific values
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');

class DocumentationSyncAutomation {
  constructor() {
    this.projectName = '{{PROJECT_NAME}}';
    this.config = {
      sourceRepo: '{{PROJECT_NAME}}',
      targetRepo: 'oppie-devkit',
      syncPaths: [
        { source: 'README.md', target: 'projects/{{PROJECT_NAME}}/README.md' },
        { source: 'CLAUDE.md', target: 'projects/{{PROJECT_NAME}}/CLAUDE.md' },
        { source: 'docs/', target: 'projects/{{PROJECT_NAME}}/docs/' },
        { source: '.claude/', target: 'knowledge/{{PROJECT_NAME}}-enforcement/' },
        { source: 'API.md', target: 'projects/{{PROJECT_NAME}}/API.md' },
        '{{ADDITIONAL_SYNC_PATHS}}'
      ],
      excludePatterns: [
        '*.log',
        '*.tmp',
        'node_modules',
        '.git',
        'enforcement-results',
        '{{ADDITIONAL_EXCLUDE_PATTERNS}}'
      ],
      templateSync: {
        enabled: true,
        paths: [
          { source: '.claude/', target: '.claude.template/' },
          { source: 'scripts/', target: 'scripts/', suffix: '.example.js' },
          { source: '.tdd-guard.json', target: '.tdd-guard.template.json' },
          { source: '.serena-config.json', target: '.serena-config.template.json' }
        ]
      }
    };
    this.syncLogPath = path.join(process.cwd(), '.claude/doc-sync-log.json');
  }

  log(message, type = 'info') {
    const prefix = {
      info: '📘',
      success: '✅',
      warning: '⚠️',
      error: '❌'
    };
    console.log(`${prefix[type]} ${message}`);
  }

  loadSyncLog() {
    if (fs.existsSync(this.syncLogPath)) {
      return JSON.parse(fs.readFileSync(this.syncLogPath, 'utf8'));
    }
    return { syncs: [], lastSync: null, project: this.projectName };
  }

  saveSyncLog(log) {
    const dir = path.dirname(this.syncLogPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(this.syncLogPath, JSON.stringify(log, null, 2));
  }

  calculateFileHash(filePath) {
    if (!fs.existsSync(filePath)) {
      return null;
    }
    const content = fs.readFileSync(filePath);
    return crypto.createHash('sha256').update(content).digest('hex');
  }

  detectChanges() {
    const changes = [];
    const syncLog = this.loadSyncLog();
    const lastSyncHashes = syncLog.lastSync?.hashes || {};

    // Check documentation changes
    for (const syncPath of this.config.syncPaths) {
      if (typeof syncPath === 'string') continue; // Skip placeholder
      
      const sourcePath = path.join(process.cwd(), syncPath.source);
      
      if (fs.existsSync(sourcePath)) {
        if (fs.statSync(sourcePath).isDirectory()) {
          // Handle directory sync
          const files = this.getFilesRecursive(sourcePath);
          files.forEach(file => {
            const relativePath = path.relative(sourcePath, file);
            const fullPath = path.join(syncPath.source, relativePath);
            const currentHash = this.calculateFileHash(file);
            const lastHash = lastSyncHashes[fullPath];
            
            if (currentHash !== lastHash) {
              changes.push({
                source: fullPath,
                target: path.join(syncPath.target, relativePath),
                type: lastHash ? 'modified' : 'added',
                hash: currentHash,
                category: 'documentation'
              });
            }
          });
        } else {
          // Handle file sync
          const currentHash = this.calculateFileHash(sourcePath);
          const lastHash = lastSyncHashes[syncPath.source];
          
          if (currentHash !== lastHash) {
            changes.push({
              source: syncPath.source,
              target: syncPath.target,
              type: lastHash ? 'modified' : 'added',
              hash: currentHash,
              category: 'documentation'
            });
          }
        }
      }
    }

    // Check template changes
    if (this.config.templateSync.enabled) {
      this.detectTemplateChanges(changes, lastSyncHashes);
    }

    return changes;
  }

  detectTemplateChanges(changes, lastSyncHashes) {
    for (const templatePath of this.config.templateSync.paths) {
      const sourcePath = path.join(process.cwd(), templatePath.source);
      
      if (fs.existsSync(sourcePath)) {
        if (fs.statSync(sourcePath).isDirectory()) {
          const files = this.getFilesRecursive(sourcePath);
          files.forEach(file => {
            const relativePath = path.relative(sourcePath, file);
            const currentHash = this.calculateFileHash(file);
            const templateKey = `template:${templatePath.source}/${relativePath}`;
            const lastHash = lastSyncHashes[templateKey];
            
            if (currentHash !== lastHash) {
              const targetName = templatePath.suffix 
                ? relativePath.replace(/\.(js|ts)$/, templatePath.suffix)
                : relativePath + '.template';
                
              changes.push({
                source: path.join(templatePath.source, relativePath),
                target: path.join(templatePath.target, targetName),
                type: lastHash ? 'modified' : 'added',
                hash: currentHash,
                category: 'template',
                transform: 'templatize'
              });
            }
          });
        } else {
          // Single file template
          const currentHash = this.calculateFileHash(sourcePath);
          const templateKey = `template:${templatePath.source}`;
          const lastHash = lastSyncHashes[templateKey];
          
          if (currentHash !== lastHash) {
            changes.push({
              source: templatePath.source,
              target: templatePath.target,
              type: lastHash ? 'modified' : 'added',
              hash: currentHash,
              category: 'template',
              transform: 'templatize'
            });
          }
        }
      }
    }
  }

  getFilesRecursive(dir, files = []) {
    const items = fs.readdirSync(dir);
    
    items.forEach(item => {
      const fullPath = path.join(dir, item);
      const stat = fs.statSync(fullPath);
      
      // Check if should be excluded
      const shouldExclude = this.config.excludePatterns.some(pattern => {
        if (typeof pattern === 'string' && pattern !== '{{ADDITIONAL_EXCLUDE_PATTERNS}}') {
          if (pattern.includes('*')) {
            return item.match(new RegExp(pattern.replace('*', '.*')));
          }
          return item === pattern;
        }
        return false;
      });
      
      if (!shouldExclude) {
        if (stat.isDirectory()) {
          this.getFilesRecursive(fullPath, files);
        } else {
          files.push(fullPath);
        }
      }
    });
    
    return files;
  }

  templatizeFile(content) {
    // Replace project-specific values with template variables
    let templated = content;
    
    // Replace project name
    templated = templated.replace(new RegExp(this.projectName, 'g'), '{{PROJECT_NAME}}');
    
    // Replace common paths
    templated = templated.replace(/src\//g, '{{SOURCE_DIR|src}}/');
    templated = templated.replace(/tests?\//g, '{{TEST_DIR|tests}}/');
    templated = templated.replace(/dist\//g, '{{BUILD_DIR|dist}}/');
    
    // Replace common values
    templated = templated.replace(/80(%|\s)/g, '{{COVERAGE_THRESHOLD|80}}$1');
    templated = templated.replace(/npm test/g, '{{TEST_COMMAND|npm test}}');
    templated = templated.replace(/npm run/g, '{{RUN_COMMAND|npm run}}');
    
    // Add template header if it's a script
    if (content.includes('#!/usr/bin/env node')) {
      const header = `/**
 * This is a template file for {{PROJECT_NAME}}
 * Replace all {{VARIABLE}} placeholders with your project-specific values
 */

`;
      templated = templated.replace(/(#!.*\n)/, '$1\n' + header);
    }
    
    return templated;
  }

  generateSyncReport(changes) {
    const report = {
      timestamp: new Date().toISOString(),
      project: this.projectName,
      totalChanges: changes.length,
      changes: changes.map(change => ({
        ...change,
        source: change.source,
        target: change.target,
        action: change.type,
        category: change.category
      })),
      estimatedImpact: this.assessImpact(changes)
    };

    return report;
  }

  assessImpact(changes) {
    let impact = 'low';
    
    // High impact files
    const highImpactFiles = ['README.md', 'CLAUDE.md', 'API.md', 'enforcement-layers.json'];
    const hasHighImpact = changes.some(change => 
      highImpactFiles.some(file => change.source.includes(file))
    );
    
    const templateChanges = changes.filter(c => c.category === 'template').length;
    
    if (hasHighImpact || templateChanges > 3) {
      impact = 'high';
    } else if (changes.length > 5 || templateChanges > 0) {
      impact = 'medium';
    }
    
    return {
      level: impact,
      affectedAreas: this.categorizeChanges(changes)
    };
  }

  categorizeChanges(changes) {
    const categories = {
      core: [],
      documentation: [],
      enforcement: [],
      configuration: [],
      templates: []
    };

    changes.forEach(change => {
      if (change.category === 'template') {
        categories.templates.push(change.source);
      } else if (change.source.includes('.claude/')) {
        categories.enforcement.push(change.source);
      } else if (change.source.includes('docs/') || change.source.endsWith('.md')) {
        categories.documentation.push(change.source);
      } else if (change.source.endsWith('.json')) {
        categories.configuration.push(change.source);
      } else {
        categories.core.push(change.source);
      }
    });

    return categories;
  }

  createSyncPR(changes, report) {
    this.log('Creating sync PR for oppie-devkit...', 'info');
    
    try {
      // Create a sync branch
      const branchName = `${this.projectName}-sync-${Date.now()}`;
      const prTitle = `[Auto] Sync ${this.projectName} documentation and templates - ${changes.length} changes`;
      
      const prBody = `## 🔄 Automated Sync from ${this.projectName}

This PR automatically syncs documentation and templates from the ${this.projectName} repository.

### 📊 Summary
- **Total Changes**: ${changes.length}
- **Documentation Changes**: ${changes.filter(c => c.category === 'documentation').length}
- **Template Changes**: ${changes.filter(c => c.category === 'template').length}
- **Impact Level**: ${report.estimatedImpact.level}
- **Timestamp**: ${report.timestamp}

### 📝 Changed Files
${changes.map(change => `- \`${change.source}\` → \`${change.target}\` (${change.type}) [${change.category}]`).join('\n')}

### 🎯 Affected Areas
${Object.entries(report.estimatedImpact.affectedAreas)
  .filter(([_, files]) => files.length > 0)
  .map(([area, files]) => `- **${area}**: ${files.length} files`)
  .join('\n')}

### 📋 Template Updates
${changes.filter(c => c.category === 'template').length > 0 ? 
  'This PR includes template updates that may be used by other projects.' : 
  'No template updates in this PR.'}

### 🤖 Automated by ${this.projectName} Documentation Sync
This PR was automatically generated. Please review the changes before merging.

---
*Project: ${this.projectName}*
*Generated at: ${new Date().toISOString()}*`;

      // Save PR info for manual creation
      const prInfoPath = path.join(process.cwd(), '.claude/pending-sync-pr.json');
      fs.writeFileSync(prInfoPath, JSON.stringify({
        branch: branchName,
        title: prTitle,
        body: prBody,
        changes,
        report,
        project: this.projectName
      }, null, 2));

      this.log(`PR info saved to: ${prInfoPath}`, 'success');
      this.log('To create the PR:', 'info');
      this.log(`  1. Copy changed files to oppie-devkit repo`, 'info');
      this.log(`  2. Process templates if needed`, 'info');
      this.log(`  3. Create branch: ${branchName}`, 'info');
      this.log(`  4. Commit with message: "${prTitle}"`, 'info');
      this.log(`  5. Create PR with the generated body`, 'info');

      return {
        success: true,
        prInfo: { branch: branchName, title: prTitle }
      };
    } catch (error) {
      this.log(`Failed to prepare PR: ${error.message}`, 'error');
      return { success: false, error: error.message };
    }
  }

  async performSync(dryRun = false) {
    this.log(`🔍 Detecting ${this.projectName} documentation changes...`, 'info');
    
    const changes = this.detectChanges();
    
    if (changes.length === 0) {
      this.log('No documentation or template changes detected', 'success');
      return;
    }

    this.log(`Found ${changes.length} changes to sync`, 'warning');
    
    const report = this.generateSyncReport(changes);
    
    // Display changes
    console.log('\n📋 Changes to sync:');
    changes.forEach(change => {
      const icon = change.category === 'template' ? '🔧' : 
                   change.type === 'added' ? '➕' : '📝';
      console.log(`  ${icon} ${change.source} → ${change.target} [${change.category}]`);
    });

    if (dryRun) {
      this.log('\nDry run mode - no actual sync performed', 'info');
      return;
    }

    // Create sync PR
    const prResult = this.createSyncPR(changes, report);
    
    if (prResult.success) {
      // Update sync log
      const syncLog = this.loadSyncLog();
      const hashes = {};
      
      changes.forEach(change => {
        const key = change.category === 'template' 
          ? `template:${change.source}` 
          : change.source;
        hashes[key] = change.hash;
      });
      
      syncLog.syncs.push({
        timestamp: report.timestamp,
        changes: changes.length,
        pr: prResult.prInfo,
        project: this.projectName
      });
      
      syncLog.lastSync = {
        timestamp: report.timestamp,
        hashes
      };
      
      this.saveSyncLog(syncLog);
      this.log('Sync log updated', 'success');
    }
  }

  checkSyncStatus() {
    const syncLog = this.loadSyncLog();
    const pendingChanges = this.detectChanges();
    
    console.log(`\n📊 ${this.projectName} Documentation Sync Status`);
    console.log('═══════════════════════════════════════\n');
    
    if (syncLog.lastSync) {
      console.log(`Last sync: ${new Date(syncLog.lastSync.timestamp).toLocaleString()}`);
      console.log(`Total syncs performed: ${syncLog.syncs.length}`);
    } else {
      console.log('No previous syncs recorded');
    }
    
    console.log(`\nPending changes: ${pendingChanges.length}`);
    
    if (pendingChanges.length > 0) {
      console.log('\nFiles requiring sync:');
      
      const docChanges = pendingChanges.filter(c => c.category === 'documentation');
      const templateChanges = pendingChanges.filter(c => c.category === 'template');
      
      if (docChanges.length > 0) {
        console.log('\n  Documentation:');
        docChanges.forEach(change => {
          console.log(`    - ${change.source} (${change.type})`);
        });
      }
      
      if (templateChanges.length > 0) {
        console.log('\n  Templates:');
        templateChanges.forEach(change => {
          console.log(`    - ${change.source} (${change.type})`);
        });
      }
    }

    // Check for pending PR
    const prInfoPath = path.join(process.cwd(), '.claude/pending-sync-pr.json');
    if (fs.existsSync(prInfoPath)) {
      const prInfo = JSON.parse(fs.readFileSync(prInfoPath, 'utf8'));
      console.log('\n⚠️  Pending PR creation:');
      console.log(`  Branch: ${prInfo.branch}`);
      console.log(`  Title: ${prInfo.title}`);
      console.log(`  Project: ${prInfo.project}`);
    }
  }

  generateSyncScript(changes) {
    const scriptPath = path.join(process.cwd(), '.claude/sync-to-oppie.sh');
    
    const script = `#!/bin/bash
# Auto-generated sync script for ${this.projectName} to oppie-devkit
# Generated at: ${new Date().toISOString()}

set -e

echo "🔄 Syncing ${this.projectName} documentation and templates to oppie-devkit..."

# Check if oppie-devkit path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <path-to-oppie-devkit>"
  exit 1
fi

OPPIE_PATH="$1"
PROJECT_PATH="$(pwd)"
PROJECT_NAME="${this.projectName}"

# Verify oppie-devkit exists
if [ ! -d "$OPPIE_PATH" ]; then
  echo "❌ oppie-devkit not found at: $OPPIE_PATH"
  exit 1
fi

echo "📁 Source: $PROJECT_PATH ($PROJECT_NAME)"
echo "📁 Target: $OPPIE_PATH"

# Create directories if needed
${changes.map(change => {
  const targetDir = path.dirname(change.target);
  return `mkdir -p "$OPPIE_PATH/${targetDir}"`;
}).filter((v, i, a) => a.indexOf(v) === i).join('\n')}

# Copy and process files
${changes.map(change => {
  if (change.category === 'template' && change.transform === 'templatize') {
    return `echo "  Processing template ${change.source}..."
# Templatize the file
node -e "
const fs = require('fs');
const content = fs.readFileSync('$PROJECT_PATH/${change.source}', 'utf8');
let templated = content.replace(/${this.projectName}/g, '{{PROJECT_NAME}}');
// Add more templatization logic here
fs.writeFileSync('$OPPIE_PATH/${change.target}', templated);
"`;
  } else {
    return `echo "  Copying ${change.source}..."
cp "$PROJECT_PATH/${change.source}" "$OPPIE_PATH/${change.target}"`;
  }
}).join('\n\n')}

echo "✅ Sync complete! ${changes.length} files processed."
echo ""
echo "Next steps:"
echo "  1. cd $OPPIE_PATH"
echo "  2. git checkout -b ${this.projectName}-sync-${Date.now()}"
echo "  3. git add -A"
echo "  4. git commit -m '[Auto] Sync ${this.projectName} documentation and templates - ${changes.length} changes'"
echo "  5. git push and create PR"
`;

    fs.writeFileSync(scriptPath, script);
    fs.chmodSync(scriptPath, '755');
    
    this.log(`Sync script generated: ${scriptPath}`, 'success');
    this.log(`Run: ${scriptPath} <path-to-oppie-devkit>`, 'info');
  }
}

// CLI Interface
const sync = new DocumentationSyncAutomation();
const command = process.argv[2];

switch (command) {
  case 'check':
    sync.checkSyncStatus();
    break;
    
  case 'sync':
    const dryRun = process.argv.includes('--dry-run');
    sync.performSync(dryRun);
    break;
    
  case 'generate':
    const changes = sync.detectChanges();
    if (changes.length > 0) {
      sync.generateSyncScript(changes);
    } else {
      sync.log('No changes to sync', 'info');
    }
    break;
    
  default:
    console.log(`📚 ${sync.projectName} Documentation Sync Automation`);
    console.log('\nCommands:');
    console.log('  check     - Check sync status and pending changes');
    console.log('  sync      - Perform documentation and template sync (use --dry-run for preview)');
    console.log('  generate  - Generate sync script for manual execution');
    console.log('\nExamples:');
    console.log('  node scripts/doc-sync-automation.js check');
    console.log('  node scripts/doc-sync-automation.js sync --dry-run');
    console.log('  node scripts/doc-sync-automation.js generate');
    console.log('\nTemplate variables to replace:');
    console.log('  {{PROJECT_NAME}} - Your project name');
    console.log('  {{ADDITIONAL_SYNC_PATHS}} - Additional paths to sync');
    console.log('  {{ADDITIONAL_EXCLUDE_PATTERNS}} - Additional patterns to exclude');
}