import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useMutation } from "@tanstack/react-query";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage, FormDescription } from "@/components/ui/form";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/hooks/use-toast";
import { Building2, Calendar, Users, Target, FileText, CheckCircle2 } from "lucide-react";

// Calpion RPA/Olympus Project Request Form Schema
const calpionRPAProjectSchema = z.object({
  // Basic Information
  projectClientName: z.string().min(2, "Project/Client name is required"),
  department: z.string().min(2, "Department is required"),
  processNameArea: z.string().min(2, "Process name/area is required"),
  processKeyContact: z.string().min(2, "Process key contact is required"),
  projectType: z.enum(["new_automation", "enhancement", "maintenance", "migration"]),
  
  // Project Details
  scopeOfProject: z.string().min(20, "Scope of the project must be detailed"),
  automationBenefits: z.string().min(20, "Automation benefits must be specified"),
  fteSavings: z.string().optional(),
  
  // Current State
  currentFTEUtilized: z.string().optional(),
  currentTargetFTE: z.string().optional(),
  
  // Volume Information
  expectedVolumeMonth: z.string().optional(),
  expectedMinimumVolumeDay: z.string().optional(),
  expectedMaximumVolumeDay: z.string().optional(),
  inputDataSample: z.string().optional(),
  outputDataSample: z.string().optional(),
  inputAvailableTime: z.string().optional(),
  outputRequiredTime: z.string().optional(),
  currentProcess: z.string().optional(),
  applicationToBeAccessed: z.string().optional(),
  expectedOutcomeFromAutomation: z.string().optional(),
  
  // Approvals Section
  operationManagerDirector: z.string().optional(),
  operationsBUHead: z.string().optional(),
  automationBUHead: z.string().optional(),
  
  // IT Development Team Section
  prototypeDesignRequired: z.enum(["yes", "no"]).optional(),
  prototypeApprovedBy: z.string().optional(),
  projectAllocatedTo: z.string().optional(),
  developmentEstimates: z.string().optional(),
  projectStartDate: z.string().optional(),
  projectEndDate: z.string().optional(),
  
  // Requirements and Technical
  requirementsGatheredByIT: z.string().optional(),
  requirementsProvidedByOPS: z.string().optional(),
  brdDocumentDesignedBy: z.string().optional(),
  uatStartDate: z.string().optional(),
  uatEndDate: z.string().optional(),
  uatDoneBy: z.string().optional(),
  goLiveDate: z.string().optional(),
  goLiveFeedback: z.string().optional(),
  projectSignOffDetails: z.string().optional(),
  
  // Remarks
  remarks: z.string().optional(),
});

type CalpionRPAProjectForm = z.infer<typeof calpionRPAProjectSchema>;

