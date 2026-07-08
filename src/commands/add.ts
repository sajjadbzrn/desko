import { loadTasks, saveTasks, generateId, isPriority } from "../storage.js";
import type { Priority } from "../storage.js";
import { renderSuccess, renderError } from "../ui.js";

interface AddOptions {
  priority?: string;
}

export function addTask(description: string, options: AddOptions = {}): void {
  if (!description || description.trim() === "") {
    renderError("Task description cannot be empty.");
    return;
  }

  let priority: Priority = "medium";
  if (options.priority !== undefined) {
    if (!isPriority(options.priority)) {
      renderError(
        `Invalid priority "${options.priority}". Use: low, medium, or high.`,
      );
      return;
    }
    priority = options.priority;
  }

  const tasks = loadTasks();
  const now = new Date().toISOString();
  const newTask = {
    id: generateId(tasks),
    description: description.trim(),
    done: false,
    priority,
    createdAt: now,
    updatedAt: now,
    completedAt: null,
  };
  tasks.push(newTask);
  saveTasks(tasks);
  renderSuccess(`Added #${newTask.id}: "${newTask.description}" (${priority})`);
}
