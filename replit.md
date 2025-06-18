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

### June 18, 2025 - Clean Deployment Package Complete ✓ COMPLETED
- **Deployment Package Created**: Complete deployment package with all application files ready for server transfer
  - Includes client/, server/, shared/ directories with all dependencies
  - Automated deployment scripts for Ubuntu server installation
  - Clean installation script for removing existing installations
- **Common Deployment Fixes**: Identified and created solutions for typical server deployment issues
  - PM2 configuration format error (module.exports in .js files)
  - Nginx proxy configuration syntax issues
  - Application startup and port binding problems
  - Environment variable loading issue (DATABASE_URL not accessible to Node.js)
  - ES modules import order causing dotenv to load after database module
  - ES modules vs CommonJS compatibility issues with PM2 process management
  - Silent process failures requiring comprehensive debugging and alternative startup methods
  - Database connection issues when cloud Neon configuration conflicts with local PostgreSQL setup
  - WebSocket connection errors requiring conversion from Neon serverless to standard PostgreSQL drivers
- **Clean Deployment Strategy**: Complete package with multiple deployment options
  - Git-based deployment with repository cloning and version control
  - Local file deployment for offline installation scenarios
  - Comprehensive cleanup tools for removing existing installations
  - Immediate fix scripts for common environment variable issues
  - All scripts include automatic system setup and security configuration

### June 17, 2025 - Production Database Connection Fixed ✓ COMPLETED
- **Local PostgreSQL Setup**: Successfully configured local PostgreSQL database on production server
  - PostgreSQL cluster properly started and configured to listen on port 5432
  - Created servicedesk database and user with proper authentication
  - Updated DATABASE_URL to use local connection: postgresql://servicedesk:password@localhost:5432/servicedesk
  - Connection timeout errors completely resolved
- **Database Configuration Optimization**: Enhanced connection settings for local database
  - Disabled SSL for local connections (ssl: false)
  - Optimized connection pool settings for local PostgreSQL
  - Reduced connection timeouts for faster local responses
- **Environment File Management**: Fixed .env file permissions and ownership
  - Proper www-data ownership for security compliance
  - Backup system implemented for configuration changes
  - Database connection tests passing successfully

### June 17, 2025 - Dynamic URL Detection & API Key Persistence ✓ COMPLETED
- **Dynamic Base URL Detection**: Automatic URL detection for all environments
  - Dev Preview: Auto-detects Replit preview domains without hardcoding
  - Production: Uses BASE_URL environment variable when available
  - Local Development: Falls back to localhost appropriately
- **Manager Approval Visibility Fix**: Managers now see all tickets pending approval
  - Modified getTicketsForUser() to include all pending approval tickets for managers
  - Approval workflow now works across all departments and assignments
- **SendGrid API Key Persistence**: Database storage for email configuration
  - Added settings table for persistent configuration storage
  - API key entered once stays saved between application restarts
  - Email configuration survives server reboots and deployments

### June 17, 2025 - Production Deployment Complete ✓ COMPLETED
- **Ubuntu Server Deployment**: Full production deployment on Ubuntu server completed
  - Git-based deployment with automated build process
  - Systemd service configuration for reliable operation
  - PostgreSQL database integration with proper connection handling
  - Environment variable management with secure .env file loading
  - Static file serving with proper build directory structure
- **Service Management**: Complete systemd integration
  - Auto-restart on failure with proper logging
  - Service starts automatically on server boot
  - Comprehensive logging through journalctl
  - Process management under www-data user for security
- **Email Integration**: SendGrid fully operational in production
  - API key configuration verified and working
  - Professional email notifications active
  - All notification workflows operational
- **Network Configuration**: HTTPS production setup complete
  - Nginx reverse proxy configured with SSL certificates
  - HTTPS accessible on standard port 443 with HTTP redirect
  - Self-signed certificates for secure IP-based access
  - Firewall configured for web traffic (ports 80, 443, 22)

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