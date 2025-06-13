import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Ticket, User } from "@shared/schema";
import { Clock, User as UserIcon, AlertCircle, Package, Eye } from "lucide-react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { formatDateIST } from "@/lib/utils";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import { TicketDetailsModal } from "./ticket-details-modal";

interface TicketsListProps {
  tickets: Ticket[];
  getStatusColor: (status: string) => string;
  getPriorityColor: (priority: string) => string;
  currentUser: any;
}

export function TicketsList({ tickets, getStatusColor, getPriorityColor, currentUser }: TicketsListProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [selectedTicket, setSelectedTicket] = useState<Ticket | null>(null);

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

  // Get allowed status options for a specific ticket
  const getAllowedStatusOptions = (ticket: Ticket) => {
    if (currentUser?.role === 'user') {
      // Users can only modify their own tickets
      if (!ticket.requesterId || ticket.requesterId !== currentUser?.id) {
        return []; // No options for tickets they don't own
      }
      
      // Users can only reopen resolved/closed tickets or close open/reopened tickets
      if (ticket.status === 'resolved' || ticket.status === 'closed') {
        return ['reopen'];
      }
      if (ticket.status === 'open' || ticket.status === 'reopen') {
        return ['closed'];
      }
      return [];
    }
    
    // Agents, managers, and admins have different options based on current status
    if (ticket.status === 'closed') {
      // Closed tickets cannot be moved to any other status - they are final
      return [];
    }
    
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
    </div>
  );
}