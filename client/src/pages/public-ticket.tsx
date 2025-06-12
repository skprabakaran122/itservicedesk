import { AnonymousTicketForm } from "@/components/anonymous-ticket-form";
import { AnonymousTicketSearchNew } from "@/components/anonymous-ticket-search-new";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Link } from "wouter";
import { ArrowLeft, Headphones, Search, Plus } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import type { Product } from "@shared/schema";
import { Skeleton } from "@/components/ui/skeleton";

export default function PublicTicketPage() {
  // Fetch products once at the parent level to avoid duplicate API calls
  const { data: products = [], isLoading: productsLoading } = useQuery<Product[]>({
    queryKey: ['/api/products'],
    retry: false,
  });

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800 py-8 px-4">
      <div className="container mx-auto max-w-4xl">
        {/* Header */}
        <div className="text-center mb-8">
          <div className="flex items-center justify-center mb-4">
            <Headphones className="h-12 w-12 text-blue-600" />
          </div>
          <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2">
            Calpion IT Support
          </h1>
          <p className="text-xl text-gray-600 dark:text-gray-300">
            Get help with your IT issues - no account required
          </p>
        </div>

        {/* Main Content with Tabs */}
        <Tabs defaultValue="submit" className="w-full">
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
            {productsLoading ? (
              <Card>
                <CardHeader>
                  <Skeleton className="h-6 w-1/3" />
                  <Skeleton className="h-4 w-2/3" />
                </CardHeader>
                <CardContent className="space-y-4">
                  <Skeleton className="h-10 w-full" />
                  <Skeleton className="h-10 w-full" />
                  <Skeleton className="h-24 w-full" />
                  <Skeleton className="h-10 w-1/4" />
                </CardContent>
              </Card>
            ) : (
              <AnonymousTicketForm products={products} productsLoading={productsLoading} />
            )}
          </TabsContent>
          
          <TabsContent value="search">
            {productsLoading ? (
              <Card>
                <CardHeader>
                  <Skeleton className="h-6 w-1/3" />
                  <Skeleton className="h-4 w-2/3" />
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="grid grid-cols-1 md:grid-cols-4 gap-2">
                    <Skeleton className="h-10 w-full" />
                    <Skeleton className="h-10 w-full md:col-span-2" />
                    <Skeleton className="h-10 w-full" />
                  </div>
                </CardContent>
              </Card>
            ) : (
              <AnonymousTicketSearchNew products={products} productsLoading={productsLoading} />
            )}
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