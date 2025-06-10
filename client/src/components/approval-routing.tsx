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
  productId: z.number().min(1, "Product is required"),
  riskLevel: z.enum(["low", "medium", "high"], { required_error: "Risk level is required" }),
  approverId: z.number().min(1, "Approver is required"),
});

interface ApprovalRoutingProps {
  currentUser: any;
}

export function ApprovalRoutingManager({ currentUser }: ApprovalRoutingProps) {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [showForm, setShowForm] = useState(false);
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

  const form = useForm<z.infer<typeof routingSchema>>({
    resolver: zodResolver(routingSchema),
    defaultValues: {
      productId: 0,
      riskLevel: "medium",
      approverId: 0,
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

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Shield className="h-5 w-5" />
              <CardTitle>Approval Routing Configuration</CardTitle>
            </div>
            <Button 
              onClick={() => {
                setEditingRouting(null);
                form.reset();
                setShowForm(true);
              }}
              className="bg-primary hover:bg-primary/90"
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Routing Rule
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Product</TableHead>
                  <TableHead>Risk Level</TableHead>
                  <TableHead>Approver</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {routingsLoading ? (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center py-8">
                      Loading approval routing rules...
                    </TableCell>
                  </TableRow>
                ) : routings.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={5} className="text-center py-8">
                      No approval routing rules configured
                    </TableCell>
                  </TableRow>
                ) : (
                  routings.map((routing: ApprovalRouting) => (
                    <TableRow key={routing.id}>
                      <TableCell className="font-medium">
                        {getProductName(routing.productId)}
                      </TableCell>
                      <TableCell>
                        <Badge className={getRiskColor(routing.riskLevel)}>
                          {routing.riskLevel.toUpperCase()}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Users className="h-4 w-4" />
                          {getApproverName(routing.approverId)}
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant={routing.isActive === 'true' ? 'default' : 'secondary'}>
                          {routing.isActive === 'true' ? 'Active' : 'Inactive'}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
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
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
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
    </div>
  );
}