import { tickets, changes, users, ticketHistory, changeHistory, products, attachments, approvalRouting, changeApprovals, settings, groups, categories, type Ticket, type InsertTicket, type Change, type InsertChange, type User, type InsertUser, type TicketHistory, type InsertTicketHistory, type ChangeHistory, type InsertChangeHistory, type Product, type InsertProduct, type Attachment, type InsertAttachment, type ApprovalRouting, type InsertApprovalRouting, type ChangeApproval, type InsertChangeApproval, type Setting, type InsertSetting, type Group, type InsertGroup, type Category, type InsertCategory } from "@shared/schema";
import { db, pool } from "./db";
import { eq, and, desc, or, like, sql, not, isNull, lte, notInArray, inArray, gte, lt, isNotNull } from "drizzle-orm";

export interface IStorage {
  // Ticket methods
  getTickets(): Promise<Ticket[]>;
  getTicketsForUser(userId: number): Promise<Ticket[]>;
  getUserGroups(userId: number): Promise<string[]>;
  getTicketsByGroups(groupNames: string[]): Promise<Ticket[]>;
  getTicket(id: number): Promise<Ticket | undefined>;
  createTicket(ticket: InsertTicket): Promise<Ticket>;
  updateTicket(id: number, updates: Partial<InsertTicket>): Promise<Ticket | undefined>;
  searchTickets(filters: {
    status?: string;
    priority?: string;
    category?: string;
    assignedTo?: string;
    assignedGroup?: string;
    searchQuery?: string;
  }): Promise<Ticket[]>;
  
  // Change methods
  getChanges(): Promise<Change[]>;
  getChangesForUser(userId: number, userRole: string): Promise<Change[]>;
  getChange(id: number): Promise<Change | undefined>;
  createChange(change: InsertChange): Promise<Change>;
  updateChange(id: number, updates: Partial<InsertChange>): Promise<Change | undefined>;
  searchChanges(filters: {
    status?: string;
    priority?: string;
    category?: string;
    requestedBy?: string;
  }): Promise<Change[]>;
  
  // User methods
  getUsers(): Promise<User[]>;
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  getUserByEmail(email: string): Promise<User | undefined>;
  getUserByUsernameOrEmail(usernameOrEmail: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  updateUser(id: number, updates: Partial<InsertUser>): Promise<User | undefined>;
  deleteUser(id: number): Promise<boolean>;
  
  // History methods
  getTicketHistory(ticketId: number): Promise<TicketHistory[]>;
  createTicketHistory(history: InsertTicketHistory): Promise<TicketHistory>;
  getChangeHistory(changeId: number): Promise<ChangeHistory[]>;
  createChangeHistory(history: InsertChangeHistory): Promise<ChangeHistory>;
  
  // Product methods
  getProducts(): Promise<Product[]>;
  getProduct(id: number): Promise<Product | undefined>;
  createProduct(product: InsertProduct): Promise<Product>;
  updateProduct(id: number, updates: Partial<InsertProduct>): Promise<Product | undefined>;
  deleteProduct(id: number): Promise<boolean>;
  
  // Attachment methods
  getAttachments(ticketId?: number, changeId?: number): Promise<Attachment[]>;
  getAttachment(id: number): Promise<Attachment | undefined>;
  createAttachment(attachment: InsertAttachment): Promise<Attachment>;
  deleteAttachment(id: number): Promise<boolean>;
  
  // Approval routing methods
  getApprovalRouting(): Promise<ApprovalRouting[]>;
  createApprovalRouting(routing: InsertApprovalRouting): Promise<ApprovalRouting>;
  updateApprovalRouting(id: number, updates: Partial<InsertApprovalRouting>): Promise<ApprovalRouting | undefined>;
  deleteApprovalRouting(id: number): Promise<boolean>;
  getApprovalWorkflow(productId: number, riskLevel: string): Promise<ApprovalRouting[]>;
  
  // Change approval methods
  getChangeApprovals(changeId: number): Promise<ChangeApproval[]>;
  createChangeApproval(approval: InsertChangeApproval): Promise<ChangeApproval>;
  updateChangeApproval(id: number, updates: Partial<InsertChangeApproval>): Promise<ChangeApproval | undefined>;
  initializeChangeApprovals(changeId: number, productId: number, riskLevel: string, changeType?: string): Promise<void>;
  processApproval(changeId: number, approverId: number, action: 'approved' | 'rejected', comments?: string): Promise<{ approved: boolean; nextLevel?: number; completed: boolean }>;
  
  // SLA methods
  getSLAMetrics(): Promise<{
    totalTickets: number;
    responseMetrics: {
      met: number;
      breached: number;
      pending: number;
      percentage: number;
    };
    resolutionMetrics: {
      met: number;
      breached: number;
      pending: number;
      percentage: number;
    };
    averageResponseTime: number;
    averageResolutionTime: number;
    metricsByProduct: Record<string, {
      total: number;
      responseMet: number;
      resolutionMet: number;
      responsePercentage: number;
      resolutionPercentage: number;
      averageResponseTime: number;
      averageResolutionTime: number;
    }>;
  }>;
  updateTicketSLA(id: number): Promise<void>;
  refreshSLAMetrics(): Promise<void>;
  autoCloseResolvedTickets(): Promise<{ closedCount: number; tickets: Ticket[] }>;
  
  // Overdue change monitoring methods
  checkOverdueChanges(): Promise<Change[]>;
  markChangeAsOverdue(changeId: number): Promise<void>;
  sendOverdueNotifications(): Promise<{ notificationCount: number; changes: Change[] }>;
  
  // Settings methods
  getSetting(key: string): Promise<Setting | undefined>;
  setSetting(key: string, value: string, description?: string): Promise<Setting>;
  getSettings(): Promise<Setting[]>;
  
  // Groups methods
  getGroups(): Promise<Group[]>;
  getGroup(id: number): Promise<Group | undefined>;
  getGroupByName(name: string): Promise<Group | undefined>;
  createGroup(group: InsertGroup): Promise<Group>;
  updateGroup(id: number, updates: Partial<InsertGroup>): Promise<Group | undefined>;
  deleteGroup(id: number): Promise<boolean>;
  getActiveGroups(): Promise<Group[]>;

  // Password reset methods
  setPasswordResetToken(email: string, token: string, expiry: Date): Promise<void>;
  getUserByResetToken(token: string): Promise<User | null>;
  resetPassword(token: string, newPassword: string): Promise<boolean>;

  // Analytics methods
  getAnalyticsData(days: number, group: string, startDate?: string, endDate?: string): Promise<any>;
  generateReport(type: string, days: number, startDate?: string, endDate?: string): Promise<any>;

  // Categories methods
  getCategories(): Promise<Category[]>;
  getActiveCategories(): Promise<Category[]>;
  getCategoriesByProduct(productId: number): Promise<Category[]>;
  createCategory(category: InsertCategory): Promise<Category>;
  updateCategory(id: number, updates: Partial<InsertCategory>): Promise<Category | undefined>;
  deleteCategory(id: number): Promise<boolean>;

}

export class DatabaseStorage implements IStorage {
  private static initialized = false;

