import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { useToast } from "@/hooks/use-toast";
import { CalendarIcon, DollarSign, Users, Target, Clock, AlertTriangle } from "lucide-react";

const projectIntakeSchema = z.object({
  // Section 1: Project Information
  projectTitle: z.string().min(3, "Project title is required"),
  projectCode: z.string().optional(),
  submissionDate: z.string().min(1, "Submission date is required"),
  requestedBy: z.string().min(2, "Requestor name is required"),
  department: z.string().min(2, "Department is required"),
  businessUnit: z.string().min(2, "Business unit is required"),
  contactEmail: z.string().email("Valid email address is required"),
  contactPhone: z.string().min(10, "Phone number is required"),
  
  // Section 2: Project Classification
  projectCategory: z.enum(["strategic", "operational", "compliance", "infrastructure", "enhancement"]),
  projectType: z.enum(["new_development", "system_upgrade", "process_improvement", "integration", "migration", "security"]),
  businessPriority: z.enum(["critical", "high", "medium", "low"]),
  estimatedComplexity: z.enum(["simple", "moderate", "complex", "very_complex"]),
  
  // Section 3: Business Case
  businessProblem: z.string().min(50, "Business problem description must be at least 50 characters"),
  proposedSolution: z.string().min(50, "Proposed solution must be at least 50 characters"),
  businessBenefits: z.string().min(50, "Business benefits must be at least 50 characters"),
  expectedROI: z.string().optional(),
  alternativesConsidered: z.string().optional(),
  consequencesOfNotDoing: z.string().min(20, "Consequences if not implemented are required"),
  
  // Section 4: Project Scope
  inScope: z.string().min(30, "In-scope items are required"),
  outOfScope: z.string().min(20, "Out-of-scope items are required"),
  assumptions: z.string().min(20, "Project assumptions are required"),
  constraints: z.string().optional(),
  
  // Section 5: Timeline & Resources
  proposedStartDate: z.string().min(1, "Proposed start date is required"),
  requiredCompletionDate: z.string().min(1, "Required completion date is required"),
  criticalMilestones: z.string().min(20, "Critical milestones are required"),
  estimatedEffort: z.string().optional(),
  resourceRequirements: z.string().min(20, "Resource requirements are required"),
  
  // Section 6: Financial Information
  estimatedTotalCost: z.string().optional(),
  capitalExpenditure: z.string().optional(),
  operationalExpenditure: z.string().optional(),
  budgetSource: z.string().min(5, "Budget source is required"),
  fundingApprovalStatus: z.enum(["approved", "pending", "not_submitted", "not_required"]),
  costBenefitAnalysis: z.string().optional(),
  
  // Section 7: Stakeholders & Impact
  executiveSponsor: z.string().min(2, "Executive sponsor is required"),
  projectManager: z.string().optional(),
  businessOwner: z.string().min(2, "Business owner is required"),
  keyStakeholders: z.string().min(20, "Key stakeholders are required"),
  impactedUsers: z.string().min(10, "Impacted users description is required"),
  estimatedUserCount: z.string().optional(),
  changeManagementNeeds: z.string().optional(),
  
  // Section 8: Technical Requirements
  currentSystemsAffected: z.string().optional(),
  technologyPlatform: z.string().optional(),
  integrationRequirements: z.string().optional(),
  dataRequirements: z.string().optional(),
  securityRequirements: z.string().optional(),
  complianceRequirements: z.string().optional(),
  infrastructureNeeds: z.string().optional(),
  
  // Section 9: Risk Assessment
  majorRisks: z.string().min(20, "Major risks must be identified"),
  riskMitigationStrategies: z.string().min(20, "Risk mitigation strategies are required"),
  dependencies: z.string().optional(),
  criticalSuccessFactors: z.string().min(20, "Critical success factors are required"),
  
  // Section 10: Approval & Authorization
  businessCaseApproved: z.boolean().default(false),
  budgetApproved: z.boolean().default(false),
  resourcesSecured: z.boolean().default(false),
  executiveApproval: z.string().optional(),
  additionalComments: z.string().optional(),
});

type ProjectIntakeForm = z.infer<typeof projectIntakeSchema>;

