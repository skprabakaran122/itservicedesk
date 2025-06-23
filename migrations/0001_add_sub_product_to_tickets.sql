-- Migration: Add sub_product field to tickets table
-- Date: 2025-06-23
-- Description: Adds sub_product column to support sub-product/category functionality in ticket management

-- Add sub_product column to tickets table
ALTER TABLE "tickets" ADD COLUMN "sub_product" varchar(100);

-- Add comment for documentation
COMMENT ON COLUMN "tickets"."sub_product" IS 'Sub-product/category name for organizational hierarchy';

-- Optional: Add index for better query performance on sub_product field
CREATE INDEX IF NOT EXISTS "idx_tickets_sub_product" ON "tickets" ("sub_product");

-- Update any existing tickets with product ID "1" to show proper product name
-- This fixes data integrity issue where product IDs were stored instead of names
UPDATE "tickets" SET "product" = 'Olympus 2' WHERE "product" = '1';