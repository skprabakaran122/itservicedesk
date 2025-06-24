import { useState, useEffect } from "react";
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

const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884D8'];

export function AnalyticsDashboard() {
  const [timeRange, setTimeRange] = useState("30");
  const [selectedGroup, setSelectedGroup] = useState("all");
  const [reportType, setReportType] = useState("monthly");
  const [customDateRange, setCustomDateRange] = useState(false);
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [appliedCustomRange, setAppliedCustomRange] = useState(false);

  console.log("Using preset range:", timeRange, "days");

  // Build analytics query URL
  const buildAnalyticsUrl = () => {
    let url = `/api/analytics?group=${selectedGroup}&days=${timeRange}`;
    if (appliedCustomRange && startDate && endDate) {
      url += `&startDate=${startDate}&endDate=${endDate}`;
    }
    console.log("Analytics URL:", url);
    return url;
  };

  // Fetch analytics data
  const { data: analyticsData, isLoading, refetch } = useQuery({
    queryKey: ['analytics', timeRange, selectedGroup, appliedCustomRange ? startDate : '', appliedCustomRange ? endDate : ''],
    queryFn: () => fetch(buildAnalyticsUrl()).then(res => res.json()),
    enabled: true
  });

  // Fetch groups for filter
  const { data: groups = [] } = useQuery({
    queryKey: ['groups'],
    queryFn: () => fetch('/api/groups').then(res => res.json())
  });

  // Generate reports
  const generateReport = async () => {
    try {
      const url = `/api/analytics/report?type=${reportType}&days=${timeRange}&group=${selectedGroup}${customDateRange && startDate && endDate ? `&startDate=${startDate}&endDate=${endDate}` : ''}`;
      const response = await fetch(url);
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.style.display = 'none';
      a.href = downloadUrl;
      a.download = `analytics-report-${reportType}-${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Error generating report:', error);
    }
  };

  const applyCustomDateRange = () => {
    if (startDate && endDate) {
      setAppliedCustomRange(true);
      refetch();
    }
  };

  const resetDateRange = () => {
    setCustomDateRange(false);
    setAppliedCustomRange(false);
    setStartDate("");
    setEndDate("");
    // Automatically refetch with preset range when resetting
    setTimeout(() => refetch(), 100);
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
      <div className="flex items-center justify-center h-64">
        <div className="text-center">
          <p className="text-gray-500">No analytics data available</p>
          <Button onClick={() => refetch()} className="mt-2">
            <RefreshCw className="h-4 w-4 mr-2" />
            Retry
          </Button>
        </div>
      </div>
    );
  }

  const { overview, ticketTrends, priorityDistribution, groupPerformance, slaMetrics, categoryBreakdown } = analyticsData;
  
  // Remove debug logs now that we've identified the issue

  return (
    <div className="space-y-6">
      {/* Header Controls */}
      <div className="flex justify-between items-center">
        <div>
          <h2 className="text-3xl font-bold tracking-tight">Analytics Dashboard</h2>
          <p className="text-muted-foreground">
            Comprehensive insights and performance metrics
          </p>
        </div>
        
        <div className="flex items-center gap-4">
          {/* Date Range Controls */}
          <div className="flex items-center gap-2">
            {!customDateRange ? (
              <>
                <Select value={timeRange} onValueChange={setTimeRange}>
                  <SelectTrigger className="w-40">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="7">Last 7 days</SelectItem>
                    <SelectItem value="30">Last 30 days</SelectItem>
                    <SelectItem value="90">Last 90 days</SelectItem>
                    <SelectItem value="365">Last year</SelectItem>
                  </SelectContent>
                </Select>
                <Button 
                  variant="outline" 
                  size="sm" 
                  onClick={() => setCustomDateRange(true)}
                >
                  <Calendar className="h-4 w-4 mr-1" />
                  Custom
                </Button>
              </>
            ) : (
              <div className="flex items-center gap-2">
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className="px-3 py-1 border rounded text-sm"
                  max={new Date().toISOString().split('T')[0]}
                />
                <span className="text-sm text-gray-500">to</span>
                <input
                  type="date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className="px-3 py-1 border rounded text-sm"
                  min={startDate}
                  max={new Date().toISOString().split('T')[0]}
                />
                <Button size="sm" onClick={applyCustomDateRange} disabled={!startDate || !endDate}>
                  Apply
                </Button>
                <Button size="sm" variant="outline" onClick={resetDateRange}>
                  Reset
                </Button>
              </div>
            )}
          </div>
          
          <Select value={selectedGroup} onValueChange={setSelectedGroup}>
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Groups</SelectItem>
              {groups && groups.map && groups.map((group: any) => (
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
            <div className="text-2xl font-bold">{overview?.totalTickets || 0}</div>
            <p className="text-xs text-muted-foreground">
              {overview?.openTickets || 0} open, {overview?.resolvedTickets || 0} resolved
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Resolution Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{overview?.avgResolutionTime || overview?.averageResolutionTime || 0}h</div>
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
            <div className="text-2xl font-bold">{overview?.slaCompliance || 0}%</div>
            <Progress value={parseInt(overview?.slaCompliance || '0')} className="mt-2" />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Users</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{overview?.activeUsers || 0}</div>
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
            {/* Ticket Trends */}
            <Card>
              <CardHeader>
                <CardTitle>Ticket Trends</CardTitle>
                <CardDescription>Created vs Resolved tickets over time</CardDescription>
              </CardHeader>
              <CardContent>
                <ResponsiveContainer width="100%" height={300}>
                  <AreaChart data={ticketTrends || []}>
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
                      data={priorityDistribution || []}
                      cx="50%"
                      cy="50%"
                      labelLine={false}
                      label={({priority, percentage}) => `${priority} (${percentage}%)`}
                      outerRadius={80}
                      fill="#8884d8"
                      dataKey="count"
                    >
                      {(priorityDistribution || []).map((entry, index) => (
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
                  <BarChart data={categoryBreakdown || []}>
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
                {(groupPerformance || []).map((group, index) => (
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
                {(!groupPerformance || groupPerformance.length === 0) && (
                  <div className="text-center py-8 text-muted-foreground">
                    No group performance data available for the selected period.
                  </div>
                )}
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
                    <span>Compliance Rate</span>
                    <span className="font-medium">{slaMetrics?.compliance || 0}%</span>
                  </div>
                  <Progress value={parseInt(slaMetrics?.compliance || '0')} />
                </div>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-muted-foreground">Total Tickets</p>
                    <p className="text-lg font-semibold">{slaMetrics?.totalTickets || 0}</p>
                  </div>
                  <div>
                    <p className="text-muted-foreground">Compliant</p>
                    <p className="text-lg font-semibold text-green-600">{slaMetrics?.compliantTickets || 0}</p>
                  </div>
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
                    {slaMetrics?.breachedTickets || 0}
                  </div>
                  <p className="text-sm text-muted-foreground">
                    Tickets breached SLA in the selected period
                  </p>
                  <div className="mt-4 text-sm">
                    <p className="text-muted-foreground">
                      Avg Resolution Time: {slaMetrics?.avgResolutionTime || 0}h
                    </p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="reports" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Generate Reports</CardTitle>
              <CardDescription>Download detailed analytics reports for stakeholders</CardDescription>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <h4 className="font-medium mb-2">Report Summary</h4>
                    <div className="text-sm space-y-1">
                      <p><span className="font-medium">Period:</span> {customDateRange && startDate && endDate ? `${startDate} to ${endDate}` : `Last ${timeRange} days`}</p>
                      <p><span className="font-medium">Group:</span> {selectedGroup === 'all' ? 'All Groups' : selectedGroup}</p>
                      <p><span className="font-medium">Total Tickets:</span> {overview?.totalTickets || 0}</p>
                      <p><span className="font-medium">Resolution Rate:</span> {overview?.totalTickets ? Math.round((parseInt(overview.resolvedTickets || '0') / parseInt(overview.totalTickets || '1')) * 100) : 0}%</p>
                    </div>
                  </div>
                  <div>
                    <h4 className="font-medium mb-2">Export Options</h4>
                    <div className="flex gap-2">
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
                        Generate CSV
                      </Button>
                    </div>
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  );
}