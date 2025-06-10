import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Change, ChangeHistory, User } from "@shared/schema";
import { Calendar, Users, Shield, AlertTriangle, History, CheckCircle, XCircle, Clock, Settings } from "lucide-react";
import { format } from "date-fns";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";

interface ChangeDetailsModalProps {
  change: Change;
  isOpen: boolean;
  onClose: () => void;
  currentUser: any;
  getStatusColor: (status: string) => string;
  getPriorityColor: (priority: string) => string;
}

export function ChangeDetailsModal({ 
  change, 
  isOpen, 
  onClose, 
  currentUser, 
  getStatusColor, 
  getPriorityColor 
}: ChangeDetailsModalProps) {
  const [newStatus, setNewStatus] = useState(change.status);
  const [notes, setNotes] = useState("");
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: users = [] } = useQuery<User[]>({
    queryKey: ["/api/users"],
  });

  const { data: history = [] } = useQuery<ChangeHistory[]>({
    queryKey: ["/api/changes", change.id, "history"],
    queryFn: async () => {
      const response = await apiRequest("GET", `/api/changes/${change.id}/history`);
      return await response.json();
    },
    enabled: isOpen,
  });

  const updateChangeMutation = useMutation({
    mutationFn: async ({ status, notes }: { status: string; notes?: string }) => {
      const response = await apiRequest("PATCH", `/api/changes/${change.id}`, { 
        status,
        ...(notes && { notes })
      });
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Change request updated successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/changes"] });
      queryClient.invalidateQueries({ queryKey: ["/api/changes", change.id, "history"] });
      setNotes("");
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to update change request",
        variant: "destructive",
      });
    },
  });

  const addCommentMutation = useMutation({
    mutationFn: async (comment: string) => {
      const response = await apiRequest("POST", `/api/changes/${change.id}/comments`, { 
        notes: comment,
        userId: currentUser?.id
      });
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Comment added successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/changes", change.id, "history"] });
      setNotes("");
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to add comment",
        variant: "destructive",
      });
    },
  });

  const getUserName = (userId: number) => {
    const user = users.find(u => u.id === userId);
    return user ? user.name : `User ${userId}`;
  };

  const getActionDescription = (action: string, field?: string) => {
    if (!action) return 'Unknown action';
    
    const actionMap: Record<string, string> = {
      'created': 'created change request',
      'updated_status': 'changed status',
      'updated_priority': 'changed priority',
      'updated_riskLevel': 'changed risk level',
      'updated_category': 'changed category',
      'updated_title': 'updated title',
      'updated_description': 'updated description',
      'updated_rollbackPlan': 'updated rollback plan',
      'updated_approvedBy': 'changed approver',
      'updated_implementedBy': 'changed implementer',
      'comment_added': 'added comment',
      'approved': 'approved change',
      'rejected': 'rejected change',
      'status_changed': 'changed status'
    };

    return actionMap[action] || action.replace(/_/g, ' ').replace('updated ', 'updated ');
  };

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'pending': return <Clock className="h-4 w-4" />;
      case 'approved': return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'rejected': return <XCircle className="h-4 w-4 text-red-500" />;
      case 'in-progress': return <Settings className="h-4 w-4 text-blue-500" />;
      case 'testing': return <AlertTriangle className="h-4 w-4 text-orange-500" />;
      case 'completed': return <CheckCircle className="h-4 w-4 text-green-600" />;
      case 'failed': return <XCircle className="h-4 w-4 text-red-600" />;
      case 'rollback': return <History className="h-4 w-4 text-amber-500" />;
      default: return <Clock className="h-4 w-4" />;
    }
  };

  const getRiskLevelColor = (riskLevel: string) => {
    switch (riskLevel) {
      case 'low': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      case 'medium': return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300';
      case 'high': return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300';
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    }
  };

  const canUpdateStatus = () => {
    const userRole = currentUser?.role;
    const currentStatus = change.status;
    
    // Managers and admins can approve/reject
    if ((userRole === 'manager' || userRole === 'admin') && 
        (currentStatus === 'submitted' || currentStatus === 'pending')) {
      return true;
    }
    
    // Technicians can implement approved changes
    if (userRole === 'technician' && currentStatus === 'approved') {
      return true;
    }
    
    // Admins can do anything
    if (userRole === 'admin') {
      return true;
    }
    
    return false;
  };

  const getAvailableStatuses = () => {
    const userRole = currentUser?.role;
    const currentStatus = change.status;
    
    if (userRole === 'admin') {
      return ['submitted', 'pending', 'approved', 'rejected', 'implemented', 'completed', 'rolled-back'];
    }
    
    if ((userRole === 'manager') && (currentStatus === 'submitted' || currentStatus === 'pending')) {
      return ['approved', 'rejected'];
    }
    
    if (userRole === 'technician' && currentStatus === 'approved') {
      return ['implemented', 'completed'];
    }
    
    return [currentStatus];
  };

  const handleStatusUpdate = () => {
    if (newStatus !== change.status && canUpdateStatus()) {
      // Require notes when changing status to completed or rejected
      if ((newStatus === 'completed' || newStatus === 'rejected') && !notes.trim()) {
        toast({
          title: "Notes Required",
          description: `Please provide notes when ${newStatus === 'completed' ? 'completing' : 'rejecting'} a change request`,
          variant: "destructive",
        });
        return;
      }
      updateChangeMutation.mutate({ status: newStatus, notes });
    }
  };

  const handleAddComment = () => {
    if (notes.trim()) {
      addCommentMutation.mutate(notes);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-5xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Shield className="h-5 w-5" />
            Change Request #{change.id} - {change.title}
          </DialogTitle>
        </DialogHeader>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Change Info */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span>Change Request Information</span>
                  <div className="flex gap-2">
                    <Badge className={getPriorityColor(change.priority)}>
                      {change.priority.toUpperCase()}
                    </Badge>
                    <Badge className={getRiskLevelColor(change.riskLevel)}>
                      Risk: {change.riskLevel.toUpperCase()}
                    </Badge>
                    <Badge variant="secondary" className={getStatusColor(change.status)}>
                      <div className="flex items-center gap-1">
                        {getStatusIcon(change.status)}
                        {change.status.replace('-', ' ').toUpperCase()}
                      </div>
                    </Badge>
                  </div>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-2">Description</h4>
                  <p className="text-gray-900 dark:text-white">{change.description}</p>
                </div>
                
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Category</h4>
                    <p className="capitalize">{change.category}</p>
                  </div>
                  {change.product && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Product</h4>
                      <p>{change.product}</p>
                    </div>
                  )}
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Risk Level</h4>
                    <div className="flex items-center gap-2">
                      <AlertTriangle className="h-4 w-4 text-orange-500" />
                      <span className="capitalize">{change.riskLevel}</span>
                    </div>
                  </div>
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Requested By</h4>
                    <p>{change.requestedBy}</p>
                  </div>
                  {change.approvedBy && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Approved By</h4>
                      <p>{change.approvedBy}</p>
                    </div>
                  )}
                  {change.implementedBy && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Implemented By</h4>
                      <p>{change.implementedBy}</p>
                    </div>
                  )}
                </div>

                <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                  {change.plannedDate && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Planned Date</h4>
                      <p className="text-sm flex items-center gap-1">
                        <Calendar className="h-4 w-4" />
                        {change.plannedDate ? format(new Date(change.plannedDate), 'PPP') : 'N/A'}
                      </p>
                    </div>
                  )}
                  {change.startDate && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Start Date</h4>
                      <p className="text-sm flex items-center gap-1">
                        <Calendar className="h-4 w-4 text-green-600" />
                        {format(new Date(change.startDate), 'PPP p')}
                      </p>
                    </div>
                  )}
                  {change.endDate && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">End Date</h4>
                      <p className="text-sm flex items-center gap-1">
                        <Calendar className="h-4 w-4 text-red-600" />
                        {format(new Date(change.endDate), 'PPP p')}
                      </p>
                    </div>
                  )}
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Created</h4>
                    <p className="text-sm">
                      {change.createdAt ? format(new Date(change.createdAt), 'PPP p') : 'N/A'}
                    </p>
                  </div>
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Last Updated</h4>
                    <p className="text-sm">
                      {change.updatedAt ? format(new Date(change.updatedAt), 'PPP p') : 'N/A'}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Update Status */}
            {canUpdateStatus() && (
              <Card>
                <CardHeader>
                  <CardTitle>Update Change Request</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Status</label>
                    <Select value={newStatus} onValueChange={setNewStatus}>
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {getAvailableStatuses().map(status => (
                          <SelectItem key={status} value={status}>
                            <div className="flex items-center gap-2">
                              {getStatusIcon(status)}
                              {status.replace('-', ' ').toUpperCase()}
                            </div>
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                  
                  <div>
                    <label className="block text-sm font-medium mb-2">
                      Notes {(newStatus === 'completed' || newStatus === 'rejected') ? '(Required)' : '(Optional)'}
                      {(newStatus === 'completed' || newStatus === 'rejected') && <span className="text-red-500 ml-1">*</span>}
                    </label>
                    <Textarea
                      value={notes}
                      onChange={(e) => setNotes(e.target.value)}
                      placeholder={
                        newStatus === 'completed' ? "Describe what was completed..." :
                        newStatus === 'rejected' ? "Explain why this was rejected..." :
                        "Add notes about this update..."
                      }
                      className={`min-h-[100px] ${(newStatus === 'completed' || newStatus === 'rejected') && !notes.trim() ? 'border-red-300 focus:border-red-500' : ''}`}
                    />
                    {(newStatus === 'completed' || newStatus === 'rejected') && !notes.trim() && (
                      <p className="text-sm text-red-500 mt-1">Notes are required when {newStatus === 'completed' ? 'completing' : 'rejecting'} a change request</p>
                    )}
                  </div>

                  <div className="flex gap-2">
                    <Button 
                      onClick={handleStatusUpdate}
                      disabled={updateChangeMutation.isPending || newStatus === change.status}
                    >
                      {updateChangeMutation.isPending ? "Updating..." : "Update Status"}
                    </Button>
                    <Button 
                      variant="outline"
                      onClick={handleAddComment}
                      disabled={addCommentMutation.isPending || !notes.trim()}
                    >
                      {addCommentMutation.isPending ? "Adding..." : "Add Comment"}
                    </Button>
                  </div>
                </CardContent>
              </Card>
            )}
          </div>

          {/* History Sidebar */}
          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <History className="h-4 w-4" />
                  Change History
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {history.length === 0 ? (
                    <p className="text-sm text-gray-500">No activity yet</p>
                  ) : (
                    history.map((entry, index) => (
                      <div key={entry.id} className="relative">
                        {index < history.length - 1 && (
                          <div className="absolute left-2 top-8 bottom-0 w-px bg-gray-200 dark:bg-gray-700" />
                        )}
                        <div className="flex gap-3">
                          <div className="w-4 h-4 rounded-full bg-primary flex-shrink-0 mt-1" />
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-sm font-medium">{getUserName(entry.userId)}</span>
                              <span className="text-xs text-gray-500">
                                {entry.timestamp ? format(new Date(entry.timestamp), 'MMM dd, HH:mm') : 'N/A'}
                              </span>
                            </div>
                            <p className="text-sm text-gray-700 dark:text-gray-300">
                              {getActionDescription(entry.action)}
                              {entry.previousStatus && entry.newStatus && (
                                <span className="text-xs block text-gray-500 mt-1">
                                  {entry.previousStatus} → {entry.newStatus}
                                </span>
                              )}
                            </p>
                            {entry.notes && (
                              <p className="text-sm text-gray-600 dark:text-gray-400 mt-1 italic">
                                "{entry.notes}"
                              </p>
                            )}
                          </div>
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Change Workflow Guide */}
            <Card>
              <CardHeader>
                <CardTitle className="text-sm">Change Workflow</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-3 text-xs">
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full bg-gray-400" />
                    <span>1. Submitted → Pending Review</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full bg-yellow-400" />
                    <span>2. Manager/Admin Approval</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full bg-blue-400" />
                    <span>3. Implementation</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full bg-green-400" />
                    <span>4. Testing & Completion</span>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}