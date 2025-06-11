import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { CheckCircle, Phone, Mail, User, MessageSquare } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { apiRequest } from "@/lib/queryClient";

const anonymousTicketSchema = z.object({
  requesterName: z.string().min(1, "Name is required"),
  requesterEmail: z.string().email("Valid email is required"),
  requesterPhone: z.string().optional(),
  title: z.string().min(1, "Issue title is required"),
  description: z.string().min(10, "Description must be at least 10 characters"),
  priority: z.enum(["low", "medium", "high", "critical"]).default("medium"),
  category: z.enum(["software", "hardware", "network", "access", "other"]).default("software"),
  product: z.string().optional(),
});

type AnonymousTicketForm = z.infer<typeof anonymousTicketSchema>;

interface AnonymousTicketFormProps {
  onSuccess?: () => void;
}

export function AnonymousTicketForm({ onSuccess }: AnonymousTicketFormProps) {
  const { toast } = useToast();
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [ticketId, setTicketId] = useState<number | null>(null);

  const form = useForm<AnonymousTicketForm>({
    resolver: zodResolver(anonymousTicketSchema),
    defaultValues: {
      requesterName: "",
      requesterEmail: "",
      requesterPhone: "",
      title: "",
      description: "",
      priority: "medium",
      category: "software",
      product: "",
    },
  });

  const createTicketMutation = useMutation({
    mutationFn: async (data: AnonymousTicketForm) => {
      const ticketData = {
        ...data,
        status: "open",
        requesterId: null, // Anonymous ticket
      };
      const response = await apiRequest("POST", "/api/tickets/anonymous", ticketData);
      return response.json();
    },
    onSuccess: (ticket) => {
      setTicketId(ticket.id);
      setIsSubmitted(true);
      toast({
        title: "Success",
        description: `Support ticket #${ticket.id} created successfully`,
      });
      onSuccess?.();
    },
    onError: (error) => {
      toast({
        title: "Error",
        description: "Failed to create ticket. Please try again.",
        variant: "destructive",
      });
    },
  });

  const onSubmit = (data: AnonymousTicketForm) => {
    createTicketMutation.mutate(data);
  };

  if (isSubmitted && ticketId) {
    return (
      <Card className="w-full max-w-2xl mx-auto">
        <CardHeader className="text-center">
          <div className="flex justify-center mb-4">
            <CheckCircle className="h-16 w-16 text-green-500" />
          </div>
          <CardTitle className="text-2xl text-green-700">Ticket Created Successfully!</CardTitle>
          <CardDescription>
            Your support request has been submitted and our team will respond soon.
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <Alert>
            <AlertDescription className="text-center">
              <strong>Ticket ID: #{ticketId}</strong>
              <br />
              Please save this number for future reference.
            </AlertDescription>
          </Alert>
          
          <div className="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg">
            <h3 className="font-semibold mb-2">What happens next?</h3>
            <ul className="space-y-1 text-sm">
              <li>• Our support team will review your request</li>
              <li>• You'll receive an email confirmation shortly</li>
              <li>• We'll contact you via email or phone for updates</li>
              <li>• Expected response time: 4-24 hours based on priority</li>
            </ul>
          </div>

          <Button 
            onClick={() => {
              setIsSubmitted(false);
              setTicketId(null);
              form.reset();
            }}
            variant="outline"
            className="w-full"
          >
            Submit Another Ticket
          </Button>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="w-full max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <MessageSquare className="h-6 w-6" />
          Submit Support Request
        </CardTitle>
        <CardDescription>
          Create a support ticket without creating an account. We'll contact you via email with updates.
        </CardDescription>
      </CardHeader>
      
      <CardContent>
        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
            {/* Contact Information */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold flex items-center gap-2">
                <User className="h-5 w-5" />
                Contact Information
              </h3>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="requesterName"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Full Name *</FormLabel>
                      <FormControl>
                        <Input placeholder="Your full name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="requesterEmail"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Email Address *</FormLabel>
                      <FormControl>
                        <Input type="email" placeholder="your.email@company.com" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <FormField
                control={form.control}
                name="requesterPhone"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Phone Number (Optional)</FormLabel>
                    <FormControl>
                      <Input placeholder="+1 (555) 123-4567" {...field} value={field.value || ''} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            {/* Issue Details */}
            <div className="space-y-4">
              <h3 className="text-lg font-semibold">Issue Details</h3>
              
              <FormField
                control={form.control}
                name="title"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Issue Title *</FormLabel>
                    <FormControl>
                      <Input placeholder="Brief description of the problem" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <FormField
                  control={form.control}
                  name="category"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Category *</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select category" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="hardware">Hardware</SelectItem>
                          <SelectItem value="software">Software</SelectItem>
                          <SelectItem value="network">Network</SelectItem>
                          <SelectItem value="access">Access/Security</SelectItem>
                          <SelectItem value="other">Other</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="priority"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Priority *</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select priority" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="low">Low</SelectItem>
                          <SelectItem value="medium">Medium</SelectItem>
                          <SelectItem value="high">High</SelectItem>
                          <SelectItem value="critical">Critical</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="product"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Product/System</FormLabel>
                      <FormControl>
                        <Input placeholder="e.g., Office 365, CRM" {...field} value={field.value || ''} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <FormField
                control={form.control}
                name="description"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Detailed Description *</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Please describe the issue in detail. Include error messages, steps to reproduce, and any troubleshooting you've already tried."
                        className="min-h-[120px]"
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <div className="bg-yellow-50 dark:bg-yellow-900/20 p-4 rounded-lg">
              <p className="text-sm text-yellow-800 dark:text-yellow-200">
                <strong>Note:</strong> By submitting this form, you agree that our support team may contact you 
                via email or phone to resolve your issue. Your information will only be used for support purposes.
              </p>
            </div>

            <Button 
              type="submit" 
              disabled={createTicketMutation.isPending}
              className="w-full"
              size="lg"
            >
              {createTicketMutation.isPending ? "Submitting..." : "Submit Support Request"}
            </Button>
          </form>
        </Form>
      </CardContent>
    </Card>
  );
}