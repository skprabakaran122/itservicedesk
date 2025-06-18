import { Button } from "@/components/ui/button";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { SlidersHorizontal, Wifi, Car, Dumbbell, Bus, Utensils } from "lucide-react";

interface FiltersBarProps {
  selectedFilters: string[];
  onFilterToggle: (filter: string) => void;
  sortBy: string;
  onSortChange: (sort: string) => void;
}

export default function FiltersBar({ selectedFilters, onFilterToggle, sortBy, onSortChange }: FiltersBarProps) {
  const filters = [
    { id: "wifi", label: "WiFi Included", icon: Wifi },
    { id: "parking", label: "Parking", icon: Car },
    { id: "gym", label: "Gym", icon: Dumbbell },
    { id: "shuttle", label: "Campus Shuttle", icon: Bus },
    { id: "meal", label: "Meal Plan", icon: Utensils },
  ];

  return (
    <section className="bg-white border-b border-gray-200 py-4 sticky top-16 z-30">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4 overflow-x-auto">
            <Button 
              variant="secondary"
              className="flex items-center space-x-2 px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-full whitespace-nowrap"
            >
              <SlidersHorizontal size={16} />
              <span>All Filters</span>
            </Button>
            
            {filters.map((filter) => {
              const Icon = filter.icon;
              const isSelected = selectedFilters.includes(filter.id);
              
              return (
                <Button
                  key={filter.id}
                  variant="outline"
                  onClick={() => onFilterToggle(filter.id)}
                  className={`flex items-center space-x-2 px-4 py-2 rounded-full whitespace-nowrap transition-colors ${
                    isSelected 
                      ? 'bg-primary text-white border-primary hover:bg-primary/90' 
                      : 'border-gray-300 hover:border-primary hover:text-primary'
                  }`}
                >
                  <Icon size={16} />
                  <span>{filter.label}</span>
                </Button>
              );
            })}
          </div>
          
          <div className="flex items-center space-x-2">
            <span className="text-sm text-gray-600">Sort by:</span>
            <Select value={sortBy} onValueChange={onSortChange}>
              <SelectTrigger className="px-3 py-1 border border-gray-300 rounded-md text-sm focus:ring-2 focus:ring-primary focus:border-transparent min-w-[160px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="price-low">Price: Low to High</SelectItem>
                <SelectItem value="price-high">Price: High to Low</SelectItem>
                <SelectItem value="distance">Distance to Campus</SelectItem>
                <SelectItem value="newest">Newest</SelectItem>
                <SelectItem value="rating">Highest Rated</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </div>
    </section>
  );
}
