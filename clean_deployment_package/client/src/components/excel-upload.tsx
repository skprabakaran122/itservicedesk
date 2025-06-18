import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Upload, FileSpreadsheet, AlertCircle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

interface ExcelUploadProps {
  onFormStructureExtracted: (structure: any) => void;
}

export function ExcelUpload({ onFormStructureExtracted }: ExcelUploadProps) {
  const [isUploading, setIsUploading] = useState(false);
  const { toast } = useToast();

  const handleFileUpload = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!file.name.toLowerCase().endsWith('.xlsx') && !file.name.toLowerCase().endsWith('.xls')) {
      toast({
        title: "Invalid File Type",
        description: "Please upload an Excel file (.xlsx or .xls)",
        variant: "destructive",
      });
      return;
    }

    setIsUploading(true);
    const formData = new FormData();
    formData.append('excel', file);

    try {
      const response = await fetch('/api/parse-excel', {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        throw new Error('Failed to parse Excel file');
      }

      const result = await response.json();
      onFormStructureExtracted(result);
      
      toast({
        title: "Excel Parsed Successfully",
        description: "Form structure has been extracted from your Excel file.",
      });
    } catch (error) {
      toast({
        title: "Upload Failed", 
        description: "Could not parse the Excel file. Please check the format.",
        variant: "destructive",
      });
    } finally {
      setIsUploading(false);
    }
  };

  return (
    <Card className="w-full max-w-md mx-auto">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <FileSpreadsheet className="h-5 w-5" />
          Upload Excel Form Template
        </CardTitle>
        <CardDescription>
          Upload your "New Project Intake form" Excel file to automatically create the form structure.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid w-full max-w-sm items-center gap-1.5">
          <Label htmlFor="excel-file">Excel File</Label>
          <Input 
            id="excel-file" 
            type="file" 
            accept=".xlsx,.xls"
            onChange={handleFileUpload}
            disabled={isUploading}
          />
        </div>
        
        <div className="flex items-center gap-2 p-3 bg-blue-50 dark:bg-blue-950 rounded-lg">
          <AlertCircle className="h-4 w-4 text-blue-600" />
          <div className="text-sm text-blue-800 dark:text-blue-200">
            <strong>Note:</strong> The form will be automatically generated based on your Excel template structure.
          </div>
        </div>

        {isUploading && (
          <div className="flex items-center justify-center p-4">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            <span className="ml-2">Parsing Excel file...</span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}