import { loadTasks, saveTasks } from "../storage.js";
import { renderSuccess, renderError } from "../ui.js";

export function deleteTask(id: number): void {
  const tasks = loadTasks();
  const index = tasks.findIndex((t) => t.id === id);
  if (index === -1) {
    renderError(`Task #${id} not found.`);
    return;
  }
  const removed = tasks.splice(index, 1)[0];
  saveTasks(tasks);
  renderSuccess(`Deleted #${id}: "${removed.description}"`);
}
