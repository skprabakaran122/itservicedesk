import { pgTable, text, serial, integer, timestamp, varchar, jsonb, index } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const tickets = pgTable("tickets", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  status: varchar("status", { length: 20 }).notNull(), // pending, open, in-progress, resolved, closed
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

// Ticket history for tracking changes
export const ticketHistory = pgTable("ticket_history", {
  id: serial("id").primaryKey(),
  ticketId: integer("ticket_id").notNull().references(() => tickets.id),
  action: varchar("action", { length: 50 }).notNull(), // created, updated, assigned, status_changed, etc.
  field: varchar("field", { length: 50 }), // which field was changed
  oldValue: text("old_value"),
  newValue: text("new_value"),
  userId: integer("user_id").notNull().references(() => users.id),
  timestamp: timestamp("timestamp").defaultNow().notNull(),
  notes: text("notes"),
});

export const insertTicketHistorySchema = createInsertSchema(ticketHistory).omit({
  id: true,
  timestamp: true,
});

export type InsertTicketHistory = z.infer<typeof insertTicketHistorySchema>;
export type TicketHistory = typeof ticketHistory.$inferSelect;

// Change history for tracking change workflow
export const changeHistory = pgTable("change_history", {
  id: serial("id").primaryKey(),
  changeId: integer("change_id").notNull().references(() => changes.id),
  action: varchar("action", { length: 50 }).notNull(), // submitted, reviewed, approved, rejected, implemented, etc.
  userId: integer("user_id").notNull().references(() => users.id),
  timestamp: timestamp("timestamp").defaultNow().notNull(),
  notes: text("notes"),
  previousStatus: varchar("previous_status", { length: 20 }),
  newStatus: varchar("new_status", { length: 20 }),
});

export const insertChangeHistorySchema = createInsertSchema(changeHistory).omit({
  id: true,
  timestamp: true,
});

export type InsertChangeHistory = z.infer<typeof insertChangeHistorySchema>;
export type ChangeHistory = typeof changeHistory.$inferSelect;

// Session storage table for authentication
export const sessions = pgTable(
  "sessions",
  {
    sid: varchar("sid").primaryKey(),
    sess: jsonb("sess").notNull(),
    expire: timestamp("expire").notNull(),
  },
  (table) => [index("IDX_session_expire").on(table.expire)],
);