  constructor() {
    // Initialization will be handled externally at server startup
  }

  private getSLATargets(priority: string): { response: number; resolution: number } {
    // SLA targets in minutes based on priority
    switch (priority) {
      case 'critical':
        return { response: 15, resolution: 240 }; // 15 min response, 4 hours resolution
      case 'high':
        return { response: 60, resolution: 480 }; // 1 hour response, 8 hours resolution
      case 'medium':
        return { response: 240, resolution: 1440 }; // 4 hours response, 24 hours resolution
      case 'low':
        return { response: 480, resolution: 2880 }; // 8 hours response, 48 hours resolution
      default:
        return { response: 240, resolution: 1440 };
    }
  }

  private calculateSLAStatus(createdAt: Date, targetMinutes: number, actualAt?: Date): string {
    const now = new Date();
    const targetTime = new Date(createdAt.getTime() + targetMinutes * 60000);
    
    if (actualAt) {
      return actualAt <= targetTime ? 'met' : 'breached';
    } else {
      return now > targetTime ? 'breached' : 'pending';
    }
  }

  async initializeData() {
    try {
      // Check if users exist, if not create sample users
      const existingUsers = await this.getUsers();
      if (existingUsers.length === 0) {
        const sampleUsers: InsertUser[] = [
          { username: "john.doe", email: "john.doe@company.com", password: "password123", role: "admin", name: "John Doe", assignedProducts: null },
          { username: "jane.smith", email: "jane.smith@company.com", password: "password123", role: "agent", name: "Jane Smith", assignedProducts: ["Olympus 1.0", "Olympus 2.0"] },
          { username: "mike.wilson", email: "mike.wilson@company.com", password: "password123", role: "manager", name: "Mike Wilson", assignedProducts: null },
          { username: "sarah.jones", email: "sarah.jones@company.com", password: "password123", role: "user", name: "Sarah Jones", assignedProducts: null },
        ];

        for (const user of sampleUsers) {
          await this.createUser(user);
        }
      }
    } catch (error) {
      console.error("Error initializing data:", error);
    }
  }

  // Ticket methods
  async getTickets(): Promise<Ticket[]> {
    return await db.select().from(tickets).orderBy(desc(tickets.createdAt));
  }

  async getTicketsForUser(userId: number): Promise<Ticket[]> {
    const user = await this.getUser(userId);
    if (!user) return [];
    
    if (user.role === 'admin') {
      // Admins see all tickets with proper priority sorting
      const combinedOrder = sql`CASE
        WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'critical' THEN 1
        WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'high' THEN 2
        WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'medium' THEN 3
        WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'low' THEN 4
        WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'critical' THEN 5
        WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'high' THEN 6
        WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'medium' THEN 7
        WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'low' THEN 8
        WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'critical' THEN 9
        WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'high' THEN 10
        WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'medium' THEN 11
        WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'low' THEN 12
        WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'critical' THEN 13
        WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'high' THEN 14
        WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'medium' THEN 15
        WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'low' THEN 16
        WHEN ${tickets.status} = 'closed' AND ${tickets.priority} = 'critical' THEN 17
        WHEN ${tickets.status} = 'closed' AND ${tickets.priority} = 'high' THEN 18
        WHEN ${tickets.status} = 'closed' AND ${tickets.priority} = 'medium' THEN 19
        WHEN ${tickets.status} = 'closed' AND ${tickets.priority} = 'low' THEN 20
        ELSE 21
      END`;
      
      return await db.select().from(tickets).orderBy(combinedOrder, desc(tickets.createdAt));
    }
    
    if (user.role === 'agent' || user.role === 'manager') {
      // Agents and managers see tickets for groups they are members of, excluding closed tickets
      const userGroups = await this.getUserGroups(userId);
      if (userGroups.length === 0) {
        return [];
      }
      
      return await this.getTicketsByGroupsExcludingClosed(userGroups);
    }
    
    // Users only see their own tickets
    return await db.select().from(tickets)
      .where(eq(tickets.requesterId, userId))
      .orderBy(desc(tickets.createdAt));
  }

  async getUserGroups(userId: number): Promise<string[]> {
    const allGroups = await db.select().from(groups);
    const userGroups = allGroups.filter(group => 
      group.members && 
      Array.isArray(group.members) && 
      (group.members.includes(userId) || group.members.includes(userId.toString()))
    );
    return userGroups.map(group => group.name);
  }

  async getTicketsByGroups(groupNames: string[]): Promise<Ticket[]> {
    if (groupNames.length === 0) {
      return [];
    }
    
    return await db.select().from(tickets)
      .where(or(...groupNames.map(groupName => eq(tickets.assignedGroup, groupName))))
      .orderBy(desc(tickets.createdAt));
  }

  async getTicketsByGroupsExcludingClosed(groupNames: string[]): Promise<Ticket[]> {
    if (groupNames.length === 0) {
      return [];
    }
    
    // Combined sorting: Status first, then priority within each status
    const combinedOrder = sql`CASE
      WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'critical' THEN 1
      WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'high' THEN 2
      WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'medium' THEN 3
      WHEN ${tickets.status} = 'open' AND ${tickets.priority} = 'low' THEN 4
      WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'critical' THEN 5
      WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'high' THEN 6
      WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'medium' THEN 7
      WHEN ${tickets.status} = 'in_progress' AND ${tickets.priority} = 'low' THEN 8
      WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'critical' THEN 9
      WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'high' THEN 10
      WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'medium' THEN 11
      WHEN ${tickets.status} = 'pending' AND ${tickets.priority} = 'low' THEN 12
      WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'critical' THEN 13
      WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'high' THEN 14
      WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'medium' THEN 15
      WHEN ${tickets.status} = 'resolved' AND ${tickets.priority} = 'low' THEN 16
      ELSE 17
    END`;
    
    return await db.select().from(tickets)
      .where(and(
        or(...groupNames.map(groupName => eq(tickets.assignedGroup, groupName))),
        not(eq(tickets.status, 'closed'))
      ))
      .orderBy(combinedOrder, desc(tickets.createdAt));
  }

