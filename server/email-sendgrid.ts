import sgMail from '@sendgrid/mail';
import type { Ticket, Change, User } from '@shared/schema';
import { getEmailConfig, isEmailConfigured } from './email-config';

class EmailService {
  private isEnabled: boolean = false;
  private fromEmail: string = '';

  private getBaseUrl(): string {
    // Check for explicit BASE_URL override first (production)
    if (process.env.BASE_URL) {
      return process.env.BASE_URL;
    }
    
    // Auto-detect Replit environment URLs
    if (process.env.REPLIT_DEV_DOMAIN) {
      return `https://${process.env.REPLIT_DEV_DOMAIN}`;
    }
    
    // Check for Replit deployment URL patterns
    if (process.env.REPL_SLUG && process.env.REPL_OWNER) {
      return `https://${process.env.REPL_SLUG}.${process.env.REPL_OWNER}.repl.co`;
    }
    
    // Check for other Replit domain patterns
    if (process.env.REPLIT_DOMAINS) {
      const domains = process.env.REPLIT_DOMAINS.split(',');
      if (domains.length > 0) {
        return `https://${domains[0]}`;
      }
    }
    
    // Development fallback
    return 'http://localhost:5000';
  }

  constructor() {
    this.initialize();
  }

  private async initialize() {
    const config = await getEmailConfig();
    
    // Try dynamic config first, then fallback to environment variable
    const apiKey = config.sendgridApiKey || process.env.SENDGRID_API_KEY;
    
    if (apiKey && (config.provider === 'sendgrid' || !config.sendgridApiKey)) {
      try {
        // Validate API key format
        if (!apiKey.startsWith('SG.')) {
          console.log('[Email] Warning: SendGrid API key should start with "SG."');
        }
        
        // Trim any potential whitespace and set API key
        const cleanApiKey = apiKey.trim();
        sgMail.setApiKey(cleanApiKey);
        console.log(`[Email] Using API key: ${cleanApiKey.substring(0, 10)}...`);
        this.fromEmail = config.fromEmail || process.env.FROM_EMAIL || 'no-reply@calpion.com';
        this.isEnabled = true;
        console.log('[Email] SendGrid configured successfully');
        console.log(`[Email] From address: ${this.fromEmail}`);
        console.log(`[Email] API key format check: ${apiKey.startsWith('SG.') ? 'Valid' : 'Invalid'}`);
        console.log(`[Email] API key length: ${apiKey.length}`);
      } catch (error) {
        console.log('[Email] Failed to initialize SendGrid:', error);
        this.isEnabled = false;
      }
    } else {
      console.log('[Email] SENDGRID_API_KEY not configured. Email notifications disabled.');
      console.log('[Email] Please set SENDGRID_API_KEY environment variable to enable email notifications.');
      this.isEnabled = false;
    }
  }

  async reinitialize() {
    await this.initialize();
  }

  async sendEmail(to: string, subject: string, html: string, text?: string): Promise<boolean> {
    if (!this.isEnabled) {
      console.log('[Email] Email service disabled, skipping send');
      return false;
    }

    try {
      const msg = {
        to,
        from: this.fromEmail,
        subject,
        text: text || html.replace(/<[^>]*>/g, ''), // Strip HTML for text version
        html,
      };

      await sgMail.send(msg);
      console.log(`[Email] Email sent successfully to ${to}`);
      return true;
    } catch (error: any) {
      console.error('[Email] Failed to send email - Code:', error.code);
      
      // Log detailed SendGrid error information
      if (error.response && error.response.body) {
        console.error('[Email] SendGrid error details:', JSON.stringify(error.response.body, null, 2));
        if (error.response.body.errors) {
          error.response.body.errors.forEach((err: any, index: number) => {
            console.error(`[Email] Error ${index + 1}:`, err.message || err);
          });
        }
      }
      
      return false;
    }
  }

