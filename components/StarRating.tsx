import React, { useState } from 'react';
import { Star } from 'lucide-react';

interface StarRatingProps {
  initialRating?: number;
  readonly?: boolean;
  onRate?: (value: number) => void;
  size?: number;
}

export const StarRating: React.FC<StarRatingProps> = ({ 
  initialRating = 0, 
  readonly = false, 
  onRate,
  size = 20
}) => {
  const [hoverRating, setHoverRating] = useState<number>(0);
  const [rating, setRating] = useState<number>(initialRating);

  const handleRate = (value: number): void => {
    if (!readonly) {
      setRating(value);
      if (onRate) onRate(value);
    }
  };

  return (
    <div className="flex gap-1" id="star-rating-container">
      {[1, 2, 3, 4, 5].map((star: number) => (
        <button
          key={star}
          type="button"
          onClick={() => handleRate(star)}
          onMouseEnter={() => !readonly && setHoverRating(star)}
          onMouseLeave={() => !readonly && setHoverRating(0)}
          className={`${readonly ? 'cursor-default' : 'cursor-pointer'} transition-colors duration-150`}
          disabled={readonly}
          id={`star-${star}`}
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
