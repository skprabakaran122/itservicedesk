import { Switch, Route } from "wouter";
import { useState, useEffect } from "react";
import { queryClient } from "./lib/queryClient";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import Dashboard from "@/pages/dashboard";
import Login from "@/pages/login";
import PublicTicketPage from "@/pages/public-ticket";
import NotFound from "@/pages/not-found";

function Router({ currentUser, onLogout }: { currentUser: any; onLogout: () => void }) {
  return (
    <Switch>
      <Route path="/support" component={PublicTicketPage} />
      <Route path="/">
        {currentUser ? (
          <Dashboard currentUser={currentUser} onLogout={onLogout} />
        ) : (
          <Login onLoginSuccess={(user) => window.location.reload()} />
        )}
      </Route>
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check if user session exists on the server
    const checkSession = async () => {
      try {
        const response = await fetch('/api/auth/me', {
          credentials: 'include'
        });
        if (response.ok) {
          const data = await response.json();
          setCurrentUser(data.user);
        }
      } catch (error) {
        console.log('No active session');
      }
      setIsLoading(false);
    };
    
    checkSession();
  }, []);

  const handleLogin = (user: any) => {
    setCurrentUser(user);
  };

  const handleLogout = async () => {
    try {
      await fetch('/api/auth/logout', {
        method: 'POST',
        credentials: 'include'
      });
    } catch (error) {
      console.log('Logout error:', error);
    }
    setCurrentUser(null);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto"></div>
          <p className="mt-2 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        {!currentUser ? (
          <Login onLoginSuccess={handleLogin} />
        ) : (
          <Router currentUser={currentUser} onLogout={handleLogout} />
        )}
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
