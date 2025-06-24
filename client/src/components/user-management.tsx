import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { useToast } from "@/hooks/use-toast";
import { apiRequest } from "@/lib/queryClient";
import { User, Group } from "@shared/schema";
import { UserPlus, Users, Shield, UserCheck, UserX, Edit, Trash2, RefreshCw } from "lucide-react";
import { Checkbox } from "@/components/ui/checkbox";

const userFormSchema = z.object({
  username: z.string().min(3, "Username must be at least 3 characters"),
  email: z.string().email("Valid email is required"),
  password: z.string().min(6, "Password must be at least 6 characters").optional(),
  name: z.string().min(1, "Name is required"),
  role: z.enum(["user", "agent", "manager", "admin"]),
});

interface UserManagementProps {
  currentUser: any;
}

export function UserManagement({ currentUser }: UserManagementProps) {
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [selectedGroups, setSelectedGroups] = useState<number[]>([]);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const { data: users = [], isLoading } = useQuery<User[]>({
    queryKey: ["/api/users"],
    refetchInterval: 30000,
  });

  const { data: groups = [] } = useQuery<Group[]>({
    queryKey: ["/api/groups"],
    refetchInterval: 2000, // Faster refresh for testing
    staleTime: 0, // Always refetch fresh data
  });

  const createForm = useForm<z.infer<typeof userFormSchema>>({
    resolver: zodResolver(userFormSchema),
    defaultValues: {
      username: "",
      email: "",
      password: "",
      name: "",
      role: "user",
    },
  });

  const editForm = useForm<z.infer<typeof userFormSchema>>({
    resolver: zodResolver(userFormSchema.partial({ password: true })),
    defaultValues: {
      username: "",
      email: "",
      name: "",
      role: "user",
    },
  });

  const createUserMutation = useMutation({
    mutationFn: async (userData: z.infer<typeof userFormSchema>) => {
      const response = await apiRequest("POST", "/api/users", userData);
      const newUser = await response.json();
      
      // If groups selected, update group membership
      if (selectedGroups.length > 0) {
        for (const groupId of selectedGroups) {
          await apiRequest("POST", `/api/groups/${groupId}/members`, { userId: newUser.user.id });
        }
      }
      
      return newUser;
    },
    onSuccess: () => {
      toast({
        title: "User created successfully",
        description: "The new user has been added to the system",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/users"] });
      queryClient.invalidateQueries({ queryKey: ["/api/groups"] });
      // Force immediate refetch to update display
      setTimeout(() => {
        queryClient.refetchQueries({ queryKey: ["/api/users"] });
        queryClient.refetchQueries({ queryKey: ["/api/groups"] });
      }, 100);
      setIsCreateDialogOpen(false);
      createForm.reset();
      setSelectedGroups([]);
    },
    onError: (error: any) => {
      toast({
        title: "Error creating user",
        description: error.message || "Failed to create user",
        variant: "destructive",
      });
    },
  });

  const updateUserMutation = useMutation({
    mutationFn: async (data: { id: number } & Partial<z.infer<typeof userFormSchema>>) => {
      const { id, ...userData } = data;
      const response = await apiRequest("PATCH", `/api/users/${id}`, userData);
      
      // Update group memberships - remove user from all groups then add to selected ones
      const userGroups = groups.filter(group => group.members && group.members.includes(id));
      for (const group of userGroups) {
        await apiRequest("DELETE", `/api/groups/${group.id}/members/${id}`);
      }
      
      // Add to selected groups
      for (const groupId of selectedGroups) {
        await apiRequest("POST", `/api/groups/${groupId}/members`, { userId: id });
      }
      
      return await response.json();
    },
    onSuccess: () => {
      toast({
        title: "User updated successfully",
        description: "The user information has been updated",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/users"] });
      queryClient.invalidateQueries({ queryKey: ["/api/groups"] });
      // Force immediate refetch to update display
      setTimeout(() => {
        queryClient.refetchQueries({ queryKey: ["/api/users"] });
        queryClient.refetchQueries({ queryKey: ["/api/groups"] });
      }, 100);
      setIsEditDialogOpen(false);
      setSelectedUser(null);
      editForm.reset();
      setSelectedGroups([]);
    },
    onError: (error: any) => {
      toast({
        title: "Error updating user",
        description: error.message || "Failed to update user",
        variant: "destructive",
      });
    },
  });

  const deleteUserMutation = useMutation({
    mutationFn: async (userId: number) => {
      const response = await apiRequest("DELETE", `/api/users/${userId}`);
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "User deleted successfully",
        description: "The user has been removed from the system",
      });
      queryClient.invalidateQueries({ queryKey: ["/api/users"] });
    },
    onError: (error: any) => {
      toast({
        title: "Error deleting user",
        description: error.message || "Failed to delete user",
        variant: "destructive",
      });
    },
  });

  const onCreateUser = (data: z.infer<typeof userFormSchema>) => {
    createUserMutation.mutate(data);
  };

  const onEditUser = (data: z.infer<typeof userFormSchema>) => {
    if (selectedUser) {
      const updateData = { ...data };
      if (!updateData.password) {
        delete updateData.password;
      }
      updateUserMutation.mutate({ ...updateData, id: selectedUser.id });
    }
  };

  const handleEditUser = (user: User) => {
    setSelectedUser(user);
    editForm.reset({
      username: user.username,
      email: user.email,
      name: user.name,
      role: user.role as "user" | "agent" | "manager" | "admin",
    });
    // Find groups this user belongs to
    const userGroups = groups.filter(group => group.members && group.members.includes(user.id));
    setSelectedGroups(userGroups.map(g => g.id));
    setIsEditDialogOpen(true);
  };

  const handleDeleteUser = (user: User) => {
    if (user.id === currentUser?.id) {
      toast({
        title: "Error",
        description: "You cannot delete your own account",
        variant: "destructive",
      });
      return;
    }

    if (confirm(`Are you sure you want to delete user "${user.username}"? This action cannot be undone.`)) {
      deleteUserMutation.mutate(user.id);
    }
  };

  const getRoleBadgeVariant = (role: string) => {
    switch (role) {
      case "admin":
        return "destructive";
      case "manager":
        return "default";
      case "agent":
        return "secondary";
      default:
        return "outline";
    }
  };

  const getRoleIcon = (role: string) => {
    switch (role) {
      case "admin":
        return <Shield className="h-4 w-4" />;
      case "manager":
        return <UserCheck className="h-4 w-4" />;
      case "agent":
        return <UserX className="h-4 w-4" />;
      default:
        return <Users className="h-4 w-4" />;
    }
  };

  const roleStats = {
    admin: users.filter(u => u.role === "admin").length,
    manager: users.filter(u => u.role === "manager").length,
    agent: users.filter(u => u.role === "agent").length,
    user: users.filter(u => u.role === "user").length,
  };

  if (currentUser?.role !== "admin") {
    return (
      <Alert>
        <Shield className="h-4 w-4" />
        <AlertDescription>
          You don't have permission to access user management. Admin access required.
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold">User Management</h2>
          <p className="text-muted-foreground">
            Manage user accounts, roles, and group membership
          </p>
        </div>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => {
              queryClient.invalidateQueries({ queryKey: ["/api/users"] });
              queryClient.invalidateQueries({ queryKey: ["/api/groups"] });
            }}
          >
            <RefreshCw className="h-4 w-4 mr-2" />
            Refresh
          </Button>
          <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
            <DialogTrigger asChild>
              <Button>
                <UserPlus className="h-4 w-4 mr-2" />
                Add User
              </Button>
            </DialogTrigger>
            <DialogContent>
              <DialogHeader>
                <DialogTitle>Create New User</DialogTitle>
                <DialogDescription>
                  Add a new user to the system with appropriate role and group assignment
                </DialogDescription>
              </DialogHeader>
              <Form {...createForm}>
                <form onSubmit={createForm.handleSubmit(onCreateUser)} className="space-y-4">
                  <FormField
                    control={createForm.control}
                    name="name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Full Name</FormLabel>
                        <FormControl>
                          <Input placeholder="Enter full name" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={createForm.control}
                    name="username"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Username</FormLabel>
                        <FormControl>
                          <Input placeholder="Enter username" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={createForm.control}
                    name="email"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Email</FormLabel>
                        <FormControl>
                          <Input type="email" placeholder="Enter email address" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={createForm.control}
                    name="password"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Password</FormLabel>
                        <FormControl>
                          <Input type="password" placeholder="Enter password" {...field} />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  <FormField
                    control={createForm.control}
                    name="role"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel>Role</FormLabel>
                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                          <FormControl>
                            <SelectTrigger>
                              <SelectValue placeholder="Select role" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="user">User (Default)</SelectItem>
                            <SelectItem value="agent">Agent</SelectItem>
                            <SelectItem value="manager">Manager</SelectItem>
                            <SelectItem value="admin">Admin</SelectItem>
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                  
                  {/* Group Membership */}
                  <FormItem>
                    <FormLabel>Group Membership</FormLabel>
                    <div className="space-y-2 max-h-40 overflow-y-auto">
                      {groups.map((group: any) => (
                        <div key={group.id} className="flex items-center space-x-2">
                          <Checkbox
                            id={`group-${group.id}`}
                            checked={selectedGroups.includes(group.id)}
                            onCheckedChange={(checked) => {
                              if (checked) {
                                setSelectedGroups([...selectedGroups, group.id]);
                              } else {
                                setSelectedGroups(selectedGroups.filter(g => g !== group.id));
                              }
                            }}
                          />
                          <label
                            htmlFor={`group-${group.id}`}
                            className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                          >
                            {group.name}
                          </label>
                        </div>
                      ))}
                    </div>
                  </FormItem>
                  
                  <div className="flex gap-2 pt-4">
                    <Button type="submit" disabled={createUserMutation.isPending} className="flex-1">
                      {createUserMutation.isPending ? "Creating..." : "Create User"}
                    </Button>
                    <Button type="button" variant="outline" onClick={() => setIsCreateDialogOpen(false)}>
                      Cancel
                    </Button>
                  </div>
                </form>
              </Form>
            </DialogContent>
          </Dialog>
        </div>
      </div>

      {/* User Statistics */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Users</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{users.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Admins</CardTitle>
            <Shield className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{roleStats.admin}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Agents</CardTitle>
            <UserCheck className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{roleStats.agent}</div>
          </CardContent>
        </Card>
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Regular Users</CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{roleStats.user}</div>
          </CardContent>
        </Card>
      </div>

      {/* Users Table */}
      <Card>
        <CardHeader>
          <CardTitle>Users</CardTitle>
          <CardDescription>
            Manage user accounts and group assignments
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
              <p className="mt-2 text-gray-600 dark:text-gray-400">Loading users...</p>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>User</TableHead>
                  <TableHead>Role</TableHead>
                  <TableHead>Group Membership</TableHead>
                  <TableHead>Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {users.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell>
                      <div>
                        <div className="font-medium">{user.name}</div>
                        <div className="text-sm text-muted-foreground">
                          {user.email} • @{user.username}
                        </div>
                      </div>
                    </TableCell>
                    <TableCell>
                      <Badge variant={getRoleBadgeVariant(user.role)} className="flex items-center gap-1 w-fit">
                        {getRoleIcon(user.role)}
                        {user.role}
                      </Badge>
                    </TableCell>
                    <TableCell>
                      <div className="flex flex-wrap gap-1">
                        {(() => {
                          console.log(`User ${user.id} groups check:`, groups.map(g => ({ id: g.id, name: g.name, members: g.members })));
                          const userGroups = groups.filter(group => {
                            return group.members && Array.isArray(group.members) && group.members.includes(user.id);
                          });
                          console.log(`User ${user.id} belongs to:`, userGroups);
                          return userGroups.length > 0 ? (
                            userGroups.map((group, index) => (
                              <Badge key={index} variant="outline" className="text-xs">
                                {group.name}
                              </Badge>
                            ))
                          ) : (
                            <span className="text-gray-500 italic">No groups assigned</span>
                          );
                        })()}
                      </div>
                    </TableCell>
                    <TableCell>
                      <div className="flex gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleEditUser(user)}
                          disabled={user.id === currentUser?.id}
                        >
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleDeleteUser(user)}
                          disabled={user.id === currentUser?.id}
                        >
                          <Trash2 className="h-4 w-4" />
                        </Button>
                      </div>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      {/* Edit User Dialog */}
      <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit User</DialogTitle>
            <DialogDescription>
              Update user information and group assignments
            </DialogDescription>
          </DialogHeader>
          {selectedUser && (
            <Form {...editForm}>
              <form onSubmit={editForm.handleSubmit(onEditUser)} className="space-y-4">
                <FormField
                  control={editForm.control}
                  name="name"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Full Name</FormLabel>
                      <FormControl>
                        <Input placeholder="Enter full name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={editForm.control}
                  name="username"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Username</FormLabel>
                      <FormControl>
                        <Input placeholder="Enter username" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={editForm.control}
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Email</FormLabel>
                      <FormControl>
                        <Input type="email" placeholder="Enter email address" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                <FormField
                  control={editForm.control}
                  name="role"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Role</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select role" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="user">User (Default)</SelectItem>
                          <SelectItem value="agent">Agent</SelectItem>
                          <SelectItem value="manager">Manager</SelectItem>
                          <SelectItem value="admin">Admin</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                {/* Group Membership */}
                <FormItem>
                  <FormLabel>Group Membership</FormLabel>
                  <div className="space-y-2 max-h-40 overflow-y-auto">
                    {groups.map((group: any) => (
                      <div key={group.id} className="flex items-center space-x-2">
                        <Checkbox
                          id={`edit-group-${group.id}`}
                          checked={selectedGroups.includes(group.id)}
                          onCheckedChange={(checked) => {
                            if (checked) {
                              setSelectedGroups([...selectedGroups, group.id]);
                            } else {
                              setSelectedGroups(selectedGroups.filter(g => g !== group.id));
                            }
                          }}
                        />
                        <label
                          htmlFor={`edit-group-${group.id}`}
                          className="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"
                        >
                          {group.name}
                        </label>
                      </div>
                    ))}
                  </div>
                </FormItem>

                <div className="flex gap-2 pt-4">
                  <Button
                    type="submit"
                    disabled={updateUserMutation.isPending}
                    className="flex-1"
                  >
                    Update User
                  </Button>
                  <Button 
                    type="button" 
                    variant="outline" 
                    onClick={() => setIsEditDialogOpen(false)}
                  >
                    Cancel
                  </Button>
                </div>
              </form>
            </Form>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}