export function ProjectIntakeForm() {
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<ProjectIntakeForm>({
    resolver: zodResolver(projectIntakeSchema),
    defaultValues: {
      submissionDate: new Date().toISOString().split('T')[0],
      projectCategory: "operational",
      projectType: "new_development",
      businessPriority: "medium",
      estimatedComplexity: "moderate",
      fundingApprovalStatus: "not_submitted",
      businessCaseApproved: false,
      budgetApproved: false,
      resourcesSecured: false
    }
  });

  const submitMutation = useMutation({
    mutationFn: async (data: ProjectIntakeForm) => {
      const response = await fetch('/api/project-intake', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
      if (!response.ok) {
        throw new Error('Failed to submit project intake request');
      }
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "Project Intake Submitted",
        description: "Your project intake request has been submitted successfully. You will receive a confirmation email shortly.",
      });
      form.reset();
    },
    onError: () => {
      toast({
        title: "Submission Failed",
        description: "Failed to submit project intake request. Please try again.",
        variant: "destructive",
      });
    }
  });

  const onSubmit = (data: ProjectIntakeForm) => {
    setIsSubmitting(true);
    submitMutation.mutate(data);
    setIsSubmitting(false);
  };

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
        {/* Section 1: Project Information */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Target className="h-5 w-5" />
              Section 1: Project Information
            </CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="projectTitle"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Title *</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter project title" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="projectCode"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Code</FormLabel>
                  <FormControl>
                    <Input placeholder="Optional project code" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="submissionDate"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Submission Date *</FormLabel>
                  <FormControl>
                    <Input type="date" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="requestedBy"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Requested By *</FormLabel>
                  <FormControl>
                    <Input placeholder="Full name" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="department"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Department *</FormLabel>
                  <FormControl>
                    <Input placeholder="Department name" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="businessUnit"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Business Unit *</FormLabel>
                  <FormControl>
                    <Input placeholder="Business unit" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="contactEmail"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Contact Email *</FormLabel>
                  <FormControl>
                    <Input type="email" placeholder="email@calpion.com" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="contactPhone"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Contact Phone *</FormLabel>
                  <FormControl>
                    <Input placeholder="+1 (555) 123-4567" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Project Details */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Target className="h-5 w-5" />
              Project Details
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="projectName"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Name *</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter a descriptive project name" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="projectType"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Project Type *</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select project type" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="new_system">New System Implementation</SelectItem>
                        <SelectItem value="enhancement">System Enhancement</SelectItem>
                        <SelectItem value="integration">System Integration</SelectItem>
                        <SelectItem value="infrastructure">Infrastructure Project</SelectItem>
                        <SelectItem value="security">Security Initiative</SelectItem>
                        <SelectItem value="compliance">Compliance Project</SelectItem>
                        <SelectItem value="other">Other</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="priority"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Priority *</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select priority" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="low">Low</SelectItem>
                        <SelectItem value="medium">Medium</SelectItem>
                        <SelectItem value="high">High</SelectItem>
                        <SelectItem value="critical">Critical</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            
            <FormField
              control={form.control}
              name="projectDescription"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Description *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Provide a detailed description of the project, its objectives, and what it will accomplish"
                      className="min-h-[100px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="businessJustification"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Business Justification *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Explain the business need, expected benefits, ROI, and why this project is necessary"
                      className="min-h-[100px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Scope and Requirements */}
        <Card>
          <CardHeader>
            <CardTitle>Scope and Requirements</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="projectScope"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Scope *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Define what is included and excluded from this project"
                      className="min-h-[80px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="keyRequirements"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Key Requirements *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List the key functional and technical requirements"
                      className="min-h-[80px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="successCriteria"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Success Criteria *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Define how success will be measured and what constitutes project completion"
                      className="min-h-[80px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Timeline and Budget */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Clock className="h-5 w-5" />
              Timeline and Budget
            </CardTitle>
          </CardHeader>
          <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="requestedStartDate"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Requested Start Date *</FormLabel>
                  <FormControl>
                    <Input type="date" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="desiredCompletionDate"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Desired Completion Date *</FormLabel>
                  <FormControl>
                    <Input type="date" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="estimatedBudget"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Estimated Budget</FormLabel>
                  <FormControl>
                    <Input placeholder="$0 - $50,000" {...field} />
                  </FormControl>
                  <FormDescription>
                    Provide a rough budget estimate if known
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="budgetApproval"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Budget Approval Status *</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select approval status" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="approved">Approved</SelectItem>
                      <SelectItem value="pending">Pending Approval</SelectItem>
                      <SelectItem value="not_required">Not Required</SelectItem>
                      <SelectItem value="unknown">Unknown</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Stakeholders */}
        <Card>
          <CardHeader>
            <CardTitle>Stakeholders and Impact</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="projectSponsor"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Project Sponsor *</FormLabel>
                    <FormControl>
                      <Input placeholder="Executive sponsor name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="userCount"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Estimated User Count</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., 50 users" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            
            <FormField
              control={form.control}
              name="keyStakeholders"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Key Stakeholders *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List key stakeholders and their roles in the project"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="impactedDepartments"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Impacted Departments *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List all departments that will be affected by this project"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Technical Requirements */}
        <Card>
          <CardHeader>
            <CardTitle>Technical Requirements</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="systemsInvolved"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Systems Involved</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List existing systems that will be involved or affected"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="integrationRequired"
              render={({ field }) => (
                <FormItem className="flex flex-row items-start space-x-3 space-y-0">
                  <FormControl>
                    <Checkbox
                      checked={field.value}
                      onCheckedChange={field.onChange}
                    />
                  </FormControl>
                  <div className="space-y-1 leading-none">
                    <FormLabel>Integration Required</FormLabel>
                    <FormDescription>
                      Check if this project requires integration with other systems
                    </FormDescription>
                  </div>
                </FormItem>
              )}
            />
            
            {form.watch("integrationRequired") && (
              <FormField
                control={form.control}
                name="integrationDetails"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Integration Details</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Describe the required integrations"
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            )}
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="securityRequirements"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Security Requirements</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Any specific security requirements"
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="complianceRequirements"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Compliance Requirements</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="GDPR, HIPAA, SOX, etc."
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
          </CardContent>
        </Card>

        {/* Risk and Dependencies */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5" />
              Risk and Dependencies
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="identifiedRisks"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Identified Risks</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List any known risks or potential challenges"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="dependencies"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Dependencies</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List any dependencies on other projects, systems, or resources"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="additionalNotes"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Additional Notes</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Any additional information that would be helpful"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        <div className="flex justify-end space-x-2 pt-4">
          <Button type="button" variant="outline" onClick={() => form.reset()}>
            Reset Form
          </Button>
          <Button 
            type="submit" 
            disabled={isSubmitting || submitMutation.isPending}
            className="bg-blue-600 hover:bg-blue-700"
          >
            {isSubmitting || submitMutation.isPending ? "Submitting..." : "Submit Project Intake"}
          </Button>
        </div>
      </form>
    </Form>
  );
}