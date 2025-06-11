import { Button } from "@/components/ui/button";
import { Home, Menu, User } from "lucide-react";
import calpionLogo from "@assets/image_1749619432130.png";

export default function Header() {
  return (
    <header className="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-40">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <div className="flex items-center">
              <img 
                src={calpionLogo} 
                alt="Calpion Logo" 
                className="h-8 w-auto object-contain mr-3"
              />
              <span className="text-xl font-bold text-gray-900">IT Service Desk</span>
            </div>
          </div>
          
          <div className="flex items-center space-x-4">
            <div className="relative">
              <Button 
                variant="ghost" 
                className="flex items-center space-x-2 bg-gray-100 rounded-full p-2 hover:bg-gray-200"
              >
                <Menu className="text-gray-600" size={16} />
                <div className="w-8 h-8 bg-primary rounded-full flex items-center justify-center">
                  <User className="text-white" size={14} />
                </div>
              </Button>
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
