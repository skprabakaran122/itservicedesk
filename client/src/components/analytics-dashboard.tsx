import { useState, useEffect } from "react";
import React from "react";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { 
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
  LineChart, Line, PieChart, Pie, Cell, Area, AreaChart
} from 'recharts';
import { 
  TrendingUp, TrendingDown, Clock, Users, CheckCircle, AlertTriangle,
  BarChart3, Calendar, Download, Filter, RefreshCw
} from "lucide-react";
import { apiRequest } from "@/lib/queryClient";
import { formatDateIST } from "@/lib/utils";

interface AnalyticsData {
  overview: {
    totalTickets: number;
    openTickets: number;
    resolvedTickets: number;
    averageResolutionTime: number;
    slaCompliance: number;
    activeUsers: number;
  };
  ticketTrends: Array<{
    date: string;
    created: number;
    resolved: number;
    pending: number;
  }>;
  priorityDistribution: Array<{
    priority: string;
    count: number;
    percentage: number;
  }>;
  groupPerformance: Array<{
    groupName: string;
    ticketsAssigned: number;
    ticketsResolved: number;
    averageResolutionTime: number;
    slaCompliance: number;
  }>;
  slaMetrics: {
    responseTimeCompliance: number;
    resolutionTimeCompliance: number;
    overallCompliance: number;
    breachedTickets: number;
  };
  categoryBreakdown: Array<{
    category: string;
    count: number;
    percentage: number;
  }>;
  monthlyReport: {
    month: string;
    totalTickets: number;
    resolvedTickets: number;
    averageResolutionHours: number;
    customerSatisfaction: number;
    topIssues: Array<{
      category: string;
      count: number;
    }>;
  };
}

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

