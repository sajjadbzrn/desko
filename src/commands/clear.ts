import { loadTasks, saveTasks } from "../storage.js";
import { renderSuccess, renderInfo } from "../ui.js";

export function clearDone(): void {
  const tasks = loadTasks();
  const pending = tasks.filter((t) => !t.done);
  const removedCount = tasks.length - pending.length;
  if (removedCount === 0) {
    renderInfo("No completed tasks to clear.");
    return;
  }
  saveTasks(pending);
  renderSuccess(`Cleared ${removedCount} completed task(s).`);
}
