import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { z } from "zod";

export async function registerRoutes(app: Express): Promise<Server> {
  // Get all properties
  app.get("/api/properties", async (req, res) => {
    try {
      const properties = await storage.getProperties();
      res.json(properties);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch properties" });
    }
  });

  // Get property by ID
  app.get("/api/properties/:id", async (req, res) => {
    try {
      const id = parseInt(req.params.id);
      const property = await storage.getProperty(id);
      if (!property) {
        return res.status(404).json({ message: "Property not found" });
      }
      res.json(property);
    } catch (error) {
      res.status(500).json({ message: "Failed to fetch property" });
    }
  });

  // Search properties with filters
  app.get("/api/properties/search", async (req, res) => {
    try {
      const schema = z.object({
        location: z.string().optional(),
        minRent: z.string().transform(val => val ? parseInt(val) : undefined).optional(),
        maxRent: z.string().transform(val => val ? parseInt(val) : undefined).optional(),
        amenities: z.string().optional().transform(val => val ? val.split(',') : undefined),
      });

      const filters = schema.parse(req.query);
      const properties = await storage.searchProperties(filters);
      res.json(properties);
    } catch (error) {
      res.status(400).json({ message: "Invalid search parameters" });
    }
  });

  // Chat support endpoint
  app.post("/api/chat", async (req, res) => {
    try {
      const schema = z.object({
        message: z.string().min(1),
      });

      const { message } = schema.parse(req.body);
      
      // Simple chatbot responses
      let response = "I'm here to help you find the perfect student housing! Can you tell me more about what you're looking for?";
      
      if (message.toLowerCase().includes("pet")) {
        response = "Great! I can help you find pet-friendly housing. I see we have properties like Telegraph Ave House that welcome pets. Would you like to see more pet-friendly options?";
      } else if (message.toLowerCase().includes("budget") || message.toLowerCase().includes("cheap") || message.toLowerCase().includes("affordable")) {
        response = "I understand budget is important for students! We have options starting from $650/month. Would you like me to show you properties under a specific price range?";
      } else if (message.toLowerCase().includes("gym") || message.toLowerCase().includes("fitness")) {
        response = "Looking for fitness amenities? Berkeley Student Commons and Campus View Studios both have gym facilities. Would you like to see more properties with fitness centers?";
      } else if (message.toLowerCase().includes("parking")) {
        response = "Parking is definitely important! Several of our properties offer parking, including Berkeley Student Commons. Would you like me to filter properties with parking included?";
      }

      res.json({ response });
    } catch (error) {
      res.status(400).json({ message: "Invalid message format" });
    }
  });

  const httpServer = createServer(app);
  return httpServer;
}
