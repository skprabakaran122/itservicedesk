# IT Service Desk Application

## Overview

This is a comprehensive IT Service Desk application built with modern web technologies. The system provides ticket management, change management, and user administration capabilities for IT support operations. The application supports both authenticated users and anonymous ticket submission, with comprehensive email notifications and approval workflows.

## System Architecture

### Frontend Architecture
- **Framework**: React 18 with TypeScript
- **UI Library**: Radix UI components with Tailwind CSS styling
- **State Management**: TanStack React Query for server state management
- **Form Handling**: React Hook Form with Zod validation
- **Build Tool**: Vite for fast development and optimized production builds
- **Routing**: React Router for client-side navigation

### Backend Architecture
- **Runtime**: Node.js 20 with TypeScript
- **Framework**: Express.js for REST API endpoints
- **Database ORM**: Drizzle ORM for type-safe database operations
- **Session Management**: Express-session with PostgreSQL store
- **File Handling**: Multer for file uploads and attachments
- **Email Service**: SendGrid integration for notifications

### Data Storage Solutions
- **Primary Database**: PostgreSQL for relational data storage
- **Schema Management**: Drizzle Kit for database migrations and schema updates
- **Connection Pooling**: Built-in PostgreSQL connection management
- **File Storage**: Local file system for ticket attachments

## Key Components

### Ticket Management System
- Anonymous and authenticated ticket creation
- Department and Business Unit categorization
- Priority-based routing and SLA tracking
- File attachment support
- Status workflow management (pending, open, in-progress, resolved, closed)
- Real-time updates and notifications

### Change Management System
- Change request creation and approval workflows
- Multi-level approval processes
- Risk assessment and categorization
- Implementation planning and tracking
- Rollback procedures and testing validation

### User Management
- Role-based access control (user, agent, manager, admin)
- Product assignment for specialized support
- User profile management
- Authentication and authorization

### Email Integration
- Dynamic email configuration (SendGrid/SMTP)
- Professional email templates with Calpion branding
- Automatic notifications for ticket and change events
- Test email functionality for configuration validation

## Data Flow

### Ticket Workflow
1. Ticket creation (anonymous or authenticated)
2. Automatic assignment based on category and product
3. SLA timer activation and tracking
4. Status updates with email notifications
5. Resolution and closure with customer confirmation

### Change Workflow
1. Change request submission
2. Risk assessment and categorization
3. Multi-level approval process
4. Implementation scheduling and execution
5. Testing validation and completion

### Authentication Flow
- Session-based authentication with PostgreSQL storage
- Role-based route protection
- Secure password handling and validation

## External Dependencies

### Core Dependencies
- **@tanstack/react-query**: Server state management and caching
- **@radix-ui/react-***: UI component primitives
- **drizzle-orm**: Type-safe database ORM
- **@sendgrid/mail**: Email service integration
- **express-session**: Session management
- **multer**: File upload handling

### Development Dependencies
- **tsx**: TypeScript execution for development
- **vite**: Build tool and development server
- **tailwindcss**: Utility-first CSS framework
- **drizzle-kit**: Database schema management

### Production Dependencies
- **PM2**: Process management for production deployment
- **PostgreSQL**: Production database server

## Deployment Strategy

### Development Environment
- Vite development server on port 5000
- Automatic TypeScript compilation and hot reload
- Development-friendly database configuration
- Replit-optimized environment with built-in PostgreSQL

### Production Deployment
- **Process Manager**: PM2 for application lifecycle management
- **Database**: PostgreSQL with connection pooling and authentication
- **Environment Configuration**: Environment variables for sensitive data
- **Build Process**: Vite production build with static asset optimization
- **Server Configuration**: Express.js serving both API and static files

### Production Setup Scripts
- Automated deployment scripts for Ubuntu servers
- Database schema migration and user setup
- Environment configuration and security hardening
- PM2 ecosystem configuration for reliable operation

### Key Configuration Files
- `ecosystem.config.cjs`: PM2 process configuration
- `drizzle.config.ts`: Database ORM configuration
- `vite.config.ts`: Build tool configuration
- `.env`: Environment variables for sensitive configuration

## Recent Changes

### June 17, 2025 - HTTPS Implementation & Complete Security Infrastructure ✓ COMPLETED
- **HTTPS Server Implementation**: Full SSL/TLS support with dual-port configuration
  - HTTPS server on port 5001 with SSL certificates (✓ Running)
  - HTTP server on port 5000 with automatic HTTPS redirection (✓ Running)
  - Self-signed certificate generation for development (✓ Working)
  - Production-ready certificate management (Let's Encrypt, custom certs)
- **Enhanced UI**: Fancy navigation buttons with premium styling and animations
  - Larger, more visible navigation with gradient effects and smooth transitions
  - Color-coded sections with hover animations and scale effects
  - Professional glassmorphism design with shadows and backdrop blur
- **Overdue Change Monitoring System**: Complete automated monitoring and notifications
  - Hourly checks for changes exceeding their implementation window
  - Professional overdue alert emails to all managers
  - Database tracking with isOverdue and overdueNotificationSent fields
  - Scheduler integration with existing SLA and auto-close systems
- **Security Enhancements**: Production-grade security headers and SSL management
  - HSTS, XSS protection, content-type protection, frame protection
  - Environment variable and file-based certificate management
  - Comprehensive HTTPS deployment guide and setup scripts
- **Database Connection Fixes**: Resolved SSL connection issues with Neon database
  - Proper SSL configuration for cloud database connections
  - Optimized connection pooling for stability
  - Fixed TypeScript errors in email service

### June 17, 2025 - Email-Based Approval System & Enhanced Workflows
- **Email-Based Approval System**: Managers can approve tickets and changes directly from email links
  - Secure token-based authentication for one-click approvals
  - Professional email templates with approve/reject buttons
  - Works for both tickets and change requests
  - No login required - streamlined approval process
- **Ticket Approval Workflow**: Complete system for agent-to-manager approval requests
  - Manager selection dialog for targeted approval requests
  - Email notifications to selected managers only
  - Approval status tracking with comments and timestamps
  - Status protection during pending approval (only open tickets can request approval)
- **Agent Ticket Visibility**: Enhanced visibility rules for agents
  - Agents can now see tickets they created for any product
  - Agents see tickets assigned to them for work
  - Agents see tickets for their assigned products (expertise area)
- **Database Schema Enhancements**: 
  - Added approval fields for tickets (approvalStatus, approvedBy, approvedAt, approvalComments, approvalToken)
  - Added approval token field for changes (approvalToken)
- **Email Integration**: SendGrid configuration complete (IP whitelisting needed for production)

## Changelog

- June 17, 2025. Initial setup with comprehensive ticketing system

## User Preferences

Preferred communication style: Simple, everyday language.