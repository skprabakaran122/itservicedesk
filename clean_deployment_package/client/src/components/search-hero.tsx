import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { MapPin, Search } from "lucide-react";

export default function SearchHero() {
  return (
    <section className="bg-gradient-to-br from-primary to-indigo-700 text-white py-16">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
        <h1 className="text-4xl md:text-5xl font-bold mb-4">
          Find Your Perfect Student Home
        </h1>
        <p className="text-xl text-indigo-100 mb-8">
          Discover affordable, student-friendly housing near your campus
        </p>
        
        <div className="bg-white rounded-2xl p-6 shadow-2xl">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
            <div className="relative">
              <Label className="block text-sm font-medium text-gray-700 mb-1">
                Location
              </Label>
              <div className="relative">
                <MapPin className="absolute left-3 top-3 text-gray-400" size={16} />
                <Input 
                  type="text" 
                  placeholder="University or city" 
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent text-gray-900"
                />
              </div>
            </div>
            
            <div>
              <Label className="block text-sm font-medium text-gray-700 mb-1">
                Move-in Date
              </Label>
              <Input 
                type="date" 
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent text-gray-900"
              />
            </div>
            
            <div>
              <Label className="block text-sm font-medium text-gray-700 mb-1">
                Budget
              </Label>
              <Select>
                <SelectTrigger className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent text-gray-900">
                  <SelectValue placeholder="Select budget" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="500-800">$500-800/month</SelectItem>
                  <SelectItem value="800-1200">$800-1200/month</SelectItem>
                  <SelectItem value="1200-1500">$1200-1500/month</SelectItem>
                  <SelectItem value="1500+">$1500+/month</SelectItem>
                </SelectContent>
              </Select>
            </div>
            
            <div>
              <Label className="block text-sm font-medium text-gray-700 mb-1">
                Roommates
              </Label>
              <Select>
                <SelectTrigger className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary focus:border-transparent text-gray-900">
                  <SelectValue placeholder="Select roommates" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="1-2">1-2 roommates</SelectItem>
                  <SelectItem value="3-4">3-4 roommates</SelectItem>
                  <SelectItem value="5+">5+ roommates</SelectItem>
                  <SelectItem value="none">No roommates</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          
          <Button className="w-full bg-primary hover:bg-indigo-700 text-white font-semibold py-3 px-6 rounded-lg">
            <Search className="mr-2" size={16} />
            Search Properties
          </Button>
        </div>
      </div>
    </section>
  );
}