  async getTicket(id: number): Promise<Ticket | undefined> {
    const [ticket] = await db.select().from(tickets).where(eq(tickets.id, id));
    return ticket;
  }

  async createTicket(insertTicket: InsertTicket): Promise<Ticket> {
    const slaTargets = this.getSLATargets(insertTicket.priority);
    
    const ticketData = {
      ...insertTicket,
      slaTargetResponse: slaTargets.response,
      slaTargetResolution: slaTargets.resolution,
      slaResponseMet: 'pending',
      slaResolutionMet: 'pending'
    };
    
    const [ticket] = await db.insert(tickets).values(ticketData).returning();
    return ticket;
  }

  async updateTicket(id: number, updates: Partial<InsertTicket>): Promise<Ticket | undefined> {
    const [ticket] = await db
      .update(tickets)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(tickets.id, id))
      .returning();
    return ticket;
  }

  async searchTickets(filters: {
    status?: string;
    priority?: string;
    category?: string;
    assignedTo?: string;
    assignedGroup?: string;
    searchQuery?: string;
  }): Promise<Ticket[]> {
    const conditions = [];
    
    if (filters.status) conditions.push(eq(tickets.status, filters.status));
    if (filters.priority) conditions.push(eq(tickets.priority, filters.priority));
    if (filters.category) conditions.push(eq(tickets.category, filters.category));
    if (filters.assignedTo) conditions.push(eq(tickets.assignedTo, filters.assignedTo));
    if (filters.assignedGroup) conditions.push(eq(tickets.assignedGroup, filters.assignedGroup));

    // Handle search query for text-based search
    if (filters.searchQuery) {
      const searchTerm = `%${filters.searchQuery}%`;
      const numericSearch = parseInt(filters.searchQuery);
      
      const searchConditions = or(
        sql`LOWER(${tickets.title}) LIKE LOWER(${searchTerm})`,
        sql`LOWER(${tickets.description}) LIKE LOWER(${searchTerm})`,
        sql`LOWER(${tickets.requesterName}) LIKE LOWER(${searchTerm})`,
        sql`LOWER(${tickets.product}) LIKE LOWER(${searchTerm})`,
        isNaN(numericSearch) ? sql`false` : eq(tickets.id, numericSearch)
      );
      conditions.push(searchConditions);
    }

    if (conditions.length === 0) {
      return await this.getTickets();
    }

    return await db.select().from(tickets).where(and(...conditions)).orderBy(desc(tickets.createdAt));
  }

  // Change methods
  async getChanges(): Promise<Change[]> {
    const result = await db.select().from(changes).orderBy(desc(changes.createdAt));
    return result;
  }

  async getChangesForUser(userId: number, userRole: string): Promise<Change[]> {
    if (userRole === 'admin') {
      // Admins see all changes
      return this.getChanges();
    }

    if (userRole === 'user') {
      // Users see only their own changes
      const result = await db
        .select()
        .from(changes)
        .where(eq(changes.requesterId, userId))
        .orderBy(desc(changes.createdAt));
      return result;
    }

    if (userRole === 'agent' || userRole === 'manager') {
      // Agents and managers see changes assigned to their groups
      const userGroups = await this.getUserGroups(userId);
      if (userGroups.length === 0) {
        return [];
      }

      const groupNames = userGroups.map(g => g.name);
      console.log('[Storage] User groups for changes:', groupNames);
      
      // If no group names, return empty array
      if (groupNames.length === 0) {
        return [];
      }
      
      const result = await db
        .select()
        .from(changes)
        .where(
          or(
            ...groupNames.map(groupName => eq(changes.assignedGroup, groupName))
          )
        )
        .orderBy(desc(changes.createdAt));
      console.log('[Storage] Changes found for groups:', result.length);
      return result;
    }

    return [];
  }

  async getChange(id: number): Promise<Change | undefined> {
    const [change] = await db.select().from(changes).where(eq(changes.id, id));
    return change;
  }

  async createChange(insertChange: InsertChange): Promise<Change> {
    const [change] = await db.insert(changes).values(insertChange).returning();
    return change;
  }

