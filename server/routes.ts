import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { z } from "zod";
import { insertTicketSchema, insertChangeSchema } from "@shared/schema";

export async function registerRoutes(app: Express): Promise<Server> {
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
      const ticketData = insertTicketSchema.parse(req.body);
      const ticket = await storage.createTicket(ticketData);
      res.status(201).json(ticket);
    } catch (error) {
      res.status(400).json({ message: "Invalid ticket data" });
    }
  });

  app.patch("/api/tickets/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const updates = insertTicketSchema.partial().parse(req.body);
      const ticket = await storage.updateTicket(id, updates);
      if (!ticket) {
        return res.status(404).json({ message: "Ticket not found" });
      }
      res.json(ticket);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
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
      const change = await storage.createChange(changeData);
      res.status(201).json(change);
    } catch (error) {
      res.status(400).json({ message: "Invalid change data" });
    }
  });

  app.patch("/api/changes/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const updates = insertChangeSchema.partial().parse(req.body);
      const change = await storage.updateChange(id, updates);
      if (!change) {
        return res.status(404).json({ message: "Change not found" });
      }
      res.json(change);
    } catch (error) {
      res.status(400).json({ message: "Invalid update data" });
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
        response = "Hardware issues need immediate attention. Please create a ticket with details about the problem, and our technicians will respond quickly. Is your device under warranty?";
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
