import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { Ticket, User } from "@shared/schema";
import { Clock, User as UserIcon, AlertCircle, Package, Eye, CheckCircle, XCircle, Send } from "lucide-react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDateIST } from "@/lib/utils";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import { TicketDetailsModal } from "./ticket-details-modal";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";

interface TicketsListProps {
  tickets: Ticket[];
  getStatusColor: (status: string) => string;
  getPriorityColor: (priority: string) => string;
  currentUser: any;
}

const approvalSchema = z.object({
  action: z.enum(['approve', 'reject']),
  comments: z.string().optional()
});

export function TicketsList({ tickets, getStatusColor, getPriorityColor, currentUser }: TicketsListProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);
  const [showApprovalDialog, setShowApprovalDialog] = useState(false);
  const [showRequestApprovalDialog, setShowRequestApprovalDialog] = useState(false);
  const [approvingTicket, setApprovingTicket] = useState<Ticket | null>(null);
  const [requestingApprovalTicket, setRequestingApprovalTicket] = useState<Ticket | null>(null);

  // Tickets are already filtered by the server based on user role
  const filteredTickets = tickets;
  
  const { data: users = [] } = useQuery<User[]>({
    queryKey: ["/api/users"],
  });

  const updateStatusMutation = useMutation({
    mutationFn: async ({ id, status }: { id: number; status: string }) => {
      const response = await apiRequest("PATCH", `/api/tickets/${id}`, { status });
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Ticket status updated successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/tickets"] });
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to update ticket status",
        variant: "destructive",
      });
    },
  });

  const requestApprovalMutation = useMutation({
    mutationFn: async (data: { ticketId: number; managerId: number; comments?: string }) => {
      const response = await apiRequest("POST", `/api/tickets/${data.ticketId}/request-approval`, {
        managerId: data.managerId,
        comments: data.comments
      });
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Ticket sent for approval successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/tickets"] });
      setShowRequestApprovalDialog(false);
      setRequestingApprovalTicket(null);
      requestApprovalForm.reset();
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to send ticket for approval",
        variant: "destructive",
      });
    },
  });

  const requestApprovalSchema = z.object({
    managerId: z.string().min(1, "Please select a manager"),
    comments: z.string().optional(),
  });

  const requestApprovalForm = useForm<z.infer<typeof requestApprovalSchema>>({
    resolver: zodResolver(requestApprovalSchema),
    defaultValues: {
      managerId: '',
      comments: '',
    },
  });

  const approvalForm = useForm<z.infer<typeof approvalSchema>>({
    resolver: zodResolver(approvalSchema),
    defaultValues: {
      action: 'approve',
      comments: ''
    }
  });

  const approvalMutation = useMutation({
    mutationFn: async (data: { ticketId: number; action: string; comments?: string }) => {
      const response = await apiRequest("POST", `/api/tickets/${data.ticketId}/approve`, {
        action: data.action,
        comments: data.comments
      });
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Ticket approval processed successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/tickets"] });
      setShowApprovalDialog(false);
      setApprovingTicket(null);
      approvalForm.reset();
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to process approval",
        variant: "destructive",
      });
    },
  });

  const sortedTickets = [...filteredTickets].sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  const getRequesterName = (ticket: Ticket) => {
    // Use stored requester name if available
    if (ticket.requesterName) return ticket.requesterName;
    
    // Fall back to user lookup if requesterId exists
    if (ticket.requesterId) {
      const user = users.find(u => u.id === ticket.requesterId);
      return user ? user.name : `User ${ticket.requesterId}`;
    }
    
    return 'Unknown User';
  };

  const getRequesterEmail = (ticket: Ticket) => {
    // Use stored requester email if available
    if (ticket.requesterEmail) return ticket.requesterEmail;
    
    // Fall back to user lookup if requesterId exists
    if (ticket.requesterId) {
      const user = users.find(u => u.id === ticket.requesterId);
      return user ? user.email : `user${ticket.requesterId}@company.com`;
    }
    
    return 'No email provided';
  };

  const handleStatusUpdate = (ticketId: number, newStatus: string) => {
    updateStatusMutation.mutate({ id: ticketId, status: newStatus });
  };

  const handleRequestApproval = (ticket: Ticket) => {
    setRequestingApprovalTicket(ticket);
    setShowRequestApprovalDialog(true);
    requestApprovalForm.reset();
  };

  const handleApprovalAction = (ticket: Ticket) => {
    setApprovingTicket(ticket);
    setShowApprovalDialog(true);
  };

  const onRequestApprovalSubmit = (data: z.infer<typeof requestApprovalSchema>) => {
    if (!requestingApprovalTicket) return;
    
    requestApprovalMutation.mutate({
      ticketId: requestingApprovalTicket.id,
      managerId: parseInt(data.managerId),
      comments: data.comments
    });
  };

  const onApprovalSubmit = (data: z.infer<typeof approvalSchema>) => {
    if (!approvingTicket) return;
    approvalMutation.mutate({
      ticketId: approvingTicket.id,
      action: data.action,
      comments: data.comments
    });
  };

  const canRequestApproval = (ticket: Ticket): boolean => {
    return currentUser?.role === 'agent' && 
           !ticket.approvalStatus && 
           ticket.status === 'open';
  };

  const canApprove = (ticket: Ticket): boolean => {
    return ['manager', 'admin'].includes(currentUser?.role) && 
           ticket.approvalStatus === 'pending';
  };

  const getApprovalStatusBadge = (ticket: Ticket) => {
    if (!ticket.approvalStatus) return null;
    
    switch (ticket.approvalStatus) {
      case 'pending':
        return <Badge variant="outline" className="text-orange-600 border-orange-600">Pending Approval</Badge>;
      case 'approved':
        return <Badge variant="outline" className="text-green-600 border-green-600">Approved</Badge>;
      case 'rejected':
        return <Badge variant="outline" className="text-red-600 border-red-600">Rejected</Badge>;
      default:
        return null;
    }
  };

  // Get allowed status options for a specific ticket
  const getAllowedStatusOptions = (ticket: Ticket) => {
    // Don't allow status changes for tickets pending approval
    if (ticket.approvalStatus === 'pending') {
      return [];
    }
    
    // Closed tickets cannot be moved to any other status - they are final
    if (ticket.status === 'closed') {
      return [];
    }
    
    if (currentUser?.role === 'user') {
      // Users can only modify their own tickets
      if (!ticket.requesterId || ticket.requesterId !== currentUser?.id) {
        return []; // No options for tickets they don't own
      }
      
      // Users can only reopen resolved tickets or close open/reopened tickets
      if (ticket.status === 'resolved') {
        return ['reopen'];
      }
      if (ticket.status === 'open' || ticket.status === 'reopen') {
        return ['closed'];
      }
      return [];
    }
    
    // Agents, managers, and admins have different options based on current status
    
    // For other statuses, allow all transitions except reopen (unless they're the original requester)
    const baseStatuses = ['pending', 'open', 'in-progress', 'resolved', 'closed'];
    if (ticket.requesterId === currentUser?.id) {
      baseStatuses.push('reopen');
    }
    return baseStatuses;
  };

  return (
    <div className="space-y-4">
      {sortedTickets.map((ticket) => (
        <Card key={ticket.id} className="hover:shadow-md transition-shadow">
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <CardTitle className="text-lg font-semibold text-gray-900 dark:text-white">
                  #{ticket.id} - {ticket.title}
                </CardTitle>
                <CardDescription className="mt-1">
                  {ticket.description.length > 150 
                    ? `${ticket.description.substring(0, 150)}...` 
                    : ticket.description
                  }
                </CardDescription>
              </div>
              <div className="flex flex-col items-end gap-2 ml-4">
                <Badge className={getPriorityColor(ticket.priority)}>
                  {ticket.priority.toUpperCase()}
                </Badge>
                <Badge variant="secondary" className={getStatusColor(ticket.status)}>
                  {ticket.status.replace('-', ' ').toUpperCase()}
                </Badge>
                {getApprovalStatusBadge(ticket)}
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <UserIcon className="h-4 w-4" />
                <div>
                  <div className="font-medium">{getRequesterName(ticket)}</div>
                  <div className="text-xs">{getRequesterEmail(ticket)}</div>
                  {ticket.requesterDepartment && (
                    <div className="text-xs text-gray-500">Dept: {ticket.requesterDepartment}</div>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <AlertCircle className="h-4 w-4" />
                <span className="capitalize">{ticket.category}</span>
              </div>
              {ticket.product && (
                <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <Package className="h-4 w-4" />
                  <span>{ticket.product}</span>
                </div>
              )}
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <Clock className="h-4 w-4" />
                <span>{formatDateIST(ticket.createdAt)}</span>
              </div>
            </div>
            
            {ticket.assignedTo && (
              <div className="mb-4">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  Assigned to: <span className="font-medium text-gray-900 dark:text-white">{ticket.assignedTo}</span>
                </span>
              </div>
            )}

            <div className="flex justify-between items-center">
              <div className="text-xs text-gray-500 dark:text-gray-500">
                Last updated: {ticket.updatedAt ? formatDateIST(ticket.updatedAt) : 'N/A'}
              </div>
              <div className="flex gap-2 items-center">
                {getAllowedStatusOptions(ticket).length > 0 && (
                  <Select
                    value={ticket.status}
                    onValueChange={(newStatus) => handleStatusUpdate(ticket.id, newStatus)}
                    disabled={updateStatusMutation.isPending}
                  >
                    <SelectTrigger className="w-40">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value={ticket.status}>{ticket.status.replace('-', ' ').toUpperCase()} (Current)</SelectItem>
                      {getAllowedStatusOptions(ticket).filter(status => status !== ticket.status).map(status => (
                        <SelectItem key={status} value={status}>
                          {status.replace('-', ' ').toUpperCase()}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                )}
                
                {canRequestApproval(ticket) && (
                  <Button 
                    variant="outline" 
                    size="sm" 
                    onClick={() => handleRequestApproval(ticket)}
                    disabled={requestApprovalMutation.isPending}
                    className="flex items-center gap-1 text-blue-600 border-blue-600 hover:bg-blue-50"
                  >
                    <Send className="h-3 w-3" />
                    Request Approval
                  </Button>
                )}
                
                {canApprove(ticket) && (
                  <Button 
                    variant="outline" 
                    size="sm" 
                    onClick={() => handleApprovalAction(ticket)}
                    className="flex items-center gap-1 text-orange-600 border-orange-600 hover:bg-orange-50"
                  >
                    <CheckCircle className="h-3 w-3" />
                    Review Approval
                  </Button>
                )}
                
                <Button 
                  variant="outline" 
                  size="sm" 
                  onClick={() => setSelectedTicket(ticket)}
                  className="flex items-center gap-1"
                >
                  <Eye className="h-3 w-3" />
                  View Details
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      ))}
      
      {tickets.length === 0 && (
        <Card>
          <CardContent className="text-center py-12">
            <AlertCircle className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">No tickets found</h3>
            <p className="text-gray-600 dark:text-gray-400">Create your first support ticket to get started.</p>
          </CardContent>
        </Card>
      )}

      {selectedTicket && (
        <TicketDetailsModal
          ticket={selectedTicket}
          isOpen={!!selectedTicket}
          onClose={() => setSelectedTicket(null)}
          currentUser={currentUser}
          getStatusColor={getStatusColor}
          getPriorityColor={getPriorityColor}
        />
      )}

      {/* Approval Dialog */}
      <Dialog open={showApprovalDialog} onOpenChange={setShowApprovalDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Review Ticket Approval</DialogTitle>
            <DialogDescription>
              {approvingTicket && `Review and approve or reject ticket #${approvingTicket.id}: ${approvingTicket.title}`}
            </DialogDescription>
          </DialogHeader>

          {approvingTicket && (
            <Form {...approvalForm}>
              <form onSubmit={approvalForm.handleSubmit(onApprovalSubmit)} className="space-y-4">
                <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
                  <h4 className="font-medium mb-2">Ticket Details</h4>
                  <div className="space-y-2 text-sm">
                    <div><strong>Priority:</strong> {approvingTicket.priority}</div>
                    <div><strong>Category:</strong> {approvingTicket.category}</div>
                    <div><strong>Requester:</strong> {getRequesterName(approvingTicket)}</div>
                    <div><strong>Description:</strong> {approvingTicket.description}</div>
                  </div>
                </div>

                <FormField
                  control={approvalForm.control}
                  name="action"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Decision</FormLabel>
                      <FormControl>
                        <div className="flex gap-4">
                          <label className="flex items-center gap-2">
                            <input
                              type="radio"
                              value="approve"
                              checked={field.value === 'approve'}
                              onChange={() => field.onChange('approve')}
                              className="text-green-600"
                            />
                            <CheckCircle className="h-4 w-4 text-green-600" />
                            Approve
                          </label>
                          <label className="flex items-center gap-2">
                            <input
                              type="radio"
                              value="reject"
                              checked={field.value === 'reject'}
                              onChange={() => field.onChange('reject')}
                              className="text-red-600"
                            />
                            <XCircle className="h-4 w-4 text-red-600" />
                            Reject
                          </label>
                        </div>
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={approvalForm.control}
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
                  <Button type="button" variant="outline" onClick={() => setShowApprovalDialog(false)}>
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
          )}
        </DialogContent>
      </Dialog>

      {/* Request Approval Dialog */}
      <Dialog open={showRequestApprovalDialog} onOpenChange={setShowRequestApprovalDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Request Ticket Approval</DialogTitle>
            <DialogDescription>
              {requestingApprovalTicket && `Select a manager to review and approve ticket #${requestingApprovalTicket.id}: ${requestingApprovalTicket.title}`}
            </DialogDescription>
          </DialogHeader>

          {requestingApprovalTicket && (
            <Form {...requestApprovalForm}>
              <form onSubmit={requestApprovalForm.handleSubmit(onRequestApprovalSubmit)} className="space-y-4">
                <div className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg">
                  <h4 className="font-medium mb-2">Ticket Details</h4>
                  <div className="space-y-2 text-sm">
                    <div><strong>Priority:</strong> {requestingApprovalTicket.priority}</div>
                    <div><strong>Category:</strong> {requestingApprovalTicket.category}</div>
                    <div><strong>Requester:</strong> {getRequesterName(requestingApprovalTicket)}</div>
                    <div><strong>Description:</strong> {requestingApprovalTicket.description}</div>
                  </div>
                </div>

                <FormField
                  control={requestApprovalForm.control}
                  name="managerId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Select Manager</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Choose a manager for approval" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          {users
                            .filter(user => ['manager', 'admin'].includes(user.role))
                            .map(manager => (
                              <SelectItem key={manager.id} value={manager.id.toString()}>
                                {manager.name} ({manager.role})
                              </SelectItem>
                            ))}
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={requestApprovalForm.control}
                  name="comments"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Comments (Optional)</FormLabel>
                      <FormControl>
                        <Textarea
                          placeholder="Add any additional information for the manager..."
                          {...field}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <div className="flex justify-end space-x-2 pt-4">
                  <Button type="button" variant="outline" onClick={() => setShowRequestApprovalDialog(false)}>
                    Cancel
                  </Button>
                  <Button 
                    type="submit" 
                    disabled={requestApprovalMutation.isPending}
                  >
                    {requestApprovalMutation.isPending ? "Sending..." : "Send for Approval"}
                  </Button>
                </div>
              </form>
            </Form>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}