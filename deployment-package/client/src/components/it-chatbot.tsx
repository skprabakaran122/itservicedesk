import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { MessageCircle, X, Bot, Send } from "lucide-react";
import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";

interface ChatMessage {
  id: string;
  text: string;
  isUser: boolean;
  timestamp: Date;
}

export default function ITChatbot() {
  const [isOpen, setIsOpen] = useState(false);
  const [message, setMessage] = useState("");
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: "1",
      text: "Hello! I'm your IT Support assistant. How can I help you today? I can assist with tickets, password resets, software issues, and more.",
      isUser: false,
      timestamp: new Date(),
    }
  ]);

  const chatMutation = useMutation({
    mutationFn: async (message: string) => {
      const response = await apiRequest("POST", "/api/chat", { message });
      return await response.json();
    },
    onSuccess: (data) => {
      setMessages(prev => [...prev, {
        id: Date.now().toString(),
        text: data.response,
        isUser: false,
        timestamp: new Date(),
      }]);
    },
  });

  const handleSendMessage = () => {
    if (!message.trim()) return;

    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      text: message,
      isUser: true,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    chatMutation.mutate(message);
    setMessage("");
  };

  const handleQuickReply = (text: string) => {
    setMessage(text);
    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      text: text,
      isUser: true,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    chatMutation.mutate(text);
  };

  return (
    <div className="fixed bottom-6 right-6 z-50">
      {isOpen && (
        <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 w-80 h-96 flex flex-col mb-4">
          <div className="bg-primary text-white p-4 rounded-t-2xl flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                <Bot size={16} />
              </div>
              <div>
                <h3 className="font-semibold">IT Support Assistant</h3>
                <p className="text-xs opacity-90">Available 24/7</p>
              </div>
            </div>
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setIsOpen(false)}
              className="text-white hover:bg-white hover:bg-opacity-20 p-1 rounded h-8 w-8"
            >
              <X size={16} />
            </Button>
          </div>
          
          <div className="flex-1 p-4 overflow-y-auto space-y-4">
            {messages.map((msg) => (
              <div key={msg.id} className={`flex ${msg.isUser ? 'justify-end' : 'items-start space-x-2'}`}>
                {!msg.isUser && (
                  <div className="w-6 h-6 bg-primary rounded-full flex items-center justify-center flex-shrink-0">
                    <Bot className="text-white" size={12} />
                  </div>
                )}
                <div className={`rounded-lg p-3 max-w-xs ${
                  msg.isUser 
                    ? 'bg-primary text-white' 
                    : 'bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white'
                }`}>
                  <p className="text-sm">{msg.text}</p>
                </div>
              </div>
            ))}
            
            {messages.length === 1 && (
              <div className="flex flex-col space-y-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleQuickReply("I need to reset my password")}
                  className="bg-blue-50 hover:bg-blue-100 text-blue-700 border-blue-200 text-sm dark:bg-blue-900 dark:text-blue-200 dark:border-blue-800"
                >
                  Password Reset Help
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleQuickReply("I have a computer hardware issue")}
                  className="bg-orange-50 hover:bg-orange-100 text-orange-700 border-orange-200 text-sm dark:bg-orange-900 dark:text-orange-200 dark:border-orange-800"
                >
                  Hardware Problem
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleQuickReply("I need software installed")}
                  className="bg-green-50 hover:bg-green-100 text-green-700 border-green-200 text-sm dark:bg-green-900 dark:text-green-200 dark:border-green-800"
                >
                  Software Installation
                </Button>
              </div>
            )}
          </div>
          
          <div className="p-4 border-t border-gray-200 dark:border-gray-700">
            <div className="flex space-x-2">
              <Input
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
                placeholder="Type your message..."
                className="flex-1 text-sm"
                disabled={chatMutation.isPending}
              />
              <Button 
                onClick={handleSendMessage}
                disabled={chatMutation.isPending || !message.trim()}
                className="bg-primary hover:bg-primary/90 text-white"
                size="icon"
              >
                <Send size={16} />
              </Button>
            </div>
          </div>
        </div>
      )}
      
      <Button
        onClick={() => setIsOpen(!isOpen)}
        className="bg-primary hover:bg-primary/90 text-white w-16 h-16 rounded-full shadow-2xl"
        size="icon"
      >
        <MessageCircle size={24} />
      </Button>
    </div>
  );
}