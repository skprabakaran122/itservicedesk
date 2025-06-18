import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { CheckCircle, XCircle, Clock, User, MessageSquare, ArrowRight } from "lucide-react";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import { format } from "date-fns";
import type { ChangeApproval, User as UserType } from "@shared/schema";

const approvalSchema = z.object({
  action: z.enum(["approved", "rejected"]),
  comments: z.string().optional(),
});

interface ChangeApprovalTrackerProps {
  changeId: number;
  currentUser: any;
}

export function ChangeApprovalTracker({ changeId, currentUser }: ChangeApprovalTrackerProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [showApprovalForm, setShowApprovalForm] = useState(false);
  const [selectedApproval, setSelectedApproval] = useState<ChangeApproval | null>(null);

  const { data: approvals = [], isLoading } = useQuery({
    queryKey: ["/api/changes", changeId, "approvals"],
    queryFn: async () => {
      const response = await apiRequest("GET", `/api/changes/${changeId}/approvals`);
      return response.json();
    },
  });

  const { data: users = [] } = useQuery({
    queryKey: ["/api/users"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/users");
      return response.json();
    },
  });

  const form = useForm<z.infer<typeof approvalSchema>>({
    resolver: zodResolver(approvalSchema),
    defaultValues: {
      action: "approved",
      comments: "",
    },
  });

  const approvalMutation = useMutation({
    mutationFn: async (data: z.infer<typeof approvalSchema>) => {
      const response = await apiRequest("POST", `/api/changes/${changeId}/approve`, {
        approverId: currentUser.id,
        action: data.action,
        comments: data.comments,
      });
      return response.json();
    },
    onSuccess: (result) => {
      toast({
        title: "Success",
        description: result.completed 
          ? `Change ${result.approved ? 'fully approved' : 'rejected'} successfully`
          : `Approval processed. ${result.nextLevel ? `Waiting for Level ${result.nextLevel} approval` : 'Processing next level'}`,
      });
      queryClient.invalidateQueries({ queryKey: ["/api/changes", changeId, "approvals"] });
      queryClient.invalidateQueries({ queryKey: ["/api/changes"] });
      setShowApprovalForm(false);
      form.reset();
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to process approval",
        variant: "destructive",
      });
    },
  });

  const getUserName = (userId: number) => {
    const user = users.find((u: UserType) => u.id === userId);
    return user?.username || "Unknown User";
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'approved':
        return <CheckCircle className="h-4 w-4 text-green-600" />;
      case 'rejected':
        return <XCircle className="h-4 w-4 text-red-600" />;
      default:
        return <Clock className="h-4 w-4 text-yellow-600" />;
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'approved':
        return "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200";
      case 'rejected':
        return "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200";
      default:
        return "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200";
    }
  };

  const canApprove = (approval: ChangeApproval) => {
    return approval.approverId === currentUser?.id && approval.status === 'pending';
  };

  const getCurrentPendingApproval = () => {
    return approvals.find((approval: ChangeApproval) => 
      approval.status === 'pending' && approval.approverId === currentUser?.id
    );
  };

  const handleApprove = (approval: ChangeApproval) => {
    setSelectedApproval(approval);
    setShowApprovalForm(true);
  };

  const onSubmit = (data: z.infer<typeof approvalSchema>) => {
    approvalMutation.mutate(data);
  };

  if (isLoading) {
    return (
      <Card>
        <CardContent className="p-6">
          <div className="animate-pulse space-y-4">
            <div className="h-4 bg-gray-200 rounded w-1/3"></div>
            <div className="space-y-2">
              <div className="h-3 bg-gray-200 rounded"></div>
              <div className="h-3 bg-gray-200 rounded w-2/3"></div>
            </div>
          </div>
        </CardContent>
      </Card>
    );
  }

  if (approvals.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle className="h-5 w-5" />
            Approval Status
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-gray-600 dark:text-gray-400">
            No approval workflow configured for this change.
          </p>
        </CardContent>
      </Card>
    );
  }

  const currentPendingApproval = getCurrentPendingApproval();

  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle className="h-5 w-5" />
            Multilevel Approval Workflow
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {approvals.map((approval: ChangeApproval, index: number) => (
              <div key={approval.id} className="flex items-center gap-4 p-4 border rounded-lg">
                <div className="flex items-center gap-2">
                  <Badge variant="outline" className="font-mono">
                    Level {approval.approvalLevel}
                  </Badge>
                  {getStatusIcon(approval.status)}
                </div>
                
                <div className="flex-1">
                  <div className="flex items-center gap-2 mb-1">
                    <User className="h-4 w-4" />
                    <span className="font-medium">{getUserName(approval.approverId)}</span>
                    <Badge className={getStatusColor(approval.status)}>
                      {approval.status.toUpperCase()}
                    </Badge>
                  </div>
                  
                  {approval.comments && (
                    <div className="flex items-start gap-2 mt-2 p-2 bg-gray-50 dark:bg-gray-800 rounded">
                      <MessageSquare className="h-4 w-4 mt-0.5 text-gray-500" />
                      <p className="text-sm text-gray-700 dark:text-gray-300">{approval.comments}</p>
                    </div>
                  )}
                  
                  {approval.approvedAt && (
                    <p className="text-xs text-gray-500 mt-1">
                      {approval.status === 'approved' ? 'Approved' : 'Rejected'} on {format(new Date(approval.approvedAt), 'PPP p')}
                    </p>
                  )}
                </div>

                {canApprove(approval) && (
                  <Button
                    onClick={() => handleApprove(approval)}
                    className="bg-primary hover:bg-primary/90"
                  >
                    Review & Approve
                  </Button>
                )}

                {index < approvals.length - 1 && (
                  <ArrowRight className="h-4 w-4 text-gray-400" />
                )}
              </div>
            ))}
          </div>

          {currentPendingApproval && (
            <div className="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <Clock className="h-4 w-4 text-blue-600" />
                <span className="font-medium text-blue-800 dark:text-blue-200">
                  Awaiting Your Approval
                </span>
              </div>
              <p className="text-sm text-blue-700 dark:text-blue-300">
                This change requires your approval at Level {currentPendingApproval.approvalLevel}. 
                Please review the change details and provide your decision.
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Approval Form Dialog */}
      <Dialog open={showApprovalForm} onOpenChange={setShowApprovalForm}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              Approval Decision - Level {selectedApproval?.approvalLevel}
            </DialogTitle>
          </DialogHeader>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="action"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Decision</FormLabel>
                    <div className="flex gap-4">
                      <Button
                        type="button"
                        variant={field.value === "approved" ? "default" : "outline"}
                        onClick={() => field.onChange("approved")}
                        className="flex-1"
                      >
                        <CheckCircle className="h-4 w-4 mr-2" />
                        Approve
                      </Button>
                      <Button
                        type="button"
                        variant={field.value === "rejected" ? "destructive" : "outline"}
                        onClick={() => field.onChange("rejected")}
                        className="flex-1"
                      >
                        <XCircle className="h-4 w-4 mr-2" />
                        Reject
                      </Button>
                    </div>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="comments"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Comments (Optional)</FormLabel>
                    <FormControl>
                      <Textarea
                        placeholder="Add comments about your decision..."
                        {...field}
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex justify-end space-x-2 pt-4">
                <Button type="button" variant="outline" onClick={() => setShowApprovalForm(false)}>
                  Cancel
                </Button>
                <Button 
                  type="submit" 
                  disabled={approvalMutation.isPending}
                >
                  {approvalMutation.isPending ? "Processing..." : "Submit Decision"}
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>
    </div>
  );
}