import React, { useState } from 'react';

interface TwilightLogoProps {
  className?: string;
  size?: number | string;
}

export const TwilightLogo: React.FC<TwilightLogoProps> = ({
  className = 'w-10 h-10',
  size,
}) => {
  const [imgError, setImgError] = useState(false);
  const style = size ? { width: size, height: size, minWidth: size, minHeight: size } : undefined;

  return (
    <div
      style={style}
      className={`relative inline-flex items-center justify-center shrink-0 select-none overflow-hidden rounded-2xl shadow-xl shadow-purple-950/60 bg-[#0d0722] border border-white/10 ${className}`}
    >
      {!imgError ? (
        <img
          src="/twilight_b_icon.svg"
          alt="Twilight Logo"
          className="w-full h-full object-cover block"
          onError={() => setImgError(true)}
        />
      ) : (
        <svg
          viewBox="0 0 512 512"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          className="w-full h-full block"
        >
          <defs>
            <linearGradient id="bgGrad" x1="0" y1="0" x2="512" y2="512" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#110926" />
              <stop offset="50%" stopColor="#0a0518" />
              <stop offset="100%" stopColor="#1a0b36" />
            </linearGradient>

            <linearGradient id="ringGrad" x1="120" y1="120" x2="380" y2="380" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#ff3388" />
              <stop offset="25%" stopColor="#f72585" />
              <stop offset="55%" stopColor="#7209b7" />
              <stop offset="85%" stopColor="#3a86ff" />
              <stop offset="100%" stopColor="#4cc9f0" />
            </linearGradient>

            <linearGradient id="playGrad" x1="200" y1="190" x2="330" y2="320" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#ff4088" />
              <stop offset="50%" stopColor="#d92588" />
              <stop offset="100%" stopColor="#7209b7" />
            </linearGradient>

            <linearGradient id="orbitGrad" x1="100" y1="100" x2="410" y2="410" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#ff2a85" />
              <stop offset="50%" stopColor="#9d4edd" />
              <stop offset="100%" stopColor="#3a86ff" />
            </linearGradient>
          </defs>

          <rect width="512" height="512" rx="112" fill="url(#bgGrad)" />
          <circle cx="256" cy="256" r="162" fill="#0d0722" />
          <circle cx="256" cy="256" r="164" stroke="url(#orbitGrad)" strokeWidth="4" />
          <circle cx="374" cy="188" r="14" fill="#ff2a85" />
          <circle cx="256" cy="256" r="130" stroke="url(#ringGrad)" strokeWidth="14" />
          <path
            d="M 218 198 C 218 188 228 182 237 188 L 326 245 C 334 250 334 262 326 267 L 237 324 C 228 330 218 324 218 314 Z"
            fill="url(#playGrad)"
          />
        </svg>
      )}
    </div>
  );
};
