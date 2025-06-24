import { pgTable, text, serial, integer, timestamp, varchar, jsonb, index } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const tickets = pgTable("tickets", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  description: text("description").notNull(),
  status: varchar("status", { length: 20 }).notNull(), // pending, open, in-progress, resolved, closed, reopen
  priority: varchar("priority", { length: 20 }).notNull(), // low, medium, high, critical
  category: varchar("category", { length: 50 }).notNull(), // hardware, software, network, access, product
  product: varchar("product", { length: 100 }), // specific product name
  subProduct: varchar("sub_product", { length: 100 }), // sub-product/category name
  assignedTo: text("assigned_to"),
  assignedGroup: varchar("assigned_group", { length: 100 }), // assigned support group
  requesterId: integer("requester_id"),
  requesterEmail: text("requester_email"),
  requesterName: text("requester_name"),
  requesterPhone: text("requester_phone"),
  requesterDepartment: text("requester_department"),
  requesterBusinessUnit: text("requester_business_unit"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
  firstResponseAt: timestamp("first_response_at"),
  resolvedAt: timestamp("resolved_at"),
  slaTargetResponse: integer("sla_target_response"), // target response time in minutes
  slaTargetResolution: integer("sla_target_resolution"), // target resolution time in minutes
  slaResponseMet: varchar("sla_response_met", { length: 10 }), // 'met', 'breached', 'pending'
  slaResolutionMet: varchar("sla_resolution_met", { length: 10 }), // 'met', 'breached', 'pending'
  approvalStatus: varchar("approval_status", { length: 20 }), // null, 'pending', 'approved', 'rejected'
  approvedBy: text("approved_by"),
  approvedAt: timestamp("approved_at"),
  approvalComments: text("approval_comments"),
  approvalToken: text("approval_token") // Secure token for email-based approval
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
  status: varchar("status", { length: 20 }).notNull(), // pending, approved, rejected, in-progress, testing, completed, failed, rollback
  priority: varchar("priority", { length: 20 }).notNull(), // low, medium, high, critical
  category: varchar("category", { length: 50 }).notNull(), // system, application, infrastructure, policy
  product: varchar("product", { length: 100 }), // specific product name
  requestedBy: text("requested_by").notNull(),
  approvedBy: text("approved_by"),
  implementedBy: text("implemented_by"),
  plannedDate: timestamp("planned_date"),
  completedDate: timestamp("completed_date"),
  startDate: timestamp("start_date"),
  endDate: timestamp("end_date"),
  riskLevel: varchar("risk_level", { length: 20 }).notNull(), // low, medium, high
  changeType: varchar("change_type", { length: 20 }).notNull().default('normal'), // standard, normal, emergency
  rollbackPlan: text("rollback_plan"),
  approvalToken: text("approval_token"), // Secure token for email-based approval
  overdueNotificationSent: timestamp("overdue_notification_sent"), // Track when overdue notification was sent
  isOverdue: varchar("is_overdue", { length: 10 }).default('false'), // 'true' if change is overdue
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
  assignedProducts: text("assigned_products").array(), // Array of product names this user can access
  resetToken: varchar("reset_token", { length: 255 }),
  resetTokenExpiry: timestamp("reset_token_expiry"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertUserSchema = createInsertSchema(users).omit({
  id: true,
  createdAt: true,
});

export type InsertUser = z.infer<typeof insertUserSchema>;
export type SelectUser = typeof users.$inferSelect;
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
// Products table for admin management
export const products = pgTable("products", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 100 }).notNull().unique(),
  category: varchar("category", { length: 50 }).notNull(),
  description: text("description"),
  isActive: varchar("is_active", { length: 10 }).notNull().default("true"),
  owner: varchar("owner", { length: 100 }), // Ubuntu production compatibility
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertProductSchema = createInsertSchema(products).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertProduct = z.infer<typeof insertProductSchema>;
export type Product = typeof products.$inferSelect;

// Approval routing configuration table
export const approvalRouting = pgTable("approval_routing", {
  id: serial("id").primaryKey(),
  productId: integer("product_id").notNull().references(() => products.id),
  riskLevel: varchar("risk_level", { length: 20 }).notNull(), // low, medium, high, critical
  approverId: integer("approver_id").notNull().references(() => users.id),
  approvalLevel: integer("approval_level").notNull().default(1), // 1 = first approver, 2 = second approver, etc.
  isActive: varchar("is_active", { length: 10 }).notNull().default("true"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertApprovalRoutingSchema = createInsertSchema(approvalRouting).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertApprovalRouting = z.infer<typeof insertApprovalRoutingSchema>;
export type ApprovalRouting = typeof approvalRouting.$inferSelect;

// Change approval tracking table for multilevel approvals
export const changeApprovals = pgTable("change_approvals", {
  id: serial("id").primaryKey(),
  changeId: integer("change_id").notNull().references(() => changes.id),
  approverId: integer("approver_id").notNull().references(() => users.id),
  approvalLevel: integer("approval_level").notNull(), // 1 = first level, 2 = second level, etc.
  status: varchar("status", { length: 20 }).notNull().default("pending"), // pending, approved, rejected
  approvedAt: timestamp("approved_at"),
  comments: text("comments"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertChangeApprovalSchema = createInsertSchema(changeApprovals).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertChangeApproval = z.infer<typeof insertChangeApprovalSchema>;
export type ChangeApproval = typeof changeApprovals.$inferSelect;

// Settings table for persistent configuration
export const settings = pgTable("settings", {
  id: serial("id").primaryKey(),
  key: varchar("key", { length: 100 }).notNull().unique(),
  value: text("value"),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertSettingSchema = createInsertSchema(settings).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertSetting = z.infer<typeof insertSettingSchema>;
export type Setting = typeof settings.$inferSelect;

// File attachments table
export const attachments = pgTable("attachments", {
  id: serial("id").primaryKey(),
  fileName: varchar("file_name", { length: 255 }).notNull(),
  originalName: varchar("original_name", { length: 255 }).notNull(),
  fileSize: integer("file_size").notNull(),
  mimeType: varchar("mime_type", { length: 100 }).notNull(),
  fileContent: text("file_content"), // Store base64 encoded file content
  ticketId: integer("ticket_id").references(() => tickets.id),
  changeId: integer("change_id").references(() => changes.id),
  uploadedBy: integer("uploaded_by"),
  uploadedByName: text("uploaded_by_name"), // For anonymous uploads
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertAttachmentSchema = createInsertSchema(attachments).omit({
  id: true,
  createdAt: true,
});

export type InsertAttachment = z.infer<typeof insertAttachmentSchema>;
export type Attachment = typeof attachments.$inferSelect;


// Support Groups table
export const groups = pgTable("groups", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 100 }).notNull().unique(),
  description: text("description"),
  isActive: varchar("is_active", { length: 10 }).notNull().default('true'), // 'true' or 'false'
  members: text("members").array(), // Array of usernames who are members of this group
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertGroupSchema = createInsertSchema(groups).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertGroup = z.infer<typeof insertGroupSchema>;
export type Group = typeof groups.$inferSelect;

// Categories as sub-products
export const categories = pgTable("categories", {
  id: serial("id").primaryKey(),
  name: varchar("name", { length: 100 }).notNull(),
  description: text("description"),
  productId: integer("product_id").references(() => products.id),
  isActive: varchar("is_active", { length: 10 }).notNull().default('true'), // 'true' or 'false'
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertCategorySchema = createInsertSchema(categories).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export type InsertCategory = z.infer<typeof insertCategorySchema>;
export type Category = typeof categories.$inferSelect;

export const sessions = pgTable(
  "sessions",
  {
    sid: varchar("sid").primaryKey(),
    sess: jsonb("sess").notNull(),
    expire: timestamp("expire").notNull(),
  },
  (table) => [index("IDX_session_expire").on(table.expire)],
);
