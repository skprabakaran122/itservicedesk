import { Home } from "lucide-react";

export default function Footer() {
  return (
    <footer className="bg-gray-900 text-white py-12 mt-16">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          <div>
            <div className="flex items-center mb-4">
              <Home className="text-2xl text-primary mr-2" />
              <span className="text-xl font-bold">CampusNest</span>
            </div>
            <p className="text-gray-400 mb-4">
              Making student housing search simple and affordable for college students nationwide.
            </p>
            <div className="flex space-x-4">
              <a href="#" className="text-gray-400 hover:text-white transition-colors">
                <i className="fab fa-facebook"></i>
              </a>
              <a href="#" className="text-gray-400 hover:text-white transition-colors">
                <i className="fab fa-twitter"></i>
              </a>
              <a href="#" className="text-gray-400 hover:text-white transition-colors">
                <i className="fab fa-instagram"></i>
              </a>
            </div>
          </div>
          
          <div>
            <h3 className="font-semibold mb-4">For Students</h3>
            <ul className="space-y-2 text-gray-400">
              <li><a href="#" className="hover:text-white transition-colors">Search Housing</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Housing Guide</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Roommate Finder</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Budget Calculator</a></li>
            </ul>
          </div>
          
          <div>
            <h3 className="font-semibold mb-4">For Landlords</h3>
            <ul className="space-y-2 text-gray-400">
              <li><a href="#" className="hover:text-white transition-colors">List Property</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Pricing Tools</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Property Management</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Resources</a></li>
            </ul>
          </div>
          
          <div>
            <h3 className="font-semibold mb-4">Support</h3>
            <ul className="space-y-2 text-gray-400">
              <li><a href="#" className="hover:text-white transition-colors">Help Center</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Contact Us</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Trust & Safety</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Terms of Service</a></li>
            </ul>
          </div>
        </div>
        
        <div className="border-t border-gray-800 mt-8 pt-8 text-center text-gray-400">
          <p>&copy; 2024 CampusNest. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
