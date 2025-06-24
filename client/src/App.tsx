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
import { ForgotPasswordPage } from "@/pages/forgot-password";
import { ResetPasswordPage } from "@/pages/reset-password";

function Router({ currentUser, onLogout, onLogin }: { currentUser: any; onLogout: () => void; onLogin: (user: any) => void }) {
  return (
    <Switch>
      <Route path="/support" component={PublicTicketPage} />
      <Route path="/public-ticket" component={PublicTicketPage} />
      <Route path="/forgot-password" component={ForgotPasswordPage} />
      <Route path="/reset-password" component={ResetPasswordPage} />
      <Route path="/admin">
        {currentUser ? (
          <Dashboard currentUser={currentUser} onLogout={onLogout} initialTab="admin" />
        ) : (
          <Login onLoginSuccess={onLogin} />
        )}
      </Route>
      <Route path="/dashboard">
        {currentUser ? (
          <Dashboard currentUser={currentUser} onLogout={onLogout} />
        ) : (
          <Login onLoginSuccess={onLogin} />
        )}
      </Route>
      <Route path="/login">
        <Login onLoginSuccess={onLogin} />
      </Route>
      <Route path="/">
        {currentUser ? (
          <>
            {console.log('Rendering Dashboard for user:', currentUser)}
            <Dashboard currentUser={currentUser} onLogout={onLogout} />
          </>
        ) : (
          <>
            {console.log('Rendering Login page')}
            <Login onLoginSuccess={onLogin} />
          </>
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
    // Check authentication immediately on app load
    const checkAuth = async () => {
      try {
        const response = await fetch('/api/auth/me', {
          credentials: 'include'
        });
        if (response.ok) {
          const data = await response.json();
          setCurrentUser(data.user);
        }
      } catch (error) {
        console.log('Auth check failed:', error);
      }
      setIsLoading(false);
    };

    checkAuth();
  }, []);

  const handleLogin = (user: any) => {
    console.log('Setting current user:', user);
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
          <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-2 text-gray-600">Loading IT Service Desk...</p>
        </div>
      </div>
    );
  }

  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        <Router currentUser={currentUser} onLogout={handleLogout} onLogin={handleLogin} />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;