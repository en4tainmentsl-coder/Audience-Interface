import React, { useState } from 'react';
import { Star } from 'lucide-react';

export const StarRating = ({ 
  initialRating = 0, 
  readonly = false, 
  onRate,
  size = 20
}) => {
  const [hoverRating, setHoverRating] = useState(0);
  const [rating, setRating] = useState(initialRating);

  const handleRate = (value) => {
    if (!readonly) {
      setRating(value);
      if (onRate) onRate(value);
    }
  };

  return (
    <div className="flex gap-1">
      {[1, 2, 3, 4, 5].map((star) => (
        <button
          key={star}
          type="button"
          onClick={() => handleRate(star)}
          onMouseEnter={() => !readonly && setHoverRating(star)}
          onMouseLeave={() => !readonly && setHoverRating(0)}
          className={`${readonly ? 'cursor-default' : 'cursor-pointer'} transition-colors duration-150`}
          disabled={readonly}
        >
          <Star
            size={size}
            className={`${
              star <= (hoverRating || rating)
                ? 'fill-brand-lime text-brand-lime'
                : 'fill-transparent text-gray-600'
            }`}
          />
        </button>
      ))}
    </div>
  );
};
