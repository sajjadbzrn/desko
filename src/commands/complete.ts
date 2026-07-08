import { loadTasks, saveTasks, findTask } from "../storage.js";
import { renderSuccess, renderError, renderInfo } from "../ui.js";

export function completeTask(id: number): void {
  const tasks = loadTasks();
  const task = findTask(tasks, id);
  if (!task) {
    renderError(`Task #${id} not found.`);
    return;
  }
  if (task.done) {
    renderInfo(`Task #${id} "${task.description}" is already done.`);
    return;
  }
  const now = new Date().toISOString();
  task.done = true;
  task.completedAt = now;
  task.updatedAt = now;
  saveTasks(tasks);
  renderSuccess(`Completed #${id}: "${task.description}"`);
}

export function reopenTask(id: number): void {
  const tasks = loadTasks();
  const task = findTask(tasks, id);
  if (!task) {
    renderError(`Task #${id} not found.`);
    return;
  }
  if (!task.done) {
    renderInfo(`Task #${id} "${task.description}" is already open.`);
    return;
  }
  task.done = false;
  task.completedAt = null;
  task.updatedAt = new Date().toISOString();
  saveTasks(tasks);
  renderSuccess(`Reopened #${id}: "${task.description}"`);
}