export function AnalyticsDashboard() {
  const [timeRange, setTimeRange] = useState("30");
  const [selectedGroup, setSelectedGroup] = useState("all");
  const [reportType, setReportType] = useState("monthly");
  const [customDateRange, setCustomDateRange] = useState({
    startDate: "",
    endDate: "",
    enabled: false
  });
  
  // Add state to track when user has manually applied custom range
  const [appliedCustomRange, setAppliedCustomRange] = useState<string | null>(null);

  const { data: analyticsData, isLoading, refetch } = useQuery<AnalyticsData>({
    queryKey: ["/api/analytics", timeRange, selectedGroup, appliedCustomRange],
    queryFn: async () => {
      let url = `/api/analytics?group=${selectedGroup}`;
      
      if (appliedCustomRange && customDateRange.enabled && customDateRange.startDate && customDateRange.endDate) {
        url += `&startDate=${customDateRange.startDate}&endDate=${customDateRange.endDate}`;
        console.log('Using custom date range:', customDateRange.startDate, 'to', customDateRange.endDate);
      } else {
        url += `&days=${timeRange}`;
        console.log('Using preset range:', timeRange, 'days');
      }
      
      console.log('Analytics URL:', url);
      const response = await apiRequest("GET", url);
      return response.json();
    },
    staleTime: 60000, // Consider data fresh for 1 minute
    cacheTime: 300000, // Keep in cache for 5 minutes
  });

  const { data: groups = [] } = useQuery({
    queryKey: ["/api/groups"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/groups");
      return response.json();
    },
  });

  const generateReport = async () => {
    try {
      let url = `/api/analytics/report?type=${reportType}`;
      
      if (customDateRange.enabled && customDateRange.startDate && customDateRange.endDate) {
        url += `&startDate=${customDateRange.startDate}&endDate=${customDateRange.endDate}`;
      } else {
        url += `&days=${timeRange}`;
      }
      
      const response = await apiRequest("GET", url);
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `${reportType}-report-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Failed to generate report:', error);
    }
  };

  const handleDateRangeToggle = (enabled: boolean) => {
    setCustomDateRange(prev => ({ ...prev, enabled }));
    if (!enabled) {
      // Reset to default time range when disabling custom dates
      setTimeRange("30");
      setTimeout(() => refetch(), 100);
    }
  };

  const handleDateChange = (field: 'startDate' | 'endDate', value: string) => {
    setCustomDateRange(prev => ({ ...prev, [field]: value }));
    console.log('Date changed:', field, value);
    // Don't auto-refresh when changing dates - wait for Apply button
  };

  const getDateRangeDisplay = () => {
    if (appliedCustomRange && customDateRange.startDate && customDateRange.endDate) {
      return `${customDateRange.startDate} to ${customDateRange.endDate}`;
    }
    
    switch (timeRange) {
      case "7": return "Last 7 days";
      case "30": return "Last 30 days";
      case "90": return "Last 90 days";
      case "365": return "Last year";
      default: return "Last 30 days";
    }
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <RefreshCw className="h-8 w-8 animate-spin mx-auto mb-2" />
          <p>Loading analytics...</p>
        </div>
      </div>
    );
  }

  if (!analyticsData) {
    return (
      <div className="text-center py-8">
        <p>No analytics data available</p>
      </div>
    );
  }

  const { overview, ticketTrends, priorityDistribution, groupPerformance, slaMetrics, categoryBreakdown, monthlyReport } = analyticsData;

  return (
    <div className="space-y-6">
      {/* Header Controls */}
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Analytics Dashboard</h2>
          <p className="text-muted-foreground">
            Comprehensive insights and performance metrics - {getDateRangeDisplay()}
          </p>
        </div>
        <div className="flex gap-2 flex-wrap">
          {!customDateRange.enabled && (
            <Select value={timeRange} onValueChange={setTimeRange}>
              <SelectTrigger className="w-32">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="7">Last 7 days</SelectItem>
                <SelectItem value="30">Last 30 days</SelectItem>
                <SelectItem value="90">Last 90 days</SelectItem>
                <SelectItem value="365">Last year</SelectItem>
              </SelectContent>
            </Select>
          )}
          
          <div className="relative">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setCustomDateRange(prev => ({ ...prev, enabled: !prev.enabled }))}
              className={appliedCustomRange ? "bg-green-50 border-green-300 text-green-700" : customDateRange.enabled ? "bg-blue-50 border-blue-300" : ""}
            >
              <Calendar className="h-4 w-4 mr-2" />
              {appliedCustomRange ? "Custom Applied" : "Custom Range"}
            </Button>
            
            {customDateRange.enabled && (
              <div className="absolute top-full left-0 mt-2 p-4 bg-white border rounded-lg shadow-lg z-50 w-80">
                <div className="space-y-4">
                  <div className="flex items-center space-x-2">
                    <input
                      type="checkbox"
                      id="enableCustom"
                      checked={customDateRange.enabled}
                      onChange={(e) => handleDateRangeToggle(e.target.checked)}
                      className="rounded"
                    />
                    <label htmlFor="enableCustom" className="text-sm font-medium">Use custom date range</label>
                  </div>
                  
                  <div className="space-y-2">
                    <label htmlFor="startDate" className="text-sm font-medium">Start Date</label>
                    <input
                      id="startDate"
                      type="date"
                      value={customDateRange.startDate}
                      onChange={(e) => handleDateChange('startDate', e.target.value)}
                      max={customDateRange.endDate || new Date().toISOString().split('T')[0]}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <label htmlFor="endDate" className="text-sm font-medium">End Date</label>
                    <input
                      id="endDate"
                      type="date"
                      value={customDateRange.endDate}
                      onChange={(e) => handleDateChange('endDate', e.target.value)}
                      min={customDateRange.startDate}
                      max={new Date().toISOString().split('T')[0]}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                  
                  <div className="flex gap-2">
                    <Button 
                      size="sm" 
                      onClick={() => {
                        if (customDateRange.startDate && customDateRange.endDate) {
                          console.log('Apply Range clicked - forcing refetch');
                          const rangeKey = `${customDateRange.startDate}-${customDateRange.endDate}`;
                          setAppliedCustomRange(rangeKey);
                          refetch();
                          // Close the dropdown after applying
                          setCustomDateRange(prev => ({ ...prev, enabled: false }));
                        }
                      }}
                      disabled={!customDateRange.startDate || !customDateRange.endDate}
                      className="bg-blue-600 hover:bg-blue-700 text-white"
                    >
                      Apply Range
                    </Button>
                    <Button 
                      size="sm" 
                      variant="outline"
                      onClick={() => {
                        setCustomDateRange({ startDate: "", endDate: "", enabled: false });
                        setAppliedCustomRange(null);
                        setTimeRange("30");
                        refetch();
                      }}
                    >
                      Reset
                    </Button>
                  </div>
                </div>
              </div>
            )}
          </div>
          
          <Select value={selectedGroup} onValueChange={setSelectedGroup}>
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Groups</SelectItem>
              {groups.map((group: any) => (
                <SelectItem key={group.id} value={group.name}>
                  {group.name}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          
          <Button onClick={() => refetch()} variant="outline" size="sm">
            <RefreshCw className="h-4 w-4 mr-2" />
            Refresh
          </Button>
        </div>
      </div>

      {/* Overview Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Tickets</CardTitle>
            <BarChart3 className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{overview.totalTickets}</div>
            <p className="text-xs text-muted-foreground">
              {overview.openTickets} open, {overview.resolvedTickets} resolved
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Resolution Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{overview.averageResolutionTime}h</div>
            <p className="text-xs text-muted-foreground">
              Target: &lt;24h for most tickets
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">SLA Compliance</CardTitle>
            <CheckCircle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{overview.slaCompliance}%</div>
            <Progress value={overview.slaCompliance} className="mt-2" />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Users</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{overview.activeUsers}</div>
            <p className="text-xs text-muted-foreground">
              Users with activity this period
            </p>
          </CardContent>
        </Card>
      </div>

      <Tabs defaultValue="trends" className="space-y-4">
        <TabsList>
          <TabsTrigger value="trends">Trends</TabsTrigger>
          <TabsTrigger value="performance">Group Performance</TabsTrigger>
          <TabsTrigger value="sla">SLA Metrics</TabsTrigger>
          <TabsTrigger value="reports">Reports</TabsTrigger>
        </TabsList>

        <TabsContent value="trends" className="space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {/* Ticket Trends Chart */}
            <Card>
              <CardHeader>
                <CardTitle>Ticket Trends</CardTitle>
                <CardDescription>Created vs Resolved tickets over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={ticketTrends}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Area type="monotone" dataKey="created" stackId="1" stroke="#8884d8" fill="#8884d8" />
                    <Area type="monotone" dataKey="resolved" stackId="2" stroke="#82ca9d" fill="#82ca9d" />
                  </AreaChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Priority Distribution */}
            <Card>
              <CardHeader>
                <CardTitle>Priority Distribution</CardTitle>
                <CardDescription>Breakdown of tickets by priority level</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <PieChart>
                    <Pie
                      data={priorityDistribution}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={({priority, percentage}) => `${priority} (${percentage}%)`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="count"
                    >
                      {priorityDistribution.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>

            {/* Category Breakdown */}
            <Card className="lg:col-span-2">
              <CardHeader>
                <CardTitle>Category Breakdown</CardTitle>
                <CardDescription>Most common issue categories</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <BarChart data={categoryBreakdown}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="category" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="count" fill="#8884d8" />
                  </BarChart>
                </ResponsiveContainer>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="performance" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Support Group Performance</CardTitle>
              <CardDescription>Detailed metrics for each support group</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {groupPerformance.map((group, index) => (
                  <div key={index} className="border rounded-lg p-4">
                    <div className="flex justify-between items-center mb-2">
                      <h4 className="font-semibold">{group.groupName}</h4>
                      <Badge variant={group.slaCompliance >= 90 ? "default" : "secondary"}>
                        {group.slaCompliance}% SLA
                      </Badge>
                    </div>
                    <div className="grid grid-cols-3 gap-4 text-sm">
                      <div>
                        <p className="text-muted-foreground">Assigned</p>
                        <p className="font-medium">{group.ticketsAssigned}</p>
                      </div>
                      <div>
                        <p className="text-muted-foreground">Resolved</p>
                        <p className="font-medium">{group.ticketsResolved}</p>
                      </div>
                      <div>
                        <p className="text-muted-foreground">Avg Resolution</p>
                        <p className="font-medium">{group.averageResolutionTime}h</p>
                      </div>
                    </div>
                    <Progress value={group.slaCompliance} className="mt-2" />
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="sla" className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <Card>
              <CardHeader>
                <CardTitle>SLA Compliance Overview</CardTitle>
                <CardDescription>Service level agreement performance</CardDescription>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>Response Time SLA</span>
                    <span className="font-medium">{slaMetrics.responseTimeCompliance}%</span>
                  </div>
                  <Progress value={slaMetrics.responseTimeCompliance} />
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>Resolution Time SLA</span>
                    <span className="font-medium">{slaMetrics.resolutionTimeCompliance}%</span>
                  </div>
                  <Progress value={slaMetrics.resolutionTimeCompliance} />
                </div>
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span>Overall Compliance</span>
                    <span className="font-medium">{slaMetrics.overallCompliance}%</span>
                  </div>
                  <Progress value={slaMetrics.overallCompliance} />
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>SLA Breaches</CardTitle>
                <CardDescription>Tickets that missed SLA targets</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="text-center">
                  <div className="text-3xl font-bold text-red-600 mb-2">
                    {slaMetrics.breachedTickets}
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Tickets breached SLA in the selected period
                  </p>
                  {slaMetrics.breachedTickets > 0 && (
                    <div className="mt-4 flex items-center justify-center text-orange-600">
                      <AlertTriangle className="h-4 w-4 mr-2" />
                      <span className="text-sm">Requires attention</span>
                    </div>
                  )}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="reports" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Monthly Report</CardTitle>
              <CardDescription>Comprehensive monthly performance summary</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center">
                  <div className="text-2xl font-bold">{monthlyReport.totalTickets}</div>
                  <p className="text-sm text-muted-foreground">Total Tickets</p>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold">{monthlyReport.resolvedTickets}</div>
                  <p className="text-sm text-muted-foreground">Resolved</p>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold">{monthlyReport.averageResolutionHours}h</div>
                  <p className="text-sm text-muted-foreground">Avg Resolution</p>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold">{monthlyReport.customerSatisfaction}%</div>
                  <p className="text-sm text-muted-foreground">Satisfaction</p>
                </div>
              </div>

              <div>
                <h4 className="font-semibold mb-2">Top Issues This Month</h4>
                <div className="space-y-2">
                  {monthlyReport.topIssues.map((issue, index) => (
                    <div key={index} className="flex justify-between items-center">
                      <span>{issue.category}</span>
                      <Badge variant="outline">{issue.count}</Badge>
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex gap-2 pt-4">
                <Select value={reportType} onValueChange={setReportType}>
                  <SelectTrigger className="w-40">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="monthly">Monthly Report</SelectItem>
                    <SelectItem value="quarterly">Quarterly Report</SelectItem>
                    <SelectItem value="annual">Annual Report</SelectItem>
                  </SelectContent>
                </Select>
                <Button onClick={generateReport}>
                  <Download className="h-4 w-4 mr-2" />
                  Generate Report
                </Button>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}