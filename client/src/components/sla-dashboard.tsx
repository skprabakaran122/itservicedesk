import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Clock, Target, TrendingUp, AlertTriangle, RefreshCw } from "lucide-react";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";

interface SLAMetrics {
  totalTickets: number;
  responseMetrics: {
    met: number;
    breached: number;
    pending: number;
    percentage: number;
  };
  resolutionMetrics: {
    met: number;
    breached: number;
    pending: number;
    percentage: number;
  };
  averageResponseTime: number;
  averageResolutionTime: number;
  metricsByProduct: Record<string, {
    total: number;
    responseMet: number;
    resolutionMet: number;
    responsePercentage: number;
    resolutionPercentage: number;
    averageResponseTime: number;
    averageResolutionTime: number;
  }>;
}

export function SLADashboard() {
  const queryClient = useQueryClient();
  const { toast } = useToast();
  
  const { data: slaMetrics, isLoading } = useQuery<SLAMetrics>({
    queryKey: ["/api/sla/metrics"],
    refetchInterval: 30000, // Refresh every 30 seconds
  });

  const { data: currentUser } = useQuery({
    queryKey: ["/api/auth/me"],
  });

  const refreshSLAMutation = useMutation({
    mutationFn: async () => {
      const response = await apiRequest("POST", "/api/sla/refresh");
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "SLA metrics refreshed successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/sla/metrics"] });
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to refresh SLA metrics",
        variant: "destructive",
      });
    },
  });

  if (isLoading) {
    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <Card key={i}>
              <CardContent className="p-6">
                <div className="animate-pulse">
                  <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                  <div className="h-8 bg-gray-200 rounded w-1/2"></div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  if (!slaMetrics) return null;

  const formatTime = (minutes: number) => {
    if (minutes < 60) return `${Math.round(minutes)}m`;
    const hours = Math.floor(minutes / 60);
    const mins = Math.round(minutes % 60);
    return `${hours}h ${mins}m`;
  };

  const getPerformanceColor = (percentage: number) => {
    if (percentage >= 95) return "text-green-600";
    if (percentage >= 85) return "text-yellow-600";
    return "text-red-600";
  };

  const getPerformanceBadge = (percentage: number) => {
    if (percentage >= 95) return "bg-green-100 text-green-800";
    if (percentage >= 85) return "bg-yellow-100 text-yellow-800";
    return "bg-red-100 text-red-800";
  };



  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold">SLA Performance Dashboard</h2>
        <div className="flex items-center gap-3">
          {(currentUser as any)?.user && ((currentUser as any).user.role === 'admin' || (currentUser as any).user.role === 'manager') && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => refreshSLAMutation.mutate()}
              disabled={refreshSLAMutation.isPending}
              className="flex items-center gap-2"
            >
              <RefreshCw className={`h-4 w-4 ${refreshSLAMutation.isPending ? 'animate-spin' : ''}`} />
              {refreshSLAMutation.isPending ? 'Refreshing...' : 'Refresh Metrics'}
            </Button>
          )}
          <Badge variant="outline" className="text-sm">
            Total Tickets: {slaMetrics.totalTickets}
          </Badge>
        </div>
      </div>

      {/* Overall Performance Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Response SLA</CardTitle>
            <Target className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              <span className={getPerformanceColor(slaMetrics.responseMetrics.percentage)}>
                {slaMetrics.responseMetrics.percentage.toFixed(1)}%
              </span>
            </div>
            <Progress value={slaMetrics.responseMetrics.percentage} className="mt-2" />
            <p className="text-xs text-muted-foreground mt-2">
              {slaMetrics.responseMetrics.met} met, {slaMetrics.responseMetrics.breached} breached
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Resolution SLA</CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              <span className={getPerformanceColor(slaMetrics.resolutionMetrics.percentage)}>
                {slaMetrics.resolutionMetrics.percentage.toFixed(1)}%
              </span>
            </div>
            <Progress value={slaMetrics.resolutionMetrics.percentage} className="mt-2" />
            <p className="text-xs text-muted-foreground mt-2">
              {slaMetrics.resolutionMetrics.met} met, {slaMetrics.resolutionMetrics.breached} breached
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Response Time</CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {formatTime(slaMetrics.averageResponseTime)}
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              Time to first response
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Avg Resolution Time</CardTitle>
            <AlertTriangle className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">
              {formatTime(slaMetrics.averageResolutionTime)}
            </div>
            <p className="text-xs text-muted-foreground mt-2">
              Time to resolution
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Priority Breakdown */}
      <Card>
        <CardHeader>
          <CardTitle>SLA Performance by Product</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {Object.entries(slaMetrics.metricsByProduct).map(([product, metrics]) => {
              if (!metrics || metrics.total === 0) return null;

              return (
                <div key={product} className="space-y-2">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <Badge variant="outline" className="capitalize">
                        {product}
                      </Badge>
                      <span className="text-sm text-muted-foreground">
                        {metrics.total} tickets
                      </span>
                    </div>
                    <div className="flex gap-6 text-sm">
                      <div className="text-center">
                        <div className={`font-medium ${getPerformanceColor(metrics.responsePercentage)}`}>
                          {metrics.responsePercentage.toFixed(0)}%
                        </div>
                        <div className="text-xs text-muted-foreground">Response</div>
                      </div>
                      <div className="text-center">
                        <div className={`font-medium ${getPerformanceColor(metrics.resolutionPercentage)}`}>
                          {metrics.resolutionPercentage.toFixed(0)}%
                        </div>
                        <div className="text-xs text-muted-foreground">Resolution</div>
                      </div>
                      <div className="text-center">
                        <div className="font-medium text-blue-600">
                          {formatTime(metrics.averageResponseTime)}
                        </div>
                        <div className="text-xs text-muted-foreground">Avg Response</div>
                      </div>
                      <div className="text-center">
                        <div className="font-medium text-green-600">
                          {formatTime(metrics.averageResolutionTime)}
                        </div>
                        <div className="text-xs text-muted-foreground">Avg Resolution</div>
                      </div>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Progress value={metrics.responsePercentage} className="h-2" />
                    </div>
                    <div>
                      <Progress value={metrics.resolutionPercentage} className="h-2" />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* SLA Targets Reference */}
      <Card>
        <CardHeader>
          <CardTitle>SLA Targets</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="space-y-2">
              <Badge variant="destructive" className="text-xs">Critical</Badge>
              <div className="text-sm space-y-1">
                <div>Response: 15 minutes</div>
                <div>Resolution: 4 hours</div>
              </div>
            </div>
            <div className="space-y-2">
              <Badge variant="secondary" className="text-xs bg-orange-100 text-orange-800">High</Badge>
              <div className="text-sm space-y-1">
                <div>Response: 1 hour</div>
                <div>Resolution: 8 hours</div>
              </div>
            </div>
            <div className="space-y-2">
              <Badge variant="secondary" className="text-xs bg-yellow-100 text-yellow-800">Medium</Badge>
              <div className="text-sm space-y-1">
                <div>Response: 4 hours</div>
                <div>Resolution: 24 hours</div>
              </div>
            </div>
            <div className="space-y-2">
              <Badge variant="secondary" className="text-xs bg-green-100 text-green-800">Low</Badge>
              <div className="text-sm space-y-1">
                <div>Response: 8 hours</div>
                <div>Resolution: 48 hours</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}