import nodemailer from 'nodemailer';
import type { Ticket, Change, User } from '@shared/schema';

class EmailService {
  private transporter: nodemailer.Transporter | null = null;
  private fromEmail: string = '';
  private isEnabled: boolean = false;

  constructor() {
    this.initialize();
  }

  private async initialize() {
    // Check for SMTP configuration in environment variables
    const smtpHost = process.env.SMTP_HOST;
    const smtpPort = process.env.SMTP_PORT;
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;
    const smtpSecure = process.env.SMTP_SECURE === 'true';

    if (!smtpHost && !smtpUser) {
      // Create test account using Ethereal Email for development
      try {
        const testAccount = await nodemailer.createTestAccount();
        console.log('[Email] Using Ethereal Email test account for development');
        console.log(`[Email] Preview emails at: https://ethereal.email/`);
        console.log(`[Email] Test account: ${testAccount.user}`);

        this.transporter = nodemailer.createTransport({
          host: 'smtp.ethereal.email',
          port: 587,
          secure: false,
          auth: {
            user: testAccount.user,
            pass: testAccount.pass
          }
        });

        this.fromEmail = testAccount.user;
        this.isEnabled = true;
        return;
      } catch (error) {
        console.log('[Email] Failed to create test account, email notifications disabled');
        return;
      }
    }

    if (!smtpHost || !smtpUser || !smtpPass) {
      console.log('[Email] SMTP configuration incomplete. Email notifications disabled.');
      console.log('[Email] Required: SMTP_HOST, SMTP_USER, SMTP_PASS');
      console.log('[Email] Optional: SMTP_PORT (default: 587), SMTP_SECURE (default: false)');
      return;
    }

    this.fromEmail = smtpUser;

    try {
      this.transporter = nodemailer.createTransport({
        host: smtpHost,
        port: parseInt(smtpPort || '587'),
        secure: smtpSecure,
        auth: {
          user: smtpUser,
          pass: smtpPass
        }
      });

      this.isEnabled = true;
      console.log(`[Email] SMTP service initialized with ${smtpHost}:${smtpPort}`);
    } catch (error) {
      console.error('[Email] Failed to initialize SMTP service:', error);
    }
  }

  async sendEmail(to: string, subject: string, html: string, text?: string): Promise<boolean> {
    if (!this.isEnabled || !this.transporter) {
      console.log('[Email] Email service not enabled, skipping email send');
      return false;
    }

    try {
      const info = await this.transporter.sendMail({
        from: `"Calpion IT Support" <${this.fromEmail}>`,
        to,
        subject,
        html,
        text: text || html.replace(/<[^>]*>/g, '') // Strip HTML for text version
      });
      
      console.log(`[Email] Email sent successfully to ${to}: ${subject}`);
      
      // If using Ethereal Email, log the preview URL
      if (nodemailer.getTestMessageUrl(info)) {
        console.log(`[Email] Preview URL: ${nodemailer.getTestMessageUrl(info)}`);
      }
      
      return true;
    } catch (error) {
      console.error(`[Email] Failed to send email to ${to}:`, error);
      return false;
    }
  }

