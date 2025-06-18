# IT Service Desk

A comprehensive IT Service Desk application built for Calpion, featuring ticket management, change requests, user administration, and automated workflows.

## Features

### Core Functionality
- **Ticket Management**: Submit, track, and resolve IT support tickets
- **Change Requests**: Approval workflows with risk-based routing
- **User Management**: Role-based access control (Admin, Agent, User)
- **SLA Tracking**: Automated metrics and performance monitoring
- **Email Notifications**: SendGrid integration with approval workflows

### Technical Features
- **Modern Stack**: React 18 + TypeScript + Express.js
- **Database**: PostgreSQL with Drizzle ORM
- **Authentication**: Session-based with Passport.js
- **Real-time Updates**: WebSocket support
- **File Uploads**: Secure attachment handling
- **Responsive Design**: Mobile-first Tailwind CSS

### Security & Deployment
- **HTTPS Support**: SSL certificate management
- **Process Management**: PM2 with auto-restart
- **Web Server**: Nginx reverse proxy
- **Environment Detection**: Development (Neon) vs Production (local PostgreSQL)

## Quick Start

### Development (Replit)
```bash
npm install
npm run dev
```
Visit the preview URL provided in the console.

### Production Deployment
```bash
git clone <your-repo-url>
cd <repo-directory>
chmod +x deploy.sh
./deploy.sh [server-ip-or-domain]
```

## Architecture

```
Frontend (React + TypeScript)
├── Components: shadcn/ui + Radix UI
├── State: TanStack Query
├── Routing: Wouter
└── Build: Vite

Backend (Express + TypeScript)
├── Database: Drizzle ORM
├── Auth: Passport.js sessions
├── Email: SendGrid + Nodemailer
└── Build: ESBuild

Database (PostgreSQL)
├── Development: Neon serverless
├── Production: Local PostgreSQL
└── Migrations: Drizzle Kit
```

## Configuration

### Environment Variables

**Development (.env)**
```env
DATABASE_URL=<neon-database-url>
NODE_ENV=development
PORT=5000
SENDGRID_API_KEY=<your-sendgrid-key>
```

**Production (.env)**
```env
DATABASE_URL=postgresql://servicedesk:servicedesk123@localhost:5432/servicedesk
NODE_ENV=production
PORT=3000
SENDGRID_API_KEY=<your-sendgrid-key>
```

### Database Setup

The application automatically detects the environment:
- **Development**: Uses Neon serverless database
- **Production**: Uses local PostgreSQL

## Deployment

### Prerequisites
- Ubuntu 20.04+ server
- Domain name or static IP
- SendGrid API key (optional, for email notifications)

### Automated Deployment
```bash
./deploy.sh [server-ip]
```

This script:
1. Installs Node.js 20, PostgreSQL, Nginx
2. Creates database and user
3. Builds the application
4. Configures PM2 process manager
5. Sets up Nginx reverse proxy
6. Configures firewall

### Manual Deployment
See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed manual setup instructions.

## Development

### Project Structure
```
├── client/          # React frontend
│   ├── src/
│   │   ├── components/  # UI components
│   │   ├── pages/       # Application pages
│   │   └── lib/         # Utilities
├── server/          # Express backend
│   ├── routes.ts    # API endpoints
│   ├── storage.ts   # Data layer
│   ├── db.ts        # Database connection
│   └── email.ts     # Email services
├── shared/          # Shared types and schemas
│   └── schema.ts    # Database schema
└── deploy.sh        # Production deployment script
```

### Key Commands
```bash
npm run dev          # Start development server
npm run build        # Build for production
npm run start        # Start production server
npm run db:push      # Push database schema changes
npm run check        # TypeScript type checking
```

### Adding Features

1. **Database Changes**: Update `shared/schema.ts` and run `npm run db:push`
2. **API Endpoints**: Add routes in `server/routes.ts`
3. **Frontend Pages**: Create components in `client/src/pages/`
4. **UI Components**: Use shadcn/ui components from `@/components/ui/`

## Management

### Production Commands
```bash
# Process management
pm2 status              # Check application status
pm2 restart servicedesk # Restart application
pm2 logs servicedesk    # View logs

# Updates
git pull                # Pull latest changes
npm run build          # Rebuild application
pm2 restart servicedesk # Restart with new build

# Database
npm run db:push        # Apply schema changes
```

### Monitoring
- Application logs: `pm2 logs servicedesk`
- Nginx logs: `/var/log/nginx/`
- Database logs: `sudo journalctl -u postgresql`

## Git Sync

To sync your local changes to Git:
```bash
./sync-to-git.sh <repository-url> [branch-name]
```

## Support

### Common Issues

**Database Connection Error**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Restart PostgreSQL
sudo systemctl restart postgresql
```

**Application Not Starting**
```bash
# Check PM2 logs
pm2 logs servicedesk

# Restart application
pm2 restart servicedesk
```

**Nginx Configuration Error**
```bash
# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

### Environment Troubleshooting

**Development Issues**
- Ensure DATABASE_URL points to Neon database
- Check SENDGRID_API_KEY is valid
- Verify all dependencies installed: `npm install`

**Production Issues**
- Confirm local PostgreSQL is running
- Check firewall allows HTTP/HTTPS traffic
- Verify PM2 is managing the process correctly

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

Built with ❤️ for Calpion IT Services