import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { emailService } from "./email-sendgrid";
import { z } from "zod";
import { insertTicketSchema, insertChangeSchema, insertProductSchema, insertAttachmentSchema } from "@shared/schema";
import session from "express-session";
import MemoryStore from "memorystore";
import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";

const MemoryStoreSession = MemoryStore(session);

// Utility function to generate secure approval tokens
function generateApprovalToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

// Configure multer for file uploads
const uploadDir = path.join(process.cwd(), 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const upload = multer({
  storage: multer.diskStorage({
    destination: uploadDir,
    filename: (req, file, cb) => {
      const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
      cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
    }
  }),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
    files: 5
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|pdf|txt|doc|docx|xls|xlsx/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype) || 
                    file.mimetype.startsWith('image/') ||
                    file.mimetype.startsWith('text/') ||
                    file.mimetype === 'application/pdf' ||
                    file.mimetype.includes('document') ||
                    file.mimetype.includes('sheet');
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});

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
      const user = await storage.getUserByUsernameOrEmail(username);
      
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
      const currentUser = (req as any).session?.user;
      if (!currentUser) {
        return res.status(401).json({ message: "Not authenticated" });
      }
      
      // Use product-based filtering for agents
      const tickets = await storage.getTicketsForUser(currentUser.id);
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

  // Anonymous ticket search
  app.get("/api/tickets/search/anonymous", async (req, res) => {
    try {
      const { q, searchBy = 'all' } = req.query;
      
      if (!q || typeof q !== 'string' || q.trim().length < 1) {
        return res.status(400).json({ message: "Search query must be at least 1 character long" });
      }

      const searchTerm = q.trim().toLowerCase();
      
      // Get all tickets first
      const allTickets = await storage.getTickets();
      
      // Include all tickets in search
      let searchableTickets = allTickets;

      // Apply field-specific search
      if (searchBy === 'product') {
        // For product search, q contains comma-separated product names
        const selectedProducts = searchTerm.split(',').map(p => p.trim());
        searchableTickets = searchableTickets.filter(ticket => 
          ticket.product && selectedProducts.some(product => 
            ticket.product?.toLowerCase().includes(product.toLowerCase())
          )
        );
      } else if (searchBy === 'ticketNumber') {
        searchableTickets = searchableTickets.filter(ticket => 
          ticket.id.toString().includes(q.trim()) ||
          `#${ticket.id}`.toLowerCase().includes(searchTerm)
        );
      } else if (searchBy === 'name') {
        // Get all users to look up authenticated user names
        const users = await storage.getUsers();
        searchableTickets = searchableTickets.filter(ticket => 
          (ticket.requesterName?.toLowerCase().includes(searchTerm)) ||
          (ticket.requesterId && users.find(u => u.id === ticket.requesterId)?.name?.toLowerCase().includes(searchTerm))
        );
      } else if (searchBy === 'title') {
        searchableTickets = searchableTickets.filter(ticket => 
          ticket.title.toLowerCase().includes(searchTerm)
        );
      } else if (searchBy === 'description') {
        searchableTickets = searchableTickets.filter(ticket => 
          ticket.description.toLowerCase().includes(searchTerm)
        );
      } else {
        // Default 'all' search - search across all fields
        const users = await storage.getUsers();
        searchableTickets = searchableTickets.filter(ticket => {
          const authenticatedUserName = ticket.requesterId ? 
            users.find(u => u.id === ticket.requesterId)?.name : null;
          
          return ticket.id.toString().includes(q.trim()) ||
                 `#${ticket.id}`.toLowerCase().includes(searchTerm) ||
                 ticket.title.toLowerCase().includes(searchTerm) ||
                 ticket.description.toLowerCase().includes(searchTerm) ||
                 (ticket.requesterName?.toLowerCase().includes(searchTerm) || false) ||
                 (authenticatedUserName?.toLowerCase().includes(searchTerm) || false) ||
                 (ticket.product?.toLowerCase().includes(searchTerm) || false);
        });
      }

      res.json(searchableTickets);
    } catch (error) {
      console.error("Error searching anonymous tickets:", error);
      res.status(500).json({ message: "Failed to search tickets" });
    }
  });

  // Anonymous ticket submission with file upload
  app.post("/api/tickets/anonymous", upload.array('attachments', 5), async (req, res) => {
    try {
      const anonymousTicketSchema = z.object({
        requesterName: z.string().min(1),
        requesterEmail: z.string().optional().refine((email) => !email || z.string().email().safeParse(email).success, "Please enter a valid email address"),
        requesterPhone: z.string().optional(),
        title: z.string().min(1),
        description: z.string().min(1),
        priority: z.enum(["low", "medium", "high", "critical"]),
        category: z.enum(["software", "hardware", "network", "access", "other"]),
        product: z.string().optional(),
        status: z.string().default("open")
      });

      const ticketData = anonymousTicketSchema.parse(req.body);
      
      const ticket = await storage.createTicket({
        ...ticketData,
        requesterId: null, // No user ID for anonymous tickets
      });

      // Handle file attachments
      const files = req.files as Express.Multer.File[];
      if (files && files.length > 0) {
        for (const file of files) {
          await storage.createAttachment({
            ticketId: ticket.id,
            changeId: null,
            fileName: file.filename,
            originalName: file.originalname,
            fileSize: file.size,
            mimeType: file.mimetype,
            fileContent: null, // We're storing files on disk, not in database
            uploadedBy: null, // Anonymous upload
            uploadedByName: `${ticketData.requesterName}${ticketData.requesterEmail ? ` (${ticketData.requesterEmail})` : ''}`
          });
        }
      }

      // Send email notification if email provided
      if (ticketData.requesterEmail) {
        try {
          await emailService.sendTicketCreatedEmail(ticket, ticketData.requesterEmail);
        } catch (error) {
          console.error('Failed to send ticket creation email:', error);
          // Don't fail the ticket creation if email fails
        }
      }
      
      res.status(201).json(ticket);
    } catch (error: any) {
      console.error('Anonymous ticket creation error:', error);
      res.status(400).json({ message: "Invalid ticket data", error: error.message });
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
        requesterName: currentUser.name,
        requesterEmail: currentUser.email,
        createdAt: new Date(),
        updatedAt: new Date()
      });
      
      const ticket = await storage.createTicket(ticketData);

      // Send email notification to user
      try {
        await emailService.sendTicketCreatedEmail(ticket, currentUser.email);
      } catch (error) {
        console.error('Failed to send ticket creation email:', error);
        // Don't fail the ticket creation if email fails
      }

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

      // Send email notification on ticket updates
      if (updatedTicket) {
        try {
          // Determine recipient email
          let recipientEmail = null;
          if (updatedTicket.requesterEmail) {
            recipientEmail = updatedTicket.requesterEmail;
          } else if (updatedTicket.requesterId) {
            const users = await storage.getUsers();
            const requester = users.find(u => u.id === updatedTicket.requesterId);
            if (requester?.email) {
              recipientEmail = requester.email;
            }
          }

          if (recipientEmail) {
            await emailService.sendTicketUpdatedEmail(updatedTicket, recipientEmail, notes);
          }
        } catch (error) {
          console.error('Failed to send ticket update email:', error);
          // Don't fail the update if email fails
        }
      }

      res.json(updatedTicket);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
    }
  });

  // Send ticket for approval
  app.post("/api/tickets/:id/request-approval", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { managerId, comments } = req.body;
      const currentUser = (req as any).session?.user;
      
      if (!currentUser || !['agent', 'admin'].includes(currentUser.role)) {
        return res.status(403).json({ message: "Agent access required" });
      }

      if (!managerId) {
        return res.status(400).json({ message: "Manager ID is required" });
      }

      const ticket = await storage.getTicket(id);
      if (!ticket) {
        return res.status(404).json({ message: "Ticket not found" });
      }

      if (ticket.approvalStatus === 'pending') {
        return res.status(400).json({ message: "Ticket is already pending approval" });
      }

      // Verify the selected manager exists and has proper role
      const selectedManager = await storage.getUser(managerId);
      if (!selectedManager || !['manager', 'admin'].includes(selectedManager.role)) {
        return res.status(400).json({ message: "Invalid manager selected" });
      }

      // Generate secure approval token
      const approvalToken = generateApprovalToken();
      
      // Update ticket to pending approval status with selected manager and token
      const approvalComments = comments ? `Agent comments: ${comments}` : 'Ticket sent for management approval';
      const updatedTicket = await storage.updateTicketWithHistory(id, {
        approvalStatus: 'pending',
        approvedBy: selectedManager.name, // Store which manager should approve
        approvalToken // Store secure token for email approval
      }, currentUser.id, approvalComments);

      if (!updatedTicket) {
        return res.status(404).json({ message: "Failed to update ticket" });
      }

      // Send email with approval links to the selected manager
      await emailService.sendTicketApprovalEmailWithLinks(updatedTicket, selectedManager.email, selectedManager.name, approvalToken);

      res.json({ message: "Ticket sent for approval", ticket: updatedTicket });
    } catch (error) {
      console.error('Error requesting ticket approval:', error);
      res.status(500).json({ message: "Failed to request approval" });
    }
  });

  // Email-based approval endpoints (no login required)
  app.get("/api/tickets/:id/email-approve/:token", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const token = req.params.token;

      const ticket = await storage.getTicket(id);
      if (!ticket) {
        return res.status(404).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Ticket Not Found</h2>
              <p>The ticket you're trying to approve could not be found.</p>
            </body>
          </html>
        `);
      }

      if (ticket.approvalToken !== token) {
        return res.status(403).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Invalid Approval Link</h2>
              <p>This approval link is invalid or has expired.</p>
            </body>
          </html>
        `);
      }

      if (ticket.approvalStatus !== 'pending') {
        return res.status(400).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ffc107;">Already Processed</h2>
              <p>This ticket has already been ${ticket.approvalStatus}.</p>
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 15px;">
                <h4>Ticket Details:</h4>
                <p><strong>ID:</strong> #${ticket.id}</p>
                <p><strong>Title:</strong> ${ticket.title}</p>
                <p><strong>Status:</strong> ${ticket.approvalStatus}</p>
              </div>
            </body>
          </html>
        `);
      }

      // Process approval
      const updatedTicket = await storage.updateTicketWithHistory(id, {
        approvalStatus: 'approved',
        approvedAt: new Date(),
        status: 'open', // Open ticket when approved
        approvalToken: null // Clear token after use
      }, 0, `Ticket approved via email by ${ticket.approvedBy}`);

      res.send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #28a745;">✓ Ticket Approved Successfully</h2>
            <p>Thank you for approving this ticket. The agent can now proceed with their work.</p>
            <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin-top: 15px; border-left: 4px solid #28a745;">
              <h4>Ticket Details:</h4>
              <p><strong>ID:</strong> #${ticket.id}</p>
              <p><strong>Title:</strong> ${ticket.title}</p>
              <p><strong>Priority:</strong> ${ticket.priority}</p>
              <p><strong>Category:</strong> ${ticket.category}</p>
              <p><strong>Status:</strong> Open (Ready for work)</p>
            </div>
            <p style="margin-top: 20px; color: #6c757d; font-size: 14px;">
              This ticket is now available for the assigned agent to work on.
            </p>
          </body>
        </html>
      `);
    } catch (error) {
      console.error('Error processing email approval:', error);
      res.status(500).send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">Error</h2>
            <p>An error occurred while processing your approval. Please try again or contact support.</p>
          </body>
        </html>
      `);
    }
  });

  app.get("/api/tickets/:id/email-reject/:token", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const token = req.params.token;

      const ticket = await storage.getTicket(id);
      if (!ticket) {
        return res.status(404).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Ticket Not Found</h2>
              <p>The ticket you're trying to reject could not be found.</p>
            </body>
          </html>
        `);
      }

      if (ticket.approvalToken !== token) {
        return res.status(403).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Invalid Approval Link</h2>
              <p>This approval link is invalid or has expired.</p>
            </body>
          </html>
        `);
      }

      if (ticket.approvalStatus !== 'pending') {
        return res.status(400).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ffc107;">Already Processed</h2>
              <p>This ticket has already been ${ticket.approvalStatus}.</p>
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 15px;">
                <h4>Ticket Details:</h4>
                <p><strong>ID:</strong> #${ticket.id}</p>
                <p><strong>Title:</strong> ${ticket.title}</p>
                <p><strong>Status:</strong> ${ticket.approvalStatus}</p>
              </div>
            </body>
          </html>
        `);
      }

      // Process rejection
      const updatedTicket = await storage.updateTicketWithHistory(id, {
        approvalStatus: 'rejected',
        approvedAt: new Date(),
        approvalToken: null // Clear token after use
      }, 0, `Ticket rejected via email by ${ticket.approvedBy}`);

      res.send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">✗ Ticket Rejected</h2>
            <p>You have rejected this ticket. The agent has been notified and the ticket will remain in its current state.</p>
            <div style="background-color: #f8d7da; padding: 15px; border-radius: 5px; margin-top: 15px; border-left: 4px solid #dc3545;">
              <h4>Ticket Details:</h4>
              <p><strong>ID:</strong> #${ticket.id}</p>
              <p><strong>Title:</strong> ${ticket.title}</p>
              <p><strong>Priority:</strong> ${ticket.priority}</p>
              <p><strong>Category:</strong> ${ticket.category}</p>
              <p><strong>Status:</strong> Rejected</p>
            </div>
            <p style="margin-top: 20px; color: #6c757d; font-size: 14px;">
              The agent will be notified about this rejection and can take appropriate action.
            </p>
          </body>
        </html>
      `);
    } catch (error) {
      console.error('Error processing email rejection:', error);
      res.status(500).send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">Error</h2>
            <p>An error occurred while processing your rejection. Please try again or contact support.</p>
          </body>
        </html>
      `);
    }
  });

  // Approve or reject ticket
  app.post("/api/tickets/:id/approve", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { action, comments } = req.body; // action: 'approve' or 'reject'
      const currentUser = (req as any).session?.user;
      
      if (!currentUser || !['manager', 'admin'].includes(currentUser.role)) {
        return res.status(403).json({ message: "Manager access required" });
      }

      if (!['approve', 'reject'].includes(action)) {
        return res.status(400).json({ message: "Invalid action. Must be 'approve' or 'reject'" });
      }

      const ticket = await storage.getTicket(id);
      if (!ticket) {
        return res.status(404).json({ message: "Ticket not found" });
      }

      if (ticket.approvalStatus !== 'pending') {
        return res.status(400).json({ message: "Ticket is not pending approval" });
      }

      // Update ticket with approval decision
      const approvalStatus = action === 'approve' ? 'approved' : 'rejected';
      const newStatus = action === 'approve' ? 'open' : ticket.status; // Open ticket if approved
      
      const updatedTicket = await storage.updateTicketWithHistory(id, {
        approvalStatus,
        approvedBy: currentUser.name,
        approvedAt: new Date(),
        approvalComments: comments,
        status: newStatus
      }, currentUser.id, `Ticket ${action}d by ${currentUser.name}${comments ? ': ' + comments : ''}`);

      if (!updatedTicket) {
        return res.status(404).json({ message: "Failed to update ticket" });
      }

      // Send email notification to requester
      if (updatedTicket.requesterEmail) {
        await emailService.sendTicketUpdatedEmail(
          updatedTicket, 
          updatedTicket.requesterEmail, 
          `Your ticket has been ${action}d by management${comments ? ': ' + comments : ''}`
        );
      }

      res.json({ message: `Ticket ${action}d successfully`, ticket: updatedTicket });
    } catch (error) {
      console.error('Error processing ticket approval:', error);
      res.status(500).json({ message: "Failed to process approval" });
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

  // Email-based change approval endpoints (no login required)
  app.get("/api/changes/:id/email-approve/:token", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const token = req.params.token;

      const change = await storage.getChange(id);
      if (!change) {
        return res.status(404).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Change Request Not Found</h2>
              <p>The change request you're trying to approve could not be found.</p>
            </body>
          </html>
        `);
      }

      if (change.approvalToken !== token) {
        return res.status(403).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Invalid Approval Link</h2>
              <p>This approval link is invalid or has expired.</p>
            </body>
          </html>
        `);
      }

      if (change.status !== 'pending') {
        return res.status(400).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ffc107;">Already Processed</h2>
              <p>This change request has already been ${change.status}.</p>
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 15px;">
                <h4>Change Details:</h4>
                <p><strong>ID:</strong> #${change.id}</p>
                <p><strong>Title:</strong> ${change.title}</p>
                <p><strong>Status:</strong> ${change.status}</p>
              </div>
            </body>
          </html>
        `);
      }

      // Process approval
      const updatedChange = await storage.updateChangeWithHistory(id, {
        status: 'approved',
        approvalToken: null // Clear token after use
      }, 0, `Change approved via email by ${change.approvedBy}`);

      res.send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #28a745;">✓ Change Request Approved Successfully</h2>
            <p>Thank you for approving this change request. The implementation can now proceed according to the planned schedule.</p>
            <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin-top: 15px; border-left: 4px solid #28a745;">
              <h4>Change Details:</h4>
              <p><strong>ID:</strong> #${change.id}</p>
              <p><strong>Title:</strong> ${change.title}</p>
              <p><strong>Priority:</strong> ${change.priority}</p>
              <p><strong>Risk Level:</strong> ${change.riskLevel}</p>
              <p><strong>Change Type:</strong> ${change.changeType}</p>
              <p><strong>Status:</strong> Approved (Ready for implementation)</p>
            </div>
            <p style="margin-top: 20px; color: #6c757d; font-size: 14px;">
              This change request is now approved and can be implemented according to the planned timeline.
            </p>
          </body>
        </html>
      `);
    } catch (error) {
      console.error('Error processing email change approval:', error);
      res.status(500).send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">Error</h2>
            <p>An error occurred while processing your approval. Please try again or contact support.</p>
          </body>
        </html>
      `);
    }
  });

  app.get("/api/changes/:id/email-reject/:token", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const token = req.params.token;

      const change = await storage.getChange(id);
      if (!change) {
        return res.status(404).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Change Request Not Found</h2>
              <p>The change request you're trying to reject could not be found.</p>
            </body>
          </html>
        `);
      }

      if (change.approvalToken !== token) {
        return res.status(403).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #dc3545;">Invalid Approval Link</h2>
              <p>This approval link is invalid or has expired.</p>
            </body>
          </html>
        `);
      }

      if (change.status !== 'pending') {
        return res.status(400).send(`
          <html>
            <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
              <h2 style="color: #ffc107;">Already Processed</h2>
              <p>This change request has already been ${change.status}.</p>
              <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin-top: 15px;">
                <h4>Change Details:</h4>
                <p><strong>ID:</strong> #${change.id}</p>
                <p><strong>Title:</strong> ${change.title}</p>
                <p><strong>Status:</strong> ${change.status}</p>
              </div>
            </body>
          </html>
        `);
      }

      // Process rejection
      const updatedChange = await storage.updateChangeWithHistory(id, {
        status: 'rejected',
        approvalToken: null // Clear token after use
      }, 0, `Change rejected via email by ${change.approvedBy}`);

      res.send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">✗ Change Request Rejected</h2>
            <p>You have rejected this change request. The requester has been notified and the change will not proceed.</p>
            <div style="background-color: #f8d7da; padding: 15px; border-radius: 5px; margin-top: 15px; border-left: 4px solid #dc3545;">
              <h4>Change Details:</h4>
              <p><strong>ID:</strong> #${change.id}</p>
              <p><strong>Title:</strong> ${change.title}</p>
              <p><strong>Priority:</strong> ${change.priority}</p>
              <p><strong>Risk Level:</strong> ${change.riskLevel}</p>
              <p><strong>Change Type:</strong> ${change.changeType}</p>
              <p><strong>Status:</strong> Rejected</p>
            </div>
            <p style="margin-top: 20px; color: #6c757d; font-size: 14px;">
              The requester will be notified about this rejection and can revise the change request if needed.
            </p>
          </body>
        </html>
      `);
    } catch (error) {
      console.error('Error processing email change rejection:', error);
      res.status(500).send(`
        <html>
          <body style="font-family: Arial, sans-serif; padding: 20px; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #dc3545;">Error</h2>
            <p>An error occurred while processing your rejection. Please try again or contact support.</p>
          </body>
        </html>
      `);
    }
  });

  // Change routes
  app.get("/api/changes", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      if (!currentUser) {
        return res.status(401).json({ message: "Not authenticated" });
      }
      
      // Use product-based filtering for agents
      const changes = await storage.getChangesForUser(currentUser.id);
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
      console.log('Change creation request body:', req.body);
      
      // Transform date strings to Date objects
      const transformedData = {
        ...req.body,
        plannedDate: req.body.plannedDate ? new Date(req.body.plannedDate) : null,
        completedDate: req.body.completedDate ? new Date(req.body.completedDate) : null,
        startDate: req.body.startDate ? new Date(req.body.startDate) : null,
        endDate: req.body.endDate ? new Date(req.body.endDate) : null,
      };
      
      const changeData = insertChangeSchema.parse(transformedData);
      
      // Create the change request
      const change = await storage.createChange(changeData);
      
      // Handle Standard changes (automatically approved) or initialize approval workflow
      if (changeData.changeType === 'standard') {
        // Standard changes are automatically approved - update status
        await storage.updateChange(change.id, { 
          status: 'approved',
          approvedBy: 'Auto-approved (Standard Change)'
        });
      } else if (changeData.product && changeData.riskLevel) {
        // Initialize multilevel approvals for Normal and Emergency changes
        const products = await storage.getProducts();
        const product = products.find(p => p.name === changeData.product);
        
        if (product) {
          await storage.initializeChangeApprovals(change.id, product.id, changeData.riskLevel, changeData.changeType);
          
          // Send email notifications to first level approvers
          try {
            const approvals = await storage.getChangeApprovals(change.id);
            const firstLevelApprovals = approvals.filter(a => a.approvalLevel === 1);
            const users = await storage.getUsers();
            
            for (const approval of firstLevelApprovals) {
              const approver = users.find(u => u.id === approval.approverId);
              if (approver?.email) {
                await emailService.sendChangeApprovalEmail(change, approver.email, approver.name);
              }
            }
          } catch (error) {
            console.error('Failed to send change approval emails:', error);
            // Don't fail the change creation if email fails
          }
        }
      }
      
      res.status(201).json(change);
    } catch (error: any) {
      console.error('Change creation error:', error);
      res.status(400).json({ message: "Invalid change data", error: error.message });
    }
  });

  app.patch("/api/changes/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const { notes, userId, ...updates } = req.body;
      
      // Validate implementation timing
      if (updates.status === 'in-progress') {
        const currentChange = await storage.getChange(id);
        if (currentChange?.startDate) {
          const now = new Date();
          const startTime = new Date(currentChange.startDate);
          
          if (now < startTime) {
            return res.status(400).json({ 
              message: `Implementation cannot begin before the scheduled start time: ${startTime.toISOString()}` 
            });
          }
        }
      }
      
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
      
      // Get the current product to check if name is changing
      const currentProduct = await storage.getProduct(id);
      if (!currentProduct) {
        return res.status(404).json({ message: "Product not found" });
      }
      
      const product = await storage.updateProduct(id, updates);
      if (!product) {
        return res.status(404).json({ message: "Product not found" });
      }
      
      // If product name changed, update all users' assigned products
      if (updates.name && updates.name !== currentProduct.name) {
        console.log(`[Product Update] Product name changed from "${currentProduct.name}" to "${updates.name}"`);
        const users = await storage.getUsers();
        let updatedUserCount = 0;
        
        for (const user of users) {
          if (user.assignedProducts && user.assignedProducts.length > 0) {
            // Check for any product names that contain the base product name (like "Olympus")
            const baseProductName = currentProduct.name.split(' ')[0]; // Get "Olympus" from "Olympus 1"
            const hasRelatedProduct = user.assignedProducts.some(productName => 
              productName.startsWith(baseProductName) || productName === currentProduct.name
            );
            
            if (hasRelatedProduct) {
              // Update all variations of the product name to the new name
              const updatedProducts = user.assignedProducts.map(productName => {
                // Replace exact matches and variations that start with the base name
                if (productName === currentProduct.name || productName.startsWith(baseProductName)) {
                  return updates.name;
                }
                return productName;
              });
              
              // Remove duplicates and filter out any old product names that don't exist anymore
              const uniqueProducts = Array.from(new Set(updatedProducts));
              const currentProducts = await storage.getProducts();
              const validProducts = uniqueProducts.filter(productName => 
                currentProducts.some(p => p.name === productName)
              );
              
              if (JSON.stringify(validProducts) !== JSON.stringify(user.assignedProducts)) {
                await storage.updateUser(user.id, { assignedProducts: validProducts });
                updatedUserCount++;
                console.log(`[Product Update] Updated user ${user.username} products: ${user.assignedProducts.join(', ')} -> ${validProducts.join(', ')}`);
              }
            }
          }
        }
        console.log(`[Product Update] Updated ${updatedUserCount} users with new product name`);
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

  app.post("/api/sla/refresh", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      
      if (!currentUser || (currentUser.role !== 'admin' && currentUser.role !== 'manager')) {
        return res.status(403).json({ message: "Access denied. Admin or Manager role required." });
      }
      
      await storage.refreshSLAMetrics();
      res.json({ message: "SLA metrics refreshed successfully" });
    } catch (error) {
      console.error("Error refreshing SLA metrics:", error);
      res.status(500).json({ message: "Failed to refresh SLA metrics" });
    }
  });

  // Project Intake Routes
  app.post("/api/project-intake", async (req, res) => {
    try {
      const projectData = req.body;
      
      // Create a ticket for the project intake request
      const ticketData = {
        title: `Project Intake: ${projectData.projectName}`,
        description: `
**Project Intake Request**

**Requestor:** ${projectData.requestorName} (${projectData.requestorEmail})
**Department:** ${projectData.requestorDepartment}
**Project Type:** ${projectData.projectType}
**Priority:** ${projectData.priority}

**Project Description:**
${projectData.projectDescription}

**Business Justification:**
${projectData.businessJustification}

**Project Scope:**
${projectData.projectScope}

**Key Requirements:**
${projectData.keyRequirements}

**Success Criteria:**
${projectData.successCriteria}

**Timeline:**
- Requested Start Date: ${projectData.requestedStartDate}
- Desired Completion Date: ${projectData.desiredCompletionDate}

**Budget Information:**
- Estimated Budget: ${projectData.estimatedBudget || 'Not specified'}
- Budget Approval Status: ${projectData.budgetApproval}

**Stakeholders:**
- Project Sponsor: ${projectData.projectSponsor}
- Key Stakeholders: ${projectData.keyStakeholders}
- Impacted Departments: ${projectData.impactedDepartments}
- Estimated User Count: ${projectData.userCount || 'Not specified'}

**Technical Requirements:**
- Systems Involved: ${projectData.systemsInvolved || 'Not specified'}
- Integration Required: ${projectData.integrationRequired ? 'Yes' : 'No'}
${projectData.integrationRequired && projectData.integrationDetails ? `- Integration Details: ${projectData.integrationDetails}` : ''}
- Security Requirements: ${projectData.securityRequirements || 'Not specified'}
- Compliance Requirements: ${projectData.complianceRequirements || 'Not specified'}

**Risk and Dependencies:**
- Identified Risks: ${projectData.identifiedRisks || 'None specified'}
- Dependencies: ${projectData.dependencies || 'None specified'}

**Additional Notes:**
${projectData.additionalNotes || 'None'}
        `,
        category: "project_request",
        priority: projectData.priority,
        status: "open",
        contactEmail: projectData.requestorEmail,
        contactName: projectData.requestorName,
        contactPhone: projectData.requestorPhone || null,
        productId: 2 // Default to Olympus product, or you can make this configurable
      };

      const ticket = await storage.createTicket(ticketData);
      
      // Send email notification if email service is configured
      if (ticket) {
        try {
          await emailService.sendTicketCreatedEmail(ticket, projectData.requestorEmail);
        } catch (emailError) {
          console.error("Failed to send project intake email:", emailError);
          // Don't fail the request if email fails
        }
      }

      res.status(201).json({ 
        success: true, 
        ticketId: ticket.id,
        message: "Project intake request submitted successfully" 
      });
    } catch (error) {
      console.error("Error creating project intake request:", error);
      res.status(500).json({ message: "Failed to submit project intake request" });
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
      
      // Send email notifications for next level approvals
      if (result.approved && !result.completed && result.nextLevel) {
        try {
          const change = await storage.getChange(changeId);
          const approvals = await storage.getChangeApprovals(changeId);
          const nextLevelApprovals = approvals.filter(a => a.approvalLevel === result.nextLevel && a.status === 'pending');
          const users = await storage.getUsers();
          
          for (const approval of nextLevelApprovals) {
            const approver = users.find(u => u.id === approval.approverId);
            if (approver?.email && change) {
              await emailService.sendChangeApprovalEmail(change, approver.email, approver.name);
            }
          }
        } catch (error) {
          console.error('Failed to send next level approval emails:', error);
        }
      }
      
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

  // Cleanup endpoint to sync all user assigned products with current product names
  app.post("/api/admin/sync-user-products", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      if (!currentUser || currentUser.role !== 'admin') {
        return res.status(403).json({ message: "Admin access required" });
      }

      const products = await storage.getProducts();
      const users = await storage.getUsers();
      let updatedUsers = 0;

      for (const user of users) {
        if (user.assignedProducts && user.assignedProducts.length > 0) {
          // Map old product names to current ones
          const updatedProducts = user.assignedProducts.map(assignedProduct => {
            // Find matching product by checking for partial matches or exact matches
            const currentProduct = products.find(p => 
              p.name === assignedProduct || 
              assignedProduct.includes(p.name.split(' ')[0]) || // Match first word
              p.name.includes(assignedProduct.split(' ')[0])     // Reverse match
            );
            return currentProduct ? currentProduct.name : assignedProduct;
          });

          // Remove duplicates and invalid products
          const uniqueProducts = Array.from(new Set(updatedProducts));
          const validProducts = uniqueProducts.filter(productName => 
            products.some(p => p.name === productName)
          );

          if (JSON.stringify(validProducts) !== JSON.stringify(user.assignedProducts)) {
            await storage.updateUser(user.id, { assignedProducts: validProducts });
            updatedUsers++;
          }
        }
      }

      res.json({ 
        message: `Successfully synchronized ${updatedUsers} users with current product names`,
        updatedUsers 
      });
    } catch (error) {
      res.status(500).json({ message: "Failed to sync user products" });
    }
  });

  // Email test endpoint
  app.post("/api/email/test", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      if (!currentUser || currentUser.role !== 'admin') {
        return res.status(403).json({ message: "Admin access required" });
      }

      const schema = z.object({
        email: z.string().email(),
      });

      const { email } = schema.parse(req.body);
      
      const testEmailHtml = `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center;">
            <h1 style="margin: 0;">Calpion IT Support</h1>
            <p style="margin: 5px 0 0 0;">Email System Test</p>
          </div>
          
          <div style="padding: 20px; background: #f9f9f9;">
            <h2 style="color: #333; margin-top: 0;">✅ Email Configuration Successful!</h2>
            <p>This is a test email to verify that your email notifications are working correctly.</p>
            
            <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 5px;">
              <h3 style="margin-top: 0; color: #333;">System Information:</h3>
              <ul style="margin: 0; padding-left: 20px;">
                <li>Test sent at: ${new Date().toLocaleString()}</li>
                <li>Requested by: ${currentUser.name} (${currentUser.email})</li>
                <li>System: Calpion IT Service Desk</li>
              </ul>
            </div>
            
            <div style="margin: 20px 0; padding: 15px; background: #d4edda; border-radius: 5px; border-left: 4px solid #28a745;">
              <h3 style="margin-top: 0; color: #28a745;">Email notifications are now active for:</h3>
              <ul style="margin: 0; padding-left: 20px;">
                <li>New ticket confirmations</li>
                <li>Ticket status updates</li>
                <li>Change approval requests</li>
                <li>Priority issue alerts</li>
              </ul>
            </div>
          </div>
          
          <div style="padding: 20px; background: #333; color: white; text-align: center;">
            <p style="margin: 0;">Calpion IT Support - Email Test Successful</p>
            <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.8;">If you received this email, your configuration is working correctly</p>
          </div>
        </div>
      `;

      const success = await emailService.sendEmail(
        email,
        "🔧 Calpion IT Support - Email Test",
        testEmailHtml
      );

      if (success) {
        res.json({ 
          message: "Test email sent successfully",
          recipient: email,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(500).json({ message: "Failed to send test email" });
      }
    } catch (error: any) {
      console.error('Email test error:', error);
      res.status(400).json({ message: error.message || "Invalid request" });
    }
  });

  // Email settings endpoint
  app.post("/api/email/settings", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      
      if (!currentUser || currentUser.role !== 'admin') {
        return res.status(403).json({ message: "Access denied. Admin role required." });
      }

      const { provider, sendgridApiKey, smtpHost, smtpPort, smtpSecure, smtpUser, smtpPass, fromEmail } = req.body;

      // Update email configuration
      const { updateEmailConfig } = await import('./email-config');
      updateEmailConfig({
        provider,
        sendgridApiKey,
        smtpHost,
        smtpPort,
        smtpSecure,
        smtpUser,
        smtpPass,
        fromEmail
      });

      // Reinitialize email service with new configuration
      await emailService.reinitialize();

      res.json({ 
        success: true,
        message: "Email settings updated successfully" 
      });
    } catch (error: any) {
      console.error('Email settings update error:', error);
      res.status(500).json({ message: error.message || "Failed to update email settings" });
    }
  });

  // Get email settings endpoint
  app.get("/api/email/settings", async (req, res) => {
    try {
      const currentUser = (req as any).session?.user;
      
      if (!currentUser || currentUser.role !== 'admin') {
        return res.status(403).json({ message: "Access denied. Admin role required." });
      }

      const { getEmailConfig, isEmailConfigured } = await import('./email-config');
      const config = getEmailConfig();

      res.json({
        ...config,
        // Don't send sensitive data back
        sendgridApiKey: config.sendgridApiKey ? '***configured***' : '',
        smtpPass: config.smtpPass ? '***configured***' : '',
        isConfigured: isEmailConfigured()
      });
    } catch (error: any) {
      console.error('Email settings fetch error:', error);
      res.status(500).json({ message: error.message || "Failed to fetch email settings" });
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}
