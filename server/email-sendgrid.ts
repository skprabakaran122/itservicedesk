import sgMail from '@sendgrid/mail';
import type { Ticket, Change, User } from '@shared/schema';
import { getEmailConfig, isEmailConfigured } from './email-config';

class EmailService {
  private isEnabled: boolean = false;
  private fromEmail: string = '';

  constructor() {
    this.initialize();
  }

  private async initialize() {
    const config = getEmailConfig();
    
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
              <strong style="color: #374151;">Implementation Date:</strong>
              <span style="color: #6b7280;">${new Date(change.scheduledDate).toLocaleDateString()}</span>
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
}

export const emailService = new EmailService();