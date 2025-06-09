import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Heart, MapPin, Bed, Bath, Users, Maximize, Star } from "lucide-react";
import { type Property } from "@shared/schema";
import { useState } from "react";

interface PropertyCardProps {
  property: Property;
}

export default function PropertyCard({ property }: PropertyCardProps) {
  const [isFavorited, setIsFavorited] = useState(false);

  const getStatusColor = (status: string) => {
    switch (status.toLowerCase()) {
      case "available now":
        return "bg-secondary text-white";
      case "move-in special":
        return "bg-accent text-white";
      case "limited time":
        return "bg-red-500 text-white";
      default:
        return "bg-gray-500 text-white";
    }
  };

  const getAmenityColor = (amenity: string) => {
    if (amenity.toLowerCase().includes("wifi")) return "bg-blue-100 text-blue-800";
    if (amenity.toLowerCase().includes("gym")) return "bg-green-100 text-green-800";
    if (amenity.toLowerCase().includes("study") || amenity.toLowerCase().includes("rooftop")) return "bg-purple-100 text-purple-800";
    if (amenity.toLowerCase().includes("parking")) return "bg-orange-100 text-orange-800";
    if (amenity.toLowerCase().includes("pet")) return "bg-yellow-100 text-yellow-800";
    if (amenity.toLowerCase().includes("garden") || amenity.toLowerCase().includes("laundry")) return "bg-green-100 text-green-800";
    if (amenity.toLowerCase().includes("utilities") || amenity.toLowerCase().includes("security")) return "bg-blue-100 text-blue-800";
    return "bg-gray-100 text-gray-800";
  };

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-lg transition-shadow">
      <div className="flex flex-col md:flex-row">
        <div className="md:w-1/3 relative">
          <img 
            src={property.imageUrl} 
            alt={property.title}
            className="w-full h-48 md:h-full object-cover"
          />
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setIsFavorited(!isFavorited)}
            className="absolute top-3 right-3 w-8 h-8 bg-white rounded-full shadow-md hover:bg-gray-50"
          >
            <Heart 
              className={`text-gray-600 ${isFavorited ? 'fill-red-500 text-red-500' : ''}`} 
              size={16} 
            />
          </Button>
          <div className={`absolute bottom-3 left-3 px-2 py-1 rounded text-sm font-medium ${getStatusColor(property.availabilityStatus)}`}>
            {property.availabilityStatus}
          </div>
        </div>
        
        <div className="md:w-2/3 p-6">
          <div className="flex justify-between items-start mb-3">
            <div>
              <h3 className="text-xl font-semibold text-gray-900 mb-1">
                {property.title}
              </h3>
              <p className="text-gray-600 flex items-center">
                <MapPin className="mr-1" size={16} />
                {property.address}
              </p>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold text-gray-900">${property.rent}</div>
              <div className="text-sm text-gray-600">/month</div>
            </div>
          </div>
          
          <div className="flex items-center space-x-4 mb-4 text-sm text-gray-600">
            <span className="flex items-center">
              <Bed className="mr-1" size={16} />
              {property.bedrooms}
            </span>
            <span className="flex items-center">
              <Bath className="mr-1" size={16} />
              {property.bathrooms}
            </span>
            <span className="flex items-center">
              <Users className="mr-1" size={16} />
              {property.roommates}
            </span>
            <span className="flex items-center">
              <Maximize className="mr-1" size={16} />
              {property.squareFootage} sq ft
            </span>
          </div>
          
          <div className="flex flex-wrap gap-2 mb-4">
            {property.amenities.map((amenity, index) => (
              <Badge 
                key={index}
                variant="secondary"
                className={`px-2 py-1 text-xs rounded-full ${getAmenityColor(amenity)}`}
              >
                {amenity}
              </Badge>
            ))}
          </div>
          
          <div className="flex items-center justify-between">
            <div className="flex items-center">
              <div className="flex items-center">
                <Star className="text-amber-400 fill-amber-400" size={16} />
                <span className="ml-1 font-medium">{property.rating}</span>
                <span className="ml-1 text-gray-600 text-sm">
                  ({property.reviewCount} reviews)
                </span>
              </div>
            </div>
            <Button className="bg-primary hover:bg-indigo-700 text-white px-6 py-2 rounded-lg font-medium">
              View Details
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
