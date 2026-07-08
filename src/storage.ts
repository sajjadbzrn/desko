import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  renameSync,
} from "fs";
import { homedir } from "os";
import { join } from "path";

export type Priority = "low" | "medium" | "high";

export const PRIORITIES: Priority[] = ["low", "medium", "high"];

export interface Task {
  id: number;
  description: string;
  done: boolean;
  priority: Priority;
  createdAt: string;
  updatedAt: string;
  completedAt: string | null;
}

const DESKO_DIR = join(homedir(), ".desko");
const TASKS_FILE = join(DESKO_DIR, "tasks.json");

function ensureDir(): void {
  if (!existsSync(DESKO_DIR)) {
    mkdirSync(DESKO_DIR, { recursive: true });
  }
}

export function isPriority(value: unknown): value is Priority {
  return (
    typeof value === "string" && PRIORITIES.includes(value as Priority)
  );
}

function normalizeTask(raw: unknown): Task | null {
  if (typeof raw !== "object" || raw === null) return null;
  const t = raw as Record<string, unknown>;

  const id = Number(t.id);
  if (!Number.isFinite(id)) return null;

  const description =
    typeof t.description === "string" ? t.description : String(t.description ?? "");
  if (description.trim() === "") return null;

  const done = Boolean(t.done);
  const createdAt =
    typeof t.createdAt === "string" ? t.createdAt : new Date().toISOString();

  return {
    id,
    description,
    done,
    priority: isPriority(t.priority) ? t.priority : "medium",
    createdAt,
    updatedAt: typeof t.updatedAt === "string" ? t.updatedAt : createdAt,
    completedAt:
      typeof t.completedAt === "string"
        ? t.completedAt
        : done
          ? createdAt
          : null,
  };
}

export function loadTasks(): Task[] {
  ensureDir();
  if (!existsSync(TASKS_FILE)) {
    return [];
  }
  try {
    const data = readFileSync(TASKS_FILE, "utf-8");
    const parsed = JSON.parse(data);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map(normalizeTask)
      .filter((t): t is Task => t !== null);
  } catch {
    return [];
  }
}

export function saveTasks(tasks: Task[]): void {
  ensureDir();
  const tmp = `${TASKS_FILE}.${process.pid}.tmp`;
  writeFileSync(tmp, JSON.stringify(tasks, null, 2), "utf-8");
  renameSync(tmp, TASKS_FILE);
}

export function generateId(tasks: Task[]): number {
  if (tasks.length === 0) return 1;
  return Math.max(...tasks.map((t) => t.id)) + 1;
}

export function findTask(tasks: Task[], id: number): Task | undefined {
  return tasks.find((t) => t.id === id);
}
