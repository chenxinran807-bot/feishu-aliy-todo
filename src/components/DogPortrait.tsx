interface DogPortraitProps {
  size: "compact" | "hero";
  as?: "span" | "button";
  ariaLabel?: string;
  onClick?: () => void;
}

export function DogPortrait({ size, as = "span", ariaLabel, onClick }: DogPortraitProps) {
  const className = `dog-portrait dog-portrait--${size}`;
  const content = (
    <span className="dog-emoji" aria-hidden="true">
      🐶
    </span>
  );

  if (as === "button") {
    return (
      <button className={className} type="button" onClick={onClick} aria-label={ariaLabel}>
        {content}
      </button>
    );
  }

  return (
    <span className={className} aria-hidden="true">
      {content}
    </span>
  );
}
