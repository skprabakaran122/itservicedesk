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
import { Clock, User as UserIcon, Package, AlertCircle, MessageSquare, History, FileText, Download, Eye } from "lucide-react";
import { formatDateIST } from "@/lib/utils";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import { FileUpload } from "./file-upload";

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
  const [previewAttachment, setPreviewAttachment] = useState<any>(null);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: users = [] } = useQuery({
    queryKey: ["/api/users"],
    queryFn: () => fetch('/api/users').then(res => res.json())
  });

  const { data: groups = [] } = useQuery({
    queryKey: ["/api/groups"],
    queryFn: () => fetch('/api/groups').then(res => res.json())
  });

  const { data: history = [] } = useQuery<TicketHistory[]>({
    queryKey: ["/api/tickets", ticket.id, "history"],
    queryFn: async () => {
      const response = await apiRequest("GET", `/api/tickets/${ticket.id}/history`);
      return await response.json();
    },
    enabled: isOpen,
  });

  const { data: attachments = [] } = useQuery({
    queryKey: ["/api/attachments", { ticketId: ticket.id }],
    queryFn: async () => {
      const response = await apiRequest("GET", `/api/attachments?ticketId=${ticket.id}`);
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
      onClose(); // Close the modal after successful update
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

  const handleViewAttachment = async (attachment: any) => {
    try {
      const response = await fetch(`/api/attachments/${attachment.id}/download`, {
        method: 'GET',
        credentials: 'include',
      });
      
      if (!response.ok) {
        throw new Error('Failed to load file');
      }
      
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      
      setPreviewAttachment({
        ...attachment,
        previewUrl: url
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to load file preview",
        variant: "destructive",
      });
    }
  };

  const handleDownloadAttachment = async (attachmentId: number, fileName: string) => {
    try {
      const response = await fetch(`/api/attachments/${attachmentId}/download`, {
        method: 'GET',
        credentials: 'include', // Include session cookies
      });
      
      if (!response.ok) {
        throw new Error('Download failed');
      }
      
      // Get the blob data
      const blob = await response.blob();
      
      // Create download link
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = fileName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
      
      toast({
        title: "Download Complete",
        description: `${fileName} downloaded successfully`,
      });
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to download attachment",
        variant: "destructive",
      });
    }
  };

  const getRequesterName = () => {
    // Use stored requester name if available
    if (ticket.requesterName) return ticket.requesterName;
    
    // Fall back to user lookup if requesterId exists
    if (ticket.requesterId) {
      const user = users.find(u => u.id === ticket.requesterId);
      return user ? user.name : `User ${ticket.requesterId}`;
    }
    
    return 'Unknown User';
  };

  const getRequesterEmail = () => {
    // Use stored requester email if available
    if (ticket.requesterEmail) return ticket.requesterEmail;
    
    // Fall back to user lookup if requesterId exists
    if (ticket.requesterId) {
      const user = users.find(u => u.id === ticket.requesterId);
      return user ? user.email : `user${ticket.requesterId}@company.com`;
    }
    
    return 'No email provided';
  };

  const getUserName = (userId: number) => {
    const user = users.find(u => u.id === userId);
    return user ? user.name : `User ${userId}`;
  };

  const canUserReopenTicket = () => {
    return ticket.requesterId && currentUser?.id === ticket.requesterId && 
           ticket.status === 'resolved'; // Only resolved tickets can be reopened, not closed ones
  };

  const canUserModifyTicket = () => {
    // Closed tickets cannot be modified by anyone
    if (ticket.status === 'closed') {
      return false;
    }
    
    if (currentUser?.role === 'user') {
      return ticket.requesterId && currentUser?.id === ticket.requesterId;
    }
    return true; // agents, managers, admins can modify any non-closed ticket
  };

  const handleStatusUpdate = () => {
    if (newStatus === 'resolved' && !notes.trim()) {
      toast({
        title: "Error",
        description: "Notes are required when resolving a ticket",
        variant: "destructive",
      });
      return;
    }
    
    updateTicketMutation.mutate({ status: newStatus, notes: notes.trim() || undefined });
  };

  const handleAddComment = () => {
    if (!notes.trim()) return;
    addCommentMutation.mutate(notes.trim());
  };

  const getActionDescription = (action: string, field?: string) => {
    switch (action) {
      case 'created':
        return 'Ticket created';
      case 'updated':
        return `Updated ${field || 'ticket'}`;
      case 'status_changed':
        return 'Status changed';
      case 'comment':
        return 'Added comment';
      default:
        return action;
    }
  };

  return (
    <>
      <Dialog open={isOpen} onOpenChange={onClose}>
        <DialogContent className="max-w-6xl max-h-[90vh] overflow-auto">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-3">
              <div className={`px-2 py-1 rounded text-xs font-medium ${getStatusColor(ticket.status)}`}>
                {ticket.status.toUpperCase()}
              </div>
              <span>#{ticket.id} - {ticket.title}</span>
            </DialogTitle>
          </DialogHeader>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
            {/* Main Content */}
            <div className="lg:col-span-2 space-y-6">
              {/* Ticket Details */}
              <Card>
                <CardHeader>
                  <CardTitle className="flex items-center gap-2">
                    <AlertCircle className="h-4 w-4" />
                    Ticket Details
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="text-sm font-medium text-gray-500">Priority</label>
                      <div className={`inline-flex px-2 py-1 rounded text-xs font-medium ${getPriorityColor(ticket.priority)}`}>
                        {ticket.priority.toUpperCase()}
                      </div>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-500">Category</label>
                      <p className="text-sm">{ticket.category}</p>
                    </div>
                    {ticket.product && (
                      <div>
                        <label className="text-sm font-medium text-gray-500">Product</label>
                        <p className="text-sm">{ticket.product}</p>
                      </div>
                    )}
                    {ticket.subProduct && (
                      <div>
                        <label className="text-sm font-medium text-gray-500">Sub-Product</label>
                        <p className="text-sm">{ticket.subProduct}</p>
                      </div>
                    )}
                    <div>
                      <label className="text-sm font-medium text-gray-500">Requester Details</label>
                      <div className="flex items-start gap-2">
                        <UserIcon className="h-4 w-4 text-gray-400 mt-0.5" />
                        <div className="space-y-1">
                          <p className="text-sm font-medium text-gray-900 dark:text-white">{getRequesterName()}</p>
                          <p className="text-sm text-blue-600 dark:text-blue-400">{getRequesterEmail()}</p>
                          {ticket.requesterPhone && (
                            <p className="text-xs text-gray-500">Phone: {ticket.requesterPhone}</p>
                          )}
                          {ticket.requesterDepartment && (
                            <p className="text-xs text-gray-500">Department: {ticket.requesterDepartment}</p>
                          )}
                          {ticket.requesterBusinessUnit && (
                            <p className="text-xs text-gray-500">Business Unit: {ticket.requesterBusinessUnit}</p>
                          )}
                        </div>
                      </div>
                    </div>
                    <div>
                      <label className="text-sm font-medium text-gray-500">Created</label>
                      <div className="flex items-center gap-2">
                        <Clock className="h-4 w-4 text-gray-400" />
                        <p className="text-sm">{formatDateIST(ticket.createdAt)}</p>
                      </div>
                    </div>
                  </div>
                  
                  <Separator />
                  
                  <div>
                    <label className="text-sm font-medium text-gray-500">Description</label>
                    <p className="text-sm mt-1 whitespace-pre-wrap">{ticket.description}</p>
                  </div>
                </CardContent>
              </Card>

              {/* Status Management - Only show if user can modify ticket */}
              {canUserModifyTicket() && (
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <MessageSquare className="h-4 w-4" />
                      Update Ticket
                    </CardTitle>
                  </CardHeader>
                  <CardContent className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium mb-2">
                        Status
                      </label>
                      <Select value={newStatus} onValueChange={setNewStatus}>
                        <SelectTrigger>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {currentUser?.role === 'user' ? (
                            <>
                              {ticket.status === 'open' && (
                                <SelectItem value="closed">Closed</SelectItem>
                              )}
                              {canUserReopenTicket() && (
                                <SelectItem value="reopen">Reopen</SelectItem>
                              )}
                            </>
                          ) : (
                            <>
                              <SelectItem value="pending">Pending</SelectItem>
                              <SelectItem value="open">Open</SelectItem>
                              <SelectItem value="in_progress">In Progress</SelectItem>
                              <SelectItem value="resolved">Resolved</SelectItem>
                              <SelectItem value="closed">Closed</SelectItem>
                              {(ticket.requesterId === currentUser?.id && ticket.status === 'resolved') && (
                                <SelectItem value="reopen">Reopen</SelectItem>
                              )}
                            </>
                          )}
                        </SelectContent>
                      </Select>
                    </div>
                  
                  <div>
                    <label className="block text-sm font-medium mb-2">
                      Notes {newStatus === 'resolved' ? '(Required)' : '(Optional)'}
                      {newStatus === 'resolved' && <span className="text-red-500 ml-1">*</span>}
                    </label>
                    <Textarea
                      value={notes}
                      onChange={(e) => setNotes(e.target.value)}
                      placeholder={newStatus === 'resolved' ? "Describe how the issue was resolved..." : "Add notes about this update..."}
                      className={`min-h-[100px] ${newStatus === 'resolved' && !notes.trim() ? 'border-red-300 focus:border-red-500' : ''}`}
                    />
                    {newStatus === 'resolved' && !notes.trim() && (
                      <p className="text-sm text-red-500 mt-1">Notes are required when resolving a ticket</p>
                    )}
                  </div>

                  {/* File Upload Section */}
                  <div>
                    <label className="block text-sm font-medium mb-2">Add Attachments</label>
                    <FileUpload 
                      ticketId={ticket.id}
                      onAttachmentAdded={() => {
                        queryClient.invalidateQueries({ queryKey: ["/api/attachments", { ticketId: ticket.id }] });
                      }}
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
              )}
            </div>

            {/* History Sidebar */}
            <div className="space-y-6">
              {/* Attachments Section */}
              {attachments.length > 0 && (
                <Card>
                  <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                      <FileText className="h-4 w-4" />
                      Attachments ({attachments.length})
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      {attachments.map((attachment: any) => (
                        <div
                          key={attachment.id}
                          className="flex items-center justify-between p-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-800"
                        >
                          <div className="flex items-center gap-2 flex-1 min-w-0">
                            <Package className="h-4 w-4 text-gray-500" />
                            <div className="flex-1 min-w-0">
                              <p className="text-sm font-medium truncate">{attachment.originalName}</p>
                              <p className="text-xs text-gray-500">
                                {Math.round(attachment.fileSize / 1024)} KB • {attachment.mimeType}
                              </p>
                            </div>
                          </div>
                          <div className="flex gap-1 ml-2">
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleViewAttachment(attachment)}
                              className="h-8 w-8 p-0"
                            >
                              <Eye className="h-3 w-3" />
                            </Button>
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleDownloadAttachment(attachment.id, attachment.originalName)}
                              className="h-8 w-8 p-0"
                            >
                              <Download className="h-3 w-3" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}

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
                                  {entry.timestamp ? formatDateIST(entry.timestamp, 'MMM dd, HH:mm') : 'N/A'}
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

      {/* Attachment Preview Modal */}
      {previewAttachment && (
        <Dialog open={!!previewAttachment} onOpenChange={() => {
          // Clean up the blob URL if it exists
          if (previewAttachment.previewUrl) {
            window.URL.revokeObjectURL(previewAttachment.previewUrl);
          }
          setPreviewAttachment(null);
        }}>
          <DialogContent className="max-w-4xl max-h-[90vh] overflow-auto">
            <DialogHeader>
              <DialogTitle className="flex items-center gap-2">
                <FileText className="h-5 w-5" />
                {previewAttachment.originalName}
              </DialogTitle>
            </DialogHeader>
            <div className="mt-4">
              {previewAttachment.previewUrl ? (
                <div className="w-full">
                  {previewAttachment.mimeType === 'application/pdf' ? (
                    <iframe
                      src={previewAttachment.previewUrl}
                      className="w-full h-[600px] border border-gray-200 dark:border-gray-700 rounded-lg"
                      title={previewAttachment.originalName}
                    />
                  ) : previewAttachment.mimeType.startsWith('image/') ? (
                    <div className="w-full max-h-[600px] overflow-auto border border-gray-200 dark:border-gray-700 rounded-lg">
                      <img
                        src={previewAttachment.previewUrl}
                        alt={previewAttachment.originalName}
                        className="w-full h-auto"
                      />
                    </div>
                  ) : (
                    <div className="w-full h-[400px] border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-800 flex items-center justify-center">
                      <div className="text-center">
                        <Package className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                        <p className="text-xl font-medium text-gray-700 dark:text-gray-300 mb-2">Preview Not Available</p>
                        <p className="text-sm text-gray-500 mb-2">{previewAttachment.originalName}</p>
                        <p className="text-xs text-gray-400 mb-4">
                          {Math.round(previewAttachment.fileSize / 1024)} KB • {previewAttachment.mimeType}
                        </p>
                      </div>
                    </div>
                  )}
                  <div className="mt-4 flex justify-center">
                    <Button 
                      onClick={() => handleDownloadAttachment(previewAttachment.id, previewAttachment.originalName)}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      Download File
                    </Button>
                  </div>
                </div>
              ) : (
                <div className="w-full h-[400px] border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-800 flex items-center justify-center">
                  <div className="text-center">
                    <Package className="h-16 w-16 text-gray-400 mx-auto mb-4" />
                    <p className="text-xl font-medium text-gray-700 dark:text-gray-300 mb-2">Loading Preview...</p>
                  </div>
                </div>
              )}
            </div>
          </DialogContent>
        </Dialog>
      )}
    </>
  );
}