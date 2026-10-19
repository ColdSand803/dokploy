export type Locale = "en" | "zh";

export interface LocaleInfo {
	code: Locale;
	name: string;
	label: string;
}

export const SUPPORTED_LOCALES: LocaleInfo[] = [
	{ code: "zh", name: "简体中文", label: "中" },
	{ code: "en", name: "English", label: "EN" },
];

export interface I18nContextType {
	locale: Locale;
	setLocale: (locale: Locale) => void;
	t: (key: string, params?: Record<string, string | number>) => string;
	isLoaded: boolean;
}
