import React from 'react';
import { Button } from '../components/Button';
import { Mail } from 'lucide-react';

export const Contact = () => {
  return (
    <div className="pt-24 pb-20 min-h-screen bg-brand-dark">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        
        <div className="text-center mb-16">
          <h1 className="text-4xl font-bold text-white mb-4">Get in Touch</h1>
          <p className="text-gray-400">Have general questions? We'd love to hear from you.</p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12">
          
          {/* Info Side */}
          <div className="space-y-8">
            <div className="bg-brand-surface p-8 rounded-2xl border border-white/5">
              <h3 className="text-2xl font-bold text-white mb-6">Contact Information</h3>
              <div className="space-y-6">
                <div className="flex items-start gap-4">
                  <div className="bg-brand-lime/20 p-3 rounded-lg text-brand-lime">
                    <Mail size={24} />
                  </div>
                  <div>
                    <h4 className="text-white font-semibold">Email</h4>
                    <p className="text-gray-400">info@en4tainment.com</p>
                  </div>
                </div>
              </div>
            </div>

            {/* Map Placeholder removed */}
          </div>

          {/* Form Side */}
          <div className="bg-brand-surface p-8 rounded-2xl border border-white/5 shadow-2xl">
            <h3 className="text-2xl font-bold text-white mb-6">Send us a Message</h3>
            <form className="space-y-6">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">First Name</label>
                  <input type="text" className="w-full bg-brand-dark border border-white/10 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2">Last Name</label>
                  <input type="text" className="w-full bg-brand-dark border border-white/10 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none" />
                </div>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Email</label>
                <input type="email" className="w-full bg-brand-dark border border-white/10 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none" />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2">Message</label>
                <textarea rows={5} className="w-full bg-brand-dark border border-white/10 rounded-lg px-4 py-3 text-white focus:ring-2 focus:ring-brand-purple focus:border-transparent outline-none resize-none"></textarea>
              </div>

              <Button type="button" className="w-full" onClick={() => alert("Message sent!")}>Send Message</Button>
            </form>
          </div>

        </div>
      </div>
    </div>
  );
};
