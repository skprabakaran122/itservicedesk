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

export function AnonymousTicketSearchNew({ onClose }: AnonymousTicketSearchProps) {
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
      case 'in progress': return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300';
      case 'resolved': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      case 'closed': return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority.toLowerCase()) {
      case 'low': return 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-300';
      case 'medium': return 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300';
      case 'high': return 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-300';
      case 'critical': return 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-300';
      default: return 'bg-gray-100 text-gray-800 dark:bg-gray-900 dark:text-gray-300';
    }
  };

  const getCategoryIcon = (category: string) => {
    switch (category.toLowerCase()) {
      case 'hardware': return <Package className="h-4 w-4" />;
      case 'software': return <FileText className="h-4 w-4" />;
      case 'network': return <AlertCircle className="h-4 w-4" />;
      case 'access': return <User className="h-4 w-4" />;
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
            Find your submitted tickets by entering search terms and optionally filtering by products.
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

      {/* Search Results */}
      {searchTriggered && (
        <Card>
          <CardHeader>
            <CardTitle>Search Results</CardTitle>
            {searchResults.length > 0 && (
              <CardDescription>
                Found {searchResults.length} ticket{searchResults.length !== 1 ? 's' : ''} matching your search
              </CardDescription>
            )}
          </CardHeader>
          <CardContent>
            {isLoading && (
              <div className="flex justify-center py-8">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
              </div>
            )}

            {error && (
              <Alert className="mb-4">
                <AlertCircle className="h-4 w-4" />
                <AlertDescription>
                  Failed to search tickets. Please try again.
                </AlertDescription>
              </Alert>
            )}

            {!isLoading && !error && searchResults.length === 0 && (
              <div className="text-center py-8 text-muted-foreground">
                <Search className="h-12 w-12 mx-auto mb-4 opacity-50" />
                <p>No tickets found matching your search criteria.</p>
                <p className="text-sm mt-2">Try different keywords or adjust your filters.</p>
              </div>
            )}

            {!isLoading && !error && searchResults.length > 0 && (
              <div className="space-y-4">
                {searchResults.map((ticket) => (
                  <Card key={ticket.id} className="hover:shadow-md transition-shadow">
                    <CardContent className="p-4">
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-2">
                            {getCategoryIcon(ticket.category)}
                            <span className="font-medium">#{ticket.id}</span>
                            <Badge className={getStatusColor(ticket.status)}>
                              {ticket.status}
                            </Badge>
                            <Badge className={getPriorityColor(ticket.priority)}>
                              {ticket.priority}
                            </Badge>
                          </div>
                          
                          <h3 className="font-semibold text-lg mb-2">{ticket.title}</h3>
                          
                          <p className="text-muted-foreground mb-3 line-clamp-2">
                            {ticket.description}
                          </p>
                          
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
                            <div className="space-y-1">
                              <div className="flex items-center gap-2">
                                <User className="h-4 w-4" />
                                <span className="font-medium">Submitted by:</span>
                                <span>{ticket.requesterName}</span>
                              </div>
                              {ticket.requesterEmail && (
                                <div className="flex items-center gap-2">
                                  <span className="font-medium">Email:</span>
                                  <span>{ticket.requesterEmail}</span>
                                </div>
                              )}
                              {ticket.product && (
                                <div className="flex items-center gap-2">
                                  <Package className="h-4 w-4" />
                                  <span className="font-medium">Product:</span>
                                  <span>{ticket.product}</span>
                                </div>
                              )}
                            </div>
                            
                            <div className="space-y-1">
                              <div className="flex items-center gap-2">
                                <Clock className="h-4 w-4" />
                                <span className="font-medium">Created:</span>
                                <span>{format(new Date(ticket.createdAt), 'MMM d, yyyy HH:mm')}</span>
                              </div>
                              <div className="flex items-center gap-2">
                                <span className="font-medium">Updated:</span>
                                <span>{format(new Date(ticket.updatedAt), 'MMM d, yyyy HH:mm')}</span>
                              </div>
                              {ticket.assignedTo && (
                                <div className="flex items-center gap-2">
                                  <span className="font-medium">Assigned to:</span>
                                  <span>{ticket.assignedTo}</span>
                                </div>
                              )}
                            </div>
                          </div>
                        </div>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      )}
    </div>
  );
}