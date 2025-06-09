import { properties, users, type Property, type InsertProperty, type User, type InsertUser } from "@shared/schema";

export interface IStorage {
  // Property methods
  getProperties(): Promise<Property[]>;
  getProperty(id: number): Promise<Property | undefined>;
  createProperty(property: InsertProperty): Promise<Property>;
  searchProperties(filters: {
    location?: string;
    minRent?: number;
    maxRent?: number;
    amenities?: string[];
  }): Promise<Property[]>;
  
  // User methods
  getUser(id: number): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
}

export class MemStorage implements IStorage {
  private properties: Map<number, Property>;
  private users: Map<number, User>;
  private currentPropertyId: number;
  private currentUserId: number;

  constructor() {
    this.properties = new Map();
    this.users = new Map();
    this.currentPropertyId = 1;
    this.currentUserId = 1;
    
    // Initialize with sample properties
    this.initializeProperties();
  }

  private async initializeProperties() {
    const sampleProperties: InsertProperty[] = [
      {
        title: "Berkeley Student Commons",
        address: "0.3 miles from UC Berkeley",
        distanceFromCampus: "0.3 miles",
        rent: 725,
        bedrooms: "2 bed",
        bathrooms: "1 bath",
        roommates: "3 roommates",
        squareFootage: 850,
        imageUrl: "https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&h=600",
        amenities: ["WiFi Included", "Gym", "Study Rooms", "Parking"],
        rating: "4.8",
        reviewCount: 124,
        availabilityStatus: "Available Now",
        featured: true,
      },
      {
        title: "Telegraph Ave House",
        address: "0.5 miles from UC Berkeley",
        distanceFromCampus: "0.5 miles",
        rent: 650,
        bedrooms: "1 bed",
        bathrooms: "1 bath",
        roommates: "4 roommates",
        squareFootage: 650,
        imageUrl: "https://images.unsplash.com/photo-1449844908441-8829872d2607?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&h=600",
        amenities: ["WiFi Included", "Garden", "Laundry", "Pet Friendly"],
        rating: "4.6",
        reviewCount: 89,
        availabilityStatus: "Move-in Special",
        featured: false,
      },
      {
        title: "Campus View Studios",
        address: "0.2 miles from UC Berkeley",
        distanceFromCampus: "0.2 miles",
        rent: 950,
        bedrooms: "Studio",
        bathrooms: "1 bath",
        roommates: "Solo living",
        squareFootage: 450,
        imageUrl: "https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&h=600",
        amenities: ["All Utilities", "Gym", "Rooftop", "24/7 Security"],
        rating: "4.9",
        reviewCount: 156,
        availabilityStatus: "Limited Time",
        featured: true,
      },
    ];

    for (const property of sampleProperties) {
      await this.createProperty(property);
    }
  }

  async getProperties(): Promise<Property[]> {
    return Array.from(this.properties.values());
  }

  async getProperty(id: number): Promise<Property | undefined> {
    return this.properties.get(id);
  }

  async createProperty(insertProperty: InsertProperty): Promise<Property> {
    const id = this.currentPropertyId++;
    const property: Property = { ...insertProperty, id };
    this.properties.set(id, property);
    return property;
  }

  async searchProperties(filters: {
    location?: string;
    minRent?: number;
    maxRent?: number;
    amenities?: string[];
  }): Promise<Property[]> {
    const allProperties = Array.from(this.properties.values());
    
    return allProperties.filter(property => {
      if (filters.location && !property.address.toLowerCase().includes(filters.location.toLowerCase())) {
        return false;
      }
      
      if (filters.minRent && property.rent < filters.minRent) {
        return false;
      }
      
      if (filters.maxRent && property.rent > filters.maxRent) {
        return false;
      }
      
      if (filters.amenities && filters.amenities.length > 0) {
        const hasAllAmenities = filters.amenities.every(amenity =>
          property.amenities.some(propAmenity => 
            propAmenity.toLowerCase().includes(amenity.toLowerCase())
          )
        );
        if (!hasAllAmenities) {
          return false;
        }
      }
      
      return true;
    });
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
    const user: User = { ...insertUser, id };
    this.users.set(id, user);
    return user;
  }
}

export const storage = new MemStorage();
