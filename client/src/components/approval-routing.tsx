import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Plus, Edit, Trash2, Users, Shield } from "lucide-react";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import type { ApprovalRouting, Product, User } from "@shared/schema";

const routingSchema = z.object({
  productId: z.number().optional(),
  groupId: z.number().optional(),
  riskLevel: z.enum(["low", "medium", "high"], { required_error: "Risk level is required" }),
  approverIds: z.array(z.number()).min(1, "At least one approver is required"),
  approvalLevel: z.number().min(1, "Approval level is required").default(1),
  requireAllApprovals: z.enum(["true", "false"]).default("true"),
}).refine(data => data.productId || data.groupId, {
  message: "Either product or group must be selected",
  path: ["productId"]
});

interface ApprovalRoutingProps {
  currentUser: any;
}

export function ApprovalRoutingManager({ currentUser }: ApprovalRoutingProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [showWizard, setShowWizard] = useState(false);
  const [editingRouting, setEditingRouting] = useState<ApprovalRouting | null>(null);

  const { data: routings = [], isLoading: routingsLoading } = useQuery({
    queryKey: ["/api/approval-routing"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/approval-routing");
      return response.json();
    },
  });

  const { data: products = [] } = useQuery({
    queryKey: ["/api/products"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/products");
      return response.json();
    },
  });

  const { data: users = [] } = useQuery({
    queryKey: ["/api/users"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/users");
      return response.json();
    },
  });

  const { data: groups = [] } = useQuery({
    queryKey: ["/api/groups"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/groups");
      return response.json();
    },
  });

  const form = useForm<z.infer<typeof routingSchema>>({
    resolver: zodResolver(routingSchema),
    defaultValues: {
      productId: undefined,
      groupId: undefined,
      riskLevel: "medium",
      approverIds: [],
      approvalLevel: 1,
      requireAllApprovals: "true",
    },
  });

  const createMutation = useMutation({
    mutationFn: async (data: z.infer<typeof routingSchema>) => {
      const response = await apiRequest("POST", "/api/approval-routing", data);
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Approval routing created successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/approval-routing"] });
      setShowForm(false);
      form.reset();
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to create approval routing",
        variant: "destructive",
      });
    },
  });

  const updateMutation = useMutation({
    mutationFn: async ({ id, ...data }: { id: number } & z.infer<typeof routingSchema>) => {
      const response = await apiRequest("PATCH", `/api/approval-routing/${id}`, data);
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Approval routing updated successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/approval-routing"] });
      setShowForm(false);
      setEditingRouting(null);
      form.reset();
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to update approval routing",
        variant: "destructive",
      });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: async (id: number) => {
      const response = await apiRequest("DELETE", `/api/approval-routing/${id}`);
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Success",
        description: "Approval routing deleted successfully",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/approval-routing"] });
    },
    onError: () => {
      toast({
        title: "Error",
        description: "Failed to delete approval routing",
        variant: "destructive",
      });
    },
  });

  const handleEdit = (routing: ApprovalRouting) => {
    setEditingRouting(routing);
    form.reset({
      productId: routing.productId,
      riskLevel: routing.riskLevel as "low" | "medium" | "high",
      approverId: routing.approverId,
      approvalLevel: routing.approvalLevel,
    });
    setShowForm(true);
  };

  const handleSubmit = (data: z.infer<typeof routingSchema>) => {
    if (editingRouting) {
      updateMutation.mutate({ id: editingRouting.id, ...data });
    } else {
      createMutation.mutate(data);
    }
  };

  const getProductName = (productId: number) => {
    const product = products.find((p: Product) => p.id === productId);
    return product?.name || "Unknown Product";
  };

  const getApproverName = (approverId: number) => {
    const user = users.find((u: User) => u.id === approverId);
    return user?.username || "Unknown User";
  };

  const getRiskColor = (riskLevel: string) => {
    switch (riskLevel) {
      case "low": return "bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200";
      case "medium": return "bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200";
      case "high": return "bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200";
      default: return "bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-200";
    }
  };

  // Filter users to show only managers and admins for approver selection
  const approverUsers = users.filter((user: User) => 
    user.role === 'manager' || user.role === 'admin'
  );

  // Group routings by product and risk level for better visualization
  const groupedRoutings = routings.reduce((groups: any, routing: ApprovalRouting) => {
    const key = `${routing.productId}-${routing.riskLevel}`;
    if (!groups[key]) {
      groups[key] = {
        productId: routing.productId,
        riskLevel: routing.riskLevel,
        approvals: []
      };
    }
    groups[key].approvals.push(routing);
    return groups;
  }, {});

  // Sort approvals within each group by level
  Object.values(groupedRoutings).forEach((group: any) => {
    group.approvals.sort((a: ApprovalRouting, b: ApprovalRouting) => a.approvalLevel - b.approvalLevel);
  });

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Shield className="h-5 w-5" />
              <CardTitle>Multilevel Approval Configuration</CardTitle>
            </div>
            <div className="flex gap-2">
              <Button 
                variant="outline"
                onClick={() => setShowWizard(true)}
              >
                <Shield className="h-4 w-4 mr-2" />
                Setup Wizard
              </Button>
              <Button 
                onClick={() => {
                  setEditingRouting(null);
                  form.reset();
                  setShowForm(true);
                }}
                className="bg-primary hover:bg-primary/90"
              >
                <Plus className="h-4 w-4 mr-2" />
                Add Approver
              </Button>
            </div>
          </div>
        </CardHeader>
        <CardContent>
          {routingsLoading ? (
            <div className="text-center py-8">Loading approval routing rules...</div>
          ) : Object.keys(groupedRoutings).length === 0 ? (
            <div className="text-center py-8">
              <div className="mb-4">
                <Shield className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">No Approval Rules</h3>
                <p className="text-gray-500 dark:text-gray-400">
                  Configure approval workflows for different risk levels and products.
                </p>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              {Object.values(groupedRoutings).map((group: any) => (
                <Card key={`${group.productId}-${group.riskLevel}`} className="border-l-4 border-l-blue-500">
                  <CardHeader className="pb-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-3">
                        <div>
                          <h3 className="font-semibold">{getProductName(group.productId)}</h3>
                          <Badge className={getRiskColor(group.riskLevel)}>
                            {group.riskLevel.toUpperCase()} Risk
                          </Badge>
                        </div>
                      </div>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => {
                          setEditingRouting(null);
                          form.reset({
                            productId: group.productId,
                            riskLevel: group.riskLevel,
                            approvalLevel: Math.max(...group.approvals.map((a: ApprovalRouting) => a.approvalLevel)) + 1,
                            approverId: 0
                          });
                          setShowForm(true);
                        }}
                      >
                        <Plus className="h-4 w-4 mr-2" />
                        Add Level
                      </Button>
                    </div>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-3">
                      {group.approvals.map((routing: ApprovalRouting, index: number) => (
                        <div key={routing.id} className="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-800 rounded-lg">
                          <div className="flex items-center gap-4">
                            <div className="flex items-center gap-2">
                              <div className="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900 flex items-center justify-center">
                                <span className="text-sm font-semibold text-blue-600 dark:text-blue-400">
                                  {routing.approvalLevel}
                                </span>
                              </div>
                              <div>
                                <div className="font-medium">{getApproverName(routing.approverId)}</div>
                                <div className="text-sm text-gray-500">Level {routing.approvalLevel} Approver</div>
                              </div>
                            </div>
                            <Badge variant={routing.isActive === 'true' ? 'default' : 'secondary'}>
                              {routing.isActive === 'true' ? 'Active' : 'Inactive'}
                            </Badge>
                          </div>
                          <div className="flex gap-2">
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => handleEdit(routing)}
                            >
                              <Edit className="h-4 w-4" />
                            </Button>
                            <Button
                              variant="outline"
                              size="sm"
                              onClick={() => deleteMutation.mutate(routing.id)}
                              className="text-red-600 hover:text-red-700"
                            >
                              <Trash2 className="h-4 w-4" />
                            </Button>
                          </div>
                        </div>
                      ))}
                      
                      {/* Approval Flow Visualization */}
                      <div className="mt-4 p-3 bg-blue-50 dark:bg-blue-950 rounded-lg">
                        <div className="text-sm font-medium text-blue-800 dark:text-blue-200 mb-2">
                          Approval Flow:
                        </div>
                        <div className="flex items-center gap-2 text-sm text-blue-700 dark:text-blue-300">
                          {group.approvals.map((routing: ApprovalRouting, index: number) => (
                            <div key={routing.id} className="flex items-center gap-2">
                              <span className="px-2 py-1 bg-blue-100 dark:bg-blue-900 rounded text-xs">
                                L{routing.approvalLevel}: {getApproverName(routing.approverId)}
                              </span>
                              {index < group.approvals.length - 1 && (
                                <span className="text-blue-400">→</span>
                              )}
                            </div>
                          ))}
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Form Dialog */}
      <Dialog open={showForm} onOpenChange={setShowForm}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {editingRouting ? "Edit Approval Routing" : "Add Approval Routing"}
            </DialogTitle>
          </DialogHeader>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="productId"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Product</FormLabel>
                    <Select 
                      onValueChange={(value) => field.onChange(parseInt(value))}
                      value={field.value?.toString()}
                    >
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select product" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        {products.map((product: Product) => (
                          <SelectItem key={product.id} value={product.id.toString()}>
                            {product.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="riskLevel"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Risk Level</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select risk level" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="low">Low Risk</SelectItem>
                        <SelectItem value="medium">Medium Risk</SelectItem>
                        <SelectItem value="high">High Risk</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="approvalLevel"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Approval Level</FormLabel>
                      <Select 
                        onValueChange={(value) => field.onChange(parseInt(value))}
                        value={field.value?.toString()}
                      >
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select level" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="1">Level 1 (Primary)</SelectItem>
                          <SelectItem value="2">Level 2 (Secondary)</SelectItem>
                          <SelectItem value="3">Level 3 (Final)</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />

                <FormField
                  control={form.control}
                  name="approverId"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Approver</FormLabel>
                      <Select 
                        onValueChange={(value) => field.onChange(parseInt(value))}
                        value={field.value?.toString()}
                      >
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select approver" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          {approverUsers.map((user: User) => (
                            <SelectItem key={user.id} value={user.id.toString()}>
                              {user.username} ({user.role})
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>

              <div className="bg-amber-50 dark:bg-amber-900/20 p-4 rounded-lg border border-amber-200 dark:border-amber-800">
                <div className="flex items-center gap-2 mb-2">
                  <Shield className="h-4 w-4 text-amber-600" />
                  <span className="text-sm font-medium text-amber-800 dark:text-amber-200">Multilevel Approval for High Risk</span>
                </div>
                <p className="text-sm text-amber-700 dark:text-amber-300">
                  For high-risk changes, configure multiple approval levels (Level 1 → Level 2 → Level 3) to ensure proper oversight and security.
                </p>
              </div>

              <div className="flex justify-end space-x-2 pt-4">
                <Button type="button" variant="outline" onClick={() => setShowForm(false)}>
                  Cancel
                </Button>
                <Button 
                  type="submit" 
                  disabled={createMutation.isPending || updateMutation.isPending}
                >
                  {editingRouting ? "Update" : "Create"} Routing Rule
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>

      {/* Setup Wizard Dialog */}
      <Dialog open={showWizard} onOpenChange={setShowWizard}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <Shield className="h-5 w-5" />
              Approval Workflow Setup Wizard
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Common Patterns */}
              <Card className="cursor-pointer hover:shadow-md transition-shadow" onClick={() => setupCommonWorkflow('simple')}>
                <CardHeader className="pb-3">
                  <CardTitle className="text-sm">Simple Approval</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2 text-xs">
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-green-500" />
                      <span>Low Risk: Auto-approve</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-yellow-500" />
                      <span>Medium Risk: 1 Level</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-red-500" />
                      <span>High Risk: 2 Levels</span>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="cursor-pointer hover:shadow-md transition-shadow" onClick={() => setupCommonWorkflow('enterprise')}>
                <CardHeader className="pb-3">
                  <CardTitle className="text-sm">Enterprise Model</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2 text-xs">
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-green-500" />
                      <span>Low Risk: Manager</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-yellow-500" />
                      <span>Medium Risk: Manager → Admin</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-red-500" />
                      <span>High Risk: Manager → Admin → Senior Admin</span>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card className="cursor-pointer hover:shadow-md transition-shadow" onClick={() => setupCommonWorkflow('custom')}>
                <CardHeader className="pb-3">
                  <CardTitle className="text-sm">Custom Setup</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2 text-xs">
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-blue-500" />
                      <span>Configure manually</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-blue-500" />
                      <span>Product-specific rules</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-blue-500" />
                      <span>Complex workflows</span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>

            <div className="bg-blue-50 dark:bg-blue-950 p-4 rounded-lg">
              <h4 className="font-medium text-blue-800 dark:text-blue-200 mb-2">Workflow Examples</h4>
              <div className="space-y-3 text-sm text-blue-700 dark:text-blue-300">
                <div>
                  <strong>Simple:</strong> Basic approval structure suitable for small teams
                </div>
                <div>
                  <strong>Enterprise:</strong> Traditional corporate approval hierarchy with multiple levels
                </div>
                <div>
                  <strong>Custom:</strong> Flexible configuration for specific organizational needs
                </div>
              </div>
            </div>

            <div className="flex justify-end space-x-2">
              <Button variant="outline" onClick={() => setShowWizard(false)}>
                Close
              </Button>
            </div>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );

  // Setup common workflow patterns
  function setupCommonWorkflow(type: 'simple' | 'enterprise' | 'custom') {
    setShowWizard(false);
    
    if (type === 'custom') {
      setShowForm(true);
      return;
    }

    // Show instructions for the selected pattern
    toast({
      title: `${type === 'simple' ? 'Simple' : 'Enterprise'} Workflow Setup`,
      description: `Use the "Add Approver" button to configure ${type} approval patterns for each product and risk level.`,
    });
  }
}