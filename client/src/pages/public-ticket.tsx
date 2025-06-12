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

export default function PublicTicketPage() {
  const [activeTab, setActiveTab] = useState("submit");
  
  // Only fetch products when needed (when tabs are accessed)
  const { data: products = [], isLoading: productsLoading } = useQuery<Product[]>({
    queryKey: ['/api/products'],
    retry: false,
    staleTime: 5 * 60 * 1000, // 5 minutes
    refetchOnMount: false,
    refetchOnWindowFocus: false,
    enabled: activeTab === "submit" || activeTab === "search", // Only fetch when tabs need it
  });

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 py-8 px-4">
      <div className="container mx-auto max-w-4xl">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-6">
            {/* Calpion Logo */}
            <div className="relative">
              <svg
                width="120"
                height="60"
                viewBox="0 0 120 60"
                className="drop-shadow-lg"
                xmlns="http://www.w3.org/2000/svg"
              >
                {/* Background circle */}
                <circle
                  cx="30"
                  cy="30"
                  r="28"
                  fill="url(#gradient1)"
                  stroke="#1e40af"
                  strokeWidth="2"
                />
                
                {/* Letter C */}
                <path
                  d="M 20 15 Q 15 15 15 30 Q 15 45 20 45 Q 25 45 30 40"
                  stroke="#ffffff"
                  strokeWidth="4"
                  fill="none"
                  strokeLinecap="round"
                />
                
                {/* Company name */}
                <text
                  x="65"
                  y="25"
                  fontFamily="Arial, sans-serif"
                  fontSize="18"
                  fontWeight="bold"
                  fill="#1e40af"
                  className="dark:fill-white"
                >
                  CALPION
                </text>
                
                <text
                  x="65"
                  y="42"
                  fontFamily="Arial, sans-serif"
                  fontSize="10"
                  fill="#64748b"
                  className="dark:fill-gray-300"
                >
                  IT SERVICES
                </text>
                
                {/* Gradient definitions */}
                <defs>
                  <linearGradient id="gradient1" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stopColor="#3b82f6" />
                    <stop offset="100%" stopColor="#1e40af" />
                  </linearGradient>
                </defs>
              </svg>
            </div>
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
          <TabsList className="grid w-full grid-cols-2 mb-6">
            <TabsTrigger value="submit" className="flex items-center gap-2">
              <Plus className="h-4 w-4" />
              Submit New Ticket
            </TabsTrigger>
            <TabsTrigger value="search" className="flex items-center gap-2">
              <Search className="h-4 w-4" />
              Search Your Tickets
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