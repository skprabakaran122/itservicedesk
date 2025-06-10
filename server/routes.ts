import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { z } from "zod";
import { insertTicketSchema, insertChangeSchema, insertProductSchema, insertAttachmentSchema } from "@shared/schema";
import session from "express-session";
import MemoryStore from "memorystore";

const MemoryStoreSession = MemoryStore(session);

export async function registerRoutes(app: Express): Promise<Server> {
  // Session middleware
  app.use(session({
    store: new MemoryStoreSession({
      checkPeriod: 86400000 // prune expired entries every 24h
    }),
    secret: process.env.SESSION_SECRET || 'your-secret-key-here',
    resave: false,
    saveUninitialized: true, // Create session for unauthenticated users
    name: 'connect.sid', // Standard session name
    cookie: {
      secure: false, // Set to true in production with HTTPS
      httpOnly: true, // Secure cookies
      maxAge: 24 * 60 * 60 * 1000, // 24 hours
      sameSite: 'lax'
    }
  }));
  // Authentication routes
  app.post("/api/auth/login", async (req, res) => {
    try {
      const { username, password } = req.body;
      const user = await storage.getUserByUsername(username);
      
      if (!user || user.password !== password) {
        return res.status(401).json({ message: "Invalid credentials" });
      }
      
      // Store user in session
      (req as any).session.user = user;
      
      const { password: _, ...userWithoutPassword } = user;
      res.json({ user: userWithoutPassword });
    } catch (error) {
      res.status(500).json({ message: "Login failed" });
    }
  });

  app.post("/api/auth/register", async (req, res) => {
    try {
      const userData = req.body;
      const existingUser = await storage.getUserByUsername(userData.username);
      
      if (existingUser) {
        return res.status(400).json({ message: "Username already exists" });
      }
      
      const user = await storage.createUser({
        ...userData,
        role: "user", // Default all new registrations to user role
        createdAt: new Date()
      });
      
      const { password: _, ...userWithoutPassword } = user;
      res.status(201).json({ user: userWithoutPassword });
    } catch (error) {
      res.status(500).json({ message: "Registration failed" });
    }
  });

  app.post("/api/auth/logout", async (req, res) => {
    try {
      (req as any).session.destroy((err: any) => {
        if (err) {
          return res.status(500).json({ message: "Logout failed" });
        }
        res.clearCookie('connect.sid');
        res.json({ message: "Logged out successfully" });
      });
    } catch (error) {
      res.status(500).json({ message: "Logout failed" });
    }
  });

  app.get("/api/auth/me", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      if (!currentUser) {
        return res.status(401).json({ message: "Not authenticated" });
      }
      
      const { password: _, ...userWithoutPassword } = currentUser;
      res.json({ user: userWithoutPassword });
    } catch (error) {
      res.status(500).json({ message: "Failed to get user session" });
    }
  });

  // User routes
  app.get("/api/users", async (req, res) => {
    try {
      const users = await storage.getUsers();
      const usersWithoutPasswords = users.map(({ password, ...user }) => user);
      res.json(usersWithoutPasswords);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch users" });
    }
  });

  app.post("/api/users", async (req, res) => {
    try {
      const userData = req.body;
      const existingUser = await storage.getUserByUsername(userData.username);
      
      if (existingUser) {
        return res.status(400).json({ message: "Username already exists" });
      }
      
      const user = await storage.createUser({
        ...userData,
        createdAt: new Date()
      });
      
      const { password: _, ...userWithoutPassword } = user;
      res.status(201).json(userWithoutPassword);
    } catch (error) {
      res.status(500).json({ message: "Failed to create user" });
    }
  });

  app.patch("/api/users/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const updates = req.body;
      
      const updatedUser = await storage.updateUser(id, updates);
      if (!updatedUser) {
        return res.status(404).json({ message: "User not found" });
      }
      
      const { password: _, ...userWithoutPassword } = updatedUser;
      res.json(userWithoutPassword);
    } catch (error) {
      res.status(500).json({ message: "Failed to update user" });
    }
  });

  app.delete("/api/users/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const success = await storage.deleteUser(id);
      
      if (!success) {
        return res.status(404).json({ message: "User not found" });
      }
      
      res.json({ success: true, message: "User deleted successfully" });
    } catch (error) {
      res.status(500).json({ message: "Failed to delete user" });
    }
  });

  // Ticket routes
  app.get("/api/tickets", async (req, res) => {
    try {
      const tickets = await storage.getTickets();
      res.json(tickets);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch tickets" });
    }
  });

  app.get("/api/tickets/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const ticket = await storage.getTicket(id);
      if (!ticket) {
        return res.status(404).json({ message: "Ticket not found" });
      }
      res.json(ticket);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch ticket" });
    }
  });

  app.post("/api/tickets", async (req, res) => {
    try {
      console.log('Session data:', (req as any).session);
      console.log('Session ID:', (req as any).sessionID);
      const currentUser = (req as any).session?.user;
      if (!currentUser) {
        console.log('No user in session, authentication failed');
        return res.status(401).json({ message: "Authentication required" });
      }

      const ticketData = insertTicketSchema.parse({
        ...req.body,
        requesterId: currentUser.id,
        createdAt: new Date(),
        updatedAt: new Date()
      });
      
      const ticket = await storage.createTicket(ticketData);
      res.status(201).json(ticket);
    } catch (error: any) {
      console.error('Ticket creation error:', error);
      res.status(400).json({ message: "Invalid ticket data", error: error.message });
    }
  });

  app.patch("/api/tickets/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { notes, userId, ...updates } = req.body;
      
      // Get current ticket and user information
      const ticket = await storage.getTicket(id);
      if (!ticket) {
        return res.status(404).json({ message: "Ticket not found" });
      }
      
      const currentUser = (req as any).session?.user;
      if (!currentUser) {
        return res.status(401).json({ message: "Authentication required" });
      }

      // Role-based access control
      if (currentUser.role === 'user') {
        // Regular users can only modify their own tickets
        if (ticket.requesterId !== currentUser.id) {
          return res.status(403).json({ message: "You can only modify your own tickets" });
        }
        
        // Regular users can only change status between specific values
        if (updates.status) {
          const allowedTransitions: Record<string, string[]> = {
            'open': ['closed'],
            'resolved': ['reopen'],
            'reopen': ['closed']
            // Note: 'closed' tickets cannot be reopened - they are final
          };
          
          const allowed = allowedTransitions[ticket.status] || [];
          if (!allowed.includes(updates.status)) {
            return res.status(403).json({ 
              message: "Invalid status change. You can only reopen resolved tickets or close your own open tickets. Closed tickets cannot be reopened." 
            });
          }
        }
        
        // Regular users cannot change assignee, priority, or category
        if (updates.assignedTo || updates.priority || updates.category) {
          return res.status(403).json({ 
            message: "You cannot modify ticket assignment, priority, or category" 
          });
        }
      } else {
        // Agents, managers, and admins cannot use "reopen" status
        // Only the original ticket requester can reopen tickets
        if (updates.status === 'reopen' && ticket.requesterId !== currentUser.id) {
          return res.status(403).json({ 
            message: "Only the original ticket requester can reopen resolved tickets" 
          });
        }
      }
      
      const updatedTicket = await storage.updateTicketWithHistory(id, updates, currentUser.id, notes);
      res.json(updatedTicket);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
    }
  });

  app.get("/api/tickets/:id/history", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const history = await storage.getTicketHistory(id);
      res.json(history);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch ticket history" });
    }
  });

  app.post("/api/tickets/:id/comments", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { notes, userId } = req.body;
      const history = await storage.createTicketHistory({
        ticketId: id,
        action: 'comment_added',
        userId: userId || 1,
        notes,
      });
      res.json(history);
    } catch (error) {
      res.status(500).json({ message: "Failed to add comment" });
    }
  });

  app.get("/api/tickets/search", async (req, res) => {
    try {
      const schema = z.object({
        status: z.string().optional(),
        priority: z.string().optional(),
        category: z.string().optional(),
        assignedTo: z.string().optional(),
      });

      const filters = schema.parse(req.query);
      const tickets = await storage.searchTickets(filters);
      res.json(tickets);
    } catch (error) {
      res.status(400).json({ message: "Invalid search parameters" });
    }
  });

  // Change routes
  app.get("/api/changes", async (req, res) => {
    try {
      const changes = await storage.getChanges();
      res.json(changes);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch changes" });
    }
  });

  app.get("/api/changes/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const change = await storage.getChange(id);
      if (!change) {
        return res.status(404).json({ message: "Change not found" });
      }
      res.json(change);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch change" });
    }
  });

  app.post("/api/changes", async (req, res) => {
    try {
      const changeData = insertChangeSchema.parse(req.body);
      
      // Create the change request
      const change = await storage.createChange(changeData);
      
      // Initialize multilevel approvals based on product and risk level
      if (changeData.product && changeData.riskLevel) {
        const products = await storage.getProducts();
        const product = products.find(p => p.name === changeData.product);
        
        if (product) {
          await storage.initializeChangeApprovals(change.id, product.id, changeData.riskLevel);
        }
      }
      
      res.status(201).json(change);
    } catch (error) {
      res.status(400).json({ message: "Invalid change data" });
    }
  });

  app.patch("/api/changes/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { notes, userId, ...updates } = req.body;
      const change = await storage.updateChangeWithHistory(id, updates, userId || 1, notes);
      if (!change) {
        return res.status(404).json({ message: "Change not found" });
      }
      res.json(change);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
    }
  });

  app.get("/api/changes/:id/history", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const history = await storage.getChangeHistory(id);
      res.json(history);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch change history" });
    }
  });

  app.post("/api/changes/:id/comments", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { notes, userId } = req.body;
      const history = await storage.createChangeHistory({
        changeId: id,
        action: 'comment_added',
        userId: userId || 1,
        notes,
      });
      res.json(history);
    } catch (error) {
      res.status(500).json({ message: "Failed to add comment" });
    }
  });

  app.get("/api/changes/search", async (req, res) => {
    try {
      const schema = z.object({
        status: z.string().optional(),
        priority: z.string().optional(),
        category: z.string().optional(),
        requestedBy: z.string().optional(),
      });

      const filters = schema.parse(req.query);
      const changes = await storage.searchChanges(filters);
      res.json(changes);
    } catch (error) {
      res.status(400).json({ message: "Invalid search parameters" });
    }
  });

  // User routes
  app.get("/api/users", async (req, res) => {
    try {
      const users = await storage.getUsers();
      res.json(users);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch users" });
    }
  });

  // Products management routes (Admin only)
  app.get("/api/products", async (req, res) => {
    try {
      const products = await storage.getProducts();
      res.json(products);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch products" });
    }
  });

  app.post("/api/products", async (req, res) => {
    try {
      const productData = insertProductSchema.parse(req.body);
      const product = await storage.createProduct(productData);
      res.status(201).json(product);
    } catch (error) {
      res.status(400).json({ message: "Invalid product data" });
    }
  });

  app.patch("/api/products/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const updates = req.body;
      const product = await storage.updateProduct(id, updates);
      if (!product) {
        return res.status(404).json({ message: "Product not found" });
      }
      res.json(product);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
    }
  });

  app.delete("/api/products/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const success = await storage.deleteProduct(id);
      if (!success) {
        return res.status(404).json({ message: "Product not found" });
      }
      res.json({ message: "Product deleted successfully" });
    } catch (error) {
      res.status(500).json({ message: "Failed to delete product" });
    }
  });

  // Attachments routes
  app.get("/api/attachments", async (req, res) => {
    try {
      const ticketId = req.query.ticketId ? parseInt(req.query.ticketId as string) : undefined;
      const changeId = req.query.changeId ? parseInt(req.query.changeId as string) : undefined;
      const attachments = await storage.getAttachments(ticketId, changeId);
      res.json(attachments);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch attachments" });
    }
  });

  app.post("/api/attachments", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      if (!currentUser) {
        return res.status(401).json({ message: "Authentication required" });
      }

      const attachmentData = insertAttachmentSchema.parse({
        ...req.body,
        uploadedBy: currentUser.id
      });
      const attachment = await storage.createAttachment(attachmentData);
      res.status(201).json(attachment);
    } catch (error: any) {
      console.error('Attachment creation error:', error);
      res.status(400).json({ message: "Invalid attachment data", error: error.message });
    }
  });

  app.get("/api/attachments/:id/download", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const attachment = await storage.getAttachment(id);
      
      if (!attachment) {
        return res.status(404).json({ message: "Attachment not found" });
      }

      if (!attachment.fileContent) {
        return res.status(404).json({ message: "File content not found" });
      }

      // Convert base64 back to binary
      const fileBuffer = Buffer.from(attachment.fileContent, 'base64');
      
      // Set appropriate headers for file download
      res.setHeader('Content-Type', attachment.mimeType);
      res.setHeader('Content-Disposition', `attachment; filename="${attachment.originalName}"`);
      res.setHeader('Content-Length', fileBuffer.length);
      
      // Send the actual file content
      res.send(fileBuffer);
    } catch (error) {
      console.error('Download error:', error);
      res.status(500).json({ message: "Failed to download attachment" });
    }
  });

  app.delete("/api/attachments/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const success = await storage.deleteAttachment(id);
      if (!success) {
        return res.status(404).json({ message: "Attachment not found" });
      }
      res.json({ message: "Attachment deleted successfully" });
    } catch (error) {
      res.status(500).json({ message: "Failed to delete attachment" });
    }
  });

  // SLA metrics routes
  app.get("/api/sla/metrics", async (req, res) => {
    try {
      const metrics = await storage.getSLAMetrics();
      res.json(metrics);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch SLA metrics" });
    }
  });

  app.post("/api/tickets/:id/sla-update", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      await storage.updateTicketSLA(id);
      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ message: "Failed to update SLA metrics" });
    }
  });

  // Approval routing endpoints
  app.get("/api/approval-routing", async (req, res) => {
    try {
      const routings = await storage.getApprovalRouting();
      res.json(routings);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch approval routing" });
    }
  });

  app.post("/api/approval-routing", async (req, res) => {
    try {
      const routingData = req.body;
      const routing = await storage.createApprovalRouting(routingData);
      res.status(201).json(routing);
    } catch (error) {
      res.status(400).json({ message: "Invalid approval routing data" });
    }
  });

  app.patch("/api/approval-routing/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const updates = req.body;
      const routing = await storage.updateApprovalRouting(id, updates);
      if (!routing) {
        return res.status(404).json({ message: "Approval routing not found" });
      }
      res.json(routing);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
    }
  });

  app.delete("/api/approval-routing/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const deleted = await storage.deleteApprovalRouting(id);
      if (!deleted) {
        return res.status(404).json({ message: "Approval routing not found" });
      }
      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ message: "Failed to delete approval routing" });
    }
  });

  // Change approval endpoints
  app.get("/api/changes/:id/approvals", async (req, res) => {
    try {
      const changeId = parseInt(req.params.id);
      const approvals = await storage.getChangeApprovals(changeId);
      res.json(approvals);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch change approvals" });
    }
  });

  app.post("/api/changes/:id/approve", async (req, res) => {
    try {
      const changeId = parseInt(req.params.id);
      const { approverId, action, comments } = req.body;
      
      const result = await storage.processApproval(changeId, approverId, action, comments);
      res.json(result);
    } catch (error: any) {
      res.status(400).json({ message: error?.message || "Failed to process approval" });
    }
  });

  // IT Support chatbot endpoint
  app.post("/api/chat", async (req, res) => {
    try {
      const schema = z.object({
        message: z.string().min(1),
      });

      const { message } = schema.parse(req.body);
      
      // IT Support chatbot responses
      let response = "Hello! I'm your IT Support assistant. How can I help you today? I can assist with tickets, password resets, software issues, and more.";
      
      if (message.toLowerCase().includes("password") || message.toLowerCase().includes("reset")) {
        response = "I can help you with password reset requests. You can submit a ticket for password reset, or if it's urgent, contact the IT helpdesk at ext. 1234. Would you like me to create a ticket for you?";
      } else if (message.toLowerCase().includes("ticket") || message.toLowerCase().includes("issue") || message.toLowerCase().includes("problem")) {
        response = "I can help you create a new support ticket. Please describe your issue, and I'll guide you through the process. What type of problem are you experiencing? (Hardware, Software, Network, or Access)";
      } else if (message.toLowerCase().includes("software") || message.toLowerCase().includes("install")) {
        response = "For software installation requests, please create a ticket with details about what software you need and why. Include your department and manager approval if required.";
      } else if (message.toLowerCase().includes("network") || message.toLowerCase().includes("internet") || message.toLowerCase().includes("wifi")) {
        response = "Network issues can be frustrating! For connectivity problems, try restarting your device first. If that doesn't work, I can help you create a high-priority ticket.";
      } else if (message.toLowerCase().includes("hardware") || message.toLowerCase().includes("computer") || message.toLowerCase().includes("laptop")) {
        response = "Hardware issues need immediate attention. Please create a ticket with details about the problem, and our agents will respond quickly. Is your device under warranty?";
      } else if (message.toLowerCase().includes("change") || message.toLowerCase().includes("request")) {
        response = "For change requests (system updates, new access, etc.), please provide details about what needs to be changed and the business justification. I can help you submit a formal change request.";
      }

      res.json({ response });
    } catch (error) {
      res.status(400).json({ message: "Invalid message format" });
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}
