import { storage } from './storage';

// Dynamic email configuration that can be updated through admin interface
export interface EmailConfig {
  provider: 'smtp' | 'sendgrid';
  sendgridApiKey?: string;
  smtpHost?: string;
  smtpPort?: number;
  smtpSecure?: boolean;
  smtpUser?: string;
  smtpPass?: string;
  fromEmail?: string;
}

let emailConfig: EmailConfig = {
  provider: 'sendgrid',
  fromEmail: 'no-reply@calpion.com'
};

let configLoaded = false;

export async function loadEmailConfig(): Promise<void> {
  if (configLoaded) return;
  
  try {
    // Load configuration from database
    const apiKeySetting = await storage.getSetting('email_sendgrid_api_key');
    const providerSetting = await storage.getSetting('email_provider');
    const fromEmailSetting = await storage.getSetting('email_from_address');
    const smtpHostSetting = await storage.getSetting('email_smtp_host');
    const smtpPortSetting = await storage.getSetting('email_smtp_port');
    const smtpUserSetting = await storage.getSetting('email_smtp_user');
    const smtpPassSetting = await storage.getSetting('email_smtp_pass');
    
    emailConfig = {
      provider: (providerSetting?.value as 'smtp' | 'sendgrid') || 'sendgrid',
      sendgridApiKey: apiKeySetting?.value || process.env.SENDGRID_API_KEY,
      fromEmail: fromEmailSetting?.value || 'no-reply@calpion.com',
      smtpHost: smtpHostSetting?.value,
      smtpPort: smtpPortSetting?.value ? parseInt(smtpPortSetting.value) : undefined,
      smtpUser: smtpUserSetting?.value,
      smtpPass: smtpPassSetting?.value,
      smtpSecure: true
    };
    
    configLoaded = true;
  } catch (error) {
    console.error('[Email Config] Failed to load from database:', error);
    // Fallback to environment variables
    emailConfig = {
      provider: 'sendgrid',
      sendgridApiKey: process.env.SENDGRID_API_KEY,
      fromEmail: 'no-reply@calpion.com'
    };
    configLoaded = true;
  }
}

export async function getEmailConfig(): Promise<EmailConfig> {
  await loadEmailConfig();
  return emailConfig;
}

export async function updateEmailConfig(config: Partial<EmailConfig>): Promise<void> {
  emailConfig = { ...emailConfig, ...config };
  
  try {
    // Save to database for persistence
    if (config.sendgridApiKey !== undefined) {
      await storage.setSetting('email_sendgrid_api_key', config.sendgridApiKey, 'SendGrid API Key for email notifications');
    }
    if (config.provider !== undefined) {
      await storage.setSetting('email_provider', config.provider, 'Email service provider (sendgrid or smtp)');
    }
    if (config.fromEmail !== undefined) {
      await storage.setSetting('email_from_address', config.fromEmail, 'From email address for notifications');
    }
    if (config.smtpHost !== undefined) {
      await storage.setSetting('email_smtp_host', config.smtpHost, 'SMTP server hostname');
    }
    if (config.smtpPort !== undefined) {
      await storage.setSetting('email_smtp_port', config.smtpPort.toString(), 'SMTP server port');
    }
    if (config.smtpUser !== undefined) {
      await storage.setSetting('email_smtp_user', config.smtpUser, 'SMTP username');
    }
    if (config.smtpPass !== undefined) {
      await storage.setSetting('email_smtp_pass', config.smtpPass, 'SMTP password');
    }
  } catch (error) {
    console.error('[Email Config] Failed to save to database:', error);
  }
}

export async function isEmailConfigured(): Promise<boolean> {
  const config = await getEmailConfig();
  if (config.provider === 'sendgrid') {
    return !!(config.sendgridApiKey && config.fromEmail);
  } else {
    return !!(config.smtpHost && config.smtpUser && config.smtpPass && config.fromEmail);
  }
}