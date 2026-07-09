#!/usr/bin/env bun
import { Command } from "commander";
import { addTask } from "./commands/add.js";
import { listTasks } from "./commands/list.js";
import { completeTask, reopenTask } from "./commands/complete.js";
import { deleteTask } from "./commands/delete.js";
import { clearDone } from "./commands/clear.js";
import { stats } from "./commands/stats.js";
import { renderBanner, renderError } from "./ui.js";

function parseId(id: string): number | null {
  const numId = parseInt(id, 10);
  if (isNaN(numId)) {
    renderError("Invalid ID. Please provide a number.");
    return null;
  }
  return numId;
}

const program = new Command();

program
  .name("desko")
  .description("Beautiful task manager CLI")
  .version("1.1.0");

program
  .command("add <description>")
  .description("Add a new task")
  .option("-p, --priority <level>", "Priority: low, medium, or high", "medium")
  .action((description: string, options: { priority?: string }) => {
    addTask(description, options);
  });

program
  .command("list")
  .alias("ls")
  .description("List tasks")
  .option("--pending", "Show only pending tasks")
  .option("--done", "Show only completed tasks")
  .action((options: { pending?: boolean; done?: boolean }) => {
    listTasks(options.pending ? "pending" : options.done ? "done" : "all");
  });

program
  .command("complete <id>")
  .alias("done")
  .description("Mark a task as done")
  .action((id: string) => {
    const numId = parseId(id);
    if (numId !== null) completeTask(numId);
  });

program
  .command("reopen <id>")
  .description("Reopen a completed task")
  .action((id: string) => {
    const numId = parseId(id);
    if (numId !== null) reopenTask(numId);
  });

program
  .command("delete <id>")
  .alias("rm")
  .description("Delete a task by ID")
  .action((id: string) => {
    const numId = parseId(id);
    if (numId !== null) deleteTask(numId);
  });

program
  .command("clear")
  .description("Remove all completed tasks")
  .action(clearDone);

program.command("stats").description("Show task statistics").action(stats);

if (!process.argv.slice(2).length) {
  renderBanner();
  program.outputHelp();
  process.exit(0);
}

program.parse(process.argv);
