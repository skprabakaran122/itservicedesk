import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Ticket, TicketHistory, User } from "@shared/schema";
import { Clock, User as UserIcon, Package, AlertCircle, MessageSquare, History } from "lucide-react";
import { format } from "date-fns";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";

interface TicketDetailsModalProps {
  ticket: Ticket;
  isOpen: boolean;
  onClose: () => void;
  currentUser: any;
  getStatusColor: (status: string) => string;
  getPriorityColor: (priority: string) => string;
}

export function TicketDetailsModal({ 
  ticket, 
  isOpen, 
  onClose, 
  currentUser, 
  getStatusColor, 
  getPriorityColor 
}: TicketDetailsModalProps) {
  const [newStatus, setNewStatus] = useState(ticket.status);
  const [notes, setNotes] = useState("");
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: users = [] } = useQuery<User[]>({
    queryKey: ["/api/users"],
  });

  const { data: history = [] } = useQuery<TicketHistory[]>({
    queryKey: ["/api/tickets", ticket.id, "history"],
    queryFn: async () => {
      const response = await apiRequest("GET", `/api/tickets/${ticket.id}/history`);
      return await response.json();
    },
    enabled: isOpen,
  });

  const updateTicketMutation = useMutation({
    mutationFn: async ({ status, notes }: { status: string; notes?: string }) => {
      const response = await apiRequest("PATCH", `/api/tickets/${ticket.id}`, { 
        status,
        ...(notes && { notes })
      });
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Ticket updated successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/tickets"] });
      queryClient.invalidateQueries({ queryKey: ["/api/tickets", ticket.id, "history"] });
      setNotes("");
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to update ticket",
        variant: "destructive",
      });
    },
  });

  const addCommentMutation = useMutation({
    mutationFn: async (comment: string) => {
      const response = await apiRequest("POST", `/api/tickets/${ticket.id}/comments`, { 
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
      queryClient.invalidateQueries({ queryKey: ["/api/tickets", ticket.id, "history"] });
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

  const getRequesterName = (requesterId: number) => {
    const user = users.find(u => u.id === requesterId);
    return user ? user.name : `User ${requesterId}`;
  };

  const getRequesterEmail = (requesterId: number) => {
    const user = users.find(u => u.id === requesterId);
    return user ? user.email : `user${requesterId}@company.com`;
  };

  const getUserName = (userId: number) => {
    const user = users.find(u => u.id === userId);
    return user ? user.name : `User ${userId}`;
  };

  const getActionDescription = (action: string, field?: string) => {
    if (!action) return 'Unknown action';
    
    const actionMap: Record<string, string> = {
      'created': 'created ticket',
      'updated_status': 'changed status',
      'updated_priority': 'changed priority',
      'updated_assignedTo': 'changed assignee',
      'updated_category': 'changed category',
      'updated_title': 'updated title',
      'updated_description': 'updated description',
      'comment_added': 'added comment',
      'assigned': 'assigned ticket',
      'status_changed': 'changed status'
    };

    return actionMap[action] || action.replace(/_/g, ' ').replace('updated ', 'updated ');
  };

  const handleStatusUpdate = () => {
    if (newStatus !== ticket.status) {
      updateTicketMutation.mutate({ status: newStatus, notes });
    }
  };

  const handleAddComment = () => {
    if (notes.trim()) {
      addCommentMutation.mutate(notes);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <AlertCircle className="h-5 w-5" />
            Ticket #{ticket.id} - {ticket.title}
          </DialogTitle>
        </DialogHeader>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6">
            {/* Ticket Info */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span>Ticket Information</span>
                  <div className="flex gap-2">
                    <Badge className={getPriorityColor(ticket.priority)}>
                      {ticket.priority.toUpperCase()}
                    </Badge>
                    <Badge variant="secondary" className={getStatusColor(ticket.status)}>
                      {ticket.status.replace('-', ' ').toUpperCase()}
                    </Badge>
                  </div>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-2">Description</h4>
                  <p className="text-gray-900 dark:text-white">{ticket.description}</p>
                </div>
                
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Category</h4>
                    <p className="capitalize">{ticket.category}</p>
                  </div>
                  {ticket.product && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Product</h4>
                      <p>{ticket.product}</p>
                    </div>
                  )}
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Requester</h4>
                    <p>{getRequesterName(ticket.requesterId)}</p>
                    <p className="text-sm text-gray-500">{getRequesterEmail(ticket.requesterId)}</p>
                  </div>
                  {ticket.assignedTo && (
                    <div>
                      <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Assigned To</h4>
                      <p>{ticket.assignedTo}</p>
                    </div>
                  )}
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Created</h4>
                    <p className="text-sm">
                      {ticket.createdAt ? format(new Date(ticket.createdAt), 'PPP p') : 'N/A'}
                    </p>
                  </div>
                  <div>
                    <h4 className="font-medium text-sm text-gray-600 dark:text-gray-400 mb-1">Last Updated</h4>
                    <p className="text-sm">
                      {ticket.updatedAt ? format(new Date(ticket.updatedAt), 'PPP p') : 'N/A'}
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Update Status */}
            <Card>
              <CardHeader>
                <CardTitle>Update Ticket</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Status</label>
                  <Select value={newStatus} onValueChange={setNewStatus}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="pending">Pending</SelectItem>
                      <SelectItem value="open">Open</SelectItem>
                      <SelectItem value="in-progress">In Progress</SelectItem>
                      <SelectItem value="resolved">Resolved</SelectItem>
                      <SelectItem value="closed">Closed</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium mb-2">Notes (Optional)</label>
                  <Textarea
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Add notes about this update..."
                    className="min-h-[100px]"
                  />
                </div>

                <div className="flex gap-2">
                  <Button 
                    onClick={handleStatusUpdate}
                    disabled={updateTicketMutation.isPending || newStatus === ticket.status}
                  >
                    {updateTicketMutation.isPending ? "Updating..." : "Update Status"}
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
          </div>

          {/* History Sidebar */}
          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <History className="h-4 w-4" />
                  Activity History
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
                              {getActionDescription(entry.action || '', entry.field || undefined)}
                              {entry.oldValue && entry.newValue && (
                                <span className="text-xs block text-gray-500 mt-1">
                                  {entry.oldValue} → {entry.newValue}
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
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}