  async sendTicketCreatedEmail(ticket: Ticket, userEmail?: string): Promise<void> {
    if (!this.isEnabled) return;

    const recipientEmail = userEmail || ticket.requesterEmail || '';
    if (!recipientEmail) {
      console.log('[Email] No recipient email for ticket notification');
      return;
    }

    const subject = `Ticket Created: #${ticket.id} - ${ticket.title}`;
    const priorityColor = this.getPriorityColor(ticket.priority);
    const statusColor = this.getStatusColor(ticket.status);
    const responseTime = this.getResponseTime(ticket.priority);

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #1e40af; color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 24px;">Calpion IT Service Desk</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.9;">Ticket Created Successfully</p>
        </div>
        
        <div style="padding: 30px; background-color: #f8fafc;">
          <h2 style="color: #1e40af; margin-top: 0;">Ticket #${ticket.id}: ${ticket.title}</h2>
          
          <div style="background-color: white; border-radius: 8px; padding: 20px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px;">
              <div>
                <strong style="color: #374151;">Priority:</strong>
                <span style="background-color: ${priorityColor}; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; margin-left: 8px;">
                  ${ticket.priority.toUpperCase()}
                </span>
              </div>
              <div>
                <strong style="color: #374151;">Status:</strong>
                <span style="background-color: ${statusColor}; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; margin-left: 8px;">
                  ${ticket.status.toUpperCase()}
                </span>
              </div>
              <div>
                <strong style="color: #374151;">Category:</strong>
                <span style="color: #6b7280;">${ticket.category}</span>
              </div>
              <div>
                <strong style="color: #374151;">Expected Response:</strong>
                <span style="color: #6b7280;">${responseTime}</span>
              </div>
            </div>
            
            <div style="margin-top: 20px;">
              <strong style="color: #374151;">Description:</strong>
              <div style="margin-top: 8px; padding: 15px; background-color: #f9fafb; border-left: 4px solid #1e40af; border-radius: 4px;">
                ${ticket.description}
              </div>
            </div>
          </div>
          
          <div style="background-color: #e0f2fe; border-radius: 8px; padding: 20px; margin: 20px 0;">
            <h3 style="color: #0369a1; margin-top: 0;">What's Next?</h3>
            <ul style="color: #374151; line-height: 1.6;">
              <li>Your ticket has been logged and assigned ID #${ticket.id}</li>
              <li>Our team will respond within ${responseTime}</li>
              <li>You'll receive updates via email as progress is made</li>
              <li>For urgent issues, please contact our support hotline</li>
            </ul>
          </div>
          
          <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
            <p style="color: #6b7280; font-size: 14px; margin: 0;">
              This is an automated notification from Calpion IT Service Desk<br>
              Please do not reply to this email
            </p>
          </div>
        </div>
      </div>
    `;

    await this.sendEmail(recipientEmail, subject, html);
  }

  async sendTicketUpdatedEmail(ticket: Ticket, userEmail?: string, updateNote?: string): Promise<void> {
    if (!this.isEnabled) return;

    const recipientEmail = userEmail || ticket.requesterEmail || '';
    if (!recipientEmail) return;

    const subject = `Ticket Updated: #${ticket.id} - ${ticket.title}`;
    const priorityColor = this.getPriorityColor(ticket.priority);
    const statusColor = this.getStatusColor(ticket.status);

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #059669; color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 24px;">Calpion IT Service Desk</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.9;">Ticket Update</p>
        </div>
        
        <div style="padding: 30px; background-color: #f8fafc;">
          <h2 style="color: #059669; margin-top: 0;">Ticket #${ticket.id} has been updated</h2>
          
          <div style="background-color: white; border-radius: 8px; padding: 20px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h3 style="color: #374151; margin-top: 0;">${ticket.title}</h3>
            
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px;">
              <div>
                <strong style="color: #374151;">Priority:</strong>
                <span style="background-color: ${priorityColor}; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; margin-left: 8px;">
                  ${ticket.priority.toUpperCase()}
                </span>
              </div>
              <div>
                <strong style="color: #374151;">Status:</strong>
                <span style="background-color: ${statusColor}; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; margin-left: 8px;">
                  ${ticket.status.toUpperCase()}
                </span>
              </div>
            </div>
            
            ${updateNote ? `
              <div style="margin-top: 20px;">
                <strong style="color: #374151;">Update Notes:</strong>
                <div style="margin-top: 8px; padding: 15px; background-color: #f0f9ff; border-left: 4px solid #059669; border-radius: 4px;">
                  ${updateNote}
                </div>
              </div>
            ` : ''}
          </div>
          
          <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
            <p style="color: #6b7280; font-size: 14px; margin: 0;">
              This is an automated notification from Calpion IT Service Desk<br>
              Please do not reply to this email
            </p>
          </div>
        </div>
      </div>
    `;

    await this.sendEmail(recipientEmail, subject, html);
  }

  async sendChangeOverdueEmail(change: Change, managerEmail: string, managerName: string): Promise<void> {
    if (!this.isEnabled) {
      console.log('[Email] Service not enabled, skipping change overdue email');
      return;
    }

    const priorityColor = this.getPriorityColor(change.priority);
    const riskColor = change.riskLevel === 'high' ? '#ef4444' : change.riskLevel === 'medium' ? '#f59e0b' : '#10b981';
    
    const subject = `🚨 OVERDUE: Change Request #${change.id} - ${change.title}`;
    
    const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Change Request Overdue</title>
      <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #dc2626 0%, #ef4444 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: white; padding: 30px; border: 1px solid #e5e7eb; }
        .footer { background: #f9fafb; padding: 20px; text-align: center; font-size: 12px; color: #6b7280; border-radius: 0 0 8px 8px; }
        .change-info { background: #fef2f2; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #ef4444; }
        .overdue-alert { background: #fee2e2; border: 2px solid #fca5a5; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center; }
        .priority-${change.priority} { color: ${priorityColor}; font-weight: bold; }
        .risk-${change.riskLevel} { color: ${riskColor}; font-weight: bold; }
        .logo { font-size: 24px; font-weight: bold; margin-bottom: 10px; }
        .btn { display: inline-block; padding: 15px 30px; margin: 10px; text-decoration: none; border-radius: 6px; font-weight: bold; text-align: center; background: #dc2626; color: white; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">🚨 Calpion Change Management</div>
          <h1 style="margin: 0; font-size: 24px;">Change Request Overdue</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.9;">Immediate attention required</p>
        </div>

        <div class="content">
          <div class="overdue-alert">
            <h2 style="color: #dc2626; margin-top: 0;">⚠️ OVERDUE ALERT ⚠️</h2>
            <p style="font-size: 18px; margin: 10px 0;"><strong>This change has exceeded its planned implementation window and requires immediate attention.</strong></p>
          </div>

          <h2>Hello ${managerName},</h2>
          <p>Change Request #${change.id} has not been implemented within its planned window and is now <strong style="color: #dc2626;">OVERDUE</strong>. This requires immediate management attention.</p>

          <div class="change-info">
            <h3 style="margin-top: 0; color: #1f2937;">Overdue Change Details</h3>
            <p><strong>Change ID:</strong> #${change.id}</p>
            <p><strong>Title:</strong> ${change.title}</p>
            <p><strong>Priority:</strong> <span class="priority-${change.priority}">${change.priority.toUpperCase()}</span></p>
            <p><strong>Risk Level:</strong> <span class="risk-${change.riskLevel}">${change.riskLevel.toUpperCase()} RISK</span></p>
            <p><strong>Status:</strong> ${change.status}</p>
            <p><strong>Planned Date:</strong> ${change.plannedDate ? new Date(change.plannedDate).toLocaleDateString() : 'Not specified'}</p>
            <p><strong>End Date:</strong> ${change.endDate ? new Date(change.endDate).toLocaleDateString() : 'Not specified'}</p>
            <p><strong>Requested By:</strong> ${change.requestedBy}</p>
            <p><strong>Category:</strong> ${change.category}</p>
            <p><strong>Product:</strong> ${change.product || 'Not specified'}</p>
            <p><strong>Description:</strong></p>
            <div style="background: white; padding: 15px; border-radius: 4px; border: 1px solid #e5e7eb;">
              ${change.description}
            </div>
            ${change.rollbackPlan ? `
            <p><strong>Rollback Plan:</strong></p>
            <div style="background: #fffbeb; padding: 15px; border-radius: 4px; border: 1px solid #fed7aa;">
              ${change.rollbackPlan}
            </div>
            ` : ''}
          </div>

          <div style="background: #fee2e2; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h3 style="color: #dc2626; margin-top: 0;">🎯 Immediate Actions Required:</h3>
            <ul style="margin: 10px 0;">
              <li><strong>Investigate delay reasons</strong> - Identify what prevented implementation</li>
              <li><strong>Assess current risk</strong> - Evaluate impact of the delay</li>
              <li><strong>Update implementation plan</strong> - Set new realistic timeline</li>
              <li><strong>Communicate with stakeholders</strong> - Inform affected parties</li>
              <li><strong>Consider rollback</strong> - If implementation is no longer viable</li>
            </ul>
          </div>

          <div style="text-align: center; margin: 30px 0;">
            <a href="${this.getBaseUrl()}/dashboard?tab=changes" class="btn">📋 REVIEW CHANGE REQUEST</a>
          </div>

          <p style="color: #dc2626; font-weight: bold; text-align: center; font-size: 16px;">
            This change is now overdue and requires immediate management intervention.
          </p>

          <p style="color: #6b7280; font-size: 14px; margin-top: 20px;">
            <strong>Note:</strong> Only administrators can close overdue changes. Please review and take appropriate action as soon as possible.
          </p>
        </div>

        <div class="footer">
          <p>Calpion Change Management System | Overdue Alert</p>
          <p>This is an automated notification. Please do not reply to this email.</p>
        </div>
      </div>
    </body>
    </html>
    `;

    const text = `
OVERDUE ALERT: Change Request #${change.id}

Change: ${change.title}
Priority: ${change.priority.toUpperCase()}
Risk Level: ${change.riskLevel.toUpperCase()}
Status: ${change.status}
Planned Date: ${change.plannedDate ? new Date(change.plannedDate).toLocaleDateString() : 'Not specified'}

This change has exceeded its planned implementation window and requires immediate attention.

Please log into the Change Management portal to review and take action.

This is an automated notification from Calpion Change Management System.
    `;

    await this.sendEmail(managerEmail, subject, html, text);
    console.log(`[Email] Change overdue notification sent to ${managerEmail} for change #${change.id}`);
  }

  async sendChangeApprovalEmail(change: Change, approverEmail: string, approverName: string): Promise<void> {
    if (!this.isEnabled) return;

    const subject = `Change Approval Required: #${change.id} - ${change.title}`;
    const priorityColor = this.getPriorityColor(change.priority);

    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background-color: #dc2626; color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 24px;">Calpion IT Service Desk</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.9;">Change Approval Required</p>
        </div>
        
        <div style="padding: 30px; background-color: #f8fafc;">
          <h2 style="color: #dc2626; margin-top: 0;">Change #${change.id} Requires Your Approval</h2>
          
          <p style="color: #374151; font-size: 16px;">Hello ${approverName},</p>
          <p style="color: #374151;">A change request has been submitted that requires your approval:</p>
          
          <div style="background-color: white; border-radius: 8px; padding: 20px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h3 style="color: #374151; margin-top: 0;">${change.title}</h3>
            
            <div style="margin-bottom: 15px;">
              <strong style="color: #374151;">Priority:</strong>
              <span style="background-color: ${priorityColor}; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; margin-left: 8px;">
                ${change.priority.toUpperCase()}
              </span>
            </div>
            
            <div style="margin-bottom: 15px;">
              <strong style="color: #374151;">Requested By:</strong>
              <span style="color: #6b7280;">${change.requestedBy}</span>
            </div>
            
            <div style="margin-bottom: 15px;">
              <strong style="color: #374151;">Planned Date:</strong>
              <span style="color: #6b7280;">${change.plannedDate ? new Date(change.plannedDate).toLocaleDateString() : 'Not scheduled'}</span>
            </div>
            
            <div style="margin-top: 20px;">
              <strong style="color: #374151;">Description:</strong>
              <div style="margin-top: 8px; padding: 15px; background-color: #f9fafb; border-left: 4px solid #dc2626; border-radius: 4px;">
                ${change.description}
              </div>
            </div>
          </div>
          
          <div style="background-color: #fef3c7; border-radius: 8px; padding: 20px; margin: 20px 0;">
            <h3 style="color: #92400e; margin-top: 0;">Action Required</h3>
            <p style="color: #374151; margin: 0;">
              Please review this change request and provide your approval decision. 
              Log into the IT Service Desk portal to approve or reject this change.
            </p>
          </div>
          
          <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;">
            <p style="color: #6b7280; font-size: 14px; margin: 0;">
              This is an automated notification from Calpion IT Service Desk<br>
              Please do not reply to this email
            </p>
          </div>
        </div>
      </div>
    `;

    await this.sendEmail(approverEmail, subject, html);
  }

  private getPriorityColor(priority: string): string {
    switch (priority.toLowerCase()) {
      case 'critical': return '#dc2626';
      case 'high': return '#ea580c';
      case 'medium': return '#d97706';
      case 'low': return '#65a30d';
      default: return '#6b7280';
    }
  }

  private getStatusColor(status: string): string {
    switch (status.toLowerCase()) {
      case 'open': return '#2563eb';
      case 'in_progress': return '#d97706';
      case 'resolved': return '#16a34a';
      case 'closed': return '#6b7280';
      default: return '#6b7280';
    }
  }

  private getResponseTime(priority: string): string {
    switch (priority.toLowerCase()) {
      case 'critical': return '1 hour';
      case 'high': return '4 hours';
      case 'medium': return '24 hours';
      case 'low': return '72 hours';
      default: return '24 hours';
    }
  }

  async sendTicketApprovalEmailWithLinks(ticket: Ticket, approverEmail: string, approverName: string, approvalToken: string): Promise<void> {
    if (!this.isEnabled) {
      console.log('[Email] Service not enabled, skipping approval email with links');
      return;
    }

    const baseUrl = this.getBaseUrl();

    const approveUrl = `${baseUrl}/approval/tickets/${ticket.id}/approve/${approvalToken}`;
    const rejectUrl = `${baseUrl}/approval/tickets/${ticket.id}/reject/${approvalToken}`;

    const priorityColor = this.getPriorityColor(ticket.priority);
    const responseTime = this.getResponseTime(ticket.priority);

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Ticket Approval Required</title>
        <style>
          body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: white; padding: 30px; border: 1px solid #e5e7eb; }
          .footer { background: #f9fafb; padding: 20px; text-align: center; font-size: 12px; color: #6b7280; border-radius: 0 0 8px 8px; }
          .ticket-info { background: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid ${priorityColor}; }
          .approval-buttons { text-align: center; margin: 30px 0; }
          .btn { display: inline-block; padding: 15px 30px; margin: 10px; text-decoration: none; border-radius: 6px; font-weight: bold; text-align: center; transition: all 0.3s ease; }
          .btn-approve { background: #10b981; color: white; }
          .btn-approve:hover { background: #059669; }
          .btn-reject { background: #ef4444; color: white; }
          .btn-reject:hover { background: #dc2626; }
          .priority-${ticket.priority} { color: ${priorityColor}; font-weight: bold; }
          .urgent-notice { background: #fef2f2; border: 1px solid #fecaca; padding: 15px; border-radius: 6px; margin: 20px 0; }
          .logo { font-size: 24px; font-weight: bold; margin-bottom: 10px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="logo">🏢 Calpion IT Service Desk</div>
            <h1 style="margin: 0; font-size: 24px;">Ticket Approval Required</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">An agent is requesting your approval to proceed</p>
          </div>

          <div class="content">
            <h2>Hello ${approverName},</h2>
            <p>An agent has requested your approval to work on the following ticket. You can approve or reject this request directly from this email.</p>

            <div class="ticket-info">
              <h3 style="margin-top: 0; color: #1f2937;">Ticket Details</h3>
              <p><strong>Ticket ID:</strong> #${ticket.id}</p>
              <p><strong>Title:</strong> ${ticket.title}</p>
              <p><strong>Priority:</strong> <span class="priority-${ticket.priority}">${ticket.priority.toUpperCase()}</span></p>
              <p><strong>Category:</strong> ${ticket.category}</p>
              <p><strong>Product:</strong> ${ticket.product || 'Not specified'}</p>
              <p><strong>Description:</strong></p>
              <div style="background: white; padding: 15px; border-radius: 4px; border: 1px solid #e5e7eb;">
                ${ticket.description}
              </div>
              ${ticket.approvalComments ? `
                <p><strong>Agent Comments:</strong></p>
                <div style="background: #fffbeb; padding: 15px; border-radius: 4px; border: 1px solid #fed7aa;">
                  ${ticket.approvalComments}
                </div>
              ` : ''}
            </div>

            <div class="approval-buttons">
              <h3>Click to make your decision:</h3>
              <a href="${approveUrl}" class="btn btn-approve">✓ APPROVE TICKET</a>
              <a href="${rejectUrl}" class="btn btn-reject">✗ REJECT TICKET</a>
            </div>

            <div class="urgent-notice">
              <p><strong>⏰ Response Time:</strong> ${responseTime}</p>
              <p style="margin: 5px 0 0 0;">Please review and respond promptly to maintain our service level commitments.</p>
            </div>

            <p style="margin-top: 30px;">
              <strong>What happens next?</strong><br>
              • If you <strong>approve</strong>: The ticket will be opened and the agent can begin work<br>
              • If you <strong>reject</strong>: The ticket will remain in its current state and the agent will be notified
            </p>

            <p style="color: #6b7280; font-size: 14px; margin-top: 20px;">
              You can also log into the IT Service Desk portal to review this request in detail if needed.
            </p>
          </div>

          <div class="footer">
            <p>Calpion IT Service Desk | Automated Notification System</p>
            <p>This email was sent automatically. Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    const text = `
Ticket Approval Required

Hello ${approverName},

An agent has requested your approval to work on ticket #${ticket.id}.

Ticket Details:
- Title: ${ticket.title}
- Priority: ${ticket.priority.toUpperCase()}
- Category: ${ticket.category}
- Product: ${ticket.product || 'Not specified'}
- Description: ${ticket.description}

To approve this ticket, visit: ${approveUrl}
To reject this ticket, visit: ${rejectUrl}

Response Time: ${responseTime}

Calpion IT Service Desk
    `;

    try {
      await this.sendEmail(
        approverEmail,
        `🔔 Approval Required: Ticket #${ticket.id} - ${ticket.title}`,
        html,
        text
      );
      console.log(`[Email] Approval email with links sent to ${approverEmail} for ticket #${ticket.id}`);
    } catch (error) {
      console.error('[Email] Failed to send approval email with links:', error);
      throw error;
    }
  }

  async sendTicketApprovalEmail(ticket: Ticket, approverEmail: string, approverName: string): Promise<void> {
    if (!this.isEnabled) return;

    const subject = `[Ticket Approval Required] ${ticket.title}`;
    const priorityColor = this.getPriorityColor(ticket.priority);
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0; font-size: 24px;">Ticket Approval Required</h1>
          <p style="margin: 10px 0 0 0; opacity: 0.9;">Calpion IT Service Desk</p>
        </div>
        
        <div style="padding: 30px; background-color: #f8f9fa;">
          <p style="font-size: 16px; color: #333; margin-bottom: 20px;">
            Dear ${approverName},
          </p>
          
          <p style="color: #666; line-height: 1.6;">
            A support ticket requires your approval before it can be worked on. Please review the details below:
          </p>
          
          <div style="background: white; border-radius: 8px; padding: 20px; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
            <h3 style="color: #333; margin: 0 0 15px 0; font-size: 18px;">${ticket.title}</h3>
            
            <div style="display: grid; grid-template-columns: 120px 1fr; gap: 10px; margin-bottom: 15px;">
              <strong style="color: #555;">Ticket ID:</strong>
              <span style="color: #333;">#${ticket.id}</span>
              
              <strong style="color: #555;">Priority:</strong>
              <span style="color: ${priorityColor}; font-weight: bold; text-transform: uppercase;">${ticket.priority}</span>
              
              <strong style="color: #555;">Category:</strong>
              <span style="color: #333;">${ticket.category}</span>
              
              <strong style="color: #555;">Product:</strong>
              <span style="color: #333;">${ticket.product || 'Not specified'}</span>
              
              <strong style="color: #555;">Requester:</strong>
              <span style="color: #333;">${ticket.requesterName || 'Unknown'}</span>
              
              <strong style="color: #555;">Department:</strong>
              <span style="color: #333;">${ticket.requesterDepartment || 'Not specified'}</span>
            </div>
            
            <div style="border-top: 1px solid #eee; padding-top: 15px;">
              <strong style="color: #555; display: block; margin-bottom: 8px;">Description:</strong>
              <p style="color: #333; line-height: 1.6; margin: 0;">${ticket.description}</p>
            </div>
          </div>
          
          <div style="text-align: center; margin: 30px 0;">
            <p style="color: #666; margin-bottom: 15px;">Please review and approve this ticket to allow agents to begin work.</p>
            <p style="color: #888; font-size: 14px; margin: 20px 0;">
              Log in to the Calpion IT Service Desk to approve or reject this ticket.
            </p>
          </div>
        </div>
        
        <div style="background-color: #667eea; color: white; padding: 20px; text-align: center;">
          <p style="margin: 0; font-size: 14px;">
            This is an automated notification from Calpion IT Service Desk
          </p>
        </div>
      </div>
    `;

    const text = `
Ticket Approval Required - ${ticket.title}

Dear ${approverName},

A support ticket requires your approval before it can be worked on:

Ticket ID: #${ticket.id}
Title: ${ticket.title}
Priority: ${ticket.priority}
Category: ${ticket.category}
Product: ${ticket.product || 'Not specified'}
Requester: ${ticket.requesterName || 'Unknown'}
Department: ${ticket.requesterDepartment || 'Not specified'}

Description: ${ticket.description}

Please log in to the Calpion IT Service Desk to review and approve this ticket.

This is an automated notification from Calpion IT Service Desk.
    `;

    await this.sendEmail(approverEmail, subject, html, text);
  }

  async sendChangeApprovalEmailWithLinks(change: Change, approverEmail: string, approverName: string, approvalToken: string): Promise<void> {
    if (!this.isEnabled) {
      console.log('[Email] Service not enabled, skipping change approval email with links');
      return;
    }

    const baseUrl = this.getBaseUrl();

    const approveUrl = `${baseUrl}/approval/changes/${change.id}/approve/${approvalToken}`;
    const rejectUrl = `${baseUrl}/approval/changes/${change.id}/reject/${approvalToken}`;

    const priorityColor = this.getPriorityColor(change.priority);
    const riskColor = change.riskLevel === 'high' ? '#ef4444' : change.riskLevel === 'medium' ? '#f59e0b' : '#10b981';

    const html = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Change Request Approval Required</title>
        <style>
          body { font-family: 'Segoe UI', Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #7c3aed 0%, #a855f7 100%); color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background: white; padding: 30px; border: 1px solid #e5e7eb; }
          .footer { background: #f9fafb; padding: 20px; text-align: center; font-size: 12px; color: #6b7280; border-radius: 0 0 8px 8px; }
          .change-info { background: #faf5ff; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid ${priorityColor}; }
          .approval-buttons { text-align: center; margin: 30px 0; }
          .btn { display: inline-block; padding: 15px 30px; margin: 10px; text-decoration: none; border-radius: 6px; font-weight: bold; text-align: center; transition: all 0.3s ease; }
          .btn-approve { background: #10b981; color: white; }
          .btn-approve:hover { background: #059669; }
          .btn-reject { background: #ef4444; color: white; }
          .btn-reject:hover { background: #dc2626; }
          .priority-${change.priority} { color: ${priorityColor}; font-weight: bold; }
          .risk-${change.riskLevel} { color: ${riskColor}; font-weight: bold; }
          .urgent-notice { background: #fef2f2; border: 1px solid #fecaca; padding: 15px; border-radius: 6px; margin: 20px 0; }
          .logo { font-size: 24px; font-weight: bold; margin-bottom: 10px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="logo">🔄 Calpion Change Management</div>
            <h1 style="margin: 0; font-size: 24px;">Change Request Approval Required</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Your approval is needed to proceed with this change</p>
          </div>

          <div class="content">
            <h2>Hello ${approverName},</h2>
            <p>A change request has been submitted and requires your approval before implementation can begin. You can approve or reject this request directly from this email.</p>

            <div class="change-info">
              <h3 style="margin-top: 0; color: #1f2937;">Change Request Details</h3>
              <p><strong>Change ID:</strong> #${change.id}</p>
              <p><strong>Title:</strong> ${change.title}</p>
              <p><strong>Priority:</strong> <span class="priority-${change.priority}">${change.priority.toUpperCase()}</span></p>
              <p><strong>Risk Level:</strong> <span class="risk-${change.riskLevel}">${change.riskLevel.toUpperCase()}</span></p>
              <p><strong>Change Type:</strong> ${change.changeType}</p>
              <p><strong>Category:</strong> ${change.category}</p>
              <p><strong>Product:</strong> ${change.product || 'Not specified'}</p>
              <p><strong>Requested By:</strong> ${change.requestedBy}</p>
              ${change.plannedDate ? `<p><strong>Planned Date:</strong> ${new Date(change.plannedDate).toLocaleDateString()}</p>` : ''}
              <p><strong>Description:</strong></p>
              <div style="background: white; padding: 15px; border-radius: 4px; border: 1px solid #e5e7eb;">
                ${change.description}
              </div>
              ${change.rollbackPlan ? `
                <p><strong>Rollback Plan:</strong></p>
                <div style="background: #fffbeb; padding: 15px; border-radius: 4px; border: 1px solid #fed7aa;">
                  ${change.rollbackPlan}
                </div>
              ` : ''}
            </div>

            <div class="approval-buttons">
              <h3>Click to make your decision:</h3>
              <a href="${approveUrl}" class="btn btn-approve">✓ APPROVE CHANGE</a>
              <a href="${rejectUrl}" class="btn btn-reject">✗ REJECT CHANGE</a>
            </div>

            <div class="urgent-notice">
              <p><strong>⚠️ Risk Assessment:</strong> This is a <span class="risk-${change.riskLevel}">${change.riskLevel.toUpperCase()} RISK</span> change</p>
              <p style="margin: 5px 0 0 0;">Please review all details carefully before making your decision.</p>
            </div>

            <p style="margin-top: 30px;">
              <strong>What happens next?</strong><br>
              • If you <strong>approve</strong>: The change will be scheduled for implementation<br>
              • If you <strong>reject</strong>: The change will be returned to the requester for revision
            </p>

            <p style="color: #6b7280; font-size: 14px; margin-top: 20px;">
              You can also log into the Change Management portal to review this request in detail if needed.
            </p>
          </div>

          <div class="footer">
            <p>Calpion Change Management System | Automated Notification</p>
            <p>This email was sent automatically. Please do not reply to this email.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    const text = `
Change Request Approval Required

Hello ${approverName},

A change request has been submitted and requires your approval.

Change Details:
- ID: #${change.id}
- Title: ${change.title}
- Priority: ${change.priority.toUpperCase()}
- Risk Level: ${change.riskLevel.toUpperCase()}
- Change Type: ${change.changeType}
- Category: ${change.category}
- Product: ${change.product || 'Not specified'}
- Requested By: ${change.requestedBy}
- Description: ${change.description}

To approve this change, visit: ${approveUrl}
To reject this change, visit: ${rejectUrl}

Calpion Change Management System
    `;

    try {
      await this.sendEmail(
        approverEmail,
        `🔄 Change Approval Required: #${change.id} - ${change.title}`,
        html,
        text
      );
      console.log(`[Email] Change approval email with links sent to ${approverEmail} for change #${change.id}`);
    } catch (error) {
      console.error('[Email] Failed to send change approval email with links:', error);
      throw error;
    }
  }
}

export const emailService = new EmailService();