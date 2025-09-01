#!/usr/bin/env node

/**
 * Claude Task Master for {{PROJECT_NAME}} Project
 * Manages tasks and workflows with Claude Code integration
 * 
 * This is a template - replace {{VARIABLES}} with your project-specific values
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');

class ClaudeTaskMaster {
  constructor() {
    this.config = this.loadConfig();
    this.tasksDir = path.join(process.cwd(), '.claude/tasks');
    this.ensureTasksDirectory();
  }

  loadConfig() {
    const configPath = path.join(process.cwd(), '.claude-task-master.json');
    if (!fs.existsSync(configPath)) {
      console.error('Claude Task Master config not found');
      console.error('Create .claude-task-master.json from the template');
      process.exit(1);
    }
    return JSON.parse(fs.readFileSync(configPath, 'utf8'));
  }

  ensureTasksDirectory() {
    if (!fs.existsSync(this.tasksDir)) {
      fs.mkdirSync(this.tasksDir, { recursive: true });
    }
  }

  generateTaskId() {
    return crypto.randomBytes(4).toString('hex').toUpperCase();
  }

  slugify(text) {
    return text
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
  }

  createTask(type, title, description = '') {
    const taskId = this.generateTaskId();
    const category = this.config.taskCategories[type];
    
    if (!category) {
      console.error(`Unknown task type: ${type}`);
      console.error('Available types:', Object.keys(this.config.taskCategories).join(', '));
      process.exit(1);
    }

    const task = {
      id: `${category.prefix}-${taskId}`,
      type,
      title,
      description,
      status: 'pending',
      created: new Date().toISOString(),
      updated: new Date().toISOString(),
      workflow: this.config.workflows[type] || null,
      projectName: '{{PROJECT_NAME}}' // Template variable
    };

    const taskFile = path.join(this.tasksDir, `${task.id}.json`);
    fs.writeFileSync(taskFile, JSON.stringify(task, null, 2));

    console.log(`✓ Task created: ${task.id}`);
    console.log(`  Title: ${title}`);
    console.log(`  Type: ${type}`);
    console.log(`  Project: {{PROJECT_NAME}}`);
    
    if (task.workflow) {
      console.log(`  Workflow: ${task.workflow.steps.length} steps`);
    }

    // Sync to oppie-devkit if enabled
    if (this.config.syncToOppieDevkit) {
      this.syncTaskToOppieDevkit(task);
    }

    return task;
  }

  syncTaskToOppieDevkit(task) {
    // Template for syncing tasks to oppie-devkit
    const syncPath = path.join(process.cwd(), '.claude/oppie-sync-queue.json');
    let syncQueue = [];
    
    if (fs.existsSync(syncPath)) {
      syncQueue = JSON.parse(fs.readFileSync(syncPath, 'utf8'));
    }
    
    syncQueue.push({
      type: 'task',
      task,
      timestamp: new Date().toISOString(),
      project: '{{PROJECT_NAME}}'
    });
    
    fs.writeFileSync(syncPath, JSON.stringify(syncQueue, null, 2));
    console.log('  → Task queued for oppie-devkit sync');
  }

  listTasks(filter = {}) {
    const taskFiles = fs.readdirSync(this.tasksDir)
      .filter(f => f.endsWith('.json'));

    const tasks = taskFiles.map(file => {
      const content = fs.readFileSync(path.join(this.tasksDir, file), 'utf8');
      return JSON.parse(content);
    });

    let filtered = tasks;

    if (filter.type) {
      filtered = filtered.filter(t => t.type === filter.type);
    }

    if (filter.status) {
      filtered = filtered.filter(t => t.status === filter.status);
    }

    return filtered.sort((a, b) => 
      new Date(b.created).getTime() - new Date(a.created).getTime()
    );
  }

  getTask(taskId) {
    const taskFile = path.join(this.tasksDir, `${taskId}.json`);
    if (!fs.existsSync(taskFile)) {
      throw new Error(`Task not found: ${taskId}`);
    }
    return JSON.parse(fs.readFileSync(taskFile, 'utf8'));
  }

  updateTask(taskId, updates) {
    const task = this.getTask(taskId);
    const updated = {
      ...task,
      ...updates,
      updated: new Date().toISOString()
    };

    const taskFile = path.join(this.tasksDir, `${taskId}.json`);
    fs.writeFileSync(taskFile, JSON.stringify(updated, null, 2));
    
    // Sync updates to oppie-devkit
    if (this.config.syncToOppieDevkit) {
      this.syncTaskToOppieDevkit(updated);
    }
    
    return updated;
  }

  runWorkflow(taskId) {
    const task = this.getTask(taskId);
    
    if (!task.workflow) {
      console.error(`No workflow defined for task type: ${task.type}`);
      return;
    }

    console.log(`Starting workflow for ${taskId}: ${task.title}`);
    console.log('Project: {{PROJECT_NAME}}');
    console.log('='.repeat(50));

    const context = {
      taskId: taskId,
      taskSlug: this.slugify(task.title),
      projectName: '{{PROJECT_NAME}}',
      ...task
    };

    for (const [index, step] of task.workflow.steps.entries()) {
      console.log(`\nStep ${index + 1}/${task.workflow.steps.length}: ${step.name}`);
      
      if (step.manual) {
        console.log('⚠️  Manual step - please complete and press Enter to continue');
        require('readline-sync').question('');
      } else if (step.command) {
        try {
          const command = this.interpolateCommand(step.command, context);
          console.log(`> ${command}`);
          
          execSync(command, { stdio: 'inherit' });
          
          if (step.expectFailure) {
            console.error('Expected failure but command succeeded!');
            process.exit(1);
          }
        } catch (error) {
          if (!step.expectFailure) {
            console.error('Step failed!');
            process.exit(1);
          }
        }
      }
    }

    this.updateTask(taskId, { status: 'completed' });
    console.log(`\n✓ Workflow completed for ${taskId}`);
  }

  interpolateCommand(command, context) {
    // Replace template variables
    command = command.replace(/\{\{PROJECT_NAME\}\}/g, '{{PROJECT_NAME}}');
    
    // Replace context variables
    return command.replace(/\${(\w+)}/g, (match, key) => {
      return context[key] || match;
    });
  }

  runPreCommitChecks() {
    if (!this.config.automations.preCommit.enabled) {
      return true;
    }

    console.log('Running pre-commit checks for {{PROJECT_NAME}}...');
    
    // TDD Foundation check first (mandatory)
    console.log('\n→ TDD Foundation Check');
    try {
      execSync('node scripts/tdd-guard-enhanced.js validate', { stdio: 'inherit' });
      console.log('✓ TDD Foundation passed');
    } catch (error) {
      console.error('✗ TDD Foundation failed - tests must be written first!');
      return false;
    }
    
    // Run other configured checks
    for (const check of this.config.automations.preCommit.checks) {
      console.log(`\n→ ${check.name}`);
      try {
        execSync(check.command, { stdio: 'inherit' });
        console.log('✓ Passed');
      } catch (error) {
        console.error('✗ Failed');
        return false;
      }
    }

    return true;
  }

  exportTasks(format = 'json') {
    const tasks = this.listTasks();
    
    if (format === 'markdown') {
      const md = `# {{PROJECT_NAME}} Tasks\n\n` +
        tasks.map(task => 
          `## ${task.id}: ${task.title}\n` +
          `- Type: ${task.type}\n` +
          `- Status: ${task.status}\n` +
          `- Created: ${task.created}\n` +
          `${task.description ? `- Description: ${task.description}\n` : ''}\n`
        ).join('\n');
      
      return md;
    }

    return JSON.stringify(tasks, null, 2);
  }
}

// CLI Interface
const taskMaster = new ClaudeTaskMaster();
const [,, command, ...args] = process.argv;

switch (command) {
  case 'create': {
    const [type, ...titleParts] = args;
    const title = titleParts.join(' ');
    if (!type || !title) {
      console.error('Usage: task-master create <type> <title>');
      process.exit(1);
    }
    taskMaster.createTask(type, title);
    break;
  }

  case 'list': {
    const tasks = taskMaster.listTasks();
    if (tasks.length === 0) {
      console.log('No tasks found');
    } else {
      console.log(`\n{{PROJECT_NAME}} Tasks:\n`);
      tasks.forEach(task => {
        const status = task.status === 'completed' ? '✓' : '○';
        console.log(`${status} ${task.id}: ${task.title} (${task.type})`);
      });
    }
    break;
  }

  case 'run': {
    const [taskId] = args;
    if (!taskId) {
      console.error('Usage: task-master run <task-id>');
      process.exit(1);
    }
    taskMaster.runWorkflow(taskId);
    break;
  }

  case 'precommit': {
    const success = taskMaster.runPreCommitChecks();
    process.exit(success ? 0 : 1);
  }

  case 'export': {
    const [format = 'json'] = args;
    console.log(taskMaster.exportTasks(format));
    break;
  }

  default:
    console.log('Claude Task Master for {{PROJECT_NAME}}');
    console.log('\nCommands:');
    console.log('  create <type> <title>  - Create a new task');
    console.log('  list                   - List all tasks');
    console.log('  run <task-id>         - Run task workflow');
    console.log('  precommit             - Run pre-commit checks');
    console.log('  export [format]       - Export tasks (json/markdown)');
    console.log('\nTask types:', Object.keys(taskMaster.config.taskCategories).join(', '));
    console.log('\nTemplate variables to replace:');
    console.log('  {{PROJECT_NAME}} - Your project name');
}