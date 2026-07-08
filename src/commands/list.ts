import { loadTasks } from "../storage.js";
import type { Priority, Task } from "../storage.js";
import { renderTaskList, renderHeader } from "../ui.js";

type Filter = "all" | "pending" | "done";

const PRIORITY_RANK: Record<Priority, number> = { high: 0, medium: 1, low: 2 };

function sortTasks(tasks: Task[]): Task[] {
  return [...tasks].sort((a, b) => {
    if (a.done !== b.done) return a.done ? 1 : -1;
    if (a.priority !== b.priority)
      return PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority];
    return a.id - b.id;
  });
}

export function listTasks(filter: Filter = "all"): void {
  const tasks = loadTasks();
  const filtered = tasks.filter((t) =>
    filter === "all" ? true : filter === "done" ? t.done : !t.done,
  );

  const label =
    filter === "pending"
      ? "Pending tasks"
      : filter === "done"
        ? "Completed tasks"
        : "All tasks";

  renderHeader("Your Tasks", `${label} · ${filtered.length} shown`);
  renderTaskList(sortTasks(filtered));
}
