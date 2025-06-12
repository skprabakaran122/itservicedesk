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
    enabled: false,
    smtpHost: "",
    smtpPort: 587,
    smtpSecure: false,
    smtpUser: "",
    smtpPass: "",
    fromEmail: "",
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
      if (!response.ok) throw new Error('Failed to send test email');
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Test Email Sent",
        description: "Check your inbox for the test email. It may take a few minutes to arrive.",
      });
    },
    onError: (error: any) => {
      toast({
        title: "Test Email Failed",
        description: error.message || "Failed to send test email",
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
            Configure SMTP settings for email notifications. Leave blank to use Ethereal Email for testing.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
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
            <Label htmlFor="fromEmail">From Email (optional)</Label>
            <Input
              id="fromEmail"
              placeholder="noreply@yourcompany.com"
              value={settings.fromEmail}
              onChange={(e) => handleSettingsChange('fromEmail', e.target.value)}
            />
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
            className="w-full md:w-auto"
          >
            <Send className="h-4 w-4 mr-2" />
            {testEmailMutation.isPending ? "Sending..." : "Send Test Email"}
          </Button>
          
          {testEmailMutation.isPending && (
            <p className="text-sm text-muted-foreground">
              Sending test email... This may take a few moments.
            </p>
          )}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>Email Configuration Guide</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <h4 className="font-medium">Popular SMTP Providers:</h4>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div className="space-y-1">
                <p><strong>Gmail:</strong></p>
                <p>Host: smtp.gmail.com</p>
                <p>Port: 587 (or 465 with SSL)</p>
                <p>Note: Use App Password, not regular password</p>
              </div>
              
              <div className="space-y-1">
                <p><strong>Outlook/Office 365:</strong></p>
                <p>Host: smtp-mail.outlook.com</p>
                <p>Port: 587</p>
                <p>Security: STARTTLS</p>
              </div>
              
              <div className="space-y-1">
                <p><strong>Yahoo:</strong></p>
                <p>Host: smtp.mail.yahoo.com</p>
                <p>Port: 587 (or 465 with SSL)</p>
                <p>Note: Use App Password</p>
              </div>
              
              <div className="space-y-1">
                <p><strong>Custom SMTP:</strong></p>
                <p>Contact your hosting provider</p>
                <p>Common ports: 587, 465, 25</p>
                <p>Check SSL/TLS requirements</p>
              </div>
            </div>
          </div>
          
          <Separator />
          
          <div className="space-y-2">
            <h4 className="font-medium">Development Mode:</h4>
            <p className="text-sm text-muted-foreground">
              If no SMTP settings are configured, the system will automatically use Ethereal Email 
              for testing. Check the server logs for preview URLs to view sent emails.
            </p>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}