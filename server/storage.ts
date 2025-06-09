import { tickets, changes, users, ticketHistory, changeHistory, type Ticket, type InsertTicket, type Change, type InsertChange, type User, type InsertUser, type TicketHistory, type InsertTicketHistory, type ChangeHistory, type InsertChangeHistory } from "@shared/schema";
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
}

export class DatabaseStorage implements IStorage {
  constructor() {
    this.initializeData();
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

        // Create sample tickets
        const sampleTickets: InsertTicket[] = [
          {
            title: "Computer won't start",
            description: "My laptop won't turn on when I press the power button. I've tried holding it for 10 seconds but nothing happens.",
            status: "open",
            priority: "high",
            category: "hardware",
            product: "Dell Laptop",
            assignedTo: "John Doe",
            requesterId: 4,
          },
          {
            title: "Email not syncing",
            description: "Outlook is not receiving new emails. Last email received was yesterday at 3 PM.",
            status: "in-progress",
            priority: "medium",
            category: "software",
            product: "Microsoft Outlook",
            assignedTo: "John Doe",
            requesterId: 4,
          },
          {
            title: "VPN connection issues",
            description: "Cannot connect to company VPN from home. Getting 'authentication failed' error.",
            status: "resolved",
            priority: "medium",
            category: "network",
            product: "Cisco VPN",
            assignedTo: "Jane Smith",
            requesterId: 3,
          },
        ];

        for (const ticket of sampleTickets) {
          await this.createTicket(ticket);
        }

        // Create sample changes
        const sampleChanges: InsertChange[] = [
          {
            title: "Server OS Upgrade",
            description: "Upgrade production servers from Windows Server 2019 to Windows Server 2022",
            status: "pending",
            priority: "high",
            category: "infrastructure",
            riskLevel: "high",
            requestedBy: "Mike Wilson",
            approvedBy: "Jane Smith",
            plannedDate: new Date("2024-02-15"),
            implementedBy: null,
          },
          {
            title: "New Firewall Rules",
            description: "Implement new firewall rules to block social media access during work hours",
            status: "approved",
            priority: "medium",
            category: "security",
            riskLevel: "medium",
            requestedBy: "Jane Smith",
            approvedBy: "Jane Smith",
            plannedDate: new Date("2024-02-10"),
            implementedBy: "John Doe",
          },
        ];

        for (const change of sampleChanges) {
          await this.createChange(change);
        }
      }
    } catch (error) {
      console.error("Failed to initialize database data:", error);
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
    const [ticket] = await db.insert(tickets).values(insertTicket).returning();
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

    const [updatedTicket] = await db
      .update(tickets)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(tickets.id, id))
      .returning();

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
}

export const storage = new DatabaseStorage();