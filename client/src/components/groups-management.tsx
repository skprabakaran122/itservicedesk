import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { insertGroupSchema, type Group, type InsertGroup, type User } from "@shared/schema";
import { apiRequest } from "@/lib/queryClient";
import { useToast } from "@/hooks/use-toast";
import { Plus, Edit, Trash2, Users, UserPlus } from "lucide-react";

interface GroupsManagementProps {
  currentUser: any;
}

export function GroupsManagement({ currentUser }: GroupsManagementProps) {
  const [showGroupForm, setShowGroupForm] = useState(false);
  const [editingGroup, setEditingGroup] = useState<Group | null>(null);
  const { toast } = useToast();
  const queryClient = useQueryClient();

  const isAdmin = currentUser?.role === 'admin';

  const { data: groups = [], isLoading } = useQuery({
    queryKey: ["/api/groups"],
    queryFn: async () => {
      const response = await apiRequest("GET", "/api/groups");
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

  const form = useForm<InsertGroup>({
    resolver: zodResolver(insertGroupSchema),
    defaultValues: {
      name: "",
      description: "",
      isActive: "true",
      members: [],
    },
  });

  const createGroupMutation = useMutation({
    mutationFn: async (data: InsertGroup) => {
      const response = await apiRequest("POST", "/api/groups", data);
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/groups"] });
      toast({
        title: "Success",
        description: "Group created successfully",
      });
      setShowGroupForm(false);
      form.reset();
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to create group",
        variant: "destructive",
      });
    },
  });

  const updateGroupMutation = useMutation({
    mutationFn: async ({ id, data }: { id: number; data: Partial<InsertGroup> }) => {
      const response = await apiRequest("PATCH", `/api/groups/${id}`, data);
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/groups"] });
      toast({
        title: "Success",
        description: "Group updated successfully",
      });
      setShowGroupForm(false);
      setEditingGroup(null);
      form.reset();
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to update group",
        variant: "destructive",
      });
    },
  });

  const deleteGroupMutation = useMutation({
    mutationFn: async (id: number) => {
      const response = await apiRequest("DELETE", `/api/groups/${id}`);
      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["/api/groups"] });
      toast({
        title: "Success",
        description: "Group deleted successfully",
      });
    },
    onError: (error: any) => {
      toast({
        title: "Error",
        description: error.message || "Failed to delete group",
        variant: "destructive",
      });
    },
  });

  const handleSubmit = async (data: InsertGroup) => {
    if (editingGroup) {
      await updateGroupMutation.mutateAsync({ id: editingGroup.id, data });
    } else {
      await createGroupMutation.mutateAsync(data);
    }
  };

  const handleEdit = (group: Group) => {
    setEditingGroup(group);
    form.reset({
      name: group.name,
      description: group.description || "",
      isActive: group.isActive,
      members: group.members || [],
    });
    setShowGroupForm(true);
  };

  const handleDelete = async (id: number) => {
    if (window.confirm("Are you sure you want to delete this group?")) {
      await deleteGroupMutation.mutateAsync(id);
    }
  };

  if (!isAdmin) {
    return (
      <Card>
        <CardContent className="pt-6">
          <div className="text-center text-gray-500">
            Access denied. Admin privileges required.
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5" />
            Support Groups
          </CardTitle>
          <CardDescription>
            Manage support groups for ticket assignment and organization
          </CardDescription>
          <div className="flex justify-end">
            <Button onClick={() => setShowGroupForm(true)}>
              <Plus className="h-4 w-4 mr-2" />
              Add Group
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
              <p className="mt-2 text-gray-600 dark:text-gray-400">Loading groups...</p>
            </div>
          ) : groups.length === 0 ? (
            <div className="text-center py-8">
              <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-2">No Groups</h3>
              <p className="text-gray-500 dark:text-gray-400 mb-4">
                No support groups have been created yet. Create your first group to organize ticket assignments.
              </p>
              <Button onClick={() => setShowGroupForm(true)}>
                <Plus className="h-4 w-4 mr-2" />
                Add First Group
              </Button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {groups.map((group: Group) => (
                <Card key={group.id} className="relative">
                  <CardHeader className="pb-3">
                    <div className="flex items-start justify-between">
                      <div>
                        <CardTitle className="text-lg">{group.name}</CardTitle>
                        <CardDescription>
                          {group.members?.length || 0} members
                        </CardDescription>
                      </div>
                      <Badge variant={group.isActive === 'true' ? 'default' : 'secondary'}>
                        {group.isActive === 'true' ? 'Active' : 'Inactive'}
                      </Badge>
                    </div>
                  </CardHeader>
                  <CardContent>
                    {group.description && (
                      <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
                        {group.description}
                      </p>
                    )}
                    {group.members && group.members.length > 0 && (
                      <div className="mb-4">
                        <p className="text-sm font-medium mb-2">Members:</p>
                        <div className="flex flex-wrap gap-1">
                          {group.members.slice(0, 3).map((member) => (
                            <Badge key={member} variant="outline" className="text-xs">
                              {member}
                            </Badge>
                          ))}
                          {group.members.length > 3 && (
                            <Badge variant="outline" className="text-xs">
                              +{group.members.length - 3} more
                            </Badge>
                          )}
                        </div>
                      </div>
                    )}
                    <div className="flex gap-2">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleEdit(group)}
                      >
                        <Edit className="h-4 w-4 mr-1" />
                        Edit
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => handleDelete(group.id)}
                      >
                        <Trash2 className="h-4 w-4 mr-1" />
                        Delete
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Group Form Dialog */}
      <Dialog open={showGroupForm} onOpenChange={(open) => {
        setShowGroupForm(open);
        if (!open) {
          setEditingGroup(null);
          form.reset();
        }
      }}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editingGroup ? "Edit Group" : "Add New Group"}
            </DialogTitle>
            <DialogDescription>
              {editingGroup 
                ? "Update the group information and member assignments." 
                : "Create a new support group for ticket assignment."
              }
            </DialogDescription>
          </DialogHeader>
          <Form {...form}>
            <form onSubmit={form.handleSubmit(handleSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="name"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Group Name</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., Level 1 Support" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="description"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Description</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Describe the group's role and responsibilities"
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="isActive"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Status</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select status" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="true">Active</SelectItem>
                        <SelectItem value="false">Inactive</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={form.control}
                name="members"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Members</FormLabel>
                    <FormControl>
                      <Select 
                        onValueChange={(value) => {
                          const currentMembers = field.value || [];
                          if (!currentMembers.includes(value)) {
                            field.onChange([...currentMembers, value]);
                          }
                        }}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="Add members to group" />
                        </SelectTrigger>
                        <SelectContent>
                          {users.filter((user: User) => 
                            !field.value?.includes(user.username)
                          ).map((user: User) => (
                            <SelectItem key={user.id} value={user.username}>
                              {user.name} ({user.username})
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </FormControl>
                    {field.value && field.value.length > 0 && (
                      <div className="flex flex-wrap gap-2 mt-2">
                        {field.value.map((member) => (
                          <Badge key={member} variant="secondary" className="flex items-center gap-1">
                            {member}
                            <button
                              type="button"
                              onClick={() => {
                                field.onChange(field.value?.filter(m => m !== member));
                              }}
                              className="ml-1 text-xs hover:text-red-500"
                            >
                              ×
                            </button>
                          </Badge>
                        ))}
                      </div>
                    )}
                    <FormMessage />
                  </FormItem>
                )}
              />

              <div className="flex justify-end gap-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setShowGroupForm(false)}
                >
                  Cancel
                </Button>
                <Button
                  type="submit"
                  disabled={createGroupMutation.isPending || updateGroupMutation.isPending}
                >
                  {editingGroup ? "Update Group" : "Create Group"}
                </Button>
              </div>
            </form>
          </Form>
        </DialogContent>
      </Dialog>
    </div>
  );
}