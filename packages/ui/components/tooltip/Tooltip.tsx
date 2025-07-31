"use client";

import * as TooltipPrimitive from "@radix-ui/react-tooltip";
import React from "react";

import classNames from "@calcom/ui/classNames";

// React 19 compatibility wrapper
const React19CompatibleTrigger = React.forwardRef<
  React.ElementRef<typeof TooltipPrimitive.Trigger>,
  React.ComponentPropsWithoutRef<typeof TooltipPrimitive.Trigger>
>((props, ref) => {
  // Suppress React 19 deprecation warning for element.ref
  const originalConsoleError = console.error;
  console.error = (...args) => {
    if (args[0]?.includes?.("Accessing element.ref was removed in React 19")) {
      return;
    }
    originalConsoleError.apply(console, args);
  };

  try {
    return <TooltipPrimitive.Trigger ref={ref} {...props} />;
  } finally {
    console.error = originalConsoleError;
  }
});

React19CompatibleTrigger.displayName = "React19CompatibleTrigger";

export function Tooltip({
  children,
  content,
  open,
  defaultOpen,
  onOpenChange,
  delayDuration,
  side = "top",
  ...props
}: {
  children: React.ReactNode;
  content: React.ReactNode;
  delayDuration?: number;
  open?: boolean;
  defaultOpen?: boolean;
  side?: "top" | "right" | "bottom" | "left";
  onOpenChange?: (open: boolean) => void;
} & TooltipPrimitive.TooltipContentProps) {
  const Content = (
    <TooltipPrimitive.Content
      {...props}
      className={classNames(
        "calcom-tooltip",
        side === "top" && "-mt-7",
        side === "right" && "ml-2",
        "bg-inverted text-inverted relative z-50 rounded-md px-2 py-1 text-xs font-semibold shadow-lg",
        props.className && `${props.className}`
      )}
      side={side}
      align="center">
      {content}
    </TooltipPrimitive.Content>
  );

  return (
    <TooltipPrimitive.Root
      delayDuration={delayDuration || 50}
      open={open}
      defaultOpen={defaultOpen}
      onOpenChange={onOpenChange}>
      <React19CompatibleTrigger asChild>{children}</React19CompatibleTrigger>
      <TooltipPrimitive.Portal>{Content}</TooltipPrimitive.Portal>
    </TooltipPrimitive.Root>
  );
}

export default Tooltip;
