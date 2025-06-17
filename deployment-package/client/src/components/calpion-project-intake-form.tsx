import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Checkbox } from "@/components/ui/checkbox";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { Building2, Calendar, DollarSign, Users, Target, AlertTriangle, FileText, CheckCircle2 } from "lucide-react";

// Comprehensive Calpion Project Intake Schema
const calpionProjectIntakeSchema = z.object({
  // Project Information
  projectTitle: z.string().min(3, "Project title is required"),
  projectCode: z.string().optional(),
  submissionDate: z.string().min(1, "Submission date is required"),
  requestorName: z.string().min(2, "Requestor name is required"),
  requestorTitle: z.string().min(2, "Job title is required"),
  department: z.string().min(2, "Department is required"),
  businessUnit: z.string().min(2, "Business unit is required"),
  contactEmail: z.string().email("Valid email address is required"),
  contactPhone: z.string().min(10, "Phone number is required"),
  
  // Project Classification
  projectCategory: z.enum(["strategic_initiative", "operational_improvement", "compliance_requirement", "infrastructure_upgrade", "system_enhancement", "cost_reduction", "revenue_generation"]),
  projectType: z.enum(["new_system_implementation", "system_upgrade", "process_improvement", "integration_project", "data_migration", "security_enhancement", "compliance_project", "research_development"]),
  businessPriority: z.enum(["critical", "high", "medium", "low"]),
  estimatedComplexity: z.enum(["low", "medium", "high", "very_high"]),
  
  // Business Case
  businessProblemStatement: z.string().min(50, "Business problem statement must be detailed (min 50 characters)"),
  proposedSolution: z.string().min(50, "Proposed solution must be detailed (min 50 characters)"),
  businessBenefits: z.string().min(50, "Business benefits must be detailed (min 50 characters)"),
  expectedROI: z.string().optional(),
  quantifiableBenefits: z.string().optional(),
  alternativesConsidered: z.string().optional(),
  consequencesOfInaction: z.string().min(20, "Consequences of not proceeding must be specified"),
  
  // Project Scope & Requirements
  projectScope: z.string().min(30, "Project scope must be clearly defined"),
  keyRequirements: z.string().min(30, "Key requirements must be specified"),
  deliverables: z.string().min(20, "Expected deliverables must be listed"),
  assumptions: z.string().min(20, "Project assumptions must be documented"),
  constraints: z.string().optional(),
  successCriteria: z.string().min(20, "Success criteria must be defined"),
  
  // Timeline & Milestones
  requestedStartDate: z.string().min(1, "Requested start date is required"),
  desiredCompletionDate: z.string().min(1, "Desired completion date is required"),
  criticalMilestones: z.string().min(20, "Critical milestones must be identified"),
  timeConstraints: z.string().optional(),
  
  // Financial Information
  estimatedProjectCost: z.string().optional(),
  budgetSource: z.string().min(5, "Budget source must be specified"),
  capitalExpenditure: z.string().optional(),
  operationalExpenditure: z.string().optional(),
  fundingStatus: z.enum(["approved", "pending_approval", "not_yet_submitted", "budget_allocated", "requires_approval"]),
  costBenefitJustification: z.string().optional(),
  
  // Resources & Stakeholders
  executiveSponsor: z.string().min(2, "Executive sponsor is required"),
  businessOwner: z.string().min(2, "Business owner is required"),
  projectManagerAssigned: z.string().optional(),
  keyStakeholders: z.string().min(20, "Key stakeholders must be identified"),
  impactedDepartments: z.string().min(10, "Impacted departments must be listed"),
  estimatedTeamSize: z.string().optional(),
  externalResourcesNeeded: z.string().optional(),
  
  // Technical Requirements
  currentSystemsAffected: z.string().optional(),
  technologyStack: z.string().optional(),
  integrationRequirements: z.string().optional(),
  dataRequirements: z.string().optional(),
  securityRequirements: z.string().optional(),
  complianceRequirements: z.string().optional(),
  infrastructureNeeds: z.string().optional(),
  
  // Risk Assessment
  identifiedRisks: z.string().min(20, "Major risks must be identified"),
  riskMitigationStrategies: z.string().min(20, "Risk mitigation strategies are required"),
  dependencies: z.string().optional(),
  criticalSuccessFactors: z.string().min(20, "Critical success factors must be identified"),
  
  // Change Management
  organizationalImpact: z.string().optional(),
  trainingRequirements: z.string().optional(),
  communicationPlan: z.string().optional(),
  changeManagementNeeds: z.string().optional(),
  
  // Approvals & Sign-offs
  businessCaseReviewed: z.boolean().default(false),
  budgetApprovalObtained: z.boolean().default(false),
  stakeholderBuyIn: z.boolean().default(false),
  executiveApprovalSignature: z.string().optional(),
  additionalComments: z.string().optional(),
});

