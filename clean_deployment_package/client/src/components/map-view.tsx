import { Button } from "@/components/ui/button";
import { MapPin, Expand } from "lucide-react";
import { type Property } from "@shared/schema";

interface MapViewProps {
  properties: Property[];
}

export default function MapView({ properties }: MapViewProps) {
  return (
    <div className="sticky top-32">
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="h-96 bg-gray-100 relative">
          <img 
            src="https://images.unsplash.com/photo-1524813686514-bb0cfcc17627?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&h=600"
            alt="Berkeley campus map" 
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-black bg-opacity-20 flex items-center justify-center">
            <div className="text-center text-white">
              <MapPin className="text-4xl mb-2 mx-auto" size={48} />
              <p className="font-medium">Interactive Map</p>
              <p className="text-sm opacity-90">View properties on map</p>
            </div>
          </div>
          
          {/* Map Markers */}
          {properties.slice(0, 3).map((property, index) => {
            const positions = [
              { top: '16%', left: '20%' },
              { top: '32%', right: '24%' },
              { bottom: '20%', left: '16%' }
            ];
            
            const position = positions[index] || positions[0];
            
            return (
              <div 
                key={property.id}
                className="absolute w-auto h-8 bg-primary rounded-full flex items-center justify-center text-white font-bold text-sm shadow-lg px-2 min-w-[3rem]"
                style={position}
              >
                ${property.rent}
              </div>
            );
          })}
        </div>
        
        <div className="p-4 border-t border-gray-200">
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600">Zoom to fit all properties</span>
            <Button 
              variant="ghost" 
              className="text-primary hover:text-indigo-700 font-medium p-0"
            >
              <Expand className="mr-1" size={16} />
              Fullscreen
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