export function CalpionRPAProjectForm() {
  const { toast } = useToast();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const form = useForm<CalpionRPAProjectForm>({
    resolver: zodResolver(calpionRPAProjectSchema),
    defaultValues: {
      projectType: "new_automation",
      prototypeDesignRequired: "no",
    }
  });

  const submitMutation = useMutation({
    mutationFn: async (data: CalpionRPAProjectForm) => {
      const response = await fetch('/api/project-intake', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...data,
          formType: 'rpa_olympus_project'
        })
      });
      if (!response.ok) {
        throw new Error('Failed to submit RPA project request');
      }
      return response.json();
    },
    onSuccess: () => {
      toast({
        title: "RPA Project Request Submitted",
        description: "Your RPA/Olympus project request has been submitted successfully and will be reviewed by the development team.",
      });
      form.reset();
    },
    onError: () => {
      toast({
        title: "Submission Failed",
        description: "Failed to submit project request. Please try again.",
        variant: "destructive",
      });
    }
  });

  const onSubmit = (data: CalpionRPAProjectForm) => {
    setIsSubmitting(true);
    submitMutation.mutate(data);
    setIsSubmitting(false);
  };

  return (
    <div className="max-w-5xl mx-auto">
      <div className="text-center mb-8">
        <h1 className="text-2xl font-bold text-blue-900 mb-2">
          Calpion RPA/Olympus - New Project Request Form
        </h1>
        <p className="text-gray-600">
          Submit your automation project request for evaluation and development
        </p>
      </div>

      <Form {...form}>
        <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-8">
          
          {/* Basic Project Information */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <FileText className="h-5 w-5" />
                Project Information
              </CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <FormField
                control={form.control}
                name="projectClientName"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Project/Client Name *</FormLabel>
                    <FormControl>
                      <Input placeholder="Enter project or client name" {...field} />
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
                      <Input placeholder="Enter department" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="processNameArea"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Process Name/Area *</FormLabel>
                    <FormControl>
                      <Input placeholder="Specify process name or area" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="processKeyContact"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Process Key Contact *</FormLabel>
                    <FormControl>
                      <Input placeholder="Key contact person" {...field} />
                    </FormControl>
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
                          <SelectValue placeholder="Select project type" />
                        </SelectTrigger>
                      </FormControl>
                      <SelectContent>
                        <SelectItem value="new_automation">New Automation</SelectItem>
                        <SelectItem value="enhancement">Enhancement</SelectItem>
                        <SelectItem value="maintenance">Maintenance</SelectItem>
                        <SelectItem value="migration">Migration</SelectItem>
                      </SelectContent>
                    </Select>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </CardContent>
          </Card>

          {/* Project Scope and Benefits */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Target className="h-5 w-5" />
                Project Scope & Benefits
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <FormField
                control={form.control}
                name="scopeOfProject"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Scope Of The Project *</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Describe the scope and objectives of the automation project..."
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
                name="automationBenefits"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Automation Benefits *</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Specify the expected benefits from automation..."
                        className="min-h-[80px]"
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <FormField
                  control={form.control}
                  name="fteSavings"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>FTE Savings</FormLabel>
                      <FormControl>
                        <Input placeholder="e.g., 2.5 FTE" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="currentFTEUtilized"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Current FTE Utilized</FormLabel>
                      <FormControl>
                        <Input placeholder="Current FTE count" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="currentTargetFTE"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Current Target FTE</FormLabel>
                      <FormControl>
                        <Input placeholder="Target FTE" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
            </CardContent>
          </Card>

          {/* Volume and Process Information */}
          <Card>
            <CardHeader>
              <CardTitle>Volume & Process Information</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <FormField
                  control={form.control}
                  name="expectedVolumeMonth"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Expected Volume/Month</FormLabel>
                      <FormControl>
                        <Input placeholder="Monthly volume" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="expectedMinimumVolumeDay"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Expected Minimum Volume/Day</FormLabel>
                      <FormControl>
                        <Input placeholder="Min daily volume" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="expectedMaximumVolumeDay"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Expected Maximum Volume/Day</FormLabel>
                      <FormControl>
                        <Input placeholder="Max daily volume" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="inputDataSample"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Input Data Sample</FormLabel>
                      <FormControl>
                        <Textarea 
                          placeholder="Provide sample input data format..."
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="outputDataSample"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Output Data Sample</FormLabel>
                      <FormControl>
                        <Textarea 
                          placeholder="Provide sample output data format..."
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="inputAvailableTime"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Input Available Time</FormLabel>
                      <FormControl>
                        <Input placeholder="When input is available" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="outputRequiredTime"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Output Required Time</FormLabel>
                      <FormControl>
                        <Input placeholder="When output is required" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <FormField
                control={form.control}
                name="currentProcess"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Current Process</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Describe the current manual process..."
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="applicationToBeAccessed"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Application to be Accessed for Automation</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="List applications that will be automated..."
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="expectedOutcomeFromAutomation"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Expected Outcome From Automation</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Describe expected outcomes and improvements..."
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </CardContent>
          </Card>

          {/* Approvals Section */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <CheckCircle2 className="h-5 w-5" />
                Approvals
              </CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <FormField
                control={form.control}
                name="operationManagerDirector"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Operation Manager/Director</FormLabel>
                    <FormControl>
                      <Input placeholder="Approver name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="operationsBUHead"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Operations BU Head</FormLabel>
                    <FormControl>
                      <Input placeholder="BU Head name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <FormField
                control={form.control}
                name="automationBUHead"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Automation BU Head</FormLabel>
                    <FormControl>
                      <Input placeholder="Automation head name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </CardContent>
          </Card>

          {/* IT Development Team Section */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Building2 className="h-5 w-5" />
                To Be Filled By IT Development Team
              </CardTitle>
              <CardDescription>
                This section will be completed by the IT development team during project planning
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="prototypeDesignRequired"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Prototype Design Required (Y/N)</FormLabel>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger>
                            <SelectValue placeholder="Select option" />
                          </SelectTrigger>
                        </FormControl>
                        <SelectContent>
                          <SelectItem value="yes">Yes</SelectItem>
                          <SelectItem value="no">No</SelectItem>
                        </SelectContent>
                      </Select>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="prototypeApprovedBy"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Prototype Approved By (Business Side)</FormLabel>
                      <FormControl>
                        <Input placeholder="Approver name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <FormField
                  control={form.control}
                  name="projectAllocatedTo"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Project Allocated To</FormLabel>
                      <FormControl>
                        <Input placeholder="Developer name" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="projectStartDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Project Start Date</FormLabel>
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="projectEndDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Project End Date</FormLabel>
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <FormField
                control={form.control}
                name="developmentEstimates"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Development Estimates Timeline</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Estimated timeline and milestones..."
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
                  name="requirementsGatheredByIT"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Requirements Gathered by IT Team (POC)</FormLabel>
                      <FormControl>
                        <Textarea 
                          placeholder="Requirements gathering details..."
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="requirementsProvidedByOPS"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Requirements Provided by OPS TEAM (POC)</FormLabel>
                      <FormControl>
                        <Textarea 
                          placeholder="Operations team requirements..."
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <FormField
                control={form.control}
                name="brdDocumentDesignedBy"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>BRD Document Designed By</FormLabel>
                    <FormControl>
                      <Input placeholder="Document designer name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="uatStartDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>UAT Start Date</FormLabel>
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="uatEndDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>UAT End Date</FormLabel>
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <FormField
                control={form.control}
                name="uatDoneBy"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>UAT Done By</FormLabel>
                    <FormControl>
                      <Input placeholder="UAT performer name" {...field} />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="goLiveDate"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Go LIVE Date</FormLabel>
                      <FormControl>
                        <Input type="date" {...field} />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="goLiveFeedback"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel>Go LIVE Feedback</FormLabel>
                      <FormControl>
                        <Textarea 
                          placeholder="Post go-live feedback and observations..."
                          {...field} 
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
              </div>
              
              <FormField
                control={form.control}
                name="projectSignOffDetails"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Project Sign off Details</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Final sign-off details and approvals..."
                        {...field} 
                      />
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />
            </CardContent>
          </Card>

          {/* Remarks */}
          <Card>
            <CardHeader>
              <CardTitle>Remarks</CardTitle>
            </CardHeader>
            <CardContent>
              <FormField
                control={form.control}
                name="remarks"
                render={({ field }) => (
                  <FormItem>
                    <FormLabel>Additional Remarks</FormLabel>
                    <FormControl>
                      <Textarea 
                        placeholder="Any additional comments or special considerations..."
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

          <div className="flex justify-end space-x-2 pt-6">
            <Button type="button" variant="outline" onClick={() => form.reset()}>
              Reset Form
            </Button>
            <Button 
              type="submit" 
              disabled={isSubmitting || submitMutation.isPending}
              className="bg-blue-600 hover:bg-blue-700"
            >
              {isSubmitting || submitMutation.isPending ? "Submitting..." : "Submit RPA Project Request"}
            </Button>
          </div>
        </form>
      </Form>
    </div>
  );
}