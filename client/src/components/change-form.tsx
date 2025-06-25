import { useState, useEffect } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Shield } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { apiRequest } from "@/lib/queryClient";
import { insertChangeSchema } from "@shared/schema";
import { ProductSelect } from "@/components/product-select";
import { FileUpload } from "@/components/file-upload";
import { toZonedTime, fromZonedTime } from "date-fns-tz";

const IST_TIMEZONE = 'Asia/Kolkata';

// Helper functions for IST timezone conversion
const convertUTCToISTForInput = (utcDateString: string | Date | null | undefined): string => {
  if (!utcDateString) return '';
  const utcDate = new Date(utcDateString);
  
  // Convert UTC to IST by adding 5 hours 30 minutes
  const istDate = new Date(utcDate.getTime() + (5.5 * 60 * 60 * 1000));
  
  // Format as YYYY-MM-DDTHH:MM for datetime-local input
  const year = istDate.getUTCFullYear();
  const month = String(istDate.getUTCMonth() + 1).padStart(2, '0');
  const day = String(istDate.getUTCDate()).padStart(2, '0');
  const hours = String(istDate.getUTCHours()).padStart(2, '0');
  const minutes = String(istDate.getUTCMinutes()).padStart(2, '0');
  
  return `${year}-${month}-${day}T${hours}:${minutes}`;
};

const convertISTInputToUTC = (istInputValue: string): string => {
  // Parse the datetime-local input as IST time
  const [datePart, timePart] = istInputValue.split('T');
  const [year, month, day] = datePart.split('-').map(Number);
  const [hours, minutes] = timePart.split(':').map(Number);
  
  // Create a Date object representing the IST time
  const istDate = new Date(Date.UTC(year, month - 1, day, hours, minutes));
  
  // Subtract IST offset (5 hours 30 minutes) to get UTC
  const utcDate = new Date(istDate.getTime() - (5.5 * 60 * 60 * 1000));
  
  return utcDate.toISOString();
};

// Get current IST time formatted for datetime-local input
const getCurrentISTDateTime = (): string => {
  const now = new Date();
  const istNow = new Date(now.getTime() + (5.5 * 60 * 60 * 1000));
  
  const year = istNow.getUTCFullYear();
  const month = String(istNow.getUTCMonth() + 1).padStart(2, '0');
  const day = String(istNow.getUTCDate()).padStart(2, '0');
  const hours = String(istNow.getUTCHours()).padStart(2, '0');
  const minutes = String(istNow.getUTCMinutes()).padStart(2, '0');

  return `${year}-${month}-${day}T${hours}:${minutes}`;
};

// Get IST time + 24 hours for Normal changes
const getMinDateTimeForNormal = (): string => {
  const now = new Date();
  const istNowPlus24h = new Date(now.getTime() + (5.5 * 60 * 60 * 1000) + (24 * 60 * 60 * 1000));
  
  const year = istNowPlus24h.getUTCFullYear();
  const month = String(istNowPlus24h.getUTCMonth() + 1).padStart(2, '0');
  const day = String(istNowPlus24h.getUTCDate()).padStart(2, '0');
  const hours = String(istNowPlus24h.getUTCHours()).padStart(2, '0');
  const minutes = String(istNowPlus24h.getUTCMinutes()).padStart(2, '0');

  return `${year}-${month}-${day}T${hours}:${minutes}`;
};

const formSchema = insertChangeSchema.extend({
  title: z.string().min(1, "Title is required"),
  description: z.string().min(10, "Description must be at least 10 characters"),
  rollbackPlan: z.string().min(10, "Rollback plan is required"),
  startDate: z.string().nullable().optional(),
  endDate: z.string().nullable().optional(),
  plannedDate: z.string().nullable().optional(),
});

interface ChangeFormProps {
  onClose: () => void;
  currentUser?: any;
}

