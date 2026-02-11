
import React, { useState, useRef, useEffect } from 'react';
import { MessageSquare, Send, X, Music, Sparkles } from 'lucide-react';
import { GoogleGenAI } from '@google/genai';
import { ARTISTS } from '../constants';

export const MusicAssistant: React.FC = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<{ role: 'user' | 'assistant'; content: string }[]>([
    { role: 'assistant', content: "Hi! I'm your En4tainment Assistant. What kind of vibe or artist are you looking for today? I can help you find the perfect music for your event!" }
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isOpen]);

  const handleSend = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage = input.trim();
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: userMessage }]);
    setIsLoading(true);

    try {
      // Fix: Create GoogleGenAI instance right before making an API call
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const artistContext = ARTISTS.map(a => `- ${a.name} (${a.category}): ${a.description}. Bio: ${a.bio}`).join('\n');
      
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: userMessage,
        config: {
          systemInstruction: `You are a helpful, professional, and enthusiastic music discovery assistant for En4tainment. 
          Your goal is to recommend artists from the provided list based on the user's needs (vibe, event type, etc.).
          
          Our Current Roster:
          ${artistContext}
          
          Guidelines:
          - Be concise but friendly.
          - If they ask for a recommendation, explain WHY an artist fits.
          - Always use a supportive tone for the artists.
          - If the user's request doesn't match our current artists, suggest the closest match or ask for more details.
          - Keep answers under 100 words.`
        }
      });

      // Fix: Access the text property directly from GenerateContentResponse
      const aiText = response.text || "I'm sorry, I couldn't process that. Can you try rephrasing?";
      setMessages(prev => [...prev, { role: 'assistant', content: aiText }]);
    } catch (error) {
      console.error('AI Error:', error);
      setMessages(prev => [...prev, { role: 'assistant', content: "Oops, something went wrong on my end. Please try again later!" }]);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed bottom-6 right-6 z-[60]">
      {isOpen ? (
        <div className="bg-brand-surface border border-white/10 w-80 md:w-96 h-[500px] rounded-2xl shadow-2xl flex flex-col overflow-hidden animate-in slide-in-from-bottom-4 duration-300">
          {/* Header */}
          <div className="bg-gradient-to-r from-brand-purple to-brand-pink p-4 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Sparkles className="text-white w-5 h-5" />
              <h3 className="font-bold text-white">Music Assistant</h3>
            </div>
            <button onClick={() => setIsOpen(false)} className="text-white hover:opacity-70 transition-opacity">
              <X size={20} />
            </button>
          </div>

          {/* Messages */}
          <div ref={scrollRef} className="flex-grow overflow-y-auto p-4 space-y-4 bg-brand-dark/50">
            {messages.map((msg, i) => (
              <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
                <div className={`max-w-[85%] p-3 rounded-2xl text-sm leading-relaxed ${
                  msg.role === 'user' 
                    ? 'bg-brand-purple text-white rounded-br-none' 
                    : 'bg-white/10 text-gray-200 rounded-bl-none'
                }`}>
                  {msg.content}
                </div>
              </div>
            ))}
            {isLoading && (
              <div className="flex justify-start">
                <div className="bg-white/5 p-3 rounded-2xl animate-pulse flex gap-1">
                  <div className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce"></div>
                  <div className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce [animation-delay:-0.15s]"></div>
                  <div className="w-1.5 h-1.5 bg-gray-400 rounded-full animate-bounce [animation-delay:-0.3s]"></div>
                </div>
              </div>
            )}
          </div>

          {/* Input */}
          <div className="p-4 bg-brand-surface border-t border-white/5">
            <div className="relative">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                onKeyPress={(e) => e.key === 'Enter' && handleSend()}
                placeholder="Ask me for a recommendation..."
                className="w-full bg-brand-dark border border-white/10 rounded-full py-2 pl-4 pr-12 text-sm text-white focus:ring-2 focus:ring-brand-purple outline-none"
              />
              <button 
                onClick={handleSend}
                disabled={!input.trim() || isLoading}
                className="absolute right-2 top-1/2 -translate-y-1/2 p-1.5 bg-brand-pink rounded-full text-white hover:scale-105 active:scale-95 transition-all disabled:opacity-50"
              >
                <Send size={14} />
              </button>
            </div>
          </div>
        </div>
      ) : (
        <button
          onClick={() => setIsOpen(true)}
          className="bg-gradient-to-br from-brand-purple to-brand-pink p-4 rounded-full text-white shadow-lg hover:scale-110 active:scale-95 transition-all group flex items-center gap-2"
        >
          <span className="max-w-0 overflow-hidden group-hover:max-w-xs transition-all duration-500 font-bold whitespace-nowrap text-sm">
            Find Artists
          </span>
          <Music size={24} />
        </button>
      )}
    </div>
  );
};