type CalpionProjectIntakeForm = z.infer<typeof calpionProjectIntakeSchema>;

export function CalpionProjectIntakeForm() {
  const { toast } = useToast();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<CalpionProjectIntakeForm>({
    resolver: zodResolver(calpionProjectIntakeSchema),
    defaultValues: {
      submissionDate: new Date().toISOString().split('T')[0],
      projectCategory: "operational_improvement",
      projectType: "new_system_implementation",
      businessPriority: "medium",
      estimatedComplexity: "medium",
      fundingStatus: "not_yet_submitted",
      businessCaseReviewed: false,
      budgetApprovalObtained: false,
      stakeholderBuyIn: false
    }
  });

  const submitMutation = useMutation({
    mutationFn: async (data: CalpionProjectIntakeForm) => {
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
        title: "Project Intake Submitted Successfully",
        description: "Your project intake request has been submitted and will be reviewed by the appropriate stakeholders.",
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

  const onSubmit = (data: CalpionProjectIntakeForm) => {
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
              <FileText className="h-5 w-5" />
              Section 1: Project Information
            </CardTitle>
            <CardDescription>
              Provide basic information about the project and the requesting party.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="projectTitle"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Title *</FormLabel>
                  <FormControl>
                    <Input placeholder="Enter descriptive project title" {...field} />
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
                  <FormLabel>Project Code (if applicable)</FormLabel>
                  <FormControl>
                    <Input placeholder="e.g., PROJ-2024-001" {...field} />
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
              name="requestorName"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Requestor Name *</FormLabel>
                  <FormControl>
                    <Input placeholder="Full name" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="requestorTitle"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Job Title *</FormLabel>
                  <FormControl>
                    <Input placeholder="Position/Title" {...field} />
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
                  <FormLabel>Email Address *</FormLabel>
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
                  <FormLabel>Phone Number *</FormLabel>
                  <FormControl>
                    <Input placeholder="+1 (555) 123-4567" {...field} />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 2: Project Classification */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Target className="h-5 w-5" />
              Section 2: Project Classification
            </CardTitle>
            <CardDescription>
              Classify the project to help with prioritization and resource allocation.
            </CardDescription>
          </CardHeader>
          <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <FormField
              control={form.control}
              name="projectCategory"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Category *</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select category" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="strategic_initiative">Strategic Initiative</SelectItem>
                      <SelectItem value="operational_improvement">Operational Improvement</SelectItem>
                      <SelectItem value="compliance_requirement">Compliance Requirement</SelectItem>
                      <SelectItem value="infrastructure_upgrade">Infrastructure Upgrade</SelectItem>
                      <SelectItem value="system_enhancement">System Enhancement</SelectItem>
                      <SelectItem value="cost_reduction">Cost Reduction</SelectItem>
                      <SelectItem value="revenue_generation">Revenue Generation</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="projectType"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Project Type *</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select type" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="new_system_implementation">New System Implementation</SelectItem>
                      <SelectItem value="system_upgrade">System Upgrade</SelectItem>
                      <SelectItem value="process_improvement">Process Improvement</SelectItem>
                      <SelectItem value="integration_project">Integration Project</SelectItem>
                      <SelectItem value="data_migration">Data Migration</SelectItem>
                      <SelectItem value="security_enhancement">Security Enhancement</SelectItem>
                      <SelectItem value="compliance_project">Compliance Project</SelectItem>
                      <SelectItem value="research_development">Research & Development</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="businessPriority"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Business Priority *</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select priority" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="critical">Critical</SelectItem>
                      <SelectItem value="high">High</SelectItem>
                      <SelectItem value="medium">Medium</SelectItem>
                      <SelectItem value="low">Low</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="estimatedComplexity"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Estimated Complexity *</FormLabel>
                  <Select onValueChange={field.onChange} defaultValue={field.value}>
                    <FormControl>
                      <SelectTrigger>
                        <SelectValue placeholder="Select complexity" />
                      </SelectTrigger>
                    </FormControl>
                    <SelectContent>
                      <SelectItem value="low">Low</SelectItem>
                      <SelectItem value="medium">Medium</SelectItem>
                      <SelectItem value="high">High</SelectItem>
                      <SelectItem value="very_high">Very High</SelectItem>
                    </SelectContent>
                  </Select>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 3: Business Case */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Building2 className="h-5 w-5" />
              Section 3: Business Case
            </CardTitle>
            <CardDescription>
              Provide detailed justification for the project including problem statement and expected benefits.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="businessProblemStatement"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Business Problem Statement *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Clearly describe the business problem this project will solve..."
                      className="min-h-[100px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormDescription>
                    Provide a detailed description of the current business problem or opportunity
                  </FormDescription>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <FormField
              control={form.control}
              name="proposedSolution"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Proposed Solution *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Describe the proposed solution and approach..."
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
              name="businessBenefits"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Expected Business Benefits *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List the expected business benefits and value this project will deliver..."
                      className="min-h-[100px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="expectedROI"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Expected ROI</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., 15% within 18 months" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="quantifiableBenefits"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Quantifiable Benefits</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., $500K annual savings" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            
            <FormField
              control={form.control}
              name="consequencesOfInaction"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Consequences of Not Proceeding *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="What happens if this project is not undertaken?"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 4: Project Scope & Requirements */}
        <Card>
          <CardHeader>
            <CardTitle>Section 4: Project Scope & Requirements</CardTitle>
            <CardDescription>
              Define what is included and excluded from the project scope.
            </CardDescription>
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
                      placeholder="Define what is included in the project scope..."
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
                      placeholder="List the key functional and technical requirements..."
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
              name="deliverables"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Expected Deliverables *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List the expected project deliverables..."
                      className="min-h-[60px]"
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
                      placeholder="Define how project success will be measured..."
                      className="min-h-[60px]"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 5: Timeline & Financial Information */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Calendar className="h-5 w-5" />
              <DollarSign className="h-5 w-5" />
              Section 5: Timeline & Financial Information
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
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
                name="estimatedProjectCost"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Estimated Project Cost</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., $250,000" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="budgetSource"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Budget Source *</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., IT Capital Budget 2024" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="fundingStatus"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Funding Status *</FormLabel>
                    <Select onValueChange={field.onChange} defaultValue={field.value}>
                      <FormControl>
                        <SelectTrigger>
                          <SelectValue placeholder="Select funding status" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="approved">Approved</SelectItem>
                        <SelectItem value="pending_approval">Pending Approval</SelectItem>
                        <SelectItem value="not_yet_submitted">Not Yet Submitted</SelectItem>
                        <SelectItem value="budget_allocated">Budget Allocated</SelectItem>
                        <SelectItem value="requires_approval">Requires Approval</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </div>
            
            <FormField
              control={form.control}
              name="criticalMilestones"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Critical Milestones *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List key project milestones and target dates..."
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 6: Stakeholders & Resources */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5" />
              Section 6: Stakeholders & Resources
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="executiveSponsor"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Executive Sponsor *</FormLabel>
                    <FormControl>
                      <Input placeholder="Executive sponsor name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="businessOwner"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Business Owner *</FormLabel>
                    <FormControl>
                      <Input placeholder="Business owner name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="projectManagerAssigned"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Project Manager (if assigned)</FormLabel>
                    <FormControl>
                      <Input placeholder="Project manager name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="estimatedTeamSize"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Estimated Team Size</FormLabel>
                    <FormControl>
                      <Input placeholder="e.g., 5-8 team members" {...field} />
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
                      placeholder="List key stakeholders and their roles in the project..."
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
                      placeholder="List all departments that will be affected by this project..."
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 7: Risk Assessment */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5" />
              Section 7: Risk Assessment
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <FormField
              control={form.control}
              name="identifiedRisks"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Identified Risks *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="List major risks and potential challenges..."
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
              name="riskMitigationStrategies"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Risk Mitigation Strategies *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Describe strategies to mitigate identified risks..."
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
              name="criticalSuccessFactors"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Critical Success Factors *</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="What factors are critical for project success?"
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        {/* Section 8: Approvals & Sign-offs */}
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CheckCircle2 className="h-5 w-5" />
              Section 8: Approvals & Sign-offs
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-4">
              <FormField
                control={form.control}
                name="businessCaseReviewed"
                render={({ field }) => (
                  <FormItem className="flex flex-row items-start space-x-3 space-y-0">
                    <FormControl>
                      <Checkbox
                        checked={field.value}
                        onCheckedChange={field.onChange}
                      />
                    </FormControl>
                    <div className="space-y-1 leading-none">
                      <FormLabel>Business case has been reviewed and approved</FormLabel>
                      <FormDescription>
                        Confirm that the business case has been thoroughly reviewed
                      </FormDescription>
                    </div>
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="budgetApprovalObtained"
                render={({ field }) => (
                  <FormItem className="flex flex-row items-start space-x-3 space-y-0">
                    <FormControl>
                      <Checkbox
                        checked={field.value}
                        onCheckedChange={field.onChange}
                      />
                    </FormControl>
                    <div className="space-y-1 leading-none">
                      <FormLabel>Budget approval has been obtained</FormLabel>
                      <FormDescription>
                        Confirm that budget approval has been secured
                      </FormDescription>
                    </div>
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="stakeholderBuyIn"
                render={({ field }) => (
                  <FormItem className="flex flex-row items-start space-x-3 space-y-0">
                    <FormControl>
                      <Checkbox
                        checked={field.value}
                        onCheckedChange={field.onChange}
                      />
                    </FormControl>
                    <div className="space-y-1 leading-none">
                      <FormLabel>Key stakeholder buy-in has been secured</FormLabel>
                      <FormDescription>
                        Confirm that key stakeholders support the project
                      </FormDescription>
                    </div>
                  </FormItem>
                )}
              />
            </div>
            
            <FormField
              control={form.control}
              name="additionalComments"
              render={({ field }) => (
                <FormItem>
                  <FormLabel>Additional Comments</FormLabel>
                  <FormControl>
                    <Textarea 
                      placeholder="Any additional information or comments..."
                      {...field} 
                    />
                  </FormControl>
                  <FormMessage />
                </FormItem>
              )}
            />
          </CardContent>
        </Card>

        <div className="flex justify-end space-x-2 pt-6">
          <Button type="button" variant="outline" onClick={() => form.reset()}>
            Reset Form
          </Button>
          <Button 
            type="submit" 
            disabled={isSubmitting || submitMutation.isPending}
            className="bg-blue-600 hover:bg-blue-700"
          >
            {isSubmitting || submitMutation.isPending ? "Submitting..." : "Submit Project Intake Request"}
          </Button>
        </div>
      </form>
    </Form>
  );
}