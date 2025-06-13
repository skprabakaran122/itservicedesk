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
  sendgridApiKey: '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',
  fromEmail: 'no-reply@calpion.com'
};

export function getEmailConfig(): EmailConfig {
  return emailConfig;
}

export function updateEmailConfig(config: Partial<EmailConfig>): void {
  emailConfig = { ...emailConfig, ...config };
}

export function isEmailConfigured(): boolean {
  if (emailConfig.provider === 'sendgrid') {
    return !!(emailConfig.sendgridApiKey && emailConfig.fromEmail);
  } else {
    return !!(emailConfig.smtpHost && emailConfig.smtpUser && emailConfig.smtpPass && emailConfig.fromEmail);
  }
}