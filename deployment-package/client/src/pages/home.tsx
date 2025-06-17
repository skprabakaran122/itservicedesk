import Header from "@/components/header";
import SearchHero from "@/components/search-hero";
import FiltersBar from "@/components/filters-bar";
import PropertyCard from "@/components/property-card";
import MapView from "@/components/map-view";
import ChatbotWidget from "@/components/chatbot-widget";
import Footer from "@/components/footer";
import { useQuery } from "@tanstack/react-query";
import { type Property } from "@shared/schema";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";

export default function Home() {
  const [selectedFilters, setSelectedFilters] = useState<string[]>([]);
  const [sortBy, setSortBy] = useState<string>("price-low");

  const { data: properties = [], isLoading } = useQuery<Property[]>({
    queryKey: ["/api/properties"],
  });

  const filteredProperties = properties.filter(property => {
    if (selectedFilters.length === 0) return true;
    return selectedFilters.every(filter => 
      property.amenities.some(amenity => 
        amenity.toLowerCase().includes(filter.toLowerCase())
      )
    );
  });

  const sortedProperties = [...filteredProperties].sort((a, b) => {
    switch (sortBy) {
      case "price-low":
        return a.rent - b.rent;
      case "price-high":
        return b.rent - a.rent;
      case "rating":
        return parseFloat(b.rating) - parseFloat(a.rating);
      default:
        return 0;
    }
  });

  const toggleFilter = (filter: string) => {
    setSelectedFilters(prev => 
      prev.includes(filter) 
        ? prev.filter(f => f !== filter)
        : [...prev, filter]
    );
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <SearchHero />
        <FiltersBar 
          selectedFilters={selectedFilters}
          onFilterToggle={toggleFilter}
          sortBy={sortBy}
          onSortChange={setSortBy}
        />
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex flex-col lg:flex-row gap-8">
            <div className="flex-1">
              <div className="mb-6">
                <Skeleton className="h-8 w-48 mb-2" />
                <Skeleton className="h-5 w-64" />
              </div>
              <div className="grid gap-6">
                {[1, 2, 3].map((i) => (
                  <div key={i} className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
                    <div className="flex flex-col md:flex-row">
                      <Skeleton className="md:w-1/3 h-48 md:h-64" />
                      <div className="md:w-2/3 p-6">
                        <Skeleton className="h-6 w-3/4 mb-2" />
                        <Skeleton className="h-4 w-1/2 mb-4" />
                        <div className="flex gap-4 mb-4">
                          <Skeleton className="h-4 w-16" />
                          <Skeleton className="h-4 w-16" />
                          <Skeleton className="h-4 w-20" />
                        </div>
                        <div className="flex gap-2 mb-4">
                          <Skeleton className="h-6 w-20" />
                          <Skeleton className="h-6 w-16" />
                          <Skeleton className="h-6 w-24" />
                        </div>
                        <div className="flex justify-between items-center">
                          <Skeleton className="h-4 w-32" />
                          <Skeleton className="h-10 w-28" />
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div className="lg:w-2/5">
              <div className="sticky top-32">
                <Skeleton className="h-96 rounded-xl" />
              </div>
            </div>
          </div>
        </div>
        <Footer />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Header />
      <SearchHero />
      <FiltersBar 
        selectedFilters={selectedFilters}
        onFilterToggle={toggleFilter}
        sortBy={sortBy}
        onSortChange={setSortBy}
      />
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex flex-col lg:flex-row gap-8">
          <div className="flex-1">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">
                {sortedProperties.length} properties found
              </h2>
              <p className="text-gray-600">Near University of California, Berkeley</p>
            </div>

            <div className="grid gap-6">
              {sortedProperties.map((property) => (
                <PropertyCard key={property.id} property={property} />
              ))}
            </div>

            {sortedProperties.length > 0 && (
              <div className="text-center mt-8">
                <Button 
                  variant="outline" 
                  className="bg-white border-gray-300 hover:border-primary hover:text-primary"
                >
                  Load More Properties
                </Button>
              </div>
            )}

            {sortedProperties.length === 0 && (
              <div className="text-center py-12">
                <p className="text-gray-600 text-lg">No properties match your current filters.</p>
                <p className="text-gray-500 mt-2">Try adjusting your search criteria.</p>
              </div>
            )}
          </div>

          <div className="lg:w-2/5">
            <MapView properties={sortedProperties} />
          </div>
        </div>
      </div>

      <ChatbotWidget />
      <Footer />
    </div>
  );
}
