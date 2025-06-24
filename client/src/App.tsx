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
          <Dashboard currentUser={currentUser} onLogout={onLogout} />
        ) : (
          <Login onLoginSuccess={onLogin} />
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
    // Defer authentication check to not block initial render
    const timeoutId = setTimeout(async () => {
      try {
        const response = await fetch('/api/auth/me', {
          credentials: 'include'
        });
        if (response.ok) {
          const data = await response.json();
          setCurrentUser(data.user);
        }
      } catch (error) {
        // Silent fail for auth check
      }
      setIsLoading(false);
    }, 50); // Minimal delay to allow initial render

    return () => clearTimeout(timeoutId);
  }, []);

  const handleLogin = (user: any) => {
    console.log('Setting current user:', user);
    setCurrentUser(user);
    // Force a re-render to trigger navigation
    setTimeout(() => {
      window.location.href = '/';
    }, 100);
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