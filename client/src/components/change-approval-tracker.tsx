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

  const { data: change } = useQuery({
    queryKey: ["/api/changes", changeId],
    queryFn: async () => {
      const response = await apiRequest("GET", `/api/changes/${changeId}`);
      return response.json();
    },
  });

  const { data: approvalRouting = [] } = useQuery({
    queryKey: ["/api/approval-routing"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/approval-routing");
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
    return user?.name || user?.username || "Unknown User";
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

  const getAllPendingApprovals = () => {
    return approvals.filter((approval: ChangeApproval) => approval.status === 'pending');
  };

  const getCurrentApprovalLevel = () => {
    const pendingApprovals = getAllPendingApprovals();
    if (pendingApprovals.length === 0) return null;
    return Math.min(...pendingApprovals.map(a => a.approvalLevel));
  };

  const getApprovalRequirement = (level: number) => {
    if (!change || !approvalRouting.length) return 'any'; // default to any one approver
    
    // Find the matching approval routing based on change's assigned group and risk level
    const routing = approvalRouting.find((r: any) => 
      r.approvalLevel === level && 
      r.riskLevel === change.riskLevel &&
      r.isActive === 'true' // Compare as string, not boolean
    );
    
    return routing?.requireAllApprovals === 'true' ? 'all' : 'any';
  };

  const isLevelComplete = (level: number) => {
    const levelApprovals = approvals.filter((a: ChangeApproval) => a.approvalLevel === level);
    const approvedCount = levelApprovals.filter((a: ChangeApproval) => a.status === 'approved').length;
    const totalCount = levelApprovals.length;
    
    const requirement = getApprovalRequirement(level);
    
    if (requirement === 'all') {
      // All approvers must approve
      return approvedCount === totalCount;
    } else {
      // Any one approver is sufficient
      return approvedCount > 0;
    }
  };

  const isWorkflowComplete = () => {
    // Check if all required levels are complete
    const levels = [...new Set(approvals.map((a: ChangeApproval) => a.approvalLevel))];
    
    return levels.every(level => isLevelComplete(level));
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
  const allPendingApprovals = getAllPendingApprovals();
  const currentLevel = getCurrentApprovalLevel();

  return (
    <div className="space-y-4">
      {/* Pending Approvals Alert - Only show if there are truly pending approvals */}
      {allPendingApprovals.length > 0 && !isWorkflowComplete() && (
        <Card className="border-orange-200 bg-orange-50 dark:bg-orange-900/20 dark:border-orange-800">
          <CardHeader className="pb-3">
            <CardTitle className="flex items-center gap-2 text-orange-800 dark:text-orange-200">
              <Clock className="h-5 w-5" />
              {isLevelComplete(currentLevel) ? `Level ${currentLevel} - Complete` : `Pending Approval - Level ${currentLevel}`}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <p className="text-sm text-orange-700 dark:text-orange-300">
                {isLevelComplete(currentLevel) 
                  ? `Level ${currentLevel} approval requirements have been satisfied.`
                  : `This change is waiting for approval from the following Level ${currentLevel} approvers:`
                }
              </p>
              {!isLevelComplete(currentLevel) && (
                <div className="space-y-2">
                  {allPendingApprovals
                    .filter(approval => approval.approvalLevel === currentLevel)
                    .map((approval: ChangeApproval) => (
                      <div key={approval.id} className="flex items-center gap-3 p-3 bg-white dark:bg-gray-800 rounded-lg border">
                        <User className="h-4 w-4 text-orange-600" />
                        <span className="font-medium text-gray-900 dark:text-gray-100">
                          {getUserName(approval.approverId)}
                        </span>
                        <Badge className="bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200">
                          Level {approval.approvalLevel}
                        </Badge>
                        {approval.approverId === currentUser?.id && (
                          <Badge variant="secondary" className="bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                            Your Action Required
                          </Badge>
                        )}
                      </div>
                  ))}
                </div>
              )}
              {!isLevelComplete(currentLevel) && allPendingApprovals.some(a => a.approverId === currentUser?.id) && (
                <Button
                  onClick={() => handleApprove(allPendingApprovals.find(a => a.approverId === currentUser?.id)!)}
                  className="w-full bg-orange-600 hover:bg-orange-700 text-white"
                >
                  Review & Provide Your Approval
                </Button>
              )}
            </div>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <CheckCircle className={`h-5 w-5 ${isWorkflowComplete() ? 'text-green-600' : 'text-gray-400'}`} />
            {isWorkflowComplete() ? 'Approval Workflow - Complete' : 'Multilevel Approval Workflow'}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {approvals
              .filter((approval: ChangeApproval) => {
                // If the level is complete with "any one approver" logic, only show approved approvals
                if (isLevelComplete(approval.approvalLevel) && approval.status === 'pending') {
                  return false;
                }
                return true;
              })
              .map((approval: ChangeApproval, index: number) => (
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

                {index < approvals.filter((approval: ChangeApproval) => {
                  if (isLevelComplete(approval.approvalLevel) && approval.status === 'pending') {
                    return false;
                  }
                  return true;
                }).length - 1 && (
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