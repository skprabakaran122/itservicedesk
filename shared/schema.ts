import { pgTable, text, serial, integer, timestamp, varchar } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const tickets = pgTable("tickets", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  status: varchar("status", { length: 20 }).notNull(), // open, in-progress, resolved, closed
  priority: varchar("priority", { length: 20 }).notNull(), // low, medium, high, critical
  category: varchar("category", { length: 50 }).notNull(), // hardware, software, network, access, product
  product: varchar("product", { length: 100 }), // specific product name
  assignedTo: text("assigned_to"),
  requesterId: integer("requester_id").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertTicketSchema = createInsertSchema(tickets).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertTicket = z.infer<typeof insertTicketSchema>;
export type Ticket = typeof tickets.$inferSelect;

export const changes = pgTable("changes", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  status: varchar("status", { length: 20 }).notNull(), // pending, approved, rejected, in-progress, completed
  priority: varchar("priority", { length: 20 }).notNull(), // low, medium, high, critical
  category: varchar("category", { length: 50 }).notNull(), // system, application, infrastructure, policy
  requestedBy: text("requested_by").notNull(),
  approvedBy: text("approved_by"),
  implementedBy: text("implemented_by"),
  plannedDate: timestamp("planned_date"),
  completedDate: timestamp("completed_date"),
  riskLevel: varchar("risk_level", { length: 20 }).notNull(), // low, medium, high
  rollbackPlan: text("rollback_plan"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertChangeSchema = createInsertSchema(changes).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertChange = z.infer<typeof insertChangeSchema>;
export type Change = typeof changes.$inferSelect;

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  email: text("email").notNull().unique(),
  password: text("password").notNull(),
  role: varchar("role", { length: 20 }).notNull(), // admin, technician, manager, user
  name: text("name").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertUserSchema = createInsertSchema(users).omit({
  id: true,
  createdAt: true,
});

export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;
