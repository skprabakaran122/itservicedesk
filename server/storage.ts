import { tickets, changes, users, ticketHistory, changeHistory, products, attachments, type Ticket, type InsertTicket, type Change, type InsertChange, type User, type InsertUser, type TicketHistory, type InsertTicketHistory, type ChangeHistory, type InsertChangeHistory, type Product, type InsertProduct, type Attachment, type InsertAttachment } from "@shared/schema";
import { db } from "./db";
import { eq, and, desc } from "drizzle-orm";

export interface IStorage {
  // Ticket methods
  getTickets(): Promise<Ticket[]>;
  getTicket(id: number): Promise<Ticket | undefined>;
  createTicket(ticket: InsertTicket): Promise<Ticket>;
  updateTicket(id: number, updates: Partial<InsertTicket>): Promise<Ticket | undefined>;
  searchTickets(filters: {
    status?: string;
    priority?: string;
    category?: string;
    assignedTo?: string;
  }): Promise<Ticket[]>;
  
  // Change methods
  getChanges(): Promise<Change[]>;
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
  createUser(user: InsertUser): Promise<User>;
  
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
  createAttachment(attachment: InsertAttachment): Promise<Attachment>;
  deleteAttachment(id: number): Promise<boolean>;
  
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
    metricsByProduct: Record<string, any>;
  }>;
  updateTicketSLA(id: number): Promise<void>;
}

export class DatabaseStorage implements IStorage {
  constructor() {
    this.initializeData();
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

  private async initializeData() {
    try {
      // Check if users exist, if not create sample users
      const existingUsers = await this.getUsers();
      if (existingUsers.length === 0) {
        const sampleUsers: InsertUser[] = [
          { username: "john.doe", email: "john.doe@company.com", password: "password123", role: "technician", name: "John Doe" },
          { username: "jane.smith", email: "jane.smith@company.com", password: "password123", role: "admin", name: "Jane Smith" },
          { username: "mike.wilson", email: "mike.wilson@company.com", password: "password123", role: "manager", name: "Mike Wilson" },
          { username: "sarah.jones", email: "sarah.jones@company.com", password: "password123", role: "user", name: "Sarah Jones" },
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
    return await db.select().from(tickets).orderBy(tickets.createdAt);
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
  }): Promise<Ticket[]> {
    const conditions = [];
    
    if (filters.status) conditions.push(eq(tickets.status, filters.status));
    if (filters.priority) conditions.push(eq(tickets.priority, filters.priority));
    if (filters.category) conditions.push(eq(tickets.category, filters.category));
    if (filters.assignedTo) conditions.push(eq(tickets.assignedTo, filters.assignedTo));

    if (conditions.length === 0) {
      return await this.getTickets();
    }

    return await db.select().from(tickets).where(and(...conditions));
  }

  // Change methods
  async getChanges(): Promise<Change[]> {
    return await db.select().from(changes).orderBy(changes.createdAt);
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

  async createUser(insertUser: InsertUser): Promise<User> {
    const [user] = await db.insert(users).values(insertUser).returning();
    return user;
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
        await this.createTicketHistory({
          ticketId: id,
          action: `updated_${field}`,
          field,
          oldValue: String(existingTicket[field as keyof Ticket] || ''),
          newValue: String(newValue || ''),
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
    metricsByPriority: Record<string, any>;
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
}

export const storage = new DatabaseStorage();