import { pgTable, text, serial, integer, boolean, varchar } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const properties = pgTable("properties", {
  id: serial("id").primaryKey(),
  title: text("title").notNull(),
  address: text("address").notNull(),
  distanceFromCampus: text("distance_from_campus").notNull(),
  rent: integer("rent").notNull(),
  bedrooms: varchar("bedrooms", { length: 20 }).notNull(),
  bathrooms: text("bathrooms").notNull(),
  roommates: text("roommates").notNull(),
  squareFootage: integer("square_footage").notNull(),
  imageUrl: text("image_url").notNull(),
  amenities: text("amenities").array().notNull(),
  rating: text("rating").notNull(),
  reviewCount: integer("review_count").notNull(),
  availabilityStatus: text("availability_status").notNull(),
  featured: boolean("featured").default(false).notNull(),
});

export const insertPropertySchema = createInsertSchema(properties).omit({
  id: true,
});

export type InsertProperty = z.infer<typeof insertPropertySchema>;
export type Property = typeof properties.$inferSelect;

export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  password: text("password").notNull(),
});

export const insertUserSchema = createInsertSchema(users).pick({
  username: true,
  password: true,
});

export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;
