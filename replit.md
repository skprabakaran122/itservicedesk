# IT Service Desk System

## Overview

This is a comprehensive IT Service Desk system built for Calpion, designed to handle tickets, change requests, user management, and automated workflows. The system provides both internal staff management tools and public-facing support portals for external users.

## System Architecture

The application follows a full-stack TypeScript architecture with:

- **Frontend**: React 18 with TypeScript, using Vite as the build tool
- **Backend**: Express.js server with TypeScript
- **Database**: PostgreSQL with Drizzle ORM
- **Styling**: Tailwind CSS with shadcn/ui components
- **State Management**: TanStack Query for server state
- **Authentication**: Session-based authentication with express-session

## Key Components

### Frontend Architecture
- **Component Library**: shadcn/ui with Radix UI primitives
- **Routing**: Wouter for client-side routing
- **Forms**: React Hook Form with Zod validation
- **Styling**: Tailwind CSS with CSS variables for theming
- **Build Tool**: Vite with custom configuration for monorepo structure

### Backend Architecture
- **Server**: Express.js with TypeScript
- **ORM**: Drizzle with PostgreSQL adapter
- **File Storage**: Local file system with multer middleware
- **Email Service**: Dual provider support (SendGrid/SMTP) with Nodemailer fallback
- **SSL Support**: Custom SSL certificate management

### Database Schema
- **Core Entities**: Tickets, Changes, Users, Products, Attachments
- **Workflow Management**: Approval routing, change approvals, history tracking
- **Configuration**: Settings table for dynamic system configuration
- **Audit Trail**: Complete history tracking for tickets and changes

## Data Flow

### Ticket Management
1. Anonymous users can submit tickets via public portal
2. Tickets are routed based on approval rules and product assignments
3. Internal users can manage, update, and resolve tickets
4. Email notifications sent for status changes and approvals
5. SLA tracking and metrics calculation

### Change Management
1. Change requests follow approval workflows
2. Risk-based routing to appropriate approvers
3. Multi-level approval support with email-based approval
4. Change tracking with detailed history and audit trails

### User Management
1. Role-based access control (admin, agent, user)
2. Department and business unit organization
3. Dynamic approval routing based on user roles

## External Dependencies

### Core Dependencies
- **Database**: PostgreSQL via Neon Database
- **UI Components**: Radix UI primitives (@radix-ui/*)
- **Email Services**: SendGrid API and Nodemailer for SMTP
- **File Handling**: Multer for file uploads
- **Validation**: Zod for schema validation

### Development Dependencies
- **TypeScript**: Full type safety across frontend and backend
- **Vite**: Fast development server and build tool
- **ESBuild**: Production bundling for server code
- **Drizzle Kit**: Database migrations and schema management

### Email Integration
- Primary: SendGrid API for production email delivery
- Fallback: SMTP with Nodemailer (including Ethereal for development)
- Email templates for approval workflows and notifications

## Deployment Strategy

### Development Environment
- Replit-optimized with custom .replit configuration
- Local PostgreSQL instance for development
- Hot module replacement via Vite
- Environment variable management via .env files

### Production Configuration
- SystemD service configuration for Linux deployment
- SSL certificate management with custom cert loading
- Multi-port configuration (HTTP/HTTPS)
- Health checks and monitoring setup

### Build Process
- Frontend: Vite build to `dist/public`
- Backend: ESBuild bundle to `dist/index.js`
- Asset handling: Static file serving with Express
- Database: Drizzle migrations with push strategy

### Security Features
- HTTPS support with custom certificates
- Session-based authentication with secure cookies
- Input validation and sanitization
- File upload restrictions and validation
- SQL injection prevention via Drizzle ORM

## Recent Changes

### June 18, 2025 - UI Styling and Logo Enhancement ✓ COMPLETED
- **CSS Styling Fix**: Resolved Tailwind CSS processing issue preventing rich UI display
  - Added Tailwind CDN fallback to ensure styles load properly
  - Fixed PostCSS configuration for proper CSS compilation
  - Restored comprehensive dashboard with all visual enhancements
- **Login Page Enhancement**: Improved Calpion logo prominence
  - Increased logo container size from 16x16 to 24x24 pixels
  - Enhanced logo image size from h-12 to h-20 for better visibility
  - Added shadow effects and improved spacing for professional appearance
- **Application Interface**: Full comprehensive dashboard restored
  - Animated gradient tabs with shine effects working
  - Rich statistics cards with color-coded status indicators
  - Professional Calpion branding throughout interface
  - All fancy UI components displaying correctly

### June 18, 2025 - Email Approval Redirect Loop Fixed ✓ COMPLETED
- **Critical Bug Fix**: Resolved redirect loop issue caused by SendGrid email approval routes
- **Email Approval System**: Fully functional with proper routing isolation
- **Application Status**: Fully operational in development mode

### June 18, 2025 - Ubuntu Production Deployment ✓ COMPLETED
- **Production Server Live**: IT Service Desk successfully deployed to Ubuntu server
  - Application accessible at https://98.81.235.7
  - PM2 process manager running servicedesk application (PID 117638)
  - Nginx reverse proxy with HTTPS redirect and SSL security headers
  - PostgreSQL database server configured and operational
- **Complete Infrastructure Stack**: Enterprise-grade production setup
  - Frontend: 661KB Vite build with enhanced Calpion branding
  - Backend: 152KB ESBuild server bundle with Express.js
  - Database: PostgreSQL with servicedesk user and schema
  - Security: Self-signed SSL certificate with TLS 1.2/1.3 protocols
  - Firewall: UFW configured for SSH (22), HTTP (80), HTTPS (443)
- **Application Features Deployed**: Full IT Service Desk functionality
  - Enhanced login page with prominent Calpion logo
  - Comprehensive dashboard with animated UI components
  - Ticket management with SLA tracking
  - Change request workflows with approval routing
  - User management with role-based access control
  - Email integration ready for SendGrid configuration

### June 18, 2025 - Repository Cleaned and Git-Ready ✓ COMPLETED
- **Repository Cleanup**: Removed all deployment artifacts and debugging files
- **Git Preparation**: Created comprehensive Git sync and deployment solution
- **Application Foundation**: Established clean, organized codebase structure

## User Preferences

Preferred communication style: Simple, everyday language.