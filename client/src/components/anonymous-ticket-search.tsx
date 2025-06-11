import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Search, Clock, AlertCircle, CheckCircle2, User, Package, FileText, Ticket as TicketIcon, X } from "lucide-react";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Separator } from "@/components/ui/separator";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { format } from "date-fns";
import type { Ticket, Product } from "@shared/schema";

interface AnonymousTicketSearchProps {
  onClose?: () => void;
}

export function AnonymousTicketSearch({ onClose }: AnonymousTicketSearchProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedProducts, setSelectedProducts] = useState<string[]>([]);
  const [searchTriggered, setSearchTriggered] = useState(false);

  // Fetch products for multi-select
  const { data: products = [] } = useQuery<Product[]>({
    queryKey: ['/api/products'],
    retry: false,
  });

  const { data: searchResults = [], isLoading, error } = useQuery<Ticket[]>({
    queryKey: ['/api/tickets/search/anonymous', searchQuery, selectedProducts],
    queryFn: async () => {
      const params = new URLSearchParams({
        q: searchQuery,
        searchBy: 'all'
      });
      
      // Add selected products as filter
      if (selectedProducts.length > 0) {
        params.append('products', selectedProducts.join(','));
      }
      
      const response = await fetch(`/api/tickets/search/anonymous?${params}`);
      if (!response.ok) {
        throw new Error('Failed to search tickets');
      }
      return response.json();
    },
    enabled: searchTriggered && searchQuery.length >= 2,
    retry: false,
  });

  const handleSearch = () => {
    if (searchQuery.trim().length >= 2) {
      setSearchTriggered(true);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch();
    }
  };

  const handleProductToggle = (productName: string) => {
    setSelectedProducts(prev => 
      prev.includes(productName) 
        ? prev.filter(p => p !== productName)
        : [...prev, productName]
    );
  };

  const removeProduct = (productName: string) => {
    setSelectedProducts(prev => prev.filter(p => p !== productName));
  };

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case 'open': return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300';
      case 'in-progress': return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300';
      case 'resolved': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      case 'closed': return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
      case 'pending': return 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300';
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority.toLowerCase()) {
      case 'critical': return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300';
      case 'high': return 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300';
      case 'medium': return 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-300';
      case 'low': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    }
  };

  const formatDate = (dateString: string | Date) => {
    const date = typeof dateString === 'string' ? new Date(dateString) : dateString;
    return format(date, 'MMM dd, yyyy HH:mm');
  };

  const getStatusIcon = (status: string) => {
    switch (status.toLowerCase()) {
      case 'open': return <AlertCircle className="h-4 w-4" />;
      case 'in-progress': return <Clock className="h-4 w-4" />;
      case 'resolved': return <CheckCircle2 className="h-4 w-4" />;
      case 'closed': return <CheckCircle2 className="h-4 w-4" />;
      default: return <TicketIcon className="h-4 w-4" />;
    }
  };

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-6 w-6" />
            Search Your Tickets
          </CardTitle>
          <CardDescription>
            Find your submitted tickets by selecting a search criteria and entering your search terms.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {/* Search Input */}
            <div className="flex gap-2">
              <Input
                placeholder="Enter ticket number, name, or keywords..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyPress={handleKeyPress}
                className="flex-1"
              />
              <Button onClick={handleSearch} disabled={searchQuery.length < 2}>
                <Search className="h-4 w-4 mr-2" />
                Search
              </Button>
            </div>

            {/* Product Multi-Select */}
            <div className="space-y-2">
              <label className="text-sm font-medium">Filter by Products (optional):</label>
              <Select onValueChange={handleProductToggle}>
                <SelectTrigger>
                  <SelectValue placeholder="Select products to filter..." />
                </SelectTrigger>
                <SelectContent>
                  {products.map((product) => (
                    <SelectItem key={product.id} value={product.name}>
                      {product.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>

              {/* Selected Products Display */}
              {selectedProducts.length > 0 && (
                <div className="flex flex-wrap gap-2 mt-2">
                  {selectedProducts.map((productName) => (
                    <Badge
                      key={productName}
                      variant="secondary"
                      className="flex items-center gap-1"
                    >
                      <Package className="h-3 w-3" />
                      {productName}
                      <X
                        className="h-3 w-3 cursor-pointer hover:text-red-500"
                        onClick={() => removeProduct(productName)}
                      />
                    </Badge>
                  ))}
                </div>
              )}
            </div>
          </div>
          {searchQuery.length > 0 && searchQuery.length < 2 && (
            <p className="text-sm text-muted-foreground mt-2">
              Please enter at least 2 characters to search
            </p>
          )}
        </CardContent>
      </Card>

      {isLoading && (
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
              <span className="ml-2">Searching tickets...</span>
            </div>
          </CardContent>
        </Card>
      )}

      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            Failed to search tickets. Please try again or contact support if the problem persists.
          </AlertDescription>
        </Alert>
      )}

      {searchTriggered && !isLoading && !error && (
        <div className="space-y-4">
          {searchResults.length === 0 ? (
            <Card>
              <CardContent className="p-6 text-center">
                <TicketIcon className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
                <h3 className="text-lg font-semibold mb-2">No tickets found</h3>
                <p className="text-muted-foreground">
                  No tickets match your search criteria. Try different keywords or check your ticket number.
                </p>
              </CardContent>
            </Card>
          ) : (
            <>
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-semibold">
                  Found {searchResults.length} ticket{searchResults.length === 1 ? '' : 's'}
                </h3>
              </div>
              
              {searchResults.map((ticket) => (
                <Card key={ticket.id} className="hover:shadow-md transition-shadow">
                  <CardContent className="p-6">
                    <div className="flex items-start justify-between mb-4">
                      <div className="flex items-center gap-2">
                        <Badge variant="outline" className="font-mono">
                          #{ticket.id}
                        </Badge>
                        <Badge className={getStatusColor(ticket.status)}>
                          {getStatusIcon(ticket.status)}
                          <span className="ml-1 capitalize">{ticket.status}</span>
                        </Badge>
                        <Badge className={getPriorityColor(ticket.priority)}>
                          <span className="capitalize">{ticket.priority}</span>
                        </Badge>
                      </div>
                      <div className="text-sm text-muted-foreground">
                        Created {formatDate(ticket.createdAt)}
                      </div>
                    </div>

                    <div className="space-y-3">
                      <div>
                        <h4 className="font-semibold text-lg mb-1">{ticket.title}</h4>
                        <p className="text-muted-foreground line-clamp-2">
                          {ticket.description}
                        </p>
                      </div>

                      <Separator />

                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
                        <div className="flex items-center gap-2">
                          <User className="h-4 w-4 text-muted-foreground" />
                          <span className="font-medium">Requester:</span>
                          <span>{ticket.requesterName}</span>
                        </div>
                        
                        {ticket.product && (
                          <div className="flex items-center gap-2">
                            <Package className="h-4 w-4 text-muted-foreground" />
                            <span className="font-medium">Product:</span>
                            <span>{ticket.product}</span>
                          </div>
                        )}
                        
                        <div className="flex items-center gap-2">
                          <FileText className="h-4 w-4 text-muted-foreground" />
                          <span className="font-medium">Category:</span>
                          <span className="capitalize">{ticket.category}</span>
                        </div>
                      </div>

                      {ticket.assignedTo && (
                        <div className="text-sm">
                          <span className="font-medium text-muted-foreground">Assigned to:</span>
                          <span className="ml-2">{ticket.assignedTo}</span>
                        </div>
                      )}

                      {ticket.resolvedAt && (
                        <div className="text-sm text-green-600 dark:text-green-400">
                          <span className="font-medium">Resolved:</span>
                          <span className="ml-2">{formatDate(ticket.resolvedAt)}</span>
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </>
          )}
        </div>
      )}

      <Card className="bg-muted/50">
        <CardContent className="p-4">
          <p className="text-sm text-muted-foreground">
            <strong>Search Tips:</strong> You can search by ticket number (e.g., "#123"), your name, 
            keywords from your issue description, or product name. Use specific terms for better results.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}