import { useState } from "react";
import { useMutation, useQueryClient, useQuery } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { useToast } from "@/hooks/use-toast";
import { apiRequest } from "@/lib/queryClient";
import { insertTicketSchema, type Group } from "@shared/schema";
import { ProductSelect } from "@/components/product-select";
import { FileUpload } from "@/components/file-upload";

const formSchema = z.object({
  title: z.string().min(1, "Title is required"),
  description: z.string().min(10, "Description must be at least 10 characters"),
  status: z.string().default("open"),
  priority: z.enum(["low", "medium", "high", "critical"]).default("medium"),
  category: z.enum(["software", "hardware", "network", "access", "other"]).default("software"),
  assignedTo: z.string().optional(),
  assignedGroup: z.string().min(1, "Assigned Group is required"),
  product: z.string().min(1, "Product is required"),
  requesterDepartment: z.string().optional(),
  requesterBusinessUnit: z.string().optional(),
});

interface TicketFormProps {
  onClose: () => void;
  currentUser?: any;
}

export function TicketForm({ onClose, currentUser }: TicketFormProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [createdTicketId, setCreatedTicketId] = useState<number | null>(null);
  const [attachments, setAttachments] = useState<File[]>([]);

  // Fetch active groups for assignment
  const { data: groups = [] } = useQuery({
    queryKey: ["/api/groups/active"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/groups/active");
      return response.json();
    },
  });

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      title: "",
      description: "",
      status: "open",
      priority: "medium",
      category: "software",
      assignedTo: "",
      assignedGroup: "",
      product: "",
    },
  });

  const createTicketMutation = useMutation({
    mutationFn: async (data: z.infer<typeof formSchema>) => {
      const response = await apiRequest("POST", "/api/tickets", data);
      const ticket = await response.json();
      
      // Upload attachments if any
      if (attachments.length > 0) {
        for (const file of attachments) {
          // Convert file to base64
          const base64Content = await new Promise<string>((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
              try {
                const result = reader.result as string;
                const base64 = result.split(',')[1];
                resolve(base64);
              } catch (error) {
                reject(error);
              }
            };
            reader.onerror = () => reject(new Error('Failed to read file'));
            reader.readAsDataURL(file);
          });

          const attachmentData = {
            fileName: `${Date.now()}_${file.name}`,
            originalName: file.name,
            fileSize: file.size,
            mimeType: file.type,
            fileContent: base64Content,
            ticketId: ticket.id,
          };
          await apiRequest("POST", "/api/attachments", attachmentData);
        }
      }
      
      return ticket;
    },
    onSuccess: (ticket) => {
      toast({
        title: "Success",
        description: "Support ticket created successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/tickets"] });
      queryClient.invalidateQueries({ queryKey: ["/api/attachments"] });
      onClose();
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to create ticket. Please try again.",
        variant: "destructive",
      });
    },
  });

  const onSubmit = (data: z.infer<typeof formSchema>) => {
    createTicketMutation.mutate(data);
  };

  return (
    <Dialog open={true} onOpenChange={(open) => { if (!open) onClose(); }} modal={true}>
      <DialogContent className="sm:max-w-[600px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle>Create Support Ticket</DialogTitle>
          <DialogDescription>
            Submit a new IT support request. Provide as much detail as possible to help us resolve your issue quickly.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <div className="mb-4 p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
              <p className="text-sm text-blue-700 dark:text-blue-300">
                Creating ticket for: <span className="font-medium">{currentUser?.name || 'Current User'}</span>
              </p>
            </div>

            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Issue Title</FormLabel>
                  <FormControl>
                    <Input placeholder="Brief description of the problem" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="grid grid-cols-3 gap-4">
              <FormField
                control={form.control}
                name="category"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Category</FormLabel>
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
                        <SelectItem value="product">Product</SelectItem>
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
                    <FormLabel>Priority</FormLabel>
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
                name="assignedTo"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Assign To (Optional)</FormLabel>
                    <FormControl>
                      <Input placeholder="Agent name" {...field} value={field.value || ''} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="assignedGroup"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Assigned Group *</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select support group" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {groups.map((group: Group) => (
                          <SelectItem key={group.id} value={group.name}>
                            {group.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <ProductSelect 
              control={form.control}
              name="product"
              label="Product"
              placeholder="Select affected product"
              required={true}
            />

            <div className="grid grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="requesterDepartment"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Department</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select department" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="IT">IT</SelectItem>
                        <SelectItem value="Finance">Finance</SelectItem>
                        <SelectItem value="HR">Human Resources</SelectItem>
                        <SelectItem value="Operations">Operations</SelectItem>
                        <SelectItem value="Sales">Sales</SelectItem>
                        <SelectItem value="Marketing">Marketing</SelectItem>
                        <SelectItem value="Legal">Legal</SelectItem>
                        <SelectItem value="Executive">Executive</SelectItem>
                        <SelectItem value="Customer Service">Customer Service</SelectItem>
                        <SelectItem value="R&D">Research & Development</SelectItem>
                        <SelectItem value="Other">Other</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="requesterBusinessUnit"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Business Unit</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select business unit" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="BU1">BU1</SelectItem>
                        <SelectItem value="BU2">BU2</SelectItem>
                        <SelectItem value="BU3">BU3</SelectItem>
                        <SelectItem value="BU4">BU4</SelectItem>
                      </SelectContent>
                    </Select>
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
                  <FormLabel>Detailed Description</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Describe the issue in detail. Include error messages, steps to reproduce, and any troubleshooting already attempted."
                      className="min-h-[120px]"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="space-y-2">
              <label className="text-sm font-medium">Attachments (Optional)</label>
              <Input
                type="file"
                multiple
                accept=".pdf,.doc,.docx,.txt,.png,.jpg,.jpeg"
                onChange={(e) => {
                  const files = Array.from(e.target.files || []);
                  setAttachments(files);
                }}
                className="file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-primary file:text-primary-foreground hover:file:bg-primary/90"
              />
              {attachments.length > 0 && (
                <div className="text-sm text-muted-foreground">
                  Selected files: {attachments.map(f => f.name).join(', ')}
                </div>
              )}
            </div>

            <div className="flex justify-end space-x-2 pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button 
                type="submit" 
                disabled={createTicketMutation.isPending}
                className="bg-primary hover:bg-primary/90"
              >
                {createTicketMutation.isPending ? "Creating..." : "Create Ticket"}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}