import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Building2, FileText, MapPin, Phone, User, Lock, CheckCircle, AlertCircle, Upload, Map as MapIcon, Info } from 'lucide-react';
import { Button } from '../components/Button';
import { supabase } from '../services/supabase';

const InfoTooltip: React.FC<{ text: string }> = ({ text }) => {
  const [show, setShow] = useState(false);

  return (
    <div className="relative inline-block ml-1 align-middle">
      <button
        type="button"
        onClick={() => setShow(!show)}
        onMouseEnter={() => setShow(true)}
        onMouseLeave={() => setShow(false)}
        className="text-gray-500 hover:text-brand-purple transition-colors"
      >
        <Info size={14} />
      </button>
      {show && (
        <div className="absolute z-50 bottom-full left-1/2 -translate-x-1/2 mb-2 w-64 p-3 bg-brand-surface border border-white/10 rounded-lg shadow-2xl text-xs text-gray-300 leading-relaxed animate-fade-in">
          {text}
          <div className="absolute top-full left-1/2 -translate-x-1/2 border-8 border-transparent border-t-brand-surface" />
        </div>
      )}
    </div>
  );
};

export const VenuePortal: React.FC = () => {
  const [isLogin, setIsLogin] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const navigate = useNavigate();

  // Login State
  const [loginData, setLoginData] = useState({
    username: '',
    password: '',
  });

  // Signup State
  const [signupData, setSignupData] = useState({
    name: '',
    registeredName: '',
    brNumber: '',
    brPhoto: null as File | null,
    locationLat: 0,
    locationLng: 0,
    registeredAddress: '',
    locationAddress: '',
    registeredPhone: '',
    mobileNumber: '',
    username: '',
    password: '',
    confirmPassword: '',
  });

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      // Mock authentication for now as requested
      // In a real app, we'd check against Supabase
      const { data, error: fetchError } = await supabase
        .from('venues')
        .select('*')
        .eq('username', loginData.username)
        .single();

      if (fetchError || !data) {
        throw new Error('Invalid username or password');
      }

      const venue = data as any;
      if (venue.status === 'pending') {
        throw new Error('Your account is still pending approval by admin.');
      }

      // Store venue in local storage for mock auth
      localStorage.setItem('venue_user', JSON.stringify(venue));
      navigate('/venue-dashboard');
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    if (signupData.password !== signupData.confirmPassword) {
      setError('Passwords do not match');
      setLoading(false);
      return;
    }

    try {
      // 1. Upload BR Photo (Mock URL for now, or use Supabase Storage if configured)
      let brPhotoUrl = 'https://picsum.photos/400/300'; // Placeholder
      
      if (signupData.brPhoto) {
        const fileExt = signupData.brPhoto.name.split('.').pop();
        const fileName = `${Math.random()}.${fileExt}`;
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from('br-certificates')
          .upload(fileName, signupData.brPhoto);
        
        if (!uploadError) {
          const { data: publicUrl } = supabase.storage.from('br-certificates').getPublicUrl(fileName);
          brPhotoUrl = publicUrl.publicUrl;
        }
      }

      // 2. Create Venue Profile
      const { error: insertError } = await supabase.from('venues').insert({
        name: signupData.name,
        registered_name: signupData.registeredName,
        br_number: signupData.brNumber,
        br_photo_url: brPhotoUrl,
        location_lat: signupData.locationLat,
        location_lng: signupData.locationLng,
        registered_address: signupData.registeredAddress,
        location_address: signupData.locationAddress,
        registered_phone: signupData.registeredPhone,
        mobile_number: signupData.mobileNumber,
        username: signupData.username,
        status: 'pending',
      } as any);

      if (insertError) throw insertError;

      setSuccess(true);
      setTimeout(() => setIsLogin(true), 3000);
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen pt-24 pb-12 px-4 bg-brand-dark">
      <div className="max-w-4xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-brand-surface rounded-2xl border border-white/10 overflow-hidden shadow-2xl"
        >
          <div className="flex border-b border-white/10">
            <button
              onClick={() => setIsLogin(true)}
              className={`flex-1 py-4 text-center font-semibold transition-colors ${
                isLogin ? 'bg-brand-purple text-white' : 'text-gray-400 hover:text-white'
              }`}
            >
              Venue Login
            </button>
            <button
              onClick={() => setIsLogin(false)}
              className={`flex-1 py-4 text-center font-semibold transition-colors ${
                !isLogin ? 'bg-brand-purple text-white' : 'text-gray-400 hover:text-white'
              }`}
            >
              Register Venue
            </button>
          </div>

          <div className="p-8">
            {isLogin ? (
              <div className="max-w-md mx-auto">
                <div className="text-center mb-8">
                  <Building2 className="w-12 h-12 text-brand-purple mx-auto mb-4" />
                  <h2 className="text-2xl font-bold">Welcome Back</h2>
                  <p className="text-gray-400">Log in to manage your bookings</p>
                </div>

                <form onSubmit={handleLogin} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-1">Username</label>
                    <div className="relative">
                      <User className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                      <input
                        type="text"
                        required
                        className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 pl-10 pr-4 focus:outline-none focus:border-brand-purple"
                        value={loginData.username}
                        onChange={(e) => setLoginData({ ...loginData, username: e.target.value })}
                      />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-400 mb-1">Password</label>
                    <div className="relative">
                      <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
                      <input
                        type="password"
                        required
                        className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 pl-10 pr-4 focus:outline-none focus:border-brand-purple"
                        value={loginData.password}
                        onChange={(e) => setLoginData({ ...loginData, password: e.target.value })}
                      />
                    </div>
                  </div>

                  {error && (
                    <div className="flex items-center gap-2 text-red-500 text-sm bg-red-500/10 p-3 rounded-lg">
                      <AlertCircle className="w-4 h-4" />
                      {error}
                    </div>
                  )}

                  <Button type="submit" className="w-full" disabled={loading}>
                    {loading ? 'Logging in...' : 'Login'}
                  </Button>

                  <div className="relative py-4">
                    <div className="absolute inset-0 flex items-center">
                      <div className="w-full border-t border-white/10"></div>
                    </div>
                    <div className="relative flex justify-center text-xs uppercase">
                      <span className="bg-brand-surface px-2 text-gray-500">Or explore the UI</span>
                    </div>
                  </div>

                  <Button 
                    type="button" 
                    variant="outline" 
                    className="w-full border-brand-purple/50 text-brand-purple hover:bg-brand-purple hover:text-white"
                    onClick={() => {
                      const mockVenue = {
                        id: 'mock_venue_123',
                        name: 'The Grand Jazz Club',
                        username: 'demo_venue',
                        status: 'approved'
                      };
                      localStorage.setItem('venue_user', JSON.stringify(mockVenue));
                      navigate('/venue-dashboard');
                    }}
                  >
                    Demo Login (Bypass Auth)
                  </Button>
                </form>
              </div>
            ) : (
              <div>
                <div className="text-center mb-8">
                  <h2 className="text-2xl font-bold">Register Your Venue</h2>
                  <p className="text-gray-400">Join En4tainment to book top artists for your venue</p>
                </div>

                {success ? (
                  <div className="text-center py-12">
                    <CheckCircle className="w-16 h-16 text-brand-lime mx-auto mb-4" />
                    <h3 className="text-xl font-bold mb-2">Registration Submitted!</h3>
                    <p className="text-gray-400">Your profile is pending admin validation. We will contact you soon.</p>
                  </div>
                ) : (
                  <form onSubmit={handleSignup} className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div className="space-y-4">
                      <h3 className="text-lg font-semibold text-brand-purple flex items-center gap-2">
                        <Building2 className="w-5 h-5" /> Basic Information
                      </h3>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                          Name of Venue
                          <InfoTooltip text="Enter the trading name of your venue — this is the name your clients and guests know you by. It will be displayed publicly on your venue profile." />
                        </label>
                        <input
                          type="text"
                          required
                          className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                          value={signupData.name}
                          onChange={(e) => setSignupData({ ...signupData, name: e.target.value })}
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                          Registered Name (as per BR)
                          <InfoTooltip text="Enter the full legal name of your business exactly as it appears on your Business Registration certificate. This must match your official documents to complete verification." />
                        </label>
                        <input
                          type="text"
                          required
                          className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                          value={signupData.registeredName}
                          onChange={(e) => setSignupData({ ...signupData, registeredName: e.target.value })}
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                          BR Number
                          <InfoTooltip text="Enter your unique Business Registration number as issued by the relevant government authority. This is used to verify the legitimacy of your venue on our platform." />
                        </label>
                        <input
                          type="text"
                          required
                          className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                          value={signupData.brNumber}
                          onChange={(e) => setSignupData({ ...signupData, brNumber: e.target.value })}
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                          BR Copy Upload (PDF only)
                          <InfoTooltip text="Upload a clear, readable copy of your Business Registration certificate in PDF format. This document is required for venue verification and will be reviewed by our team." />
                        </label>
                        <div className="relative">
                          <input
                            type="file"
                            accept="image/*"
                            required
                            className="hidden"
                            id="br-upload"
                            onChange={(e) => setSignupData({ ...signupData, brPhoto: e.target.files?.[0] || null })}
                          />
                          <label
                            htmlFor="br-upload"
                            className="flex items-center justify-center gap-2 w-full bg-brand-dark border border-dashed border-white/20 rounded-lg py-4 cursor-pointer hover:border-brand-purple transition-colors"
                          >
                            <Upload className="w-5 h-5 text-gray-400" />
                            <span className="text-gray-400">
                              {signupData.brPhoto ? signupData.brPhoto.name : 'Upload PDF Copy of BR Certificate'}
                            </span>
                          </label>
                        </div>
                      </div>
                    </div>

                    <div className="space-y-4">
                      <h3 className="text-lg font-semibold text-brand-purple flex items-center gap-2">
                        <MapPin className="w-5 h-5" /> Location & Contact
                      </h3>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                          Registered Address (as per BR)
                          <InfoTooltip text="Enter the official address of your business as stated on your Business Registration certificate. This may differ from your venue's physical location." />
                        </label>
                        <textarea
                          required
                          className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple h-20"
                          value={signupData.registeredAddress}
                          onChange={(e) => setSignupData({ ...signupData, registeredAddress: e.target.value })}
                        />
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">
                          Location Address
                          <InfoTooltip text="Enter the actual physical address where your venue is located. This is the address performers will use to find your venue." />
                        </label>
                        <textarea
                          required
                          className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple h-20"
                          value={signupData.locationAddress}
                          onChange={(e) => setSignupData({ ...signupData, locationAddress: e.target.value })}
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-400 mb-1">
                            Reg. Phone
                            <InfoTooltip text="Enter the landline or official phone number registered under your business. This is used for formal communication and verification purposes." />
                          </label>
                          <input
                            type="tel"
                            required
                            className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                            value={signupData.registeredPhone}
                            onChange={(e) => setSignupData({ ...signupData, registeredPhone: e.target.value })}
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-400 mb-1">
                            Mobile (Auth)
                            <InfoTooltip text="Enter the mobile number of the authorized person managing this venue account. This number will be used for account authentication, important notifications, and OTP verification." />
                          </label>
                          <input
                            type="tel"
                            required
                            className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                            value={signupData.mobileNumber}
                            onChange={(e) => setSignupData({ ...signupData, mobileNumber: e.target.value })}
                          />
                        </div>
                      </div>
                      <div>
                        <label className="block text-sm font-medium text-gray-400 mb-1">Google Maps Pin</label>
                        <Button
                          type="button"
                          variant="outline"
                          className="w-full flex items-center justify-center gap-2"
                          onClick={() => setSignupData({ ...signupData, locationLat: 6.9271, locationLng: 79.8612 })}
                        >
                          <MapIcon className="w-4 h-4" /> {signupData.locationLat ? 'Location Pinned' : 'Pin Location'}
                        </Button>
                      </div>
                    </div>

                    <div className="md:col-span-2 space-y-4 pt-6 border-t border-white/10">
                      <h3 className="text-lg font-semibold text-brand-purple flex items-center gap-2">
                        <Lock className="w-5 h-5" /> Account Security
                      </h3>
                      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-400 mb-1">Username</label>
                          <input
                            type="text"
                            required
                            className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                            value={signupData.username}
                            onChange={(e) => setSignupData({ ...signupData, username: e.target.value })}
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-400 mb-1">Password</label>
                          <input
                            type="password"
                            required
                            className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                            value={signupData.password}
                            onChange={(e) => setSignupData({ ...signupData, password: e.target.value })}
                          />
                        </div>
                        <div>
                          <label className="block text-sm font-medium text-gray-400 mb-1">Confirm Password</label>
                          <input
                            type="password"
                            required
                            className="w-full bg-brand-dark border border-white/10 rounded-lg py-2 px-4 focus:outline-none focus:border-brand-purple"
                            value={signupData.confirmPassword}
                            onChange={(e) => setSignupData({ ...signupData, confirmPassword: e.target.value })}
                          />
                        </div>
                      </div>
                    </div>

                    {error && (
                      <div className="md:col-span-2 flex items-center gap-2 text-red-500 text-sm bg-red-500/10 p-3 rounded-lg">
                        <AlertCircle className="w-4 h-4" />
                        {error}
                      </div>
                    )}

                    <div className="md:col-span-2 pt-4">
                      <Button type="submit" className="w-full" disabled={loading}>
                        {loading ? 'Submitting...' : 'Submit Registration'}
                      </Button>
                    </div>
                  </form>
                )}
              </div>
            )}
          </div>
        </motion.div>
      </div>
    </div>
  );
};
