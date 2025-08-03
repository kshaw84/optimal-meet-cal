import classNames from "@calcom/ui/classNames";

export function Logo({
  small,
  icon,
  inline = true,
  className,
  src = "/api/logo",
  auth,
}: {
  small?: boolean;
  icon?: boolean;
  inline?: boolean;
  className?: string;
  src?: string;
  auth?: boolean;
}) {
  return (
    <h3 className={classNames("logo", inline && "inline", className)}>
      <strong>
        {icon ? (
          <img className="mx-auto w-9 dark:invert" alt="Cal" title="Cal" src={`${src}?type=icon`} />
        ) : (
          <img
            className={classNames(auth ? "h-8 w-auto" : small ? "h-4 w-auto" : "h-8 w-auto", "dark:invert")}
            alt="Cal"
            title="Cal"
            src={src}
          />
        )}
      </strong>
    </h3>
  );
}
