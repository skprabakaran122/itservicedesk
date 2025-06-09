import { tickets, changes, users, type Ticket, type InsertTicket, type Change, type InsertChange, type User, type InsertUser } from "@shared/schema";

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
}

export class MemStorage implements IStorage {
  private tickets: Map<number, Ticket>;
  private changes: Map<number, Change>;
  private users: Map<number, User>;
  private currentTicketId: number;
  private currentChangeId: number;
  private currentUserId: number;

  constructor() {
    this.tickets = new Map();
    this.changes = new Map();
    this.users = new Map();
    this.currentTicketId = 1;
    this.currentChangeId = 1;
    this.currentUserId = 1;
    
    // Initialize with sample data
    this.initializeData();
  }

  private async initializeData() {
    // Sample users
    const sampleUsers: InsertUser[] = [
      { username: "john.doe", email: "john.doe@company.com", password: "password123", role: "technician", name: "John Doe" },
      { username: "jane.smith", email: "jane.smith@company.com", password: "password123", role: "admin", name: "Jane Smith" },
      { username: "mike.wilson", email: "mike.wilson@company.com", password: "password123", role: "manager", name: "Mike Wilson" },
      { username: "sarah.jones", email: "sarah.jones@company.com", password: "password123", role: "user", name: "Sarah Jones" },
    ];

    for (const user of sampleUsers) {
      await this.createUser(user);
    }

    // Sample tickets
    const sampleTickets: InsertTicket[] = [
      {
        title: "Computer won't start",
        description: "My workstation computer is not turning on when I press the power button. No lights or fans are running.",
        status: "open",
        priority: "high",
        category: "hardware",
        product: "Dell OptiPlex 7090",
        assignedTo: "John Doe",
        requesterId: 4,
      },
      {
        title: "Software installation request",
        description: "Need Adobe Photoshop installed on my workstation for the marketing team projects.",
        status: "in-progress",
        priority: "medium",
        category: "software",
        product: "Adobe Creative Suite",
        assignedTo: "John Doe",
        requesterId: 3,
      },
      {
        title: "Network connectivity issues",
        description: "Internet connection is very slow and intermittent. Cannot access shared drives or email consistently.",
        status: "resolved",
        priority: "high",
        category: "network",
        product: null,
        assignedTo: "Jane Smith",
        requesterId: 4,
      },
      {
        title: "Office 365 access issue",
        description: "Cannot access Office 365 applications and getting authentication errors.",
        status: "closed",
        priority: "low",
        category: "product",
        product: "Microsoft Office 365",
        assignedTo: "John Doe",
        requesterId: 3,
      },
    ];

    for (const ticket of sampleTickets) {
      await this.createTicket(ticket);
    }

    // Sample changes
    const sampleChanges: InsertChange[] = [
      {
        title: "Server OS Upgrade",
        description: "Upgrade main file server from Windows Server 2019 to Windows Server 2022",
        status: "pending",
        priority: "high",
        category: "system",
        requestedBy: "Jane Smith",
        riskLevel: "high",
        rollbackPlan: "Restore from VM snapshot taken before upgrade",
        plannedDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days from now
      },
      {
        title: "Firewall Rule Update",
        description: "Add new firewall rules to allow access to new application server",
        status: "approved",
        priority: "medium",
        category: "infrastructure",
        requestedBy: "John Doe",
        approvedBy: "Mike Wilson",
        riskLevel: "medium",
        rollbackPlan: "Remove added rules and restore previous configuration",
        plannedDate: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000), // 2 days from now
      },
      {
        title: "Email System Maintenance",
        description: "Scheduled maintenance window for email server updates and optimization",
        status: "completed",
        priority: "medium",
        category: "system",
        requestedBy: "Jane Smith",
        approvedBy: "Mike Wilson",
        implementedBy: "Jane Smith",
        riskLevel: "low",
        rollbackPlan: "Restore from backup if issues arise",
        completedDate: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000), // 3 days ago
      },
    ];

    for (const change of sampleChanges) {
      await this.createChange(change);
    }
  }

  // Ticket methods
  async getTickets(): Promise<Ticket[]> {
    return Array.from(this.tickets.values());
  }

  async getTicket(id: number): Promise<Ticket | undefined> {
    return this.tickets.get(id);
  }

  async createTicket(insertTicket: InsertTicket): Promise<Ticket> {
    const id = this.currentTicketId++;
    const now = new Date();
    const ticket: Ticket = { 
      ...insertTicket, 
      assignedTo: insertTicket.assignedTo || null,
      product: insertTicket.product || null,
      id, 
      createdAt: now, 
      updatedAt: now 
    };
    this.tickets.set(id, ticket);
    return ticket;
  }

  async updateTicket(id: number, updates: Partial<InsertTicket>): Promise<Ticket | undefined> {
    const ticket = this.tickets.get(id);
    if (!ticket) return undefined;
    
    const updatedTicket: Ticket = {
      ...ticket,
      ...updates,
      updatedAt: new Date(),
    };
    this.tickets.set(id, updatedTicket);
    return updatedTicket;
  }

  async searchTickets(filters: {
    status?: string;
    priority?: string;
    category?: string;
    assignedTo?: string;
  }): Promise<Ticket[]> {
    const allTickets = Array.from(this.tickets.values());
    
    return allTickets.filter(ticket => {
      if (filters.status && ticket.status !== filters.status) return false;
      if (filters.priority && ticket.priority !== filters.priority) return false;
      if (filters.category && ticket.category !== filters.category) return false;
      if (filters.assignedTo && ticket.assignedTo !== filters.assignedTo) return false;
      return true;
    });
  }

  // Change methods
  async getChanges(): Promise<Change[]> {
    return Array.from(this.changes.values());
  }

  async getChange(id: number): Promise<Change | undefined> {
    return this.changes.get(id);
  }

  async createChange(insertChange: InsertChange): Promise<Change> {
    const id = this.currentChangeId++;
    const now = new Date();
    const change: Change = { 
      ...insertChange, 
      approvedBy: insertChange.approvedBy || null,
      implementedBy: insertChange.implementedBy || null,
      plannedDate: insertChange.plannedDate || null,
      completedDate: insertChange.completedDate || null,
      rollbackPlan: insertChange.rollbackPlan || null,
      id, 
      createdAt: now, 
      updatedAt: now 
    };
    this.changes.set(id, change);
    return change;
  }

  async updateChange(id: number, updates: Partial<InsertChange>): Promise<Change | undefined> {
    const change = this.changes.get(id);
    if (!change) return undefined;
    
    const updatedChange: Change = {
      ...change,
      ...updates,
      updatedAt: new Date(),
    };
    this.changes.set(id, updatedChange);
    return updatedChange;
  }

  async searchChanges(filters: {
    status?: string;
    priority?: string;
    category?: string;
    requestedBy?: string;
  }): Promise<Change[]> {
    const allChanges = Array.from(this.changes.values());
    
    return allChanges.filter(change => {
      if (filters.status && change.status !== filters.status) return false;
      if (filters.priority && change.priority !== filters.priority) return false;
      if (filters.category && change.category !== filters.category) return false;
      if (filters.requestedBy && change.requestedBy !== filters.requestedBy) return false;
      return true;
    });
  }

  // User methods
  async getUsers(): Promise<User[]> {
    return Array.from(this.users.values());
  }

  async getUser(id: number): Promise<User | undefined> {
    return this.users.get(id);
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    return Array.from(this.users.values()).find(
      (user) => user.username === username,
    );
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const id = this.currentUserId++;
    const user: User = { 
      ...insertUser, 
      id,
      createdAt: new Date()
    };
    this.users.set(id, user);
    return user;
  }
}

export const storage = new MemStorage();
