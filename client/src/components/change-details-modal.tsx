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
import { formatDateIST } from "@/lib/utils";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import { ChangeApprovalTracker } from "./change-approval-tracker";

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
  const [isEditing, setIsEditing] = useState(false);
  const [editForm, setEditForm] = useState({
    title: change.title,
    description: change.description,
    priority: change.priority,
    riskLevel: change.riskLevel,
    rollbackPlan: change.rollbackPlan || '',
    revisionNotes: ''
  });
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

  const reviseChangeMutation = useMutation({
    mutationFn: async (data: any) => {
      return apiRequest("PATCH", `/api/changes/${change.id}`, {
        ...data,
        status: 'pending', // Reset to pending for new approval
        userId: currentUser?.id,
        notes: `Change revised and resubmitted for approval. Revision notes: ${data.revisionNotes}`
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/changes"] });
      queryClient.invalidateQueries({ queryKey: ["/api/changes", change.id, "history"] });
      toast({
        title: "Success",
        description: "Change revised and resubmitted for approval",
      });
      setIsEditing(false);
      onClose();
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to revise change",
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
    
    // Prevent manual approval - must use approval workflow
    if (userRole === 'admin') {
      // Admins can manage all statuses except direct approval (use approval workflow instead)
      if (currentStatus === 'submitted' || currentStatus === 'pending') {
        return ['submitted', 'pending', 'rejected', 'implemented', 'completed', 'rolled-back'];
      }
      return ['submitted', 'pending', 'approved', 'rejected', 'implemented', 'completed', 'rolled-back'];
    }
    
    // Managers should use approval workflow, not direct status changes
    if ((userRole === 'manager') && (currentStatus === 'submitted' || currentStatus === 'pending')) {
      return ['rejected']; // Can reject, but approval must go through workflow
    }
    
    if (userRole === 'agent' && currentStatus === 'approved') {
      return ['in-progress', 'testing', 'completed', 'failed'];
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

  const handleReviseSubmit = () => {
    if (!editForm.title.trim() || !editForm.description.trim() || !editForm.rollbackPlan.trim()) {
      toast({
        title: "Missing Information",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    if (!editForm.revisionNotes.trim()) {
      toast({
        title: "Revision Notes Required",
        description: "Please explain what changes you made based on the feedback",
        variant: "destructive",
      });
      return;
    }

    reviseChangeMutation.mutate(editForm);
  };

  // Show revision form if editing rejected change
  if (isEditing && change.status === 'rejected') {
    return (
      <Dialog open={isOpen} onOpenChange={onClose}>
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Settings className="h-5 w-5" />
              Revise Change Request - CHG-{change.id}
            </DialogTitle>
          </DialogHeader>
          
          <div className="space-y-6">
            <div className="p-4 bg-orange-50 border border-orange-200 rounded-lg">
              <h4 className="font-semibold text-orange-800 mb-2">Change was rejected</h4>
              <p className="text-sm text-orange-700">
                Please review the feedback and update your change request before resubmitting for approval.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium mb-2">Title *</label>
                <input
                  type="text"
                  value={editForm.title}
                  onChange={(e) => setEditForm(prev => ({ ...prev, title: e.target.value }))}
                  className="w-full p-2 border rounded-lg"
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">Priority</label>
                <select
                  value={editForm.priority}
                  onChange={(e) => setEditForm(prev => ({ ...prev, priority: e.target.value }))}
                  className="w-full p-2 border rounded-lg"
                >
                  <option value="low">Low</option>
                  <option value="medium">Medium</option>
                  <option value="high">High</option>
                  <option value="critical">Critical</option>
                </select>
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">Description *</label>
              <textarea
                value={editForm.description}
                onChange={(e) => setEditForm(prev => ({ ...prev, description: e.target.value }))}
                className="w-full p-2 border rounded-lg h-24"
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">Risk Level</label>
              <select
                value={editForm.riskLevel}
                onChange={(e) => setEditForm(prev => ({ ...prev, riskLevel: e.target.value }))}
                className="w-full p-2 border rounded-lg"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">Rollback Plan *</label>
              <textarea
                value={editForm.rollbackPlan}
                onChange={(e) => setEditForm(prev => ({ ...prev, rollbackPlan: e.target.value }))}
                className="w-full p-2 border rounded-lg h-24"
              />
            </div>

            <div>
              <label className="block text-sm font-medium mb-2">Revision Notes *</label>
              <textarea
                value={editForm.revisionNotes}
                onChange={(e) => setEditForm(prev => ({ ...prev, revisionNotes: e.target.value }))}
                placeholder="Explain what changes you made based on the feedback..."
                className="w-full p-2 border rounded-lg h-20"
              />
            </div>

            <div className="flex gap-2 justify-end">
              <Button 
                variant="outline" 
                onClick={() => setIsEditing(false)}
                disabled={reviseChangeMutation.isPending}
              >
                Cancel
              </Button>
              <Button 
                onClick={handleReviseSubmit}
                disabled={reviseChangeMutation.isPending}
                className="bg-green-600 hover:bg-green-700"
              >
                {reviseChangeMutation.isPending ? "Submitting..." : "Resubmit for Approval"}
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    );
  }

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
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Change Type</h4>
                    <div className="flex items-center gap-2">
                      {change.changeType === 'standard' && <CheckCircle className="h-4 w-4 text-green-500" />}
                      {change.changeType === 'emergency' && <AlertTriangle className="h-4 w-4 text-red-500" />}
                      {(!change.changeType || change.changeType === 'normal') && <AlertTriangle className="h-4 w-4 text-blue-500" />}
                      <span className="capitalize">{change.changeType || 'normal'}</span>
                      {change.changeType === 'standard' && <span className="text-xs text-green-600">(No Approval Required)</span>}
                    </div>
                  </div>
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
                        {change.plannedDate ? formatDateIST(change.plannedDate, 'PPP') : 'N/A'}
                      </p>
                    </div>
                  )}
                  {change.startDate && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Start Date</h4>
                      <p className="text-sm flex items-center gap-1">
                        <Calendar className="h-4 w-4 text-green-600" />
                        {formatDateIST(change.startDate, 'PPP p')}
                      </p>
                    </div>
                  )}
                  {change.endDate && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">End Date</h4>
                      <p className="text-sm flex items-center gap-1">
                        <Calendar className="h-4 w-4 text-red-600" />
                        {formatDateIST(change.endDate, 'PPP p')}
                      </p>
                    </div>
                  )}
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Created</h4>
                    <p className="text-sm">
                      {change.createdAt ? formatDateIST(change.createdAt, 'PPP p') : 'N/A'}
                    </p>
                  </div>
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Last Updated</h4>
                    <p className="text-sm">
                      {change.updatedAt ? formatDateIST(change.updatedAt, 'PPP p') : 'N/A'}
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

            {/* Revision Button for Rejected Changes */}
            {change.status === 'rejected' && (currentUser?.role === 'agent' || currentUser?.role === 'admin') && (
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm flex items-center gap-2 text-orange-700">
                    <AlertTriangle className="h-4 w-4" />
                    Change Rejected - Action Required
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-sm text-gray-600 mb-4">
                    This change has been rejected and needs to be revised before it can be resubmitted for approval.
                  </p>
                  <Button 
                    onClick={() => setIsEditing(true)}
                    className="bg-orange-600 hover:bg-orange-700 text-white"
                  >
                    Revise & Resubmit
                  </Button>
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
                                {entry.timestamp ? formatDateIST(entry.timestamp, 'MMM dd, HH:mm') : 'N/A'}
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

            {/* Multilevel Approval Tracker */}
            {(change.status === 'submitted' || change.status === 'pending' || change.status === 'approved' || change.status === 'rejected') && (
              <ChangeApprovalTracker 
                changeId={change.id}
                currentUser={currentUser}
              />
            )}

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