import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Textarea } from "@/components/ui/textarea";
import { useToast } from "@/hooks/use-toast";
import { Mail, Send, Settings, TestTube2 } from "lucide-react";
import { Separator } from "@/components/ui/separator";

interface EmailSettings {
  enabled: boolean;
  provider: 'smtp' | 'sendgrid';
  // SMTP Settings
  smtpHost: string;
  smtpPort: number;
  smtpSecure: boolean;
  smtpUser: string;
  smtpPass: string;
  // SendGrid Settings
  sendgridApiKey: string;
  fromEmail: string;
}

interface EmailSettingsProps {
  currentUser: any;
}

export function EmailSettings({ currentUser }: EmailSettingsProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  
  const [testEmail, setTestEmail] = useState(currentUser?.email || "");
  const [settings, setSettings] = useState<EmailSettings>({
    enabled: false,
    provider: 'sendgrid',
    smtpHost: "",
    smtpPort: 587,
    smtpSecure: false,
    smtpUser: "",
    smtpPass: "",
    sendgridApiKey: "",
    fromEmail: "",
  });

  // Load current email settings
  const { data: currentSettings, isLoading } = useQuery({
    queryKey: ['/api/email/settings'],
    enabled: !!currentUser && currentUser.role === 'admin',
  });

  // Update local state when settings are loaded
  React.useEffect(() => {
    if (currentSettings) {
      setSettings(prev => ({
        ...prev,
        ...currentSettings,
        // Don't overwrite if already has values (user might be editing)
        sendgridApiKey: prev.sendgridApiKey || (currentSettings.sendgridApiKey === '***configured***' ? '' : currentSettings.sendgridApiKey || ''),
        smtpPass: prev.smtpPass || (currentSettings.smtpPass === '***configured***' ? '' : currentSettings.smtpPass || ''),
      }));
    }
  }, [currentSettings]);

  // Test email mutation
  const testEmailMutation = useMutation({
    mutationFn: async (email: string) => {
      const response = await fetch('/api/email/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ email })
      });
      if (!response.ok) throw new Error('Failed to send test email');
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Test Email Sent",
        description: "Check your inbox for the test email",
      });
    },
    onError: () => {
      toast({
        title: "Test Failed",
        description: "Failed to send test email. Check your configuration.",
        variant: "destructive",
      });
    },
  });

  // Save settings mutation
  const saveSettingsMutation = useMutation({
    mutationFn: async (settings: EmailSettings) => {
      const response = await fetch('/api/email/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(settings)
      });
      if (!response.ok) throw new Error('Failed to save settings');
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Settings Saved",
        description: "Email configuration has been updated successfully",
      });
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to save email settings",
        variant: "destructive",
      });
    },
  });

  const handleTestEmail = () => {
    if (!testEmail) {
      toast({
        title: "Email Required",
        description: "Please enter an email address to test",
        variant: "destructive",
      });
      return;
    }
    testEmailMutation.mutate(testEmail);
  };

  const handleSettingsChange = (field: keyof EmailSettings, value: any) => {
    setSettings(prev => ({ ...prev, [field]: value }));
  };

  const handleSaveSettings = () => {
    saveSettingsMutation.mutate(settings);
  };

  if (currentUser?.role !== 'admin') {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Mail className="h-5 w-5" />
            Email Settings
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">Only administrators can configure email settings.</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="h-5 w-5" />
            Email Configuration
          </CardTitle>
          <CardDescription>
            Configure email provider for notifications. Choose between SendGrid or SMTP.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Email Provider Selection */}
          <div className="space-y-4">
            <Label className="text-base font-medium">Email Provider</Label>
            <div className="flex gap-4">
              <label className="flex items-center space-x-2 cursor-pointer">
                <input
                  type="radio"
                  name="provider"
                  value="sendgrid"
                  checked={settings.provider === 'sendgrid'}
                  onChange={(e) => handleSettingsChange('provider', e.target.value as 'sendgrid')}
                  className="text-primary"
                />
                <span>SendGrid (Recommended)</span>
              </label>
              <label className="flex items-center space-x-2 cursor-pointer">
                <input
                  type="radio"
                  name="provider"
                  value="smtp"
                  checked={settings.provider === 'smtp'}
                  onChange={(e) => handleSettingsChange('provider', e.target.value as 'smtp')}
                  className="text-primary"
                />
                <span>SMTP</span>
              </label>
            </div>
          </div>

          <Separator />

          {/* SendGrid Configuration */}
          {settings.provider === 'sendgrid' && (
            <div className="space-y-4">
              <h3 className="text-lg font-medium">SendGrid Configuration</h3>
              <div className="grid grid-cols-1 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="sendgridApiKey">SendGrid API Key</Label>
                  <Input
                    id="sendgridApiKey"
                    type="password"
                    placeholder="SG.xxxxxxxxxxxxxxxx"
                    value={settings.sendgridApiKey}
                    onChange={(e) => handleSettingsChange('sendgridApiKey', e.target.value)}
                  />
                  <p className="text-sm text-muted-foreground">
                    Get your API key from SendGrid Dashboard → Settings → API Keys
                  </p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="fromEmail">From Email Address</Label>
                  <Input
                    id="fromEmail"
                    type="email"
                    placeholder="noreply@calpion.com"
                    value={settings.fromEmail}
                    onChange={(e) => handleSettingsChange('fromEmail', e.target.value)}
                  />
                  <p className="text-sm text-muted-foreground">
                    Must be a verified sender in your SendGrid account
                  </p>
                </div>
              </div>
            </div>
          )}

          {/* SMTP Configuration */}
          {settings.provider === 'smtp' && (
            <div className="space-y-4">
              <h3 className="text-lg font-medium">SMTP Configuration</h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="smtpHost">SMTP Host</Label>
                  <Input
                    id="smtpHost"
                    placeholder="smtp.example.com"
                    value={settings.smtpHost}
                    onChange={(e) => handleSettingsChange('smtpHost', e.target.value)}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="smtpPort">SMTP Port</Label>
                  <Input
                    id="smtpPort"
                    type="number"
                    placeholder="587"
                    value={settings.smtpPort}
                    onChange={(e) => handleSettingsChange('smtpPort', parseInt(e.target.value) || 587)}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="smtpUser">SMTP Username</Label>
                  <Input
                    id="smtpUser"
                    placeholder="your-email@example.com"
                    value={settings.smtpUser}
                    onChange={(e) => handleSettingsChange('smtpUser', e.target.value)}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="smtpPass">SMTP Password</Label>
                  <Input
                    id="smtpPass"
                    type="password"
                    placeholder="Your SMTP password"
                    value={settings.smtpPass}
                    onChange={(e) => handleSettingsChange('smtpPass', e.target.value)}
                  />
                </div>
                
                <div className="flex items-center space-x-2">
                  <Switch
                    id="smtpSecure"
                    checked={settings.smtpSecure}
                    onCheckedChange={(checked) => handleSettingsChange('smtpSecure', checked)}
                  />
                  <Label htmlFor="smtpSecure">Use SSL/TLS (recommended for port 465)</Label>
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="fromEmailSmtp">From Email (optional)</Label>
                  <Input
                    id="fromEmailSmtp"
                    placeholder="noreply@yourcompany.com"
                    value={settings.fromEmail}
                    onChange={(e) => handleSettingsChange('fromEmail', e.target.value)}
                  />
                </div>
              </div>
            </div>
          )}

          <div className="flex justify-between items-center pt-4">
            <Button 
              onClick={handleSaveSettings}
              disabled={saveSettingsMutation.isPending}
            >
              {saveSettingsMutation.isPending ? "Saving..." : "Save Settings"}
            </Button>
          </div>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <TestTube2 className="h-5 w-5" />
            Test Email
          </CardTitle>
          <CardDescription>
            Send a test email to verify your configuration is working
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="testEmail">Test Email Address</Label>
            <Input
              id="testEmail"
              type="email"
              placeholder="test@example.com"
              value={testEmail}
              onChange={(e) => setTestEmail(e.target.value)}
            />
          </div>
          
          <Button 
            onClick={handleTestEmail}
            disabled={testEmailMutation.isPending}
            className="w-full"
          >
            <Send className="h-4 w-4 mr-2" />
            {testEmailMutation.isPending ? "Sending..." : "Send Test Email"}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}