import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Change } from "@shared/schema";
import { Clock, User, AlertTriangle, Calendar, Eye, Package, Zap, CheckCircle, AlertCircle } from "lucide-react";
import { formatDateIST } from "@/lib/utils";
import { ChangeDetailsModal } from "./change-details-modal";
import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";

interface ChangesListProps {
  changes: Change[];
  getStatusColor: (status: string) => string;
  getPriorityColor: (priority: string) => string;
  currentUser: any;
}

export function ChangesList({ changes, getStatusColor, getPriorityColor, currentUser }: ChangesListProps) {
  const [selectedChange, setSelectedChange] = useState<Change | null>(null);
  const { toast } = useToast();
  const queryClient = useQueryClient();
  
  // ✅ NEW: Overdue detection function
  const isChangeOverdue = (change: Change): boolean => {
    return change.isOverdue === 'true' || change.isOverdue === true || change.status === 'overdue';
  };

  // ✅ NEW: Get overdue classes for styling
  const getOverdueClasses = (change: Change): string => {
    if (isChangeOverdue(change)) {
      return "border-l-4 border-l-red-500 bg-gradient-to-r from-red-50 to-red-100 dark:from-red-950 dark:to-red-900";
    }
    return "";
  };

  // ✅ NEW: Overdue badge component
  const OverdueBadge = ({ change }: { change: Change }) => {
    if (!isChangeOverdue(change)) return null;
    
    return (
      <Badge className="bg-red-600 text-white animate-pulse hover:bg-red-700">
        <AlertTriangle className="h-3 w-3 mr-1" />
        OVERDUE
      </Badge>
    );
  };

  const getChangeTypeColor = (changeType: string) => {
    switch (changeType) {
      case 'standard': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      case 'emergency': return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300';
      default: return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300';
    }
  };

  const getChangeTypeIcon = (changeType: string) => {
    switch (changeType) {
      case 'standard': return <CheckCircle className="h-4 w-4" />;
      case 'emergency': return <Zap className="h-4 w-4" />;
      default: return <AlertCircle className="h-4 w-4" />;
    }
  };

  const sortedChanges = [...changes].sort((a, b) => 
    new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  const updateStatusMutation = useMutation({
    mutationFn: async ({ id, status }: { id: number; status: string }) => {
      return await apiRequest("PATCH", `/api/changes/${id}`, { 
        status, 
        userId: currentUser?.id || 1,
        notes: `Status changed to ${status}`
      });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/changes"] });
      toast({
        title: "Change Updated",
        description: "Change status has been updated successfully.",
      });
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to update change status.",
        variant: "destructive",
      });
    },
  });

  const handleStatusUpdate = (id: number, status: string) => {
    const change = sortedChanges.find(c => c.id === id);
    
    // Check if trying to move to implementation before start time
    if (status === 'in-progress' && change?.startDate) {
      const now = new Date();
      const startTime = new Date(change.startDate);
      
      if (now < startTime) {
        toast({
          title: "Cannot Start Implementation",
          description: `Implementation can only begin after the scheduled start time: ${formatDateIST(change.startDate)}`,
          variant: "destructive",
        });
        return;
      }
    }
    
    updateStatusMutation.mutate({ id, status });
  };

  const getRiskColor = (risk: string) => {
    switch (risk.toLowerCase()) {
      case "high":
        return "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200";
      case "medium":
        return "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200";
      case "low":
        return "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200";
      default:
        return "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200";
    }
  };

  return (
    <div className="space-y-4">
      {sortedChanges.map((change) => (
        <Card 
          key={change.id} 
          className={`hover:shadow-md transition-all duration-200 ${getOverdueClasses(change)}`}
        >
          <CardHeader>
            <div className="flex items-start justify-between">
              <div className="flex-1">
                <CardTitle className={`text-lg font-semibold ${
                  isChangeOverdue(change) 
                    ? 'text-red-900 dark:text-red-100' 
                    : 'text-gray-900 dark:text-white'
                }`}>
                  {/* ✅ NEW: Overdue icon in title */}
                  {isChangeOverdue(change) && (
                    <AlertTriangle className="inline h-5 w-5 mr-2 text-red-600" />
                  )}
                  CHG-{change.id} - {change.title}
                </CardTitle>
                <CardDescription className="mt-1">
                  {change.description.length > 150 
                    ? `${change.description.substring(0, 150)}...` 
                    : change.description
                  }
                </CardDescription>
              </div>
              <div className="flex flex-col items-end gap-2 ml-4">
                {/* ✅ NEW: Overdue badge at the top */}
                <OverdueBadge change={change} />
                
                <Badge className={getChangeTypeColor(change.changeType || 'normal')}>
                  <div className="flex items-center gap-1">
                    {getChangeTypeIcon(change.changeType || 'normal')}
                    {(change.changeType || 'normal').toUpperCase()}
                  </div>
                </Badge>
                <Badge className={getPriorityColor(change.priority)}>
                  {change.priority.toUpperCase()}
                </Badge>
                <Badge 
                  variant="secondary" 
                  className={`${getStatusColor(change.status)} ${
                    isChangeOverdue(change) ? 'bg-red-600 text-white' : ''
                  }`}
                >
                  {change.status.replace('-', ' ').toUpperCase()}
                </Badge>
                <Badge variant="outline" className={getRiskColor(change.riskLevel)}>
                  {change.riskLevel.toUpperCase()} RISK
                </Badge>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {/* ✅ NEW: Overdue alert banner */}
            {isChangeOverdue(change) && (
              <div className="mb-4 p-3 bg-red-100 dark:bg-red-900 border border-red-300 dark:border-red-700 rounded-lg">
                <div className="flex items-center gap-2">
                  <AlertTriangle className="h-5 w-5 text-red-600 dark:text-red-400" />
                  <div>
                    <h4 className="font-semibold text-red-800 dark:text-red-200">⚠️ OVERDUE ALERT</h4>
                    <p className="text-sm text-red-700 dark:text-red-300">
                      This change has passed its scheduled end time and requires immediate attention.
                      {change.endDate && ` End time was: ${formatDateIST(change.endDate, 'MMM dd, yyyy HH:mm')}`}
                    </p>
                  </div>
                </div>
              </div>
            )}

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-4">
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <User className="h-4 w-4" />
                <span>Requested by: {change.requestedBy}</span>
              </div>
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <AlertTriangle className="h-4 w-4" />
                <span className="capitalize">{change.category}</span>
              </div>
              {change.product && (
                <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <Package className="h-4 w-4" />
                  <span>{change.product}</span>
                </div>
              )}
              {change.assignedGroup && (
                <div className="flex items-center gap-2 text-sm text-blue-600 dark:text-blue-400">
                  <User className="h-4 w-4" />
                  <span>Group: {change.assignedGroup}</span>
                </div>
              )}
              <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                <Clock className="h-4 w-4" />
                <span>{formatDateIST(change.createdAt, 'MMM dd, yyyy HH:mm')}</span>
              </div>
              {change.plannedDate && (
                <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <Calendar className="h-4 w-4" />
                  <span>Planned: {formatDateIST(change.plannedDate, 'MMM dd, yyyy')}</span>
                </div>
              )}
              {change.startDate && (
                <div className="flex items-center gap-2 text-sm text-green-600">
                  <Calendar className="h-4 w-4" />
                  <span>Start: {formatDateIST(change.startDate, 'MMM dd, yyyy HH:mm')}</span>
                </div>
              )}
              {change.endDate && (
                <div className={`flex items-center gap-2 text-sm ${
                  isChangeOverdue(change) ? 'text-red-700 dark:text-red-400 font-bold' : 'text-red-600'
                }`}>
                  <Calendar className="h-4 w-4" />
                  <span>End: {formatDateIST(change.endDate, 'MMM dd, yyyy HH:mm')}</span>
                  {/* ✅ NEW: Overdue indicator for end date */}
                  {isChangeOverdue(change) && (
                    <span className="ml-1 text-xs bg-red-600 text-white px-2 py-1 rounded">
                      OVERDUE
                    </span>
                  )}
                </div>
              )}
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
              {change.approvedBy && (
                <div className="text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Approved by: </span>
                  <span className="font-medium text-gray-900 dark:text-white">{change.approvedBy}</span>
                </div>
              )}
              {change.implementedBy && (
                <div className="text-sm">
                  <span className="text-gray-600 dark:text-gray-400">Implemented by: </span>
                  <span className="font-medium text-gray-900 dark:text-white">{change.implementedBy}</span>
                </div>
              )}
            </div>

            {change.rollbackPlan && (
              <div className="mb-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
                <h4 className="text-sm font-medium text-gray-900 dark:text-white mb-1">Rollback Plan:</h4>
                <p className="text-sm text-gray-600 dark:text-gray-400">{change.rollbackPlan}</p>
              </div>
            )}

            <div className="flex justify-between items-center">
              <div className="text-xs text-gray-500 dark:text-gray-500">
                Last updated: {change.updatedAt ? formatDateIST(change.updatedAt, 'MMM dd, yyyy HH:mm') : 'N/A'}
                {change.completedDate && (
                  <span className="ml-2">
                    • Completed: {change.completedDate ? formatDateIST(change.completedDate, 'MMM dd, yyyy') : 'N/A'}
                  </span>
                )}
              </div>
              <div className="flex gap-2">
                <Button 
                  variant="outline" 
                  size="sm" 
                  onClick={() => setSelectedChange(change)}
                  className="flex items-center gap-1"
                >
                  <Eye className="h-3 w-3" />
                  View Details
                </Button>
                {change.status === 'pending' && (currentUser?.role === 'admin' || currentUser?.role === 'manager') && (
                  <div className="flex gap-2">
                    <Button 
                      size="sm" 
                      className="bg-blue-600 hover:bg-blue-700 text-white"
                      onClick={() => setSelectedChange(change)}
                    >
                      Review Approvals
                    </Button>
                    <Button 
                      size="sm" 
                      variant="destructive"
                      onClick={() => handleStatusUpdate(change.id, 'rejected')}
                    >
                      Reject
                    </Button>
                  </div>
                )}
                {change.status === 'rejected' && (currentUser?.role === 'agent' || currentUser?.role === 'admin') && (
                  <Button 
                    size="sm" 
                    className="bg-orange-600 hover:bg-orange-700 text-white"
                    onClick={() => {
                      setSelectedChange(change);
                      // We'll handle the editing state in the modal
                    }}
                  >
                    Revise & Resubmit
                  </Button>
                )}
                {change.status === 'approved' && (
                  (() => {
                    const canStart = !change.startDate || new Date() >= new Date(change.startDate);
                    return (
                      <Button 
                        size="sm" 
                        className={canStart 
                          ? "bg-blue-600 hover:bg-blue-700 text-white" 
                          : "bg-gray-400 cursor-not-allowed text-gray-200"
                        }
                        onClick={() => canStart && handleStatusUpdate(change.id, 'in-progress')}
                        disabled={!canStart}
                        title={!canStart && change.startDate ? `Implementation starts at: ${formatDateIST(change.startDate.toString())}` : "Start Implementation"}
                      >
                        {canStart ? 'Start Implementation' : change.startDate ? `Starts ${formatDateIST(change.startDate.toString(), 'MMM dd, HH:mm')}` : 'Start Implementation'}
                      </Button>
                    );
                  })()
                )}
                {change.status === 'in-progress' && (
                  <Button 
                    size="sm" 
                    className="bg-purple-600 hover:bg-purple-700 text-white"
                    onClick={() => handleStatusUpdate(change.id, 'testing')}
                  >
                    Move to Testing
                  </Button>
                )}
                {change.status === 'testing' && (
                  <div className="flex gap-1">
                    <Button 
                      size="sm" 
                      className="bg-green-600 hover:bg-green-700 text-white"
                      onClick={() => handleStatusUpdate(change.id, 'completed')}
                    >
                      Complete
                    </Button>
                    <Button 
                      size="sm" 
                      variant="outline"
                      className="border-red-600 text-red-600 hover:bg-red-50"
                      onClick={() => handleStatusUpdate(change.id, 'failed')}
                    >
                      Failed
                    </Button>
                  </div>
                )}
                {change.status === 'failed' && (
                  <Button 
                    size="sm" 
                    className="bg-orange-600 hover:bg-orange-700 text-white"
                    onClick={() => handleStatusUpdate(change.id, 'rollback')}
                  >
                    Rollback
                  </Button>
                )}
              </div>
            </div>
          </CardContent>
        </Card>
      ))}
      
      {changes.length === 0 && (
        <Card>
          <CardContent className="text-center py-12">
            <AlertTriangle className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">No change requests found</h3>
            <p className="text-gray-600 dark:text-gray-400">Create your first change request to get started.</p>
          </CardContent>
        </Card>
      )}

      {selectedChange && (
        <ChangeDetailsModal
          change={selectedChange}
          isOpen={!!selectedChange}
          onClose={() => setSelectedChange(null)}
          currentUser={currentUser}
          getStatusColor={getStatusColor}
          getPriorityColor={getPriorityColor}
        />
      )}
    </div>
  );
}