import { useState, useEffect } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import { Mail, Send, Settings, TestTube2 } from "lucide-react";
import { Separator } from "@/components/ui/separator";

interface EmailSettings {
  provider: 'smtp' | 'sendgrid';
  sendgridApiKey: string;
  smtpHost: string;
  smtpPort: number;
  smtpSecure: boolean;
  smtpUser: string;
  smtpPass: string;
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
    provider: 'sendgrid',
    sendgridApiKey: "",
    smtpHost: "",
    smtpPort: 587,
    smtpSecure: false,
    smtpUser: "",
    smtpPass: "",
    fromEmail: "",
  });

  // Load current email settings
  const { data: currentSettings, isLoading } = useQuery({
    queryKey: ['/api/email/settings'],
    enabled: !!currentUser && currentUser.role === 'admin',
  });

  // Update local state when settings are loaded
  useEffect(() => {
    if (currentSettings) {
      setSettings(prev => ({
        ...prev,
        ...currentSettings,
        // Don't overwrite sensitive fields if they show as configured
        sendgridApiKey: (currentSettings as any).sendgridApiKey === '***configured***' ? prev.sendgridApiKey : (currentSettings as any).sendgridApiKey || '',
        smtpPass: (currentSettings as any).smtpPass === '***configured***' ? prev.smtpPass : (currentSettings as any).smtpPass || '',
      }));
    }
  }, [currentSettings]);

  // Save settings mutation
  const saveSettingsMutation = useMutation({
    mutationFn: async (settings: EmailSettings) => {
      const response = await fetch('/api/email/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(settings)
      });
      if (!response.ok) {
        const error = await response.text();
        throw new Error(error || 'Failed to save settings');
      }
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Settings Saved",
        description: "Email configuration has been updated successfully",
      });
      queryClient.invalidateQueries({ queryKey: ['/api/email/settings'] });
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to save email settings",
        variant: "destructive",
      });
    },
  });

  // Test email mutation
  const testEmailMutation = useMutation({
    mutationFn: async (email: string) => {
      const response = await fetch('/api/email/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ email })
      });
      if (!response.ok) {
        const error = await response.text();
        throw new Error(error || 'Failed to send test email');
      }
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Test Email Sent",
        description: "Check your inbox for the test email",
      });
    },
    onError: (error: any) => {
      toast({
        title: "Test Failed",
        description: error.message || "Failed to send test email. Check your configuration.",
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
    if (settings.provider === 'sendgrid' && !settings.sendgridApiKey) {
      toast({
        title: "SendGrid API Key Required",
        description: "Please enter your SendGrid API key",
        variant: "destructive",
      });
      return;
    }
    
    if (settings.provider === 'smtp' && (!settings.smtpHost || !settings.smtpUser || !settings.smtpPass)) {
      toast({
        title: "SMTP Configuration Required",
        description: "Please fill in all SMTP settings",
        variant: "destructive",
      });
      return;
    }

    if (!settings.fromEmail) {
      toast({
        title: "From Email Required",
        description: "Please enter a from email address",
        variant: "destructive",
      });
      return;
    }

    saveSettingsMutation.mutate(settings);
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="flex items-center space-x-2">
          <Settings className="h-5 w-5" />
          <h2 className="text-lg font-semibold">Email Settings</h2>
        </div>
        <div>Loading email settings...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center space-x-2">
        <Settings className="h-5 w-5" />
        <h2 className="text-lg font-semibold">Email Settings</h2>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <Mail className="h-5 w-5" />
            <span>Email Provider Configuration</span>
          </CardTitle>
          <CardDescription>
            Configure your email service for sending notifications and alerts
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* Provider Selection */}
          <div className="space-y-2">
            <Label htmlFor="provider">Email Provider</Label>
            <Select 
              value={settings.provider} 
              onValueChange={(value: 'smtp' | 'sendgrid') => handleSettingsChange('provider', value)}
            >
              <SelectTrigger>
                <SelectValue placeholder="Select email provider" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="sendgrid">SendGrid (Recommended)</SelectItem>
                <SelectItem value="smtp">SMTP</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* From Email */}
          <div className="space-y-2">
            <Label htmlFor="fromEmail">From Email Address</Label>
            <Input
              id="fromEmail"
              type="email"
              placeholder="noreply@yourcompany.com"
              value={settings.fromEmail}
              onChange={(e) => handleSettingsChange('fromEmail', e.target.value)}
            />
          </div>

          <Separator />

          {/* SendGrid Settings */}
          {settings.provider === 'sendgrid' && (
            <div className="space-y-4">
              <h3 className="text-sm font-medium">SendGrid Configuration</h3>
              <div className="space-y-2">
                <Label htmlFor="sendgridApiKey">SendGrid API Key</Label>
                <Input
                  id="sendgridApiKey"
                  type="password"
                  placeholder={(currentSettings as any)?.sendgridApiKey === '***configured***' ? 'API key is configured' : 'Enter your SendGrid API key'}
                  value={settings.sendgridApiKey}
                  onChange={(e) => handleSettingsChange('sendgridApiKey', e.target.value)}
                />
                <p className="text-xs text-muted-foreground">
                  Get your API key from the SendGrid dashboard under Settings → API Keys
                </p>
              </div>
            </div>
          )}

          {/* SMTP Settings */}
          {settings.provider === 'smtp' && (
            <div className="space-y-4">
              <h3 className="text-sm font-medium">SMTP Configuration</h3>
              
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="smtpHost">SMTP Host</Label>
                  <Input
                    id="smtpHost"
                    placeholder="smtp.gmail.com"
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
                    onChange={(e) => handleSettingsChange('smtpPort', parseInt(e.target.value))}
                  />
                </div>
              </div>

              <div className="flex items-center space-x-2">
                <Switch
                  id="smtpSecure"
                  checked={settings.smtpSecure}
                  onCheckedChange={(checked) => handleSettingsChange('smtpSecure', checked)}
                />
                <Label htmlFor="smtpSecure">Use SSL/TLS</Label>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label htmlFor="smtpUser">SMTP Username</Label>
                  <Input
                    id="smtpUser"
                    type="email"
                    placeholder="your-email@gmail.com"
                    value={settings.smtpUser}
                    onChange={(e) => handleSettingsChange('smtpUser', e.target.value)}
                  />
                </div>
                
                <div className="space-y-2">
                  <Label htmlFor="smtpPass">SMTP Password</Label>
                  <Input
                    id="smtpPass"
                    type="password"
                    placeholder={(currentSettings as any)?.smtpPass === '***configured***' ? 'Password is configured' : 'Enter password or app password'}
                    value={settings.smtpPass}
                    onChange={(e) => handleSettingsChange('smtpPass', e.target.value)}
                  />
                </div>
              </div>
            </div>
          )}

          <Separator />

          {/* Save Settings */}
          <div className="flex space-x-2">
            <Button 
              onClick={handleSaveSettings}
              disabled={saveSettingsMutation.isPending}
            >
              {saveSettingsMutation.isPending ? "Saving..." : "Save Settings"}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* Test Email */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center space-x-2">
            <TestTube2 className="h-5 w-5" />
            <span>Test Email Configuration</span>
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
            variant="outline"
            className="w-full"
          >
            <Send className="w-4 h-4 mr-2" />
            {testEmailMutation.isPending ? "Sending..." : "Send Test Email"}
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}