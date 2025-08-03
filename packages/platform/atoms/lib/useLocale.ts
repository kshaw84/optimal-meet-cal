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

// Global i18next instance to prevent multiple initializations
let globalI18nInstance: i18n | null = null;

export const useLocale = (
  namespace: Parameters<typeof useTranslation>[0] = "common"
): useLocaleReturnType => {
  const context = useAtomsContext();

  // Ensure i18next is initialized before using useTranslation
  if (typeof window !== "undefined" && !globalI18nInstance) {
    try {
      globalI18nInstance = createInstance();
      globalI18nInstance.use(initReactI18next);
      globalI18nInstance.init({
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
        interpolation: {
          escapeValue: false,
        },
      });
    } catch (error) {
      console.warn("Failed to initialize i18next:", error);
    }
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