  async updateChange(id: number, updates: Partial<InsertChange>): Promise<Change | undefined> {
    const [change] = await db
      .update(changes)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(changes.id, id))
      .returning();
    return change;
  }

  async searchChanges(filters: {
    status?: string;
    priority?: string;
    category?: string;
    requestedBy?: string;
  }): Promise<Change[]> {
    const conditions = [];
    
    if (filters.status) conditions.push(eq(changes.status, filters.status));
    if (filters.priority) conditions.push(eq(changes.priority, filters.priority));
    if (filters.category) conditions.push(eq(changes.category, filters.category));
    if (filters.requestedBy) conditions.push(eq(changes.requestedBy, filters.requestedBy));

    if (conditions.length === 0) {
      return await this.getChanges();
    }

    return await db.select().from(changes).where(and(...conditions));
  }

  // User methods
  async getUsers(): Promise<User[]> {
    return await db.select().from(users).orderBy(users.createdAt);
  }

  async getUser(id: number): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.id, id));
    return user;
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.username, username));
    return user;
  }

  async getUserByEmail(email: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(eq(users.email, email));
    return user;
  }

  async getUserByUsernameOrEmail(usernameOrEmail: string): Promise<User | undefined> {
    const [user] = await db.select().from(users).where(
      or(
        eq(users.username, usernameOrEmail),
        eq(users.email, usernameOrEmail)
      )
    );
    return user;
  }

  async setPasswordResetToken(email: string, token: string, expiry: Date): Promise<void> {
    await db.update(users)
      .set({ 
        resetToken: token, 
        resetTokenExpiry: expiry 
      })
      .where(eq(users.email, email));
  }

  async getUserByResetToken(token: string): Promise<User | null> {
    const [user] = await db.select()
      .from(users)
      .where(eq(users.resetToken, token))
      .limit(1);
    
    return user || null;
  }

  async resetPassword(token: string, newPassword: string): Promise<boolean> {
    const user = await this.getUserByResetToken(token);
    
    if (!user || !user.resetTokenExpiry || new Date() > user.resetTokenExpiry) {
      return false;
    }

    await db.update(users)
      .set({ 
        password: newPassword,
        resetToken: null,
        resetTokenExpiry: null 
      })
      .where(eq(users.id, user.id));
    
    return true;
  }

  async getAnalyticsData(days: number, group: string, customStartDate?: string, customEndDate?: string): Promise<any> {
    let startDate: Date;
    let endDate: Date;
    
    if (customStartDate && customEndDate) {
      startDate = new Date(customStartDate);
      endDate = new Date(customEndDate);
      endDate.setHours(23, 59, 59, 999); // Include the entire end date
    } else {
      startDate = new Date();
      startDate.setDate(startDate.getDate() - days);
      endDate = new Date();
    }

    // Base query with date filtering and group filtering
    let whereConditions = and(
      gte(tickets.createdAt, startDate),
      lte(tickets.createdAt, endDate)
    );

    // Add group filtering if specified
    if (group && group !== 'all') {
      whereConditions = and(
        whereConditions,
        eq(tickets.assignedGroup, group)
      );
    }

    // Get basic metrics in a single query
    const basicMetrics = await db.select({
      total: sql`count(*)`,
      open: sql`count(case when ${tickets.status} not in ('resolved', 'closed') then 1 end)`,
      resolved: sql`count(case when ${tickets.status} = 'resolved' then 1 end)`,
      slaCompliant: sql`count(case when ${tickets.slaResolutionMet} = 'met' then 1 end)`,
      avgResolutionHours: sql`avg(case when ${tickets.resolvedAt} is not null then extract(epoch from ${tickets.resolvedAt} - ${tickets.createdAt})/3600 end)`
    }).from(tickets)
      .where(whereConditions);

    const metrics = basicMetrics[0];
    const avgResolutionTime = metrics.avgResolutionHours || 0;
    const slaCompliance = metrics.total > 0 
      ? Math.round((metrics.slaCompliant / metrics.total) * 100)
      : 100;

    // Active users count - optimized
    const activeUsersResult = await db.select({ 
      count: sql`count(distinct ${tickets.requesterId})` 
    }).from(tickets)
      .where(whereConditions);

    // Ticket trends (daily data for the period)
    const ticketTrends = [];
    const daysDiff = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
    
    for (let i = 0; i <= daysDiff; i++) {
      const date = new Date(startDate);
      date.setDate(startDate.getDate() + i);
      const dateStr = date.toISOString().split('T')[0];
      
      let dailyConditions = and(
        gte(tickets.createdAt, date),
        lt(tickets.createdAt, new Date(date.getTime() + 24 * 60 * 60 * 1000))
      );
      if (group && group !== 'all') {
        dailyConditions = and(dailyConditions, eq(tickets.assignedGroup, group));
      }
      
      const created = await db.select({ count: sql`count(*)` }).from(tickets)
        .where(dailyConditions);
      
      let resolvedConditions = and(
        gte(tickets.resolvedAt, date),
        lt(tickets.resolvedAt, new Date(date.getTime() + 24 * 60 * 60 * 1000)),
        eq(tickets.status, 'resolved')
      );
      if (group && group !== 'all') {
        resolvedConditions = and(resolvedConditions, eq(tickets.assignedGroup, group));
      }
      
      const resolved = await db.select({ count: sql`count(*)` }).from(tickets)
        .where(resolvedConditions);

      ticketTrends.push({
        date: dateStr,
        created: created[0].count,
        resolved: resolved[0].count,
        pending: created[0].count - resolved[0].count
      });
    }

    // Priority distribution - optimized single query
    const priorityDistribution = await db.select({
      priority: tickets.priority,
      count: sql`count(*)`
    }).from(tickets)
      .where(whereConditions)
      .groupBy(tickets.priority);

    const priorityData = ['low', 'medium', 'high', 'critical'].map(priority => {
      const found = priorityDistribution.find(p => p.priority === priority);
      const count = found ? found.count : 0;
      return {
        priority,
        count,
        percentage: metrics.total > 0 ? Math.round((count / metrics.total) * 100) : 0
      };
    });

    // Group performance
    const allGroups = await this.getActiveGroups();
    const groupPerformance = await Promise.all(
      allGroups.map(async (grp) => {
        const assigned = await db.select({ count: sql`count(*)` }).from(tickets)
          .where(and(
            gte(tickets.createdAt, startDate),
            lte(tickets.createdAt, endDate),
            eq(tickets.assignedGroup, grp.name)
          ));
        
        const resolved = await db.select({ count: sql`count(*)` }).from(tickets)
          .where(and(
            gte(tickets.createdAt, startDate),
            lte(tickets.createdAt, endDate),
            eq(tickets.assignedGroup, grp.name),
            eq(tickets.status, 'resolved')
          ));

        const slaCompliant = await db.select({ count: sql`count(*)` }).from(tickets)
          .where(and(
            gte(tickets.createdAt, startDate),
            lte(tickets.createdAt, endDate),
            eq(tickets.assignedGroup, grp.name),
            eq(tickets.slaResolutionMet, 'met')
          ));

        return {
          groupName: grp.name,
          ticketsAssigned: assigned[0].count,
          ticketsResolved: resolved[0].count,
          averageResolutionTime: Math.round(avgResolutionTime),
          slaCompliance: assigned[0].count > 0 
            ? Math.round((slaCompliant[0].count / assigned[0].count) * 100)
            : 100
        };
      })
    );

    // Category breakdown - optimized single query
    const categoryBreakdown = await db.select({
      category: tickets.category,
      count: sql`count(*)`
    }).from(tickets)
      .where(whereConditions)
      .groupBy(tickets.category);

    const categoryData = ['software', 'hardware', 'network', 'access', 'other'].map(category => {
      const found = categoryBreakdown.find(c => c.category === category);
      const count = found ? found.count : 0;
      return {
        category,
        count,
        percentage: metrics.total > 0 ? Math.round((count / metrics.total) * 100) : 0
      };
    });

    return {
      overview: {
        totalTickets: metrics.total.toString(),
        openTickets: metrics.open.toString(),
        resolvedTickets: metrics.resolved.toString(),
        avgResolutionTime: Math.round(avgResolutionTime).toString(),
        slaCompliance: slaCompliance.toString(),
        activeUsers: activeUsersResult[0].count.toString()
      },
      ticketTrends,
      priorityDistribution: priorityData,
      groupPerformance,
      categoryBreakdown: categoryData,
      slaMetrics: {
        compliance: slaCompliance,
        totalTickets: metrics.total,
        compliantTickets: metrics.slaCompliant,
        breachedTickets: metrics.total - metrics.slaCompliant,
        avgResolutionTime: Math.round(avgResolutionTime)
      }
    };
  }

  async generateReport(type: string, days: number, customStartDate?: string, customEndDate?: string): Promise<any> {
    const analyticsData = await this.getAnalyticsData(days, 'all', customStartDate, customEndDate);
    
    let periodDescription: string;
    if (customStartDate && customEndDate) {
      periodDescription = `${customStartDate} to ${customEndDate}`;
    } else {
      periodDescription = `${days} days`;
    }
    
    return {
      reportType: type,
      generatedAt: new Date().toISOString(),
      period: periodDescription,
      summary: analyticsData.overview,
      details: {
        ticketTrends: analyticsData.ticketTrends,
        groupPerformance: analyticsData.groupPerformance,
        slaMetrics: analyticsData.slaMetrics,
        categoryBreakdown: analyticsData.categoryBreakdown
      },
      recommendations: [
        "Focus on reducing resolution time for high priority tickets",
        "Improve SLA compliance through better resource allocation",
        "Consider additional training for underperforming groups",
        "Monitor trending issue categories for preventive measures"
      ]
    };
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const [user] = await db.insert(users).values(insertUser).returning();
    return user;
  }

  async updateUser(id: number, updates: Partial<InsertUser>): Promise<User | undefined> {
    const [user] = await db
      .update(users)
      .set(updates)
      .where(eq(users.id, id))
      .returning();
    return user;
  }

  async deleteUser(id: number): Promise<boolean> {
    const result = await db
      .delete(users)
      .where(eq(users.id, id));
    return (result.rowCount ?? 0) > 0;
  }

  // History methods
  async getTicketHistory(ticketId: number): Promise<TicketHistory[]> {
    return await db.select().from(ticketHistory)
      .where(eq(ticketHistory.ticketId, ticketId))
      .orderBy(desc(ticketHistory.timestamp));
  }

  async createTicketHistory(history: InsertTicketHistory): Promise<TicketHistory> {
    const [entry] = await db.insert(ticketHistory).values(history).returning();
    return entry;
  }

  async getChangeHistory(changeId: number): Promise<ChangeHistory[]> {
    return await db.select().from(changeHistory)
      .where(eq(changeHistory.changeId, changeId))
      .orderBy(desc(changeHistory.timestamp));
  }

  async createChangeHistory(history: InsertChangeHistory): Promise<ChangeHistory> {
    const [entry] = await db.insert(changeHistory).values(history).returning();
    return entry;
  }

  // Enhanced update methods with history tracking
  async updateTicketWithHistory(id: number, updates: Partial<InsertTicket>, userId: number, notes?: string): Promise<Ticket | undefined> {
    const existingTicket = await this.getTicket(id);
    if (!existingTicket) return undefined;

    let updatedData = { ...updates };

    // Track first response time
    if (!existingTicket.firstResponseAt && (updates.status === 'in-progress' || updates.assignedTo)) {
      updatedData.firstResponseAt = new Date();
    }

    // Track resolution time
    if (!existingTicket.resolvedAt && updates.status === 'resolved') {
      updatedData.resolvedAt = new Date();
    }

    const [updatedTicket] = await db
      .update(tickets)
      .set({ ...updatedData, updatedAt: new Date() })
      .where(eq(tickets.id, id))
      .returning();

    // Update SLA metrics
    await this.updateTicketSLA(id);

    // Create history entries for changes
    for (const [field, newValue] of Object.entries(updates)) {
      if (field !== 'updatedAt' && existingTicket[field as keyof Ticket] !== newValue) {
        let action = `updated_${field}`;
        let displayNewValue = String(newValue || '');
        
        // Special handling for assignedTo field to show user names
        if (field === 'assignedTo') {
          if (newValue) {
            const assignedUser = await this.getUser(Number(newValue));
            displayNewValue = assignedUser ? assignedUser.name : `User ${newValue}`;
            action = `assigned to ${displayNewValue}`;
          } else {
            action = 'unassigned';
            displayNewValue = '';
          }
        }
        
        await this.createTicketHistory({
          ticketId: id,
          action,
          field,
          oldValue: String(existingTicket[field as keyof Ticket] || ''),
          newValue: displayNewValue,
          userId,
          notes,
        });
      }
    }

    return updatedTicket;
  }

  async updateChangeWithHistory(id: number, updates: Partial<InsertChange>, userId: number, notes?: string): Promise<Change | undefined> {
    const existingChange = await this.getChange(id);
    if (!existingChange) return undefined;

    const [updatedChange] = await db
      .update(changes)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(changes.id, id))
      .returning();

    // Create history entry for status changes
    if (updates.status && existingChange.status !== updates.status) {
      await this.createChangeHistory({
        changeId: id,
        action: 'status_changed',
        userId,
        notes,
        previousStatus: existingChange.status,
        newStatus: updates.status,
      });
    }

    return updatedChange;
  }

  // Product methods
  async getProducts(): Promise<Product[]> {
    return await db.select().from(products).orderBy(products.name);
  }

  async getProduct(id: number): Promise<Product | undefined> {
    const [product] = await db.select().from(products).where(eq(products.id, id));
    return product;
  }

  async createProduct(insertProduct: InsertProduct): Promise<Product> {
    const [product] = await db.insert(products).values(insertProduct).returning();
    return product;
  }

  async updateProduct(id: number, updates: Partial<InsertProduct>): Promise<Product | undefined> {
    const [product] = await db
      .update(products)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(products.id, id))
      .returning();
    return product;
  }

  async deleteProduct(id: number): Promise<boolean> {
    const result = await db.delete(products).where(eq(products.id, id));
    return (result.rowCount || 0) > 0;
  }

  // Attachment methods
  async getAttachments(ticketId?: number, changeId?: number): Promise<Attachment[]> {
    const conditions = [];
    if (ticketId) conditions.push(eq(attachments.ticketId, ticketId));
    if (changeId) conditions.push(eq(attachments.changeId, changeId));
    
    if (conditions.length === 0) {
      return await db.select().from(attachments).orderBy(desc(attachments.createdAt));
    }
    
    return await db.select().from(attachments).where(and(...conditions)).orderBy(desc(attachments.createdAt));
  }

  async getAttachment(id: number): Promise<Attachment | undefined> {
    const [attachment] = await db.select().from(attachments).where(eq(attachments.id, id));
    return attachment;
  }

  async createAttachment(insertAttachment: InsertAttachment): Promise<Attachment> {
    const [attachment] = await db.insert(attachments).values(insertAttachment).returning();
    return attachment;
  }

  async deleteAttachment(id: number): Promise<boolean> {
    const result = await db.delete(attachments).where(eq(attachments.id, id));
    return (result.rowCount || 0) > 0;
  }

  // SLA methods
  async getSLAMetrics(): Promise<{
    totalTickets: number;
    responseMetrics: {
      met: number;
      breached: number;
      pending: number;
      percentage: number;
    };
    resolutionMetrics: {
      met: number;
      breached: number;
      pending: number;
      percentage: number;
    };
    averageResponseTime: number;
    averageResolutionTime: number;
    metricsByProduct: Record<string, {
      total: number;
      responseMet: number;
      resolutionMet: number;
      responsePercentage: number;
      resolutionPercentage: number;
      averageResponseTime: number;
      averageResolutionTime: number;
    }>;
  }> {
    const allTickets = await db.select().from(tickets);
    
    const responseMetrics = {
      met: allTickets.filter(t => t.slaResponseMet === 'met').length,
      breached: allTickets.filter(t => t.slaResponseMet === 'breached').length,
      pending: allTickets.filter(t => t.slaResponseMet === 'pending').length,
      percentage: 0
    };
    
    const resolutionMetrics = {
      met: allTickets.filter(t => t.slaResolutionMet === 'met').length,
      breached: allTickets.filter(t => t.slaResolutionMet === 'breached').length,
      pending: allTickets.filter(t => t.slaResolutionMet === 'pending').length,
      percentage: 0
    };

    responseMetrics.percentage = responseMetrics.met + responseMetrics.breached > 0 
      ? (responseMetrics.met / (responseMetrics.met + responseMetrics.breached)) * 100 
      : 0;

    resolutionMetrics.percentage = resolutionMetrics.met + resolutionMetrics.breached > 0 
      ? (resolutionMetrics.met / (resolutionMetrics.met + resolutionMetrics.breached)) * 100 
      : 0;

    // Calculate average times
    const respondedTickets = allTickets.filter(t => t.firstResponseAt);
    const resolvedTickets = allTickets.filter(t => t.resolvedAt);

    const averageResponseTime = respondedTickets.length > 0
      ? respondedTickets.reduce((acc, t) => {
          const responseTime = (new Date(t.firstResponseAt!).getTime() - new Date(t.createdAt).getTime()) / (1000 * 60);
          return acc + responseTime;
        }, 0) / respondedTickets.length
      : 0;

    const averageResolutionTime = resolvedTickets.length > 0
      ? resolvedTickets.reduce((acc, t) => {
          const resolutionTime = (new Date(t.resolvedAt!).getTime() - new Date(t.createdAt).getTime()) / (1000 * 60);
          return acc + resolutionTime;
        }, 0) / resolvedTickets.length
      : 0;

    // Get all unique products
    const allProducts = await this.getProducts();
    const productNames = allProducts.map(p => p.name);
    
    // Metrics by product
    const metricsByProduct = productNames.reduce((acc, productName) => {
      const productTickets = allTickets.filter(t => t.product === productName);
      acc[productName] = {
        total: productTickets.length,
        responseMet: productTickets.filter(t => t.slaResponseMet === 'met').length,
        resolutionMet: productTickets.filter(t => t.slaResolutionMet === 'met').length,
        responsePercentage: productTickets.filter(t => t.slaResponseMet !== 'pending').length > 0
          ? (productTickets.filter(t => t.slaResponseMet === 'met').length / productTickets.filter(t => t.slaResponseMet !== 'pending').length) * 100
          : 0,
        resolutionPercentage: productTickets.filter(t => t.slaResolutionMet !== 'pending').length > 0
          ? (productTickets.filter(t => t.slaResolutionMet === 'met').length / productTickets.filter(t => t.slaResolutionMet !== 'pending').length) * 100
          : 0,
        averageResponseTime: productTickets.filter(t => t.firstResponseAt).length > 0
          ? productTickets
              .filter(t => t.firstResponseAt)
              .reduce((sum, t) => sum + ((new Date(t.firstResponseAt!).getTime() - new Date(t.createdAt).getTime()) / (1000 * 60)), 0) / productTickets.filter(t => t.firstResponseAt).length
          : 0,
        averageResolutionTime: productTickets.filter(t => t.resolvedAt).length > 0
          ? productTickets
              .filter(t => t.resolvedAt)
              .reduce((sum, t) => sum + ((new Date(t.resolvedAt!).getTime() - new Date(t.createdAt).getTime()) / (1000 * 60)), 0) / productTickets.filter(t => t.resolvedAt).length
          : 0
      };
      return acc;
    }, {} as Record<string, any>);

    // Add tickets without products as "Unassigned"
    const unassignedTickets = allTickets.filter(t => !t.product);
    if (unassignedTickets.length > 0) {
      metricsByProduct['Unassigned'] = {
        total: unassignedTickets.length,
        responseMet: unassignedTickets.filter(t => t.slaResponseMet === 'met').length,
        resolutionMet: unassignedTickets.filter(t => t.slaResolutionMet === 'met').length,
        responsePercentage: unassignedTickets.filter(t => t.slaResponseMet !== 'pending').length > 0
          ? (unassignedTickets.filter(t => t.slaResponseMet === 'met').length / unassignedTickets.filter(t => t.slaResponseMet !== 'pending').length) * 100
          : 0,
        resolutionPercentage: unassignedTickets.filter(t => t.slaResolutionMet !== 'pending').length > 0
          ? (unassignedTickets.filter(t => t.slaResolutionMet === 'met').length / unassignedTickets.filter(t => t.slaResolutionMet !== 'pending').length) * 100
          : 0,
        averageResponseTime: unassignedTickets.filter(t => t.firstResponseAt).length > 0
          ? unassignedTickets
              .filter(t => t.firstResponseAt)
              .reduce((sum, t) => sum + ((new Date(t.firstResponseAt!).getTime() - new Date(t.createdAt).getTime()) / (1000 * 60)), 0) / unassignedTickets.filter(t => t.firstResponseAt).length
          : 0,
        averageResolutionTime: unassignedTickets.filter(t => t.resolvedAt).length > 0
          ? unassignedTickets
              .filter(t => t.resolvedAt)
              .reduce((sum, t) => sum + ((new Date(t.resolvedAt!).getTime() - new Date(t.createdAt).getTime()) / (1000 * 60)), 0) / unassignedTickets.filter(t => t.resolvedAt).length
          : 0
      };
    }

    return {
      totalTickets: allTickets.length,
      responseMetrics,
      resolutionMetrics,
      averageResponseTime,
      averageResolutionTime,
      metricsByProduct
    };
  }

  async updateTicketSLA(id: number): Promise<void> {
    const ticket = await this.getTicket(id);
    if (!ticket) return;

    const slaTargets = this.getSLATargets(ticket.priority);
    
    const slaResponseMet = this.calculateSLAStatus(
      new Date(ticket.createdAt),
      slaTargets.response,
      ticket.firstResponseAt ? new Date(ticket.firstResponseAt) : undefined
    );

    const slaResolutionMet = this.calculateSLAStatus(
      new Date(ticket.createdAt),
      slaTargets.resolution,
      ticket.resolvedAt ? new Date(ticket.resolvedAt) : undefined
    );

    await db.update(tickets)
      .set({
        slaTargetResponse: slaTargets.response,
        slaTargetResolution: slaTargets.resolution,
        slaResponseMet,
        slaResolutionMet,
        updatedAt: new Date()
      })
      .where(eq(tickets.id, id));
  }

  async refreshSLAMetrics(): Promise<void> {
    console.log('[SLA] Starting monthly SLA metrics refresh...');
    
    // Get all tickets that need SLA recalculation
    const allTickets = await db.select().from(tickets);
    
    for (const ticket of allTickets) {
      const slaTargets = this.getSLATargets(ticket.priority);
      
      const slaResponseMet = this.calculateSLAStatus(
        new Date(ticket.createdAt),
        slaTargets.response,
        ticket.firstResponseAt ? new Date(ticket.firstResponseAt) : undefined
      );

      const slaResolutionMet = this.calculateSLAStatus(
        new Date(ticket.createdAt),
        slaTargets.resolution,
        ticket.resolvedAt ? new Date(ticket.resolvedAt) : undefined
      );

      await db.update(tickets)
        .set({
          slaTargetResponse: slaTargets.response,
          slaTargetResolution: slaTargets.resolution,
          slaResponseMet,
          slaResolutionMet,
          updatedAt: new Date()
        })
        .where(eq(tickets.id, ticket.id));
    }
    
    console.log(`[SLA] Refreshed SLA metrics for ${allTickets.length} tickets`);
  }

  async autoCloseResolvedTickets(): Promise<{ closedCount: number; tickets: Ticket[] }> {
    // Find resolved tickets older than 3 days
    const threeDaysAgo = new Date();
    threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
    
    const resolvedTickets = await db.select()
      .from(tickets)
      .where(and(
        eq(tickets.status, 'resolved'),
        sql`resolved_at IS NOT NULL AND resolved_at < ${threeDaysAgo.toISOString()}`
      ));

    const closedTickets: Ticket[] = [];

    for (const ticket of resolvedTickets) {
      // Update ticket status to closed
      const [updatedTicket] = await db.update(tickets)
        .set({
          status: 'closed',
          updatedAt: new Date()
        })
        .where(eq(tickets.id, ticket.id))
        .returning();

      if (updatedTicket) {
        closedTickets.push(updatedTicket);

        // Create history entry for auto-closure
        await this.createTicketHistory({
          ticketId: ticket.id,
          action: 'auto_closed',
          field: 'status',
          oldValue: 'resolved',
          newValue: 'closed',
          userId: 1, // System user
          notes: 'Automatically closed after 3 days in resolved status'
        });
      }
    }

    return {
      closedCount: closedTickets.length,
      tickets: closedTickets
    };
  }

  // Approval routing methods
  async getApprovalRouting(): Promise<ApprovalRouting[]> {
    return await db.select().from(approvalRouting).orderBy(desc(approvalRouting.createdAt));
  }

  async createApprovalRouting(insertApprovalRouting: InsertApprovalRouting): Promise<ApprovalRouting> {
    const [routing] = await db.insert(approvalRouting).values({
      ...insertApprovalRouting,
      updatedAt: new Date()
    }).returning();
    return routing;
  }

  async updateApprovalRouting(id: number, updates: Partial<InsertApprovalRouting>): Promise<ApprovalRouting | undefined> {
    const [routing] = await db.update(approvalRouting)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(approvalRouting.id, id))
      .returning();
    return routing;
  }

  async deleteApprovalRouting(id: number): Promise<boolean> {
    const result = await db.delete(approvalRouting)
      .where(eq(approvalRouting.id, id));
    return (result.rowCount || 0) > 0;
  }

  async getApprovalWorkflow(productId: number, riskLevel: string): Promise<ApprovalRouting[]> {
    const routings = await db.select()
      .from(approvalRouting)
      .where(and(
        eq(approvalRouting.productId, productId),
        eq(approvalRouting.riskLevel, riskLevel),
        eq(approvalRouting.isActive, 'true')
      ))
      .orderBy(approvalRouting.approvalLevel);

    return routings;
  }

  // Change approval methods
  async getChangeApprovals(changeId: number): Promise<ChangeApproval[]> {
    return await db.select()
      .from(changeApprovals)
      .where(eq(changeApprovals.changeId, changeId))
      .orderBy(changeApprovals.approvalLevel);
  }

  async createChangeApproval(insertApproval: InsertChangeApproval): Promise<ChangeApproval> {
    const [approval] = await db.insert(changeApprovals).values({
      ...insertApproval,
      updatedAt: new Date()
    }).returning();
    return approval;
  }

  async updateChangeApproval(id: number, updates: Partial<InsertChangeApproval>): Promise<ChangeApproval | undefined> {
    const [approval] = await db.update(changeApprovals)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(changeApprovals.id, id))
      .returning();
    return approval;
  }

  async initializeChangeApprovals(changeId: number, productId: number, riskLevel: string, changeType?: string): Promise<void> {
    // Skip approval workflow for Standard changes
    if (changeType === 'standard') {
      return;
    }
    
    const workflow = await this.getApprovalWorkflow(productId, riskLevel);
    
    for (const routing of workflow) {
      await this.createChangeApproval({
        changeId,
        approverId: routing.approverId,
        approvalLevel: routing.approvalLevel,
        status: 'pending'
      });
    }
  }

  async processApproval(changeId: number, approverId: number, action: 'approved' | 'rejected', comments?: string): Promise<{ approved: boolean; nextLevel?: number; completed: boolean }> {
    // Find the current approval
    const [currentApproval] = await db.select()
      .from(changeApprovals)
      .where(and(
        eq(changeApprovals.changeId, changeId),
        eq(changeApprovals.approverId, approverId),
        eq(changeApprovals.status, 'pending')
      ))
      .limit(1);

    if (!currentApproval) {
      throw new Error('No pending approval found for this user');
    }

    // Update the current approval
    await this.updateChangeApproval(currentApproval.id, {
      status: action,
      approvedAt: new Date(),
      comments
    });

    if (action === 'rejected') {
      // If rejected, update the change status and stop the workflow
      await this.updateChange(changeId, { status: 'rejected' });
      return { approved: false, completed: true };
    }

    // Check if there are more approvals needed
    const allApprovals = await this.getChangeApprovals(changeId);
    const pendingApprovals = allApprovals.filter(a => a.status === 'pending');
    
    if (pendingApprovals.length === 0) {
      // All approvals completed, update change status to approved
      await this.updateChange(changeId, { status: 'approved' });
      return { approved: true, completed: true };
    }

    // Find the next approval level
    const nextApproval = pendingApprovals.find(a => a.approvalLevel === currentApproval.approvalLevel + 1);
    
    return { 
      approved: true, 
      nextLevel: nextApproval?.approvalLevel,
      completed: false 
    };
  }

  // Overdue change monitoring methods
  async checkOverdueChanges(): Promise<Change[]> {
    const now = new Date();
    
    // Find changes that are past their end date and not completed/failed/cancelled
    const overdueChanges = await db.select()
      .from(changes)
      .where(and(
        not(isNull(changes.endDate)),
        lte(changes.endDate, now),
        notInArray(changes.status, ['completed', 'failed', 'cancelled', 'rejected']),
        eq(changes.isOverdue, 'false')
      ));
    
    return overdueChanges;
  }

  async markChangeAsOverdue(changeId: number): Promise<void> {
    await db.update(changes)
      .set({ 
        isOverdue: 'true',
        updatedAt: new Date()
      })
      .where(eq(changes.id, changeId));
  }

  async sendOverdueNotifications(): Promise<{ notificationCount: number; changes: Change[] }> {
    const overdueChanges = await this.checkOverdueChanges();
    let notificationCount = 0;
    
    for (const change of overdueChanges) {
      // Mark as overdue first
      await this.markChangeAsOverdue(change.id);
      
      // Get all managers for notification
      const managers = await db.select()
        .from(users)
        .where(eq(users.role, 'manager'));
      
      // Import email service dynamically to avoid circular imports
      const { emailService } = await import('./email-sendgrid');
      
      // Send notifications to all managers
      for (const manager of managers) {
        try {
          await emailService.sendChangeOverdueEmail(change, manager.email, manager.name);
          notificationCount++;
        } catch (error) {
          console.error(`Failed to send overdue notification to ${manager.email}:`, error);
        }
      }
      
      // Record notification sent timestamp
      await db.update(changes)
        .set({ 
          overdueNotificationSent: new Date(),
          updatedAt: new Date()
        })
        .where(eq(changes.id, change.id));
    }
    
    return { notificationCount, changes: overdueChanges };
  }

  // Settings persistence methods
  async getSetting(key: string): Promise<Setting | undefined> {
    const [setting] = await db.select()
      .from(settings)
      .where(eq(settings.key, key))
      .limit(1);
    return setting || undefined;
  }

  async setSetting(key: string, value: string, description?: string): Promise<Setting> {
    const existing = await this.getSetting(key);
    
    if (existing) {
      const [updated] = await db.update(settings)
        .set({ 
          value, 
          description: description || existing.description,
          updatedAt: new Date()
        })
        .where(eq(settings.id, existing.id))
        .returning();
      return updated;
    } else {
      const [created] = await db.insert(settings)
        .values({ key, value, description })
        .returning();
      return created;
    }
  }

  async getSettings(): Promise<Setting[]> {
    return await db.select().from(settings).orderBy(settings.key);
  }

  // Groups methods implementation
  async getGroups(): Promise<Group[]> {
    return await db.select().from(groups).orderBy(groups.name);
  }

  async getGroup(id: number): Promise<Group | undefined> {
    const [group] = await db.select().from(groups).where(eq(groups.id, id));
    return group;
  }

  async getGroupByName(name: string): Promise<Group | undefined> {
    const [group] = await db.select().from(groups).where(eq(groups.name, name));
    return group;
  }

  async createGroup(group: InsertGroup): Promise<Group> {
    const [created] = await db.insert(groups).values(group).returning();
    return created;
  }

  async updateGroup(id: number, updates: Partial<InsertGroup>): Promise<Group | undefined> {
    const [updated] = await db.update(groups)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(groups.id, id))
      .returning();
    return updated;
  }

  async deleteGroup(id: number): Promise<boolean> {
    const result = await db.delete(groups).where(eq(groups.id, id));
    return (result.rowCount ?? 0) > 0;
  }

  async getActiveGroups(): Promise<Group[]> {
    return await db.select().from(groups)
      .where(eq(groups.isActive, 'true'))
      .orderBy(groups.name);
  }

  // Categories methods implementation
  async getCategories(): Promise<Category[]> {
    return await db.select().from(categories)
      .orderBy(categories.name);
  }

  async getActiveCategories(): Promise<Category[]> {
    return await db.select().from(categories)
      .where(eq(categories.isActive, 'true'))
      .orderBy(categories.name);
  }

  async getCategoriesByProduct(productId: number): Promise<Category[]> {
    return await db.select().from(categories)
      .where(and(eq(categories.productId, productId), eq(categories.isActive, 'true')))
      .orderBy(categories.name);
  }

  async createCategory(category: InsertCategory): Promise<Category> {
    const [created] = await db.insert(categories)
      .values({ ...category, createdAt: new Date(), updatedAt: new Date() })
      .returning();
    return created;
  }

  async updateCategory(id: number, updates: Partial<InsertCategory>): Promise<Category | undefined> {
    const [updated] = await db.update(categories)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(categories.id, id))
      .returning();
    return updated;
  }

  async deleteCategory(id: number): Promise<boolean> {
    const result = await db.delete(categories).where(eq(categories.id, id));
    return (result.rowCount ?? 0) > 0;
  }
}

export const storage = new DatabaseStorage();