  // Ticket notification emails
  async sendTicketCreatedEmail(ticket: Ticket, userEmail?: string): Promise<void> {
    if (!userEmail && !ticket.requesterEmail) return;

    const email = userEmail || ticket.requesterEmail!;
    const subject = `Ticket Created: ${ticket.title} [#${ticket.id}]`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0;">Calpion IT Support</h1>
          <p style="margin: 5px 0 0 0;">Your ticket has been created</p>
        </div>
        
        <div style="padding: 20px; background: #f9f9f9;">
          <h2 style="color: #333; margin-top: 0;">Ticket Details</h2>
          <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Ticket ID:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">#${ticket.id}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Title:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${ticket.title}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Priority:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;"><span style="background: ${this.getPriorityColor(ticket.priority)}; color: white; padding: 2px 8px; border-radius: 4px;">${ticket.priority}</span></td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Status:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;"><span style="background: ${this.getStatusColor(ticket.status)}; color: white; padding: 2px 8px; border-radius: 4px;">${ticket.status}</span></td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Created:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${new Date(ticket.createdAt).toLocaleString()}</td></tr>
          </table>
          
          <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 5px;">
            <h3 style="margin-top: 0; color: #333;">Description:</h3>
            <p style="margin: 0; line-height: 1.6;">${ticket.description}</p>
          </div>
          
          <div style="margin: 20px 0; padding: 15px; background: #e8f4f8; border-radius: 5px; border-left: 4px solid #17a2b8;">
            <h3 style="margin-top: 0; color: #17a2b8;">What happens next?</h3>
            <ul style="margin: 0; padding-left: 20px;">
              <li>Our support team will review your ticket</li>
              <li>You'll receive updates via email when status changes</li>
              <li>Expected first response: ${this.getResponseTime(ticket.priority)}</li>
            </ul>
          </div>
        </div>
        
        <div style="padding: 20px; background: #333; color: white; text-align: center;">
          <p style="margin: 0;">Need immediate help? Contact us at <strong>support@calpion.com</strong></p>
          <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.8;">This is an automated message from Calpion IT Support</p>
        </div>
      </div>
    `;

    await this.sendEmail(email, subject, html);
  }

  async sendTicketUpdatedEmail(ticket: Ticket, userEmail?: string, updateNote?: string): Promise<void> {
    if (!userEmail && !ticket.requesterEmail) return;

    const email = userEmail || ticket.requesterEmail!;
    const subject = `Ticket Updated: ${ticket.title} [#${ticket.id}]`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0;">Calpion IT Support</h1>
          <p style="margin: 5px 0 0 0;">Your ticket has been updated</p>
        </div>
        
        <div style="padding: 20px; background: #f9f9f9;">
          <h2 style="color: #333; margin-top: 0;">Ticket Update</h2>
          <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Ticket ID:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">#${ticket.id}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Title:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${ticket.title}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Current Status:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;"><span style="background: ${this.getStatusColor(ticket.status)}; color: white; padding: 2px 8px; border-radius: 4px;">${ticket.status}</span></td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Priority:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;"><span style="background: ${this.getPriorityColor(ticket.priority)}; color: white; padding: 2px 8px; border-radius: 4px;">${ticket.priority}</span></td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Updated:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${new Date(ticket.updatedAt).toLocaleString()}</td></tr>
          </table>
          
          ${updateNote ? `
          <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 5px;">
            <h3 style="margin-top: 0; color: #333;">Update Notes:</h3>
            <p style="margin: 0; line-height: 1.6;">${updateNote}</p>
          </div>
          ` : ''}
          
          ${ticket.status === 'resolved' ? `
          <div style="margin: 20px 0; padding: 15px; background: #d4edda; border-radius: 5px; border-left: 4px solid #28a745;">
            <h3 style="margin-top: 0; color: #28a745;">✅ Ticket Resolved</h3>
            <p style="margin: 0;">Your ticket has been marked as resolved. If you need further assistance, please reply to this email or create a new ticket.</p>
          </div>
          ` : ''}
        </div>
        
        <div style="padding: 20px; background: #333; color: white; text-align: center;">
          <p style="margin: 0;">Need help? Contact us at <strong>support@calpion.com</strong></p>
          <p style="margin: 5px 0 0 0; font-size: 12px; opacity: 0.8;">This is an automated message from Calpion IT Support</p>
        </div>
      </div>
    `;

    await this.sendEmail(email, subject, html);
  }

  async sendChangeApprovalEmail(change: Change, approverEmail: string, approverName: string): Promise<void> {
    const subject = `Change Approval Required: ${change.title} [#${change.id}]`;
    
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #ff6b6b 0%, #feca57 100%); color: white; padding: 20px; text-align: center;">
          <h1 style="margin: 0;">Calpion IT Support</h1>
          <p style="margin: 5px 0 0 0;">Change approval required</p>
        </div>
        
        <div style="padding: 20px; background: #f9f9f9;">
          <h2 style="color: #333; margin-top: 0;">Hello ${approverName},</h2>
          <p>A change request requires your approval:</p>
          
          <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Change ID:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">#${change.id}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Title:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${change.title}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Priority:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;"><span style="background: ${this.getPriorityColor(change.priority)}; color: white; padding: 2px 8px; border-radius: 4px;">${change.priority}</span></td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Risk Level:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${change.riskLevel}</td></tr>
            <tr><td style="padding: 8px; border-bottom: 1px solid #ddd;"><strong>Requested By:</strong></td><td style="padding: 8px; border-bottom: 1px solid #ddd;">${change.requestedBy}</td></tr>
          </table>
          
          <div style="margin: 20px 0; padding: 15px; background: white; border-radius: 5px;">
            <h3 style="margin-top: 0; color: #333;">Description:</h3>
            <p style="margin: 0; line-height: 1.6;">${change.description}</p>
          </div>
          
          <div style="margin: 20px 0; padding: 15px; background: #fff3cd; border-radius: 5px; border-left: 4px solid #ffc107;">
            <h3 style="margin-top: 0; color: #856404;">⚠️ Action Required</h3>
            <p style="margin: 0;">Please log in to the system to review and approve/reject this change request.</p>
          </div>
        </div>
        
        <div style="padding: 20px; background: #333; color: white; text-align: center;">
          <p style="margin: 0;">This is an automated message from Calpion IT Support</p>
        </div>
      </div>
    `;

    await this.sendEmail(approverEmail, subject, html);
  }

  private getPriorityColor(priority: string): string {
    switch (priority.toLowerCase()) {
      case 'critical': return '#dc3545';
      case 'high': return '#fd7e14';
      case 'medium': return '#ffc107';
      case 'low': return '#28a745';
      default: return '#6c757d';
    }
  }

  private getStatusColor(status: string): string {
    switch (status.toLowerCase()) {
      case 'open': return '#007bff';
      case 'in progress': return '#ffc107';
      case 'pending': return '#6f42c1';
      case 'resolved': return '#28a745';
      case 'closed': return '#6c757d';
      default: return '#17a2b8';
    }
  }

  private getResponseTime(priority: string): string {
    switch (priority.toLowerCase()) {
      case 'critical': return 'Within 1 hour';
      case 'high': return 'Within 4 hours';
      case 'medium': return 'Within 24 hours';
      case 'low': return 'Within 48 hours';
      default: return 'Within 24 hours';
    }
  }
}

export const emailService = new EmailService();