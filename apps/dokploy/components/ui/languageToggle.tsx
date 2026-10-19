"use client";

import { Globe } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
	DropdownMenu,
	DropdownMenuContent,
	DropdownMenuItem,
	DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { useTranslation } from "@/lib/i18n";
import { SUPPORTED_LOCALES } from "@/lib/i18n/types";

interface Props {
	variant?: "icon" | "dropdown" | "compact";
	className?: string;
}

export function LanguageToggle({ variant = "icon", className }: Props) {
	const { locale, setLocale, t } = useTranslation();

	const toggleLanguage = () => {
		setLocale(locale === "zh" ? "en" : "zh");
	};

	if (variant === "compact") {
		return (
			<Button
				variant="outline"
				size="sm"
				onClick={toggleLanguage}
				className={`h-8 gap-1.5 px-2.5 text-xs font-medium ${className || ""}`}
				title={t("nav.switchLanguage")}
			>
				<Globe className="h-3.5 w-3.5" />
				<span>{locale === "zh" ? "中 / 简体中文" : "EN / English"}</span>
			</Button>
		);
	}

	if (variant === "dropdown") {
		return (
			<DropdownMenu>
				<DropdownMenuTrigger asChild>
					<Button
						variant="outline"
						size="icon"
						className={className}
						title={t("nav.switchLanguage")}
					>
						<Globe className="h-[1.2rem] w-[1.2rem]" />
						<span className="sr-only">{t("nav.switchLanguage")}</span>
					</Button>
				</DropdownMenuTrigger>
				<DropdownMenuContent align="end">
					{SUPPORTED_LOCALES.map((l) => (
						<DropdownMenuItem
							key={l.code}
							className={`cursor-pointer ${locale === l.code ? "font-semibold text-primary" : ""}`}
							onClick={() => setLocale(l.code)}
						>
							<span className="mr-2 text-xs font-bold text-muted-foreground">{l.label}</span>
							{l.name}
						</DropdownMenuItem>
					))}
				</DropdownMenuContent>
			</DropdownMenu>
		);
	}

	// Default "icon" variant: matching ModeToggle's icon button
	return (
		<Button
			variant="outline"
			size="icon"
			onClick={toggleLanguage}
			className={className}
			title={locale === "zh" ? "当前：简体中文 (点击切换为 English)" : "Current: English (Click to switch to Chinese)"}
		>
			<span className="font-semibold text-xs tracking-tight">
				{locale === "zh" ? "中" : "EN"}
			</span>
			<span className="sr-only">Toggle language</span>
		</Button>
	);
}
