import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Ticket } from "@shared/schema";
import { Clock, User, Mail, AlertCircle } from "lucide-react";
import { format } from "date-fns";

interface TicketsListProps {
  tickets: Ticket[];
  getStatusColor: (status: string) => string;
  getPriorityColor: (priority: string) => string;
}

export function TicketsList({ tickets, getStatusColor, getPriorityColor }: TicketsListProps) {
  const sortedTickets = [...tickets].sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

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
                <User className="h-4 w-4" />
                <span>{ticket.requesterName}</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <Mail className="h-4 w-4" />
                <span>{ticket.requesterEmail}</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <AlertCircle className="h-4 w-4" />
                <span className="capitalize">{ticket.category}</span>
              </div>
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
                Last updated: {format(new Date(ticket.updatedAt), 'MMM dd, yyyy HH:mm')}
              </div>
              <div className="flex gap-2">
                <Button variant="outline" size="sm">
                  View Details
                </Button>
                <Button size="sm" className="bg-primary hover:bg-primary/90">
                  Update Status
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
    </div>
  );
}