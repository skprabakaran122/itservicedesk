import { Button } from "@/components/ui/button";
import { Home, Menu, User } from "lucide-react";

export default function Header() {
  return (
    <header className="bg-white shadow-sm border-b border-gray-200 sticky top-0 z-40">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <div className="flex items-center">
              <Home className="text-2xl text-primary mr-2" />
              <span className="text-xl font-bold text-gray-900">CampusNest</span>
            </div>
            <nav className="hidden md:flex space-x-8">
              <a href="#" className="text-gray-900 font-medium hover:text-primary transition-colors">
                Browse
              </a>
              <a href="#" className="text-gray-600 hover:text-primary transition-colors">
                Saved
              </a>
              <a href="#" className="text-gray-600 hover:text-primary transition-colors">
                Messages
              </a>
            </nav>
          </div>
          
          <div className="flex items-center space-x-4">
            <Button 
              variant="ghost" 
              className="hidden md:block text-gray-600 hover:text-primary font-medium"
            >
              List Your Property
            </Button>
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
