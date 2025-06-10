import { useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Ticket, User } from "@shared/schema";
import { Clock, User as UserIcon, AlertCircle, Package, Eye } from "lucide-react";
import { format } from "date-fns";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
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

  const sortedTickets = [...tickets].sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  const getRequesterName = (requesterId: number) => {
    const user = users.find(u => u.id === requesterId);
    return user ? user.name : `User ${requesterId}`;
  };

  const getRequesterEmail = (requesterId: number) => {
    const user = users.find(u => u.id === requesterId);
    return user ? user.email : `user${requesterId}@company.com`;
  };

  const handleStatusUpdate = (ticketId: number, newStatus: string) => {
    updateStatusMutation.mutate({ id: ticketId, status: newStatus });
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
                <span>{getRequesterName(ticket.requesterId)}</span>
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
                <span>{format(new Date(ticket.createdAt), 'MMM dd, yyyy HH:mm')}</span>
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
                Requester: {getRequesterEmail(ticket.requesterId)} • Last updated: {ticket.updatedAt ? format(new Date(ticket.updatedAt), 'MMM dd, yyyy HH:mm') : 'N/A'}
              </div>
              <div className="flex gap-2 items-center">
                <Select
                  value={ticket.status}
                  onValueChange={(newStatus) => handleStatusUpdate(ticket.id, newStatus)}
                  disabled={updateStatusMutation.isPending}
                >
                  <SelectTrigger className="w-32">
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