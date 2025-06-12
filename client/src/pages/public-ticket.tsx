import { lazy, Suspense, useState } from "react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Link } from "wouter";
import { ArrowLeft, Headphones, Search, Plus } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import type { Product } from "@shared/schema";
import { Skeleton } from "@/components/ui/skeleton";


// Lazy load heavy components
const AnonymousTicketForm = lazy(() => import("@/components/anonymous-ticket-form").then(module => ({ default: module.AnonymousTicketForm })));
const AnonymousTicketSearchNew = lazy(() => import("@/components/anonymous-ticket-search-new").then(module => ({ default: module.AnonymousTicketSearchNew })));
const CalpionProjectIntakeForm = lazy(() => import("@/components/calpion-project-intake-form").then(module => ({ default: module.CalpionProjectIntakeForm })));

export default function PublicTicketPage() {
  const [activeTab, setActiveTab] = useState("submit");
  
  // Only fetch products when needed (when tabs are accessed)
  const { data: products = [], isLoading: productsLoading } = useQuery<Product[]>({
    queryKey: ['/api/products'],
    retry: false,
    staleTime: 5 * 60 * 1000, // 5 minutes
    refetchOnMount: false,
    refetchOnWindowFocus: false,
    enabled: activeTab === "submit" || activeTab === "search" || activeTab === "project", // Only fetch when tabs need it
  });

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 py-8 px-4">
      <div className="container mx-auto max-w-4xl">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-6">
            {/* Calpion Logo */}
            <img
              src="/calpion-logo.png"
              alt="Calpion - Experience Excellence"
              className="h-16 drop-shadow-lg"
            />
          </div>
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2">
            Support Portal
          </h1>
          <p className="text-xl text-gray-600 dark:text-gray-300">
            Get help with your IT issues - no account required
          </p>
        </div>

        {/* Main Content with Tabs */}
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="grid w-full grid-cols-3 mb-6">
            <TabsTrigger value="submit" className="flex items-center gap-2">
              <Plus className="h-4 w-4" />
              Submit Ticket
            </TabsTrigger>
            <TabsTrigger value="project" className="flex items-center gap-2">
              <Headphones className="h-4 w-4" />
              Project Intake
            </TabsTrigger>
            <TabsTrigger value="search" className="flex items-center gap-2">
              <Search className="h-4 w-4" />
              Search Tickets
            </TabsTrigger>
          </TabsList>
          
          <TabsContent value="submit">
            <Suspense fallback={
              <Card>
                <CardHeader>
                  <Skeleton className="h-6 w-48" />
                  <Skeleton className="h-4 w-64" />
                </CardHeader>
                <CardContent className="space-y-4">
                  <Skeleton className="h-10 w-full" />
                  <Skeleton className="h-32 w-full" />
                  <Skeleton className="h-10 w-32" />
                </CardContent>
              </Card>
            }>
              <AnonymousTicketForm products={products} productsLoading={productsLoading} />
            </Suspense>
          </TabsContent>

          <TabsContent value="project">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Headphones className="h-5 w-5" />
                  New Project Intake Request
                </CardTitle>
                <CardDescription>
                  Submit a request for a new project or initiative. All fields are required for proper evaluation.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <Suspense fallback={
                  <div className="space-y-4">
                    <Skeleton className="h-10 w-full" />
                    <Skeleton className="h-32 w-full" />
                    <Skeleton className="h-10 w-full" />
                    <Skeleton className="h-32 w-full" />
                    <Skeleton className="h-10 w-32" />
                  </div>
                }>
                  <ProjectIntakeForm />
                </Suspense>
              </CardContent>
            </Card>
          </TabsContent>
          
          <TabsContent value="search">
            <Suspense fallback={
              <Card>
                <CardHeader>
                  <Skeleton className="h-6 w-48" />
                  <Skeleton className="h-4 w-64" />
                </CardHeader>
                <CardContent className="space-y-4">
                  <Skeleton className="h-10 w-full" />
                  <Skeleton className="h-32 w-full" />
                  <Skeleton className="h-10 w-32" />
                </CardContent>
              </Card>
            }>
              <AnonymousTicketSearchNew products={products} productsLoading={productsLoading} />
            </Suspense>
          </TabsContent>
        </Tabs>

        {/* Footer Information */}
        <div className="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Need Immediate Help?</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <p className="text-sm"><strong>Email:</strong> support@calpion.com</p>
              <p className="text-sm"><strong>Hours:</strong> 24/7 for critical issues</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="text-lg">Response Times</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <p className="text-sm"><strong>Critical:</strong> Within 1 hour</p>
              <p className="text-sm"><strong>High:</strong> Within 4 hours</p>
              <p className="text-sm"><strong>Medium:</strong> Within 24 hours</p>
              <p className="text-sm"><strong>Low:</strong> Within 48 hours</p>
            </CardContent>
          </Card>
        </div>

        {/* Login Option */}
        <div className="mt-8 text-center">
          <Card className="max-w-md mx-auto">
            <CardHeader>
              <CardTitle className="text-lg">Have an Account?</CardTitle>
              <CardDescription>
                Login to track your tickets and access additional features
              </CardDescription>
            </CardHeader>
            <CardContent>
              <Link href="/">
                <Button variant="outline" className="w-full">
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  Go to Login
                </Button>
              </Link>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}