import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Ticket, Change } from "@shared/schema";
import { TicketForm } from "../components/ticket-form";
import { ChangeForm } from "../components/change-form";
import { TicketsList } from "../components/tickets-list";
import { ChangesList } from "../components/changes-list";
import { AdminConsole } from "../components/admin-console";
import { SLADashboard } from "../components/sla-dashboard";
import { UserManagement } from "../components/user-management";
import ITChatbot from "../components/it-chatbot";
import { Plus, Ticket as TicketIcon, Settings, BarChart3, Users, Target } from "lucide-react";
import calpionLogo from "@assets/image_1749619432130.png";

interface DashboardProps {
  currentUser: any;
  onLogout: () => void;
  initialTab?: string;
}

export default function Dashboard({ currentUser, onLogout, initialTab }: DashboardProps) {
  const [showTicketForm, setShowTicketForm] = useState(false);
  const [showChangeForm, setShowChangeForm] = useState(false);

  const { data: tickets = [], isLoading: ticketsLoading } = useQuery<Ticket[]>({
    queryKey: ["/api/tickets"],
  });

  const { data: changes = [], isLoading: changesLoading } = useQuery<Change[]>({
    queryKey: ["/api/changes"],
  });

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case "open":
        return "bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200";
      case "in-progress":
        return "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200";
      case "resolved":
        return "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200";
      case "closed":
        return "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200";
      case "reopen":
        return "bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200";
      case "pending":
        return "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200";
      case "approved":
        return "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200";
      case "rejected":
        return "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200";
      case "testing":
        return "bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200";
      case "completed":
        return "bg-emerald-100 text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200";
      case "failed":
        return "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200";
      case "rollback":
        return "bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200";
      default:
        return "bg-gray-100 text-gray-800 dark:bg-gray-800 dark:text-gray-200";
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority.toLowerCase()) {
      case "critical":
        return "bg-red-500 text-white";
      case "high":
        return "bg-orange-500 text-white";
      case "medium":
        return "bg-yellow-500 text-white";
      case "low":
        return "bg-green-500 text-white";
      default:
        return "bg-gray-500 text-white";
    }
  };

  const ticketStats = {
    total: tickets.length,
    open: tickets.filter(t => t.status === "open").length,
    inProgress: tickets.filter(t => t.status === "in-progress").length,
    resolved: tickets.filter(t => t.status === "resolved").length,
  };

  const changeStats = {
    total: changes.length,
    pending: changes.filter(c => c.status === "pending").length,
    approved: changes.filter(c => c.status === "approved").length,
    inProgress: changes.filter(c => c.status === "in-progress").length,
    testing: changes.filter(c => c.status === "testing").length,
    completed: changes.filter(c => c.status === "completed").length,
    failed: changes.filter(c => c.status === "failed").length,
  };

  if (ticketsLoading || changesLoading) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="mb-8">
          <Skeleton className="h-8 w-48 mb-2" />
          <Skeleton className="h-4 w-64" />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          {[1, 2, 3, 4].map((i) => (
            <Card key={i}>
              <CardHeader>
                <Skeleton className="h-4 w-24" />
              </CardHeader>
              <CardContent>
                <Skeleton className="h-8 w-16" />
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <div className="flex items-center">
          <img 
            src={calpionLogo} 
            alt="Calpion Logo" 
            className="h-12 w-auto object-contain mr-4"
          />
          <div>
            <h1 className="text-3xl font-bold text-gray-900 dark:text-white">IT Service Desk</h1>
            <p className="text-gray-600 dark:text-gray-400">Manage tickets and change requests</p>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <div className="flex gap-2">
            <Button onClick={() => setShowTicketForm(true)} className="bg-primary hover:bg-primary/90">
              <Plus className="mr-2 h-4 w-4" />
              New Ticket
            </Button>
            {(currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
              <Button onClick={() => setShowChangeForm(true)} variant="outline">
                <Plus className="mr-2 h-4 w-4" />
                New Change
              </Button>
            )}
          </div>
          <div className="flex items-center gap-3 border-l pl-4">
            <div className="text-right">
              <div className="text-sm font-medium text-gray-900 dark:text-white">{currentUser?.name}</div>
              <div className="text-xs text-gray-500 capitalize">{currentUser?.role}</div>
            </div>
            <Button onClick={onLogout} variant="outline" size="sm">
              Logout
            </Button>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Tickets</CardTitle>
            <TicketIcon className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{ticketStats.total}</div>
            <p className="text-xs text-muted-foreground">
              {ticketStats.open} open, {ticketStats.inProgress} in progress
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Open Tickets</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">{ticketStats.open}</div>
            <p className="text-xs text-muted-foreground">
              Awaiting assignment
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Pending Changes</CardTitle>
            <Settings className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">{changeStats.pending}</div>
            <p className="text-xs text-muted-foreground">
              Awaiting approval
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Resolved Today</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{ticketStats.resolved}</div>
            <p className="text-xs text-muted-foreground">
              Great work!
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Change Workflow Status Panel - Only for agents, managers, and admins */}
      {(currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
        <Card className="mb-8">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="h-5 w-5" />
            Change Management Workflow
          </CardTitle>
          <CardDescription>
            Track changes through the complete ITIL workflow process
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-4">
            <div className="text-center p-3 bg-yellow-50 dark:bg-yellow-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-yellow-600">{changeStats.pending}</div>
              <div className="text-sm text-yellow-700 dark:text-yellow-300">Pending</div>
              <div className="text-xs text-gray-500">Awaiting Approval</div>
            </div>
            <div className="text-center p-3 bg-green-50 dark:bg-green-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-green-600">{changeStats.approved}</div>
              <div className="text-sm text-green-700 dark:text-green-300">Approved</div>
              <div className="text-xs text-gray-500">Ready for Implementation</div>
            </div>
            <div className="text-center p-3 bg-blue-50 dark:bg-blue-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-blue-600">{changeStats.inProgress}</div>
              <div className="text-sm text-blue-700 dark:text-blue-300">In Progress</div>
              <div className="text-xs text-gray-500">Being Implemented</div>
            </div>
            <div className="text-center p-3 bg-orange-50 dark:bg-orange-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-orange-600">{changeStats.testing}</div>
              <div className="text-sm text-orange-700 dark:text-orange-300">Testing</div>
              <div className="text-xs text-gray-500">Under Validation</div>
            </div>
            <div className="text-center p-3 bg-emerald-50 dark:bg-emerald-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-emerald-600">{changeStats.completed}</div>
              <div className="text-sm text-emerald-700 dark:text-emerald-300">Completed</div>
              <div className="text-xs text-gray-500">Successfully Deployed</div>
            </div>
            <div className="text-center p-3 bg-red-50 dark:bg-red-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-red-600">{changeStats.failed}</div>
              <div className="text-sm text-red-700 dark:text-red-300">Failed</div>
              <div className="text-xs text-gray-500">Needs Attention</div>
            </div>
            <div className="text-center p-3 bg-amber-50 dark:bg-amber-900/20 rounded-lg border">
              <div className="text-2xl font-bold text-amber-600">{changes.filter(c => c.status === "rollback").length}</div>
              <div className="text-sm text-amber-700 dark:text-amber-300">Rollback</div>
              <div className="text-xs text-gray-500">Being Reverted</div>
            </div>
          </div>
        </CardContent>
        </Card>
      )}

      {/* Main Content Tabs */}
      <Tabs defaultValue={initialTab || "tickets"} className="space-y-4">
        <TabsList>
          <TabsTrigger value="tickets">Support Tickets</TabsTrigger>
          {(currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
            <TabsTrigger value="changes">Change Requests</TabsTrigger>
          )}
          {(currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
            <TabsTrigger value="sla">
              <Target className="h-4 w-4 mr-2" />
              SLA Metrics
            </TabsTrigger>
          )}
          {currentUser?.role === 'admin' && (
            <TabsTrigger value="admin">
              <Settings className="h-4 w-4 mr-2" />
              Admin Console
            </TabsTrigger>
          )}
        </TabsList>

        <TabsContent value="tickets">
          <TicketsList 
            tickets={tickets} 
            getStatusColor={getStatusColor}
            getPriorityColor={getPriorityColor}
            currentUser={currentUser}
          />
        </TabsContent>

        {(currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
          <TabsContent value="changes">
            <ChangesList 
              changes={changes}
              getStatusColor={getStatusColor}
              getPriorityColor={getPriorityColor}
              currentUser={currentUser}
            />
          </TabsContent>
        )}

        {(currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
          <TabsContent value="sla">
            <SLADashboard />
          </TabsContent>
        )}

        {currentUser?.role === 'admin' && (
          <TabsContent value="admin">
            <AdminConsole currentUser={currentUser} />
          </TabsContent>
        )}
      </Tabs>

      {/* Forms */}
      {showTicketForm && (
        <TicketForm onClose={() => setShowTicketForm(false)} />
      )}

      {showChangeForm && (currentUser?.role === 'agent' || currentUser?.role === 'manager' || currentUser?.role === 'admin') && (
        <ChangeForm onClose={() => setShowChangeForm(false)} currentUser={currentUser} />
      )}

      {/* IT Support Chatbot */}
      <ITChatbot />
    </div>
  );
}