export function ChangeForm({ onClose, currentUser }: ChangeFormProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [attachments, setAttachments] = useState<File[]>([]);
  const [minDateTime, setMinDateTime] = useState<string>('');
  const [startDateTime, setStartDateTime] = useState<string>('');
  const [changeType, setChangeType] = useState<string>('normal');

  const { data: groups = [] } = useQuery({
    queryKey: ["/api/groups"],
    queryFn: async () => {
      const response = await fetch('/api/groups');
      if (!response.ok) {
        throw new Error('Failed to fetch groups');
      }
      return response.json();
    }
  });

  // Set minimum datetime based on change type
  useEffect(() => {
    const currentISTTime = getCurrentISTDateTime();
    const normalMinTime = getMinDateTimeForNormal();
    setMinDateTime(changeType === 'normal' ? normalMinTime : currentISTTime);
  }, [changeType]);

  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      title: "",
      description: "",
      status: "pending",
      priority: "medium",
      category: "system",
      requestedBy: currentUser?.username || currentUser?.email || "Anonymous",
      approvedBy: "",
      implementedBy: "",
      riskLevel: "medium",
      changeType: "normal",
      rollbackPlan: "",
    },
  });

  const createChangeMutation = useMutation({
    mutationFn: async (data: z.infer<typeof formSchema>) => {
      const response = await apiRequest("POST", "/api/changes", data);
      const change = await response.json();
      
      // Upload attachments if any
      if (attachments.length > 0) {
        for (const file of attachments) {
          const attachmentData = {
            fileName: file.name,
            fileSize: file.size,
            fileType: file.type,
            changeId: change.id,
            uploadedBy: 1, // Default user ID
          };
          await apiRequest("POST", "/api/attachments", attachmentData);
        }
      }
      
      return change;
    },
    onSuccess: (change) => {
      toast({
        title: "Success",
        description: "Change request created successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/changes"] });
      queryClient.invalidateQueries({ queryKey: ["/api/attachments"] });
      onClose();
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error?.message || "Failed to create change request. Please try again.",
        variant: "destructive",
      });
    },
  });

  const onSubmit = (data: z.infer<typeof formSchema>) => {
    // Additional frontend validation
    if (data.startDate && data.endDate) {
      const startDate = new Date(data.startDate);
      const endDate = new Date(data.endDate);
      
      if (endDate <= startDate) {
        toast({
          title: "Invalid Dates",
          description: "End date must be after the start date.",
          variant: "destructive",
        });
        return;
      }
    }

    // Validate 24-hour advance notice for Normal changes
    if (data.changeType === 'normal' && data.startDate) {
      const startDate = new Date(data.startDate);
      const now = new Date();
      const timeDifference = startDate.getTime() - now.getTime();
      const hoursDifference = timeDifference / (1000 * 60 * 60);

      if (hoursDifference < 24) {
        toast({
          title: "Invalid Start Time",
          description: "Normal changes require at least 24 hours advance notice. Please select a start time at least 24 hours from now.",
          variant: "destructive",
        });
        return;
      }
    }

    // Convert string dates back to proper format for backend
    const processedData = {
      ...data,
      startDate: data.startDate || null,
      endDate: data.endDate || null,
      plannedDate: data.plannedDate || null,
    };
    console.log('Frontend sending change data:', processedData);
    createChangeMutation.mutate(processedData);
  };

  return (
    <Dialog open={true} onOpenChange={(open) => { if (!open) onClose(); }} modal={true}>
      <DialogContent className="sm:max-w-[700px] max-h-[90vh] overflow-y-auto" onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle>Create Change Request</DialogTitle>
          <DialogDescription>
            Submit a new change request for system modifications, updates, or configurations.
            All changes require approval before implementation.
          </DialogDescription>
        </DialogHeader>

        <Form {...form}>
          <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
            <FormField
              control={form.control}
              name="title"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Change Title</FormLabel>
                  <FormControl>
                    <Input placeholder="Brief description of the change" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="grid grid-cols-2 gap-4">
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
                        <SelectItem value="system">System</SelectItem>
                        <SelectItem value="application">Application</SelectItem>
                        <SelectItem value="infrastructure">Infrastructure</SelectItem>
                        <SelectItem value="policy">Policy</SelectItem>
                        <SelectItem value="product">Product</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="changeType"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Change Type</FormLabel>
                    <Select onValueChange={(value) => {
                      field.onChange(value);
                      setChangeType(value);
                    }} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select change type" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="standard">Standard (No Approval Required)</SelectItem>
                        <SelectItem value="normal">Normal (Requires Approval - 24h advance notice)</SelectItem>
                        <SelectItem value="emergency">Emergency (Expedited Approval)</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
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
                name="riskLevel"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Risk Level</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select risk" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="low">Low Risk</SelectItem>
                        <SelectItem value="medium">Medium Risk</SelectItem>
                        <SelectItem value="high">High Risk</SelectItem>
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

            <FormField
              control={form.control}
              name="description"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Detailed Description</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Describe the change in detail. Include what will be modified, why the change is needed, and the expected impact."
                      className="min-h-[100px]"
                      {...field}
                    />
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
                  <FormLabel>Assigned Group</FormLabel>
                  <Select onValueChange={field.onChange} value={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select a group" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="">No Group</SelectItem>
                      {groups?.filter(g => g.isActive === 'true').map((group) => (
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

            <FormField
              control={form.control}
              name="rollbackPlan"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Rollback Plan</FormLabel>
                  <FormControl>
                    <Textarea
                      placeholder="Describe how to revert this change if issues arise. Include specific steps and estimated rollback time."
                      className="min-h-[100px]"
                      {...field}
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />

            <div className="grid grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="startDate"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>
                      Implementation Start Date (IST)
                      {changeType === 'normal' && (
                        <span className="text-sm text-amber-600 font-normal ml-2">
                          (Minimum 24h advance notice)
                        </span>
                      )}
                    </FormLabel>
                    <FormControl>
                      <Input
                        type="datetime-local"
                        min={minDateTime}
                        {...field}
                        value={convertUTCToISTForInput(field.value || null)}
                        onChange={(e) => {
                          if (e.target.value) {
                            const utcValue = convertISTInputToUTC(e.target.value);
                            field.onChange(utcValue);
                            setStartDateTime(e.target.value);
                          } else {
                            field.onChange(null);
                            setStartDateTime('');
                          }
                        }}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={form.control}
                name="endDate"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Implementation End Date (IST)</FormLabel>
                    <FormControl>
                      <Input
                        type="datetime-local"
                        min={startDateTime || minDateTime}
                        {...field}
                        value={convertUTCToISTForInput(field.value || null)}
                        onChange={(e) => {
                          if (e.target.value) {
                            field.onChange(convertISTInputToUTC(e.target.value));
                          } else {
                            field.onChange(null);
                          }
                        }}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

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

            <div className="space-y-4">
              <div className="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg border border-blue-200 dark:border-blue-800">
                <div className="flex items-center gap-2 mb-2">
                  <Shield className="h-4 w-4 text-blue-600" />
                  <span className="text-sm font-medium text-blue-800 dark:text-blue-200">Automatic Approval Routing</span>
                </div>
                <p className="text-sm text-blue-700 dark:text-blue-300">
                  The approver will be automatically assigned based on the selected product and risk level configuration.
                </p>
              </div>
              
              <FormField
                control={form.control}
                name="implementedBy"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Implemented By (Optional)</FormLabel>
                    <FormControl>
                      <Input placeholder="Technician name" {...field} value={field.value || ''} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>

            <div className="flex justify-end space-x-2 pt-4">
              <Button type="button" variant="outline" onClick={onClose}>
                Cancel
              </Button>
              <Button 
                type="submit" 
                disabled={createChangeMutation.isPending}
                className="bg-primary hover:bg-primary/90"
              >
                {createChangeMutation.isPending ? "Creating..." : "Submit Change Request"}
              </Button>
            </div>
          </form>
        </Form>
      </DialogContent>
    </Dialog>
  );
}