"use client";

import React, {
	createContext,
	useCallback,
	useContext,
	useEffect,
	useMemo,
	useState,
} from "react";
import { en } from "./locales/en";
import { zh } from "./locales/zh";
import type { I18nContextType, Locale } from "./types";

const COOKIE_NAME = "dokploy_locale";
const STORAGE_KEY = "dokploy_locale";

const dictionaries: Record<Locale, any> = {
	zh,
	en,
};

const I18nContext = createContext<I18nContextType>({
	locale: "zh",
	setLocale: () => {},
	t: (key: string) => key,
	isLoaded: false,
});

function getInitialLocale(): Locale {
	if (typeof window === "undefined") {
		return "zh";
	}

	try {
		const stored = localStorage.getItem(STORAGE_KEY) as Locale | null;
		if (stored === "zh" || stored === "en") {
			return stored;
		}

		const cookies = document.cookie.split(";");
		for (const cookie of cookies) {
			const [name, value] = cookie.trim().split("=");
			if (name === COOKIE_NAME) {
				const decoded = decodeURIComponent(value) as Locale;
				if (decoded === "zh" || decoded === "en") {
					return decoded;
				}
			}
		}

		const browserLang = navigator.language?.toLowerCase() || "";
		if (browserLang.startsWith("zh")) {
			return "zh";
		}
		if (browserLang.startsWith("en")) {
			return "en";
		}
	} catch {
		// Ignore storage errors
	}

	return "zh";
}

export const I18nProvider: React.FC<{ children: React.ReactNode }> = ({
	children,
}) => {
	const [locale, setLocaleState] = useState<Locale>("zh");
	const [isLoaded, setIsLoaded] = useState(false);

	useEffect(() => {
		const initial = getInitialLocale();
		setLocaleState(initial);
		setIsLoaded(true);
	}, []);

	const setLocale = useCallback((newLocale: Locale) => {
		setLocaleState(newLocale);
		try {
			localStorage.setItem(STORAGE_KEY, newLocale);
			document.cookie = `${COOKIE_NAME}=${newLocale}; path=/; max-age=31536000; SameSite=Lax`;
		} catch {
			// Ignore storage write errors
		}
	}, []);

	const t = useCallback(
		(key: string, params?: Record<string, string | number>): string => {
			const keys = key.split(".");
			
			// 1. Try current locale
			let value: any = dictionaries[locale];
			for (const k of keys) {
				if (value && typeof value === "object" && k in value) {
					value = value[k];
				} else {
					value = undefined;
					break;
				}
			}

			// 2. Fallback to English
			if (value === undefined && locale !== "en") {
				let fallbackValue: any = dictionaries.en;
				for (const k of keys) {
					if (fallbackValue && typeof fallbackValue === "object" && k in fallbackValue) {
						fallbackValue = fallbackValue[k];
					} else {
						fallbackValue = undefined;
						break;
					}
				}
				value = fallbackValue;
			}

			// 3. Fallback to key itself
			if (typeof value !== "string") {
				return key;
			}

			// 4. Interpolate params
			if (params) {
				let interpolated = value;
				for (const [pKey, pVal] of Object.entries(params)) {
					interpolated = interpolated.replaceAll(`{${pKey}}`, String(pVal));
				}
				return interpolated;
			}

			return value;
		},
		[locale],
	);

	const contextValue = useMemo(
		() => ({
			locale,
			setLocale,
			t,
			isLoaded,
		}),
		[locale, setLocale, t, isLoaded],
	);

	return (
		<I18nContext.Provider value={contextValue}>
			{children}
		</I18nContext.Provider>
	);
};

export const useTranslation = () => {
	const context = useContext(I18nContext);
	if (!context) {
		throw new Error("useTranslation must be used within an I18nProvider");
	}
	return context;
};

export const useLocale = () => {
	const { locale, setLocale, isLoaded } = useTranslation();
	return { locale, setLocale, isLoaded };
};
