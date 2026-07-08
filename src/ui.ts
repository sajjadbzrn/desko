import { ascii, color, components, gradient } from "ansimax";
import type { Priority, Task } from "./storage.js";

const BRAND = ["#7c5cff", "#22d3ee", "#34d399"];
const ACCENT = ["#a78bfa", "#f0abfc"];

const dim = (t: string) => color.gray(t);
const brand = (t: string) => gradient(t, BRAND);

function line(width = 52): string {
  return dim("─".repeat(width));
}

function relativeTime(iso: string): string {
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "—";
  const diff = Date.now() - then;
  const mins = Math.round(diff / 60000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
}

const PRIORITY_META: Record<
  Priority,
  { icon: string; color: (t: string) => string; label: string }
> = {
  high: { icon: "▲", color: (t) => color.hex("#f87171")(t), label: "high" },
  medium: { icon: "◆", color: (t) => color.hex("#fbbf24")(t), label: "med" },
  low: { icon: "▽", color: (t) => color.hex("#60a5fa")(t), label: "low" },
};

function priorityTag(p: Priority): string {
  const m = PRIORITY_META[p];
  return m.color(`${m.icon} ${m.label}`);
}

export function renderBanner(): void {
  const logo = ascii.banner("desko", { font: "small", align: "left" });
  console.log();
  console.log(gradient(logo, BRAND));
  console.log("  " + dim("a beautiful task manager for your terminal"));
  console.log();
}

export function renderHeader(title: string, subtitle?: string): void {
  console.log();
  console.log("  " + brand(title));
  if (subtitle) console.log("  " + dim(subtitle));
  console.log("  " + line());
}

export function renderSuccess(message: string): void {
  console.log(components.status("success", message));
}

export function renderError(message: string): void {
  console.log(components.status("error", message));
}

export function renderInfo(message: string): void {
  console.log(components.status("info", message));
}

export function renderWarn(message: string): void {
  console.log(components.status("warn", message));
}

function emptyState(message: string): void {
  console.log();
  console.log(
    ascii.box(color.gray(message), {
      padding: 1,
      borderStyle: "rounded",
      title: gradient(" nothing here ", ACCENT),
      titleAlign: "center",
    }),
  );
  console.log();
}

export function renderTaskList(tasks: Task[]): void {
  if (tasks.length === 0) {
    emptyState('No tasks to show. Add one with:  desko add "your task"');
    return;
  }

  const rows: string[][] = [
    ["#", "Priority", "Task", "Age"],
    ...tasks.map((task) => {
      const status = task.done
        ? color.hex("#34d399")("[x]")
        : color.hex("#fbbf24")("[ ]");
      const desc = task.done
        ? color.gray(color.strikethrough(task.description))
        : color.white(task.description);
      return [
        dim(String(task.id)),
        priorityTag(task.priority),
        status + " " + desc,
        dim(relativeTime(task.createdAt)),
      ];
    }),
  ];

  console.log();
  console.log(
    components.table(rows, {
      header: true,
      borderStyle: "rounded",
    }),
  );
  console.log();
}

export function renderStats(tasks: Task[]): void {
  const total = tasks.length;
  const done = tasks.filter((t) => t.done).length;
  const pending = total - done;
  const percent = total === 0 ? 0 : Math.round((done / total) * 100);

  renderHeader("Statistics", "your productivity at a glance");
  console.log();

  if (total === 0) {
    emptyState("No data yet. Add your first task to see stats.");
    return;
  }

  console.log(
    "  " +
      components.progressBar(percent, {
        width: 30,
        label: "Completed",
        gradient: BRAND,
        showPercentage: true,
      }),
  );
  console.log();

  const badges = [
    components.badge("total", String(total), { valueBg: 45 }),
    components.badge("done", String(done), { valueBg: 42 }),
    components.badge("pending", String(pending), { valueBg: 43 }),
  ];
  console.log("  " + badges.join("  "));
  console.log();

  const byPriority = (["high", "medium", "low"] as Priority[]).map((p) => {
    const count = tasks.filter((t) => t.priority === p && !t.done).length;
    return "  " + priorityTag(p) + dim(`  ${count} pending`);
  });
  console.log("  " + dim("Pending by priority"));
  console.log(byPriority.join("\n"));
  console.log();
}
