import { loadTasks } from "../storage.js";
import { renderStats } from "../ui.js";

export function stats(): void {
  renderStats(loadTasks());
}
