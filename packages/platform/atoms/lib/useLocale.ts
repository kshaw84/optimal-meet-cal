import { createInstance } from "i18next";
import type { TFunction, i18n } from "i18next";
import { useTranslation } from "react-i18next";
import { initReactI18next } from "react-i18next";

import { useAtomsContext } from "@calcom/atoms/hooks/useAtomsContext";

type useLocaleReturnType = {
  i18n: i18n;
  t: TFunction;
  isLocaleReady: boolean;
};

export const useLocale = (
  namespace: Parameters<typeof useTranslation>[0] = "common"
): useLocaleReturnType => {
  const context = useAtomsContext();

  // Ensure i18next is initialized before using useTranslation
  if (typeof window !== "undefined" && !window.i18next) {
    const i18n = createInstance();
    i18n.use(initReactI18next);
    i18n.init({
      lng: "en",
      fallbackLng: "en",
      resources: {
        en: {
          [namespace]: {},
        },
      },
      react: {
        useSuspense: false,
      },
    });
  }

  const { i18n, t } = useTranslation(namespace);
  const isLocaleReady = Object.keys(i18n).length > 0;
  if (context?.clientId) {
    return { i18n: context.i18n, t: context.t, isLocaleReady: true } as unknown as useLocaleReturnType;
  }
  return {
    i18n,
    t,
    isLocaleReady,
  